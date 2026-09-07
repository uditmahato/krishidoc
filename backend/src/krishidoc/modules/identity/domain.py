"""Device identity domain."""

from __future__ import annotations

import base64
import binascii
from dataclasses import dataclass, replace
from datetime import datetime
from typing import Protocol
from uuid import UUID

# Ed25519 public keys are exactly 32 bytes. Accepting anything else would let
# a client park arbitrary data in the identity table.
_ED25519_KEY_BYTES = 32
_MAX_PLATFORM_LENGTH = 32
_MAX_APP_VERSION_LENGTH = 32


class InvalidPublicKeyError(ValueError):
    """The submitted device key is not a usable Ed25519 public key."""


def normalize_public_key(raw: str) -> str:
    """Validates and canonicalises a base64 Ed25519 public key.

    Canonical form matters: the key is the lookup identity for a device, and
    two encodings of the same key would otherwise create two devices.
    """
    candidate = raw.strip()
    if not candidate:
        raise InvalidPublicKeyError("public key must not be empty")
    try:
        decoded = base64.b64decode(candidate, validate=True)
    except (binascii.Error, ValueError) as error:
        raise InvalidPublicKeyError("public key must be valid base64") from error
    if len(decoded) != _ED25519_KEY_BYTES:
        raise InvalidPublicKeyError(
            f"public key must decode to {_ED25519_KEY_BYTES} bytes, got {len(decoded)}"
        )
    return base64.b64encode(decoded).decode()


def normalize_label(value: str, *, field: str, limit: int) -> str:
    trimmed = value.strip()
    if not trimmed:
        raise ValueError(f"{field} must not be empty")
    if len(trimmed) > limit:
        raise ValueError(f"{field} must be at most {limit} characters")
    return trimmed


@dataclass(frozen=True)
class Device:
    id: UUID
    public_key: str
    platform: str
    app_version: str
    created_at: datetime

    # Identifier of the refresh token currently valid for this device. A
    # presented token whose jti is not this one has been rotated already,
    # which means it leaked.
    current_refresh_jti: str | None = None

    def with_refresh(self, jti: str | None) -> Device:
        return replace(self, current_refresh_jti=jti)


class DeviceRepository(Protocol):
    async def get(self, device_id: UUID) -> Device | None: ...

    async def get_by_public_key(self, public_key: str) -> Device | None: ...

    async def add(self, device: Device) -> None: ...

    async def set_refresh_jti(self, device_id: UUID, jti: str | None) -> None: ...


class InMemoryDeviceRepository:
    """Local and test implementation; Postgres adapter lands with D-28."""

    def __init__(self) -> None:
        self._by_id: dict[UUID, Device] = {}
        self._id_by_key: dict[str, UUID] = {}

    async def get(self, device_id: UUID) -> Device | None:
        return self._by_id.get(device_id)

    async def get_by_public_key(self, public_key: str) -> Device | None:
        device_id = self._id_by_key.get(public_key)
        return self._by_id.get(device_id) if device_id else None

    async def add(self, device: Device) -> None:
        self._by_id[device.id] = device
        self._id_by_key[device.public_key] = device.id

    async def set_refresh_jti(self, device_id: UUID, jti: str | None) -> None:
        device = self._by_id.get(device_id)
        if device is not None:
            self._by_id[device_id] = device.with_refresh(jti)
