"""API application factory (D-26). Run: `uvicorn krishidoc.main_api:create_app --factory`."""

from __future__ import annotations

from fastapi import FastAPI
from pydantic import BaseModel

from krishidoc import __version__
from krishidoc.modules.identity.domain import DeviceRepository, InMemoryDeviceRepository
from krishidoc.modules.identity.router import router as identity_router
from krishidoc.modules.identity.service import IdentityService
from krishidoc.modules.identity.tokens import TokenService
from krishidoc.platform.config import Settings
from krishidoc.platform.errors import register_error_handlers
from krishidoc.platform.idempotency import (
    IdempotencyMiddleware,
    IdempotencyStore,
    InMemoryIdempotencyStore,
)
from krishidoc.platform.logging import configure_logging
from krishidoc.platform.request_id import RequestIdMiddleware


class HealthResponse(BaseModel):
    status: str
    version: str


def create_app(
    *,
    settings: Settings | None = None,
    device_repository: DeviceRepository | None = None,
    idempotency_store: IdempotencyStore | None = None,
) -> FastAPI:
    """Builds the API.

    Dependencies are injected rather than constructed inline so tests run
    against the real code paths with in-memory adapters, and so the Postgres
    and Redis adapters can be swapped in without touching a route.
    """
    configure_logging()
    resolved_settings = settings or Settings.from_env()

    app = FastAPI(
        title="KrishiDoc API",
        version=__version__,
        docs_url=None,
        redoc_url=None,
        openapi_url="/v1/openapi.json",
    )

    app.state.identity_service = IdentityService(
        device_repository or InMemoryDeviceRepository(),
        TokenService(resolved_settings),
    )

    # Middleware runs outermost-first, so the request id is bound before
    # idempotency can short-circuit a replay, and every response carries it.
    app.add_middleware(
        IdempotencyMiddleware,
        store=idempotency_store or InMemoryIdempotencyStore(),
    )
    app.add_middleware(RequestIdMiddleware)
    register_error_handlers(app)
    app.include_router(identity_router)

    @app.get("/healthz", response_model=HealthResponse, include_in_schema=False)
    async def healthz() -> HealthResponse:
        return HealthResponse(status="ok", version=__version__)

    return app
