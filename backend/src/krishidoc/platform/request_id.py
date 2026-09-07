"""Request-id propagation (D-38): accept `X-Request-Id` or mint one, expose it
on the response, and bind it to log records for end-to-end correlation."""

from __future__ import annotations

import contextvars
import re
import uuid

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

REQUEST_ID_HEADER = "X-Request-Id"
_SAFE_ID = re.compile(r"^[A-Za-z0-9._-]{8,128}$")

request_id_var: contextvars.ContextVar[str] = contextvars.ContextVar("request_id", default="-")


class RequestIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        supplied = request.headers.get(REQUEST_ID_HEADER, "")
        request_id = supplied if _SAFE_ID.fullmatch(supplied) else uuid.uuid4().hex
        token = request_id_var.set(request_id)
        try:
            response = await call_next(request)
        finally:
            request_id_var.reset(token)
        response.headers[REQUEST_ID_HEADER] = request_id
        return response
