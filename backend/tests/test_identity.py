import base64
import os
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from krishidoc.main_api import create_app
from krishidoc.platform.config import Settings


def device_key() -> str:
    """A syntactically valid Ed25519 public key."""
    return base64.b64encode(os.urandom(32)).decode()


@pytest.fixture()
def client(settings: Settings) -> Iterator[TestClient]:
    with TestClient(create_app(settings=settings)) as test_client:
        yield test_client


def register(client: TestClient, *, key: str | None = None, idempotency_key: str = "reg-1"):
    # `key if key is not None` rather than `key or`: an empty string is a case
    # under test, and truthiness would quietly replace it with a valid key.
    return client.post(
        "/v1/devices",
        json={
            "public_key": key if key is not None else device_key(),
            "platform": "android",
            "app_version": "0.1.0",
        },
        headers={"Idempotency-Key": idempotency_key},
    )


class TestRegistration:
    def test_registers_a_guest_device_and_returns_tokens(self, client: TestClient) -> None:
        response = register(client)

        assert response.status_code == 201
        body = response.json()
        assert body["device_id"]
        assert body["access_token"]
        assert body["refresh_token"]
        assert body["expires_in"] == 900
        # Guest-first (D-13): nothing about an account, an email, or a password.
        assert "password" not in response.text.lower()

    def test_same_key_returns_the_same_device_rather_than_a_duplicate(
        self, client: TestClient
    ) -> None:
        key = device_key()

        first = register(client, key=key, idempotency_key="a")
        second = register(client, key=key, idempotency_key="b")

        assert first.json()["device_id"] == second.json()["device_id"]
        assert first.json()["refresh_token"] != second.json()["refresh_token"]

    @pytest.mark.parametrize(
        ("value", "reason"),
        [
            ("", "empty"),
            ("not base64!!", "not base64"),
            (base64.b64encode(b"short").decode(), "wrong length"),
        ],
    )
    def test_rejects_keys_that_are_not_ed25519(
        self, client: TestClient, value: str, reason: str
    ) -> None:
        response = register(client, key=value)

        assert response.status_code == 400, reason
        assert response.json()["error"]["code"] == "bad_request"

    def test_rejects_an_oversized_platform_label(self, client: TestClient) -> None:
        response = client.post(
            "/v1/devices",
            json={
                "public_key": device_key(),
                "platform": "x" * 100,
                "app_version": "0.1.0",
            },
            headers={"Idempotency-Key": "big-label"},
        )

        assert response.status_code == 400


class TestRefreshRotation:
    def test_rotates_and_returns_a_new_pair(self, client: TestClient) -> None:
        original = register(client).json()

        rotated = client.post(
            "/v1/auth/refresh",
            json={"refresh_token": original["refresh_token"]},
            headers={"Idempotency-Key": "rot-1"},
        )

        assert rotated.status_code == 200
        assert rotated.json()["refresh_token"] != original["refresh_token"]

    def test_a_reused_refresh_token_is_refused(self, client: TestClient) -> None:
        original = register(client).json()
        client.post(
            "/v1/auth/refresh",
            json={"refresh_token": original["refresh_token"]},
            headers={"Idempotency-Key": "rot-1"},
        )

        replay = client.post(
            "/v1/auth/refresh",
            json={"refresh_token": original["refresh_token"]},
            headers={"Idempotency-Key": "rot-2"},
        )

        assert replay.status_code == 401

    def test_reuse_revokes_the_whole_device_session(self, client: TestClient) -> None:
        # A stolen token is indistinguishable from a stale one, so reuse must
        # invalidate the chain rather than merely refusing the older token.
        original = register(client).json()
        rotated = client.post(
            "/v1/auth/refresh",
            json={"refresh_token": original["refresh_token"]},
            headers={"Idempotency-Key": "rot-1"},
        ).json()

        client.post(
            "/v1/auth/refresh",
            json={"refresh_token": original["refresh_token"]},
            headers={"Idempotency-Key": "rot-2"},
        )
        after_theft = client.post(
            "/v1/auth/refresh",
            json={"refresh_token": rotated["refresh_token"]},
            headers={"Idempotency-Key": "rot-3"},
        )

        assert after_theft.status_code == 401

    def test_an_access_token_cannot_be_used_to_refresh(self, client: TestClient) -> None:
        tokens = register(client).json()

        response = client.post(
            "/v1/auth/refresh",
            json={"refresh_token": tokens["access_token"]},
            headers={"Idempotency-Key": "rot-x"},
        )

        assert response.status_code == 401

    def test_garbage_and_foreign_tokens_are_refused_identically(
        self, client: TestClient, settings: Settings
    ) -> None:
        forged_app = create_app(
            settings=Settings(token_signing_key="a-different-key-of-sufficient-len")
        )
        with TestClient(forged_app) as other:
            foreign = register(other).json()["refresh_token"]

        garbage_response = client.post(
            "/v1/auth/refresh",
            json={"refresh_token": "not-a-token"},
            headers={"Idempotency-Key": "g1"},
        )
        foreign_response = client.post(
            "/v1/auth/refresh",
            json={"refresh_token": foreign},
            headers={"Idempotency-Key": "g2"},
        )

        assert garbage_response.status_code == 401
        assert foreign_response.status_code == 401
        # Identical wording: a token holder must not learn why it failed.
        assert garbage_response.json() == foreign_response.json()
