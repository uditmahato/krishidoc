"""Uniform error envelope (D-27).

Every non-2xx response body is exactly `{"error": {...}}` so generated
clients decode one shape. Internal details never leak: unexpected
exceptions map to an opaque `internal` code.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger("krishidoc.errors")

_HTTP_CODE_NAMES: dict[int, str] = {
    400: "bad_request",
    401: "unauthenticated",
    403: "forbidden",
    404: "not_found",
    409: "conflict",
    422: "validation_failed",
    429: "rate_limited",
}


class ErrorBody(BaseModel):
    code: str
    message: str
    retriable: bool
    details: dict[str, Any] | None = None


class ErrorEnvelope(BaseModel):
    error: ErrorBody


def envelope(
    status: int,
    code: str,
    message: str,
    *,
    retriable: bool | None = None,
    details: dict[str, Any] | None = None,
    headers: dict[str, str] | None = None,
) -> JSONResponse:
    body = ErrorEnvelope(
        error=ErrorBody(
            code=code,
            message=message,
            retriable=retriable if retriable is not None else status in (429, 503),
            details=details,
        )
    )
    return JSONResponse(status_code=status, content=body.model_dump(), headers=headers)


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        code = _HTTP_CODE_NAMES.get(exc.status_code, f"http_{exc.status_code}")
        message = exc.detail if isinstance(exc.detail, str) else code
        return envelope(exc.status_code, code, message, headers=dict(exc.headers or {}))

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        # Strip submitted values and doc links: clients get locations and
        # reasons, never an echo of what they sent.
        sanitized = [
            {key: value for key, value in error.items() if key not in ("input", "url")}
            for error in exc.errors()
        ]
        return envelope(
            422,
            "validation_failed",
            "Request failed validation.",
            details={"errors": sanitized},
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
        logger.exception("unhandled error on %s %s", request.method, request.url.path)
        return envelope(500, "internal", "Internal error.", retriable=True)
