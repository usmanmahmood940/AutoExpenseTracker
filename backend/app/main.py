"""FastAPI application factory.

Route paths follow the API table in docs/backend-migration-plan.md exactly (no
version prefix) so `/docs` is a faithful contract for the Flutter client.
"""

from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import (
    analytics,
    auth,
    categories,
    health,
    ingest,
    jobs,
    me,
    merchants,
    period_stats,
    review,
    transactions,
)
from app.core import firebase
from app.core.config import Settings, get_settings
from app.core.errors import register_error_handlers
from app.core.logging import configure_logging
from app.core.middleware import RequestContextMiddleware
from app.db.session import dispose_engine

logger = logging.getLogger(__name__)

API_VERSION = "0.1.0"
API_DESCRIPTION = (
    "NovaSpend backend. Auth is a facade over Firebase Auth; product data lives "
    "in PostgreSQL."
)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings: Settings = app.state.settings
    logger.info(
        "startup",
        extra={"environment": settings.environment, "version": API_VERSION},
    )
    # Non-fatal: an unconfigured identity provider degrades /health/ready and
    # fails auth routes with 503, but the service still boots.
    firebase.init_firebase(settings)
    try:
        yield
    finally:
        await dispose_engine()
        firebase.shutdown_firebase()
        logger.info("shutdown")


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    configure_logging(settings)

    app = FastAPI(
        title="NovaSpend API",
        version=API_VERSION,
        description=API_DESCRIPTION,
        lifespan=lifespan,
        docs_url="/docs" if settings.docs_enabled else None,
        redoc_url=None,
        openapi_url="/openapi.json" if settings.docs_enabled else None,
    )
    app.state.settings = settings

    if settings.cors_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
            expose_headers=["X-Request-Id"],
        )

    app.add_middleware(RequestContextMiddleware)
    register_error_handlers(app)

    app.include_router(health.router)
    app.include_router(auth.router)
    app.include_router(me.router)
    app.include_router(ingest.router)
    app.include_router(jobs.router)
    app.include_router(transactions.router)
    app.include_router(period_stats.router)
    app.include_router(analytics.router)
    app.include_router(merchants.router)
    app.include_router(review.router)
    app.include_router(categories.router)

    return app


app = create_app()
