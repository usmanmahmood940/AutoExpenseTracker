# syntax=docker/dockerfile:1
FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Dependencies first so code edits do not invalidate the install layer.
# asyncpg ships wheels, so no libpq or build toolchain is needed.
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY alembic.ini ./
COPY alembic ./alembic
COPY app ./app

RUN useradd --create-home --uid 1000 appuser \
    && chown -R appuser:appuser /app
USER appuser

# Cloud Run injects PORT and ignores EXPOSE; this is for local `docker run`.
ENV PORT=8080
EXPOSE 8080

# Shell form so ${PORT} expands. Cloud Run terminates TLS, so no certs here.
CMD exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --workers 1
