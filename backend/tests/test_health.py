"""Phase A exit criteria: the service boots, answers /health, and serves /docs."""

from __future__ import annotations

from fastapi.testclient import TestClient


def test_health_is_ok_without_dependencies(client: TestClient) -> None:
    with client:
        response = client.get("/health")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["environment"] == "local"


def test_health_echoes_request_id(client: TestClient) -> None:
    with client:
        response = client.get("/health", headers={"X-Request-Id": "abc123"})

    assert response.headers["X-Request-Id"] == "abc123"


def test_readiness_reports_a_live_database(client: TestClient) -> None:
    with client:
        response = client.get("/health/ready")

    dependencies = response.json()["dependencies"]
    assert dependencies["database"] == "ok"
    # Firebase is typically "unconfigured" locally, which makes the whole probe
    # degrade to 503 by design — that is what keeps an unconfigured revision out
    # of a load balancer.
    assert response.status_code == (200 if dependencies["firebase"] == "ok" else 503)


def test_openapi_contract_is_served(client: TestClient) -> None:
    with client:
        assert client.get("/docs").status_code == 200
        schema = client.get("/openapi.json").json()

    assert schema["info"]["title"] == "NovaSpend API"
    assert "/health" in schema["paths"]
