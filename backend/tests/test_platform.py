from collections.abc import Iterator

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from pydantic import BaseModel

from krishidoc import __version__
from krishidoc.main_api import create_app
from krishidoc.platform.request_id import REQUEST_ID_HEADER


@pytest.fixture()
def client() -> Iterator[TestClient]:
    app = create_app()

    @app.get("/boom-http")
    async def boom_http() -> None:
        raise HTTPException(status_code=409, detail="Version conflict.")

    @app.get("/boom-crash")
    async def boom_crash() -> None:
        raise RuntimeError("secret internal detail")

    class EchoBody(BaseModel):
        count: int

    @app.post("/echo")
    async def echo(body: EchoBody) -> EchoBody:
        return body

    with TestClient(app, raise_server_exceptions=False) as test_client:
        yield test_client


def test_healthz_ok_with_minted_request_id(client: TestClient) -> None:
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "version": __version__}
    assert len(response.headers[REQUEST_ID_HEADER]) == 32


def test_supplied_request_id_is_echoed(client: TestClient) -> None:
    response = client.get("/healthz", headers={REQUEST_ID_HEADER: "client-abc-123"})
    assert response.headers[REQUEST_ID_HEADER] == "client-abc-123"


def test_unsafe_request_id_is_replaced(client: TestClient) -> None:
    response = client.get("/healthz", headers={REQUEST_ID_HEADER: "bad id!\n"})
    assert response.headers[REQUEST_ID_HEADER] != "bad id!\n"


def test_404_uses_error_envelope(client: TestClient) -> None:
    body = client.get("/no-such-route").json()
    error = body["error"]
    assert error["code"] == "not_found"
    assert error["retriable"] is False
    assert set(error) == {"code", "message", "retriable", "details"}


def test_http_exception_maps_to_envelope(client: TestClient) -> None:
    response = client.get("/boom-http")
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "conflict"
    assert response.json()["error"]["message"] == "Version conflict."


def test_unhandled_error_is_opaque_and_retriable(client: TestClient) -> None:
    response = client.get("/boom-crash")
    assert response.status_code == 500
    error = response.json()["error"]
    assert error == {
        "code": "internal",
        "message": "Internal error.",
        "retriable": True,
        "details": None,
    }
    assert "secret" not in response.text


def test_method_not_allowed_uses_envelope(client: TestClient) -> None:
    response = client.post("/boom-http")
    assert response.status_code == 405
    assert response.json()["error"]["code"] == "http_405"


def test_validation_error_never_echoes_submitted_values(client: TestClient) -> None:
    response = client.post("/echo", json={"count": "not-a-number", "note": "s3cret-value"})
    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "validation_failed"
    assert error["details"]["errors"], "expected at least one validation item"
    for item in error["details"]["errors"]:
        assert "input" not in item
        assert "url" not in item
    assert "s3cret-value" not in response.text
    assert "not-a-number" not in response.text
