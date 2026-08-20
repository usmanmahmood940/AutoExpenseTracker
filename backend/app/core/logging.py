"""Structured logging.

Emits Cloud Logging compatible JSON when deployed so Cloud Run parses severity
and groups entries, and plain lines locally where a human is reading them.
"""

from __future__ import annotations

import json
import logging
import sys
from contextvars import ContextVar
from typing import Any

from app.core.config import Settings

request_id_var: ContextVar[str | None] = ContextVar("request_id", default=None)
uid_var: ContextVar[str | None] = ContextVar("uid", default=None)

# Cloud Logging uses its own severity vocabulary; WARNING/ERROR happen to match.
_SEVERITY = {
    logging.DEBUG: "DEBUG",
    logging.INFO: "INFO",
    logging.WARNING: "WARNING",
    logging.ERROR: "ERROR",
    logging.CRITICAL: "CRITICAL",
}

_RESERVED = frozenset(logging.LogRecord("", 0, "", 0, "", None, None).__dict__) | {
    "message",
    "asctime",
    "taskName",
    # uvicorn attaches an ANSI-decorated copy of its own message.
    "color_message",
}


def _extras(record: logging.LogRecord) -> dict[str, Any]:
    return {
        key: value
        for key, value in record.__dict__.items()
        if key not in _RESERVED and not key.startswith("_")
    }


class JsonFormatter(logging.Formatter):
    def __init__(self, service_name: str) -> None:
        super().__init__()
        self.service_name = service_name

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "severity": _SEVERITY.get(record.levelno, record.levelname),
            "message": record.getMessage(),
            "logger": record.name,
            "service": self.service_name,
        }

        if request_id := request_id_var.get():
            payload["requestId"] = request_id
        if uid := uid_var.get():
            payload["uid"] = uid
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        payload.update(_extras(record))

        return json.dumps(payload, default=str)


class TextFormatter(logging.Formatter):
    def __init__(self) -> None:
        super().__init__(
            fmt="%(asctime)s %(levelname)-8s %(name)s: %(message)s",
            datefmt="%H:%M:%S",
        )

    def format(self, record: logging.LogRecord) -> str:
        base = super().format(record)
        context = []
        if request_id := request_id_var.get():
            context.append(request_id[:8])
        if uid := uid_var.get():
            context.append(f"uid={uid}")
        extras = " ".join(f"{k}={v}" for k, v in _extras(record).items())
        suffix = " ".join(part for part in (" ".join(context), extras) if part)
        return f"{base} {suffix}".rstrip() if suffix else base


def configure_logging(settings: Settings) -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(
        JsonFormatter(settings.service_name) if settings.log_json else TextFormatter()
    )

    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(settings.log_level)

    # uvicorn ships its own handlers; drop them so everything goes through ours
    # in one format. access logs are replaced by RequestContextMiddleware.
    for name in ("uvicorn", "uvicorn.error", "uvicorn.access"):
        logger = logging.getLogger(name)
        logger.handlers = []
        logger.propagate = True
    logging.getLogger("uvicorn.access").disabled = True
