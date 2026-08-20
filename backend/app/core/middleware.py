"""Request-scoped context and access logging."""

from __future__ import annotations

import logging
import time
import uuid

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

from app.core.logging import request_id_var, uid_var

logger = logging.getLogger("app.access")

REQUEST_ID_HEADER = "X-Request-Id"


def _incoming_request_id(request: Request) -> str:
    if incoming := request.headers.get(REQUEST_ID_HEADER):
        return incoming[:128]
    # Reuse the Cloud Run trace id when present so app logs correlate with the
    # request entry Google generates. Format: TRACE_ID/SPAN_ID;o=1
    if trace := request.headers.get("X-Cloud-Trace-Context"):
        return trace.split("/", 1)[0][:128]
    return uuid.uuid4().hex


class RequestContextMiddleware(BaseHTTPMiddleware):
    """Attaches a request id to logs and emits one access line per request."""

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        request_id = _incoming_request_id(request)
        request_id_token = request_id_var.set(request_id)
        uid_token = uid_var.set(None)
        request.state.request_id = request_id

        started = time.perf_counter()
        status_code = 500
        try:
            response = await call_next(request)
            status_code = response.status_code
            response.headers[REQUEST_ID_HEADER] = request_id
            return response
        finally:
            duration_ms = round((time.perf_counter() - started) * 1000, 2)
            # Health checks fire constantly; keep them out of the normal stream.
            level = (
                logging.DEBUG
                if request.url.path.startswith("/health")
                else (logging.INFO if status_code < 500 else logging.ERROR)
            )
            logger.log(
                level,
                "request",
                extra={
                    "method": request.method,
                    "path": request.url.path,
                    "status": status_code,
                    "durationMs": duration_ms,
                },
            )
            request_id_var.reset(request_id_token)
            uid_var.reset(uid_token)
