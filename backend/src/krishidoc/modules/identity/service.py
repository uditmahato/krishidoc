"""Identity use cases."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime

from krishidoc.modules.identity.domain import (
    Device,
    DeviceRepository,
    normalize_label,
    normalize_public_key,
)
from krishidoc.modules.identity.tokens import REFRESH, IssuedTokens, TokenError, TokenService
from krishidoc.platform.ids import uuid7


class RefreshRejected(Exception):
    """A refresh token was invalid, expired, or already rotated."""


@dataclass(frozen=True)
class Registration:
    device: Device
    tokens: IssuedTokens
    created: bool


class IdentityService:
    def __init__(self, repository: DeviceRepository, tokens: TokenService) -> None:
        self._repository = repository
        self._tokens = tokens

    async def register_device(
        self, *, public_key: str, platform: str, app_version: str
    ) -> Registration:
        """Registers a device, or re-issues tokens for one already known.

        Registration is keyed on the public key rather than on the request, so
        a reinstall that reuses the same hardware-backed key does not litter
        the table with duplicate identities.
        """
        key = normalize_public_key(public_key)
        existing = await self._repository.get_by_public_key(key)

        device = existing or Device(
            id=uuid7(),
            public_key=key,
            platform=normalize_label(platform, field="platform", limit=32),
            app_version=normalize_label(app_version, field="app_version", limit=32),
            created_at=datetime.now(UTC),
        )
        if existing is None:
            await self._repository.add(device)

        issued = self._tokens.issue(device.id)
        await self._repository.set_refresh_jti(device.id, issued.refresh_jti)
        return Registration(device=device, tokens=issued, created=existing is None)

    async def refresh(self, refresh_token: str) -> IssuedTokens:
        """Rotates a refresh token, detecting reuse.

        Rotation means the presented token is spent. If a token arrives whose
        id is not the one currently on file, either it is stale or it leaked,
        and the two are indistinguishable from here. The safe reading is theft:
        every token for the device is revoked, so the legitimate holder is
        forced to re-register rather than silently sharing a session with an
        attacker.
        """
        try:
            claims = self._tokens.verify(refresh_token, expected_type=REFRESH)
        except TokenError as error:
            raise RefreshRejected(str(error)) from error

        device = await self._repository.get(claims.device_id)
        if device is None:
            raise RefreshRejected("unknown device")

        if device.current_refresh_jti != claims.jti:
            await self._repository.set_refresh_jti(device.id, None)
            raise RefreshRejected("refresh token has already been used")

        issued = self._tokens.issue(device.id)
        await self._repository.set_refresh_jti(device.id, issued.refresh_jti)
        return issued
