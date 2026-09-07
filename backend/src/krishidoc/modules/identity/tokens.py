"""Device token minting and verification (D-13).

Short-lived access tokens with long-lived, rotating, device-bound refresh
tokens. There are no passwords in this system at all: V1's login screen
promised an account it could not create, and its "reset" accepted a
hardcoded code. Nothing here can grow into that.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID

import jwt

from krishidoc.platform.config import Settings

_ALGORITHM = "HS256"
ACCESS = "access"
REFRESH = "refresh"


class TokenError(Exception):
    """A token was absent, malformed, expired, or of the wrong kind."""


@dataclass(frozen=True)
class IssuedTokens:
    access_token: str
    refresh_token: str
    refresh_jti: str
    expires_in: int


@dataclass(frozen=True)
class TokenClaims:
    device_id: UUID
    jti: str
    token_type: str


class TokenService:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def issue(self, device_id: UUID, *, now: datetime | None = None) -> IssuedTokens:
        moment = now or datetime.now(UTC)
        refresh_jti = uuid.uuid4().hex
        return IssuedTokens(
            access_token=self._mint(
                device_id,
                ACCESS,
                uuid.uuid4().hex,
                self._settings.access_token_ttl_seconds,
                moment,
            ),
            refresh_token=self._mint(
                device_id,
                REFRESH,
                refresh_jti,
                self._settings.refresh_token_ttl_seconds,
                moment,
            ),
            refresh_jti=refresh_jti,
            expires_in=self._settings.access_token_ttl_seconds,
        )

    def verify(self, token: str, *, expected_type: str) -> TokenClaims:
        try:
            payload = jwt.decode(
                token,
                self._settings.token_signing_key,
                algorithms=[_ALGORITHM],
                options={"require": ["exp", "sub", "jti"]},
            )
        except jwt.PyJWTError as error:
            raise TokenError(str(error)) from error

        token_type = payload.get("typ")
        if token_type != expected_type:
            # Refusing a refresh token where an access token belongs (and the
            # reverse) keeps a long-lived credential from standing in for a
            # short-lived one.
            raise TokenError(f"expected a {expected_type} token, got {token_type}")

        try:
            device_id = UUID(payload["sub"])
        except (KeyError, ValueError) as error:
            raise TokenError("token subject is not a device id") from error

        return TokenClaims(
            device_id=device_id,
            jti=str(payload["jti"]),
            token_type=token_type,
        )

    def _mint(
        self,
        device_id: UUID,
        token_type: str,
        jti: str,
        ttl_seconds: int,
        now: datetime,
    ) -> str:
        return jwt.encode(
            {
                "sub": str(device_id),
                "typ": token_type,
                "jti": jti,
                "iat": int(now.timestamp()),
                "exp": int((now + timedelta(seconds=ttl_seconds)).timestamp()),
            },
            self._settings.token_signing_key,
            algorithm=_ALGORITHM,
        )
