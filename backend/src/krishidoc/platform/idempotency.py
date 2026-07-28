"""Idempotency-Key enforcement for mutating requests (D-27).

Offline-first clients retry: a farmer's phone loses signal mid-request and
tries again when it returns, with no way to know whether the first attempt
landed. Without replay protection a retry registers a second device or files
a second referral. Every mutation therefore carries a key, and a repeat of
the same key returns the first response instead of doing the work twice.

The store is a port. In production it is Redis (D-04: cache and short-lived
coordination, never durable state); the in-memory implementation here is what
tests and local development use.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Protocol

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint

from krishidoc.platform.errors import envelope

IDEMPOTENCY_HEADER = "Idempotency-Key"
_MUTATING_METHODS = frozenset({"POST", "PUT", "PATCH", "DELETE"})


@dataclass(frozen=True)
class StoredResponse:
    status_code: int
    body: bytes
    fingerprint: str


class IdempotencyStore(Protocol):
    """Records in-flight and completed requests by key."""

    async def begin(self, key: str, fingerprint: str) -> StoredResponse | None:
        """Claim [key], or return what is already known about it.

        Returns None when the caller now owns the key and should do the work.
        """

    async def complete(self, key: str, response: StoredResponse) -> None: ...

    async def release(self, key: str) -> None:
        """Drop a claim whose work failed, so a retry may try again."""


class InMemoryIdempotencyStore:
    """Single-process store for tests and local development."""

    def __init__(self) -> None:
        self._claimed: dict[str, str] = {}
        self._completed: dict[str, StoredResponse] = {}

    async def begin(self, key: str, fingerprint: str) -> StoredResponse | None:
        completed = self._completed.get(key)
        if completed is not None:
            return completed
        claimed = self._claimed.get(key)
        if claimed is not None:
            # Still running: report it as such rather than duplicating work.
            return StoredResponse(status_code=0, body=b"", fingerprint=claimed)
        self._claimed[key] = fingerprint
        return None

    async def complete(self, key: str, response: StoredResponse) -> None:
        self._completed[key] = response
        self._claimed.pop(key, None)

    async def release(self, key: str) -> None:
        self._claimed.pop(key, None)


def fingerprint_request(method: str, path: str, body: bytes) -> str:
    digest = hashlib.sha256()
    digest.update(method.encode())
    digest.update(b"\0")
    digest.update(path.encode())
    digest.update(b"\0")
    digest.update(body)
    return digest.hexdigest()


class IdempotencyMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: object, store: IdempotencyStore) -> None:
        super().__init__(app)  # type: ignore[arg-type]
        self._store = store

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        if request.method not in _MUTATING_METHODS or not request.url.path.startswith("/v1/"):
            return await call_next(request)

        key = request.headers.get(IDEMPOTENCY_HEADER, "").strip()
        if not key:
            return envelope(
                400,
                "idempotency_key_required",
                f"{IDEMPOTENCY_HEADER} is required on this request.",
                retriable=False,
            )

        body = await request.body()
        fingerprint = fingerprint_request(request.method, request.url.path, body)

        known = await self._store.begin(key, fingerprint)
        if known is not None:
            if known.fingerprint != fingerprint:
                # The same key with a different body is a client bug, and
                # replaying the old response would hide it.
                return envelope(
                    409,
                    "idempotency_key_reused",
                    f"{IDEMPOTENCY_HEADER} was already used for a different request.",
                    retriable=False,
                )
            if known.status_code == 0:
                return envelope(
                    409,
                    "request_in_flight",
                    "An identical request is still being processed.",
                    retriable=True,
                )
            return Response(
                content=known.body,
                status_code=known.status_code,
                media_type="application/json",
                headers={"Idempotent-Replay": "true"},
            )

        try:
            response = await call_next(request)
        except Exception:
            await self._store.release(key)
            raise

        chunks = [chunk async for chunk in response.body_iterator]  # type: ignore[attr-defined]
        payload = b"".join(chunks)

        if 200 <= response.status_code < 300:
            await self._store.complete(
                key,
                StoredResponse(
                    status_code=response.status_code,
                    body=payload,
                    fingerprint=fingerprint,
                ),
            )
        else:
            # Failures stay retriable: a 500 the client retries should get a
            # real attempt, not a replayed error.
            await self._store.release(key)

        return Response(
            content=payload,
            status_code=response.status_code,
            media_type=response.media_type,
            headers=dict(response.headers),
        )


def json_body(payload: object) -> bytes:
    return json.dumps(payload).encode()
