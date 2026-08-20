"""Every failure must leave the API as {"detail", "code"}."""

from __future__ import annotations

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.deps import CurrentIdentity
from app.core.errors import ConflictError
from app.main import create_app


@pytest.fixture
def app_with_probes() -> FastAPI:
    app = create_app()

    @app.get("/_test/protected")
    async def protected(identity: CurrentIdentity) -> dict[str, str]:
        return {"uid": identity.uid}

    @app.get("/_test/conflict")
    async def conflict() -> None:
        raise ConflictError("Email already registered.", code="email_exists")

    @app.get("/_test/boom")
    async def boom() -> None:
        raise RuntimeError("database password is hunter2")

    return app


def test_unknown_route_uses_the_envelope(client: TestClient) -> None:
    with client:
        response = client.get("/does-not-exist")

    assert response.status_code == 404
    assert response.json() == {"detail": "Not Found", "code": "not_found"}


def test_missing_bearer_token_is_rejected(app_with_probes: FastAPI) -> None:
    with TestClient(app_with_probes) as client:
        response = client.get("/_test/protected")

    assert response.status_code == 401
    assert response.json()["code"] == "token_missing"


def test_garbage_bearer_token_is_rejected(app_with_probes: FastAPI) -> None:
    with TestClient(app_with_probes) as client:
        response = client.get(
            "/_test/protected", headers={"Authorization": "Bearer not-a-jwt"}
        )

    # 503 when Firebase Admin never initialized (no local credentials), 401 once
    # it has. Either way the request is refused and the envelope is intact.
    assert response.status_code in (401, 503)
    assert response.json()["code"] in ("token_invalid", "auth_unavailable")


def test_domain_errors_carry_their_code(app_with_probes: FastAPI) -> None:
    with TestClient(app_with_probes) as client:
        response = client.get("/_test/conflict")

    assert response.status_code == 409
    assert response.json() == {
        "detail": "Email already registered.",
        "code": "email_exists",
    }


def test_unhandled_errors_do_not_leak_internals(app_with_probes: FastAPI) -> None:
    with TestClient(app_with_probes, raise_server_exceptions=False) as client:
        response = client.get("/_test/boom")

    assert response.status_code == 500
    assert response.json() == {
        "detail": "Something went wrong.",
        "code": "internal_error",
    }
    assert "hunter2" not in response.text


def test_health_stays_public(client: TestClient) -> None:
    with client:
        response = client.get("/health", headers={"Authorization": "Basic nope"})

    # Guards against a global auth dependency being added later and locking
    # Cloud Run's probes out of the service.
    assert response.status_code == 200
