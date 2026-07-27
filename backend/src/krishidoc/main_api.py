"""API application factory (D-26). Run: `uvicorn krishidoc.main_api:create_app --factory`."""

from __future__ import annotations

from fastapi import FastAPI
from pydantic import BaseModel

from krishidoc import __version__
from krishidoc.platform.errors import register_error_handlers
from krishidoc.platform.logging import configure_logging
from krishidoc.platform.request_id import RequestIdMiddleware


class HealthResponse(BaseModel):
    status: str
    version: str


def create_app() -> FastAPI:
    configure_logging()
    app = FastAPI(
        title="KrishiDoc API",
        version=__version__,
        docs_url=None,
        redoc_url=None,
        openapi_url="/v1/openapi.json",
    )
    app.add_middleware(RequestIdMiddleware)
    register_error_handlers(app)

    @app.get("/healthz", response_model=HealthResponse, include_in_schema=False)
    async def healthz() -> HealthResponse:
        return HealthResponse(status="ok", version=__version__)

    return app
