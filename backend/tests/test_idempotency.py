import base64
import os
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from krishidoc.main_api import create_app
from krishidoc.platform.config import Settings


@pytest.fixture()
def client(settings: Settings) -> Iterator[TestClient]:
    with TestClient(create_app(settings=settings)) as test_client:
        yield test_client


def body() -> dict[str, str]:
    return {
        "public_key": base64.b64encode(os.urandom(32)).decode(),
        "platform": "android",
        "app_version": "0.1.0",
    }


def test_a_mutation_without_a_key_is_refused(client: TestClient) -> None:
    response = client.post("/v1/devices", json=body())

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "idempotency_key_required"


def test_reads_do_not_require_a_key(client: TestClient) -> None:
    assert client.get("/healthz").status_code == 200


def test_a_retried_request_replays_the_first_response(client: TestClient) -> None:
    payload = body()
    headers = {"Idempotency-Key": "retry-me"}

    first = client.post("/v1/devices", json=payload, headers=headers)
    second = client.post("/v1/devices", json=payload, headers=headers)

    assert first.status_code == 201
    assert second.status_code == 201
    # The retry must not have registered a second device or minted new tokens.
    assert second.json() == first.json()
    assert second.headers.get("Idempotent-Replay") == "true"
    assert first.headers.get("Idempotent-Replay") is None


def test_the_same_key_with_a_different_body_is_a_conflict(
    client: TestClient,
) -> None:
    headers = {"Idempotency-Key": "shared"}
    client.post("/v1/devices", json=body(), headers=headers)

    response = client.post("/v1/devices", json=body(), headers=headers)

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "idempotency_key_reused"


def test_a_failed_request_stays_retriable(client: TestClient) -> None:
    headers = {"Idempotency-Key": "was-invalid"}
    broken = dict(body(), public_key="not base64!!")

    first = client.post("/v1/devices", json=broken, headers=headers)
    # Same key, now with a valid payload: a client fixing its input and
    # retrying must not be stuck behind a cached failure.
    second = client.post("/v1/devices", json=body(), headers=headers)

    assert first.status_code == 400
    assert second.status_code == 201


def test_the_request_id_survives_a_replayed_response(client: TestClient) -> None:
    payload = body()
    headers = {"Idempotency-Key": "with-request-id"}

    client.post("/v1/devices", json=payload, headers=headers)
    replay = client.post("/v1/devices", json=payload, headers=headers)

    assert replay.headers.get("X-Request-Id")
