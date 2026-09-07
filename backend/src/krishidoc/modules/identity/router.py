"""Identity endpoints under /v1 (D-27)."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request, status
from pydantic import BaseModel, Field

from krishidoc.modules.identity.domain import InvalidPublicKeyError
from krishidoc.modules.identity.service import IdentityService, RefreshRejected


class RegisterDeviceRequest(BaseModel):
    public_key: str = Field(
        description="Base64 Ed25519 public key held in hardware-backed storage.",
    )
    platform: str = Field(description='Client platform, for example "android".')
    app_version: str = Field(description="Client app version.")


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    expires_in: int


class RegisterDeviceResponse(TokenResponse):
    device_id: str


class RefreshRequest(BaseModel):
    refresh_token: str


router = APIRouter(prefix="/v1", tags=["identity"])


def _service(request: Request) -> IdentityService:
    return request.app.state.identity_service  # type: ignore[no-any-return]


@router.post(
    "/devices",
    response_model=RegisterDeviceResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a device and receive its tokens",
)
async def register_device(body: RegisterDeviceRequest, request: Request) -> RegisterDeviceResponse:
    try:
        registration = await _service(request).register_device(
            public_key=body.public_key,
            platform=body.platform,
            app_version=body.app_version,
        )
    except InvalidPublicKeyError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error

    return RegisterDeviceResponse(
        device_id=str(registration.device.id),
        access_token=registration.tokens.access_token,
        refresh_token=registration.tokens.refresh_token,
        expires_in=registration.tokens.expires_in,
    )


@router.post(
    "/auth/refresh",
    response_model=TokenResponse,
    summary="Rotate a refresh token",
)
async def refresh_tokens(body: RefreshRequest, request: Request) -> TokenResponse:
    try:
        issued = await _service(request).refresh(body.refresh_token)
    except RefreshRejected as error:
        # Deliberately uniform: distinguishing "expired" from "already used"
        # would tell an attacker holding a stolen token which it is.
        raise HTTPException(status_code=401, detail="Refresh token is not valid.") from error

    return TokenResponse(
        access_token=issued.access_token,
        refresh_token=issued.refresh_token,
        expires_in=issued.expires_in,
    )
