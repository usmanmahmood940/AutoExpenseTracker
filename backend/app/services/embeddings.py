"""Gemini embeddings for RAG documents.

Falls back to a deterministic hash vector when GEMINI_API_KEY is unset so
local tests and ingest hooks still produce comparable vectors.
"""

from __future__ import annotations

import asyncio
import hashlib
import logging
import math

import httpx

from app.core.config import get_settings
from app.db.models.rag_document import EMBEDDING_DIM
from app.services.gemini import _is_retryable

logger = logging.getLogger(__name__)

_EMBED_ENDPOINT = (
    "https://generativelanguage.googleapis.com/v1beta/models/{model}:embedContent"
)
_BATCH_ENDPOINT = (
    "https://generativelanguage.googleapis.com/v1beta/models/{model}:batchEmbedContents"
)
_BATCH_SIZE = 16


def hash_embed(text: str) -> list[float]:
    """Stable 768-d bag-of-bytes vector. Good enough for tests and local dev."""
    digest = hashlib.sha256(text.encode()).digest()
    vec = [0.0] * EMBEDDING_DIM
    for i, byte in enumerate(text.encode()[:EMBEDDING_DIM] or b"\x00"):
        vec[i] += byte / 255.0
    for i, byte in enumerate(digest):
        vec[i % EMBEDDING_DIM] += (byte / 255.0) * 0.25
    norm = math.sqrt(sum(v * v for v in vec)) or 1.0
    return [v / norm for v in vec]


def _normalize(values: list[float]) -> list[float]:
    if len(values) != EMBEDDING_DIM:
        padded = (values + [0.0] * EMBEDDING_DIM)[:EMBEDDING_DIM]
        values = padded
    norm = math.sqrt(sum(v * v for v in values)) or 1.0
    return [v / norm for v in values]


async def embed_texts(texts: list[str]) -> list[list[float]]:
    if not texts:
        return []
    settings = get_settings()
    api_key = settings.gemini_api_key or ""
    if not api_key:
        return [hash_embed(text) for text in texts]

    model = settings.gemini_embedding_model
    out: list[list[float]] = []
    async with httpx.AsyncClient(timeout=45.0) as client:
        for start in range(0, len(texts), _BATCH_SIZE):
            chunk = texts[start : start + _BATCH_SIZE]
            out.extend(await _embed_chunk(client, api_key, model, chunk))
    return out


async def _embed_chunk(
    client: httpx.AsyncClient,
    api_key: str,
    model: str,
    texts: list[str],
) -> list[list[float]]:
    last_error = "unknown"
    for attempt in range(3):
        try:
            if len(texts) == 1:
                url = _EMBED_ENDPOINT.format(model=model)
                body = {
                    "content": {"parts": [{"text": texts[0]}]},
                    "outputDimensionality": EMBEDDING_DIM,
                }
                response = await client.post(url, params={"key": api_key}, json=body)
                if response.status_code >= 400:
                    raise RuntimeError(f"{response.status_code} {response.text[:400]}")
                values = (response.json().get("embedding") or {}).get("values") or []
                return [_normalize([float(v) for v in values])]

            url = _BATCH_ENDPOINT.format(model=model)
            body = {
                "requests": [
                    {
                        "model": f"models/{model}",
                        "content": {"parts": [{"text": text}]},
                        "outputDimensionality": EMBEDDING_DIM,
                    }
                    for text in texts
                ]
            }
            response = await client.post(url, params={"key": api_key}, json=body)
            if response.status_code >= 400:
                raise RuntimeError(f"{response.status_code} {response.text[:400]}")
            embeddings = response.json().get("embeddings") or []
            return [
                _normalize([float(v) for v in (item.get("values") or [])])
                for item in embeddings
            ]
        except Exception as exc:
            last_error = str(exc)
            if _is_retryable(last_error) and attempt < 2:
                logger.warning("embed retry %s: %s", attempt + 1, exc)
                await asyncio.sleep(1.5)
                continue
            logger.warning("embed failed: %s", exc)
            break
    logger.warning("embed falling back to hash vectors: %s", last_error)
    return [hash_embed(text) for text in texts]
