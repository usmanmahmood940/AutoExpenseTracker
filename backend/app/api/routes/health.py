"""Health and readiness probes."""

from __future__ import annotations

import logging
from typing import Literal

from fastapi import APIRouter, Response, status
from pydantic import BaseModel
from sqlalchemy import text

from app.api.deps import AppSettings, DbSession
from app.core import firebase

logger = logging.getLogger(__name__)

router = APIRouter(tags=["health"])


class HealthResponse(BaseModel):
    status: Literal["ok"] = "ok"
    service: str
    environment: str


class DependencyStatus(BaseModel):
    database: Literal["ok", "error"]
    firebase: Literal["ok", "unconfigured"]
    detail: str | None = None


class ReadyResponse(BaseModel):
    status: Literal["ready", "degraded"]
    dependencies: DependencyStatus


@router.get("/health", response_model=HealthResponse, summary="Liveness probe")
async def health(settings: AppSettings) -> HealthResponse:
    """Cheap liveness check. Touches no dependencies, so it stays green while
    Postgres or Firebase are down and Cloud Run does not kill the revision."""
    return HealthResponse(
        service=settings.service_name, environment=settings.environment
    )


@router.get("/health/ready", response_model=ReadyResponse, summary="Readiness probe")
async def ready(session: DbSession, response: Response) -> ReadyResponse:
    """Verifies the things a real request needs: a live DB and Firebase Admin."""
    detail: str | None = None

    try:
        await session.execute(text("SELECT 1"))
        database: Literal["ok", "error"] = "ok"
    except Exception as exc:
        database = "error"
        detail = str(exc)
        logger.warning("readiness_db_failed", extra={"error": detail})

    firebase_state: Literal["ok", "unconfigured"] = (
        "ok" if firebase.is_available() else "unconfigured"
    )
    if firebase_state == "unconfigured" and detail is None:
        detail = firebase.init_error()

    is_ready = database == "ok" and firebase_state == "ok"
    if not is_ready:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE

    return ReadyResponse(
        status="ready" if is_ready else "degraded",
        dependencies=DependencyStatus(
            database=database, firebase=firebase_state, detail=detail
        ),
    )
