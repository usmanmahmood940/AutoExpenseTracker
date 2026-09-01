# NovaSpend Backend — Encryption & RAG Plan

**Status:** Draft (2026-09-01) — not started  
**Stack:** FastAPI (Cloud Run) + PostgreSQL (Supabase) + pgvector + Gemini  
**App:** NovaSpend (Flutter) — app UI is out of scope for this doc  
**Prerequisite:** Phase F backend migration complete ([backend-migration-plan.md](./backend-migration-plan.md))

This is the plan of record for **field-level encryption of sensitive ingest payloads** (Option A) and **Retrieval-Augmented Generation (RAG)** for chat + proactive Insights. Flutter integration comes after backend phases are stable.

> **Where to start:** [§8 Implementation order](#8-implementation-order-checklist) is the authoritative sequence. [§15 One-page summary](#15-one-page-summary) is the short version.

---

## 1. Goals

### Encryption

- Protect **bank SMS / email raw payloads** at rest in Postgres.
- Keep **structured transaction columns** queryable for SQL analytics, search, and RAG indexing without decrypt loops.
- Preserve the **existing API contract** — clients still receive `sms_source.raw` as plaintext; decryption happens server-side only.
- Ship encryption **before user-facing RAG/chat** goes to production.

### RAG

- Enable **“Ask about my spending”** chat with grounded answers and transaction citations.
- Enable **proactive smart insight cards** on Insights (beyond the existing rule-based + Gemini narrative).
- Generate **dynamic suggested questions** (top 5) that require cross-transaction reasoning, not simple list filters.
- Store vectors in **Supabase Postgres via pgvector** — no separate vector DB (Pinecone, etc.) for MVP.

### Non-goals (this plan)

- Encrypting merchant names, amounts, categories, or dates (Option A).
- Client-side encryption or E2E encryption.
- Replacing Gemini SMS parse at ingest (`functions/src/gemini.ts` / `app/services/gemini.py`).
- Flutter chat UI, Insights UI changes, or push notifications for insights.
- Fine-tuning or hosting custom LLMs.

---

## 2. Decisions locked

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Encryption scope | **Option A** — raw payloads only | ~90% sensitive volume is SMS text; structured fields power the product |
| Vector store | **pgvector on Supabase Postgres** | Same DB as transactions; hybrid SQL + vector queries; already deployed |
| Embedding model | **Gemini `text-embedding-004`** (768 dims) | Same vendor as parse + narrative; REST API from FastAPI |
| RAG document source | **Derived text from structured columns** | Never index or embed raw SMS |
| Chat generation | **Gemini flash models** (same fallback chain as narrative) | Proven in `insights_narrative.py` |
| Cache invalidation | **Fingerprint pattern** (like `ai_summaries`) | `transaction_count` + `source_updated_at` already works |
| API style | **Tool-augmented RAG** | Exact numbers from `analytics.py`; RAG for context and explanation |

---

## 3. Target architecture

```text
┌─────────────────────────────────────────────────────────────────────────┐
│ Flutter (later)                                                         │
│  Chat screen · Insights smart cards · Suggested question chips          │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ HTTPS + Bearer
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ FastAPI (Cloud Run)                                                     │
│  Existing: /ingest  /review  /transactions/*  /analytics/*              │
│  New:      /chat/suggestions  /chat/ask  /insights/smart-cards          │
│           /internal/jobs/reindex-rag                                    │
└───────────────┬─────────────────────────────┬───────────────────────────┘
                │                             │
                ▼                             ▼
┌───────────────────────────────┐   ┌─────────────────────────────────────┐
│ field_crypto.py               │   │ Gemini API                          │
│ encrypt on ingest write       │   │ embed (indexer) · generate (chat)   │
│ decrypt on review/detail only │   │ parse (ingest — unchanged)          │
└───────────────┬───────────────┘   └─────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Supabase PostgreSQL                                                     │
│  transactions (structured plaintext + sms_source metadata)              │
│  raw_ingestions (encrypted raw column)                                  │
│  ai_summaries (existing narrative cache)                                │
│  rag_documents (content_text + vector embedding)          ← NEW         │
│  rag_insight_cache (smart cards cache)                    ← NEW         │
│  chat_messages (optional, phase 3+)                       ← NEW         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Data flow — ingest (unchanged logic, new encrypt step)

```text
SMS → POST /ingest → Gemini parse → structured columns (plaintext)
                                  → encrypt(raw) → raw_ingestions.raw
                                  → encrypt(raw) → transactions.sms_source
                                  → rag_indexer.upsert_transaction_doc()  (phase 2+)
```

### Data flow — chat ask

```text
POST /chat/ask
  → guardrail (in-scope?)
  → intent classify
  → analytics tools (exact totals if needed)
  → pgvector retrieve top-k rag_documents (user_id scoped)
  → Gemini generate (facts + citations only)
  → response { answer, citations[], confidence }
```

---

## 4. Data classification

### Tier 1 — Encrypt at rest

| Location | Field | Content |
|----------|-------|---------|
| `raw_ingestions` | `raw` | Full inbound SMS/email body |
| `transactions` | `sms_source.raw` | Copy of original message (see storage format below) |

**Storage format (Option A1 — recommended for MVP):**

Keep JSONB shape; replace plaintext `raw` with encrypted blob key:

```json
{
  "raw_encrypted": "v1:base64(iv+ciphertext+tag)",
  "source": "ios_shortcut",
  "receivedAt": "2026-07-06T11:27:00+05:00",
  "messageId": "...",
  "idempotencyKey": "..."
}
```

Legacy rows may still have `"raw": "..."` until backfill completes. Readers dual-read both keys.

### Tier 2 — Plaintext (operational + RAG source)

All other `transactions` columns, including:

- `amount`, `currency`, `type`
- `merchant`, `merchant_normalized`, `merchant_details`
- `category`, `category_source`, `payment_method`
- `bank`, `account_id`, `account_id_masked`, `branch`
- `transaction_date`, `transaction_time`, `day`
- `is_recurring`, `recurring_group_id`, `status`, `dedup_key`
- `parse_confidence`, flags (`is_auto_detected`, `is_edited`, etc.)

`raw_ingestions` metadata: `source`, `status`, `received_at`, `message_id`, `idempotency_key`, `transaction_id`, `error`.

### Tier 3 — RAG documents (derived, never from Tier 1)

Built at index time from Tier 2 only. Examples:

```text
transaction | 2026-07-06 | debit | PKR 5990.00 | PSO RANGERS | Fuel | debit_card
merchant    | PSO RANGERS | 12 visits | total PKR 62400 | avg PKR 5200 | last 2026-07-06
period      | 2026-03 | spent PKR 149952 | received PKR 200711 | net +50759 | top Food, Fuel
```

---

## 5. Encryption design

### 5.1 Crypto module

**New file:** `backend/app/services/field_crypto.py`

| Property | Value |
|----------|-------|
| Algorithm | AES-256-GCM |
| Key | 32-byte DEK from `FIELD_ENCRYPTION_KEY` (base64 in env) |
| IV | 12 random bytes per encryption |
| Wire format | `v1:` + base64(`iv ‖ ciphertext ‖ tag`) |
| AAD | Optional bind to `str(user_id)` to prevent cross-user blob swap |

**Public interface:**

```python
def encrypt_plaintext(plaintext: str, *, aad: str | None = None) -> str: ...
def decrypt_ciphertext(blob: str, *, aad: str | None = None) -> str: ...
def is_encrypted(blob: str) -> bool: ...
def maybe_decrypt(blob: str, *, aad: str | None = None) -> str:
    """Decrypt v1 blobs; return legacy plaintext unchanged."""
```

**Config** (`app/core/config.py`, `.env.example`):

```env
FIELD_ENCRYPTION_KEY=           # base64-encoded 32 bytes; required staging/prod
FIELD_ENCRYPTION_ENABLED=true   # false allowed in local/test
```

Behavior mirrors `otp_hash_secret`: if unset in `local`, generate ephemeral key at startup (log once); prod/staging must set explicitly.

**Dependencies:** Python `cryptography` package (add to `requirements.txt` / `pyproject.toml`).

### 5.2 SMS source helpers

**New file:** `backend/app/services/sms_source.py`

Centralize read/write so ingest, transactions, migrate, and API schemas never touch JSONB shape directly.

```python
def build_sms_source(*, raw_plaintext: str, source: str, received_at: datetime, ...) -> dict: ...
def encrypt_sms_source(source: dict, *, user_id: UUID) -> dict: ...
def decrypt_sms_source_raw(source: dict, *, user_id: UUID) -> str: ...
def sms_source_for_api(source: dict, *, user_id: UUID) -> dict:
    """Returns client-facing shape with decrypted `raw`."""
```

### 5.3 Write path touchpoints

| File | Change |
|------|--------|
| `app/services/ingest.py` | After parse: encrypt `request.raw` before `RawIngestion.raw` and `sms_source` persist |
| `app/services/transactions.py` | Manual create from ingestion: decrypt ingestion raw only when copying to tx (ingestion already encrypted) |
| `app/services/firestore_migrate.py` | Encrypt on migrate write |
| `scripts/migrate_firestore.py` | No change if it calls firestore_migrate service |

Gemini parse still receives **plaintext** `request.raw` in memory before encrypt — unchanged.

### 5.4 Read path touchpoints (decrypt only here)

| Endpoint / path | Decrypt? |
|-----------------|----------|
| `GET /review` → `IngestionOut.raw` | **Yes** |
| `GET /transactions/{id}` → `sms_source.raw` | **Yes** (if exposed) |
| `GET /transactions` list | **No** by default (omit raw from list serializer) |
| `GET /analytics/*` | **No** |
| `GET /search` | **No** |
| RAG indexer | **No** |
| Internal re-parse job (future) | **Yes** |

| File | Change |
|------|--------|
| `app/api/product_schemas.py` | `SmsSourceOut` / `IngestionOut` — decrypt via validator using `user_id` from parent context, or decrypt in route layer before validate |
| `app/api/routes/review.py` | Ensure decrypted raw in response |

### 5.5 Migration & backfill

**Alembic:** no column rename required for Option A1 (same `raw` / JSONB columns store ciphertext strings).

**Backfill script:** `backend/scripts/backfill_encrypt_raw.py`

```text
For each raw_ingestions row where raw NOT LIKE 'v1:%':
  encrypt → update

For each transactions row where sms_source->>'raw' IS NOT NULL:
  encrypt → move to raw_encrypted, remove raw key
```

Run against Supabase via session pooler URI. Idempotent. Supports `DRY_RUN=1`, `LIMIT`, `USER_ID` filters.

**Rollout:**

1. Deploy code with dual-read (plaintext + encrypted).
2. Run backfill on staging → verify review + ingest.
3. Run backfill on prod.
4. Remove dual-write of plaintext `raw` key (keep dual-read indefinitely for safety).

### 5.6 Key management

| Phase | Approach |
|-------|----------|
| MVP | Single app DEK in Cloud Run secret / Supabase-adjacent env |
| Later | Per-user DEK wrapped by KMS; `key_version` column; rotation runbook |

Document in deploy runbook: key generation (`openssl rand -base64 32`), where stored, rotation = decrypt-with-old + reencrypt-with-new via backfill script.

### 5.7 Encryption exit criteria

- [ ] New ingestions store no plaintext SMS in DB
- [ ] Backfill complete on Supabase prod
- [ ] `GET /review` returns correct original SMS
- [ ] `tests/test_ingest.py`, `tests/test_review.py` pass with encryption enabled
- [ ] Analytics / search tests unchanged (no decrypt in hot path)
- [ ] `FIELD_ENCRYPTION_KEY` set in staging + prod Cloud Run

---

## 6. RAG design

### 6.1 Vector store — Supabase pgvector

Enable once via Alembic (works on local Homebrew Postgres + Supabase):

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

**No separate Pinecone/Qdrant.** Query via SQLAlchemy + raw SQL or `pgvector` Python bindings.

Local dev: install pgvector for PostgreSQL 16 (`brew install pgvector` or build from source).

### 6.2 Table: `rag_documents`

```sql
CREATE TABLE rag_documents (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    doc_type        TEXT NOT NULL,  -- transaction | merchant | period
    content_text    TEXT NOT NULL,
    embedding       vector(768) NOT NULL,
    ref_id          TEXT NOT NULL,  -- transaction UUID, merchant_normalized, or YYYY-MM
    period_from     DATE,
    period_to       DATE,
    fingerprint     TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_rag_documents_user_type_ref
        UNIQUE (user_id, doc_type, ref_id)
);

CREATE INDEX ix_rag_documents_user_id ON rag_documents (user_id);
CREATE INDEX ix_rag_documents_user_embedding
    ON rag_documents
    USING hnsw (embedding vector_cosine_ops);
```

**SQLAlchemy model:** `backend/app/db/models/rag_document.py`

**Alembic:** `backend/alembic/versions/xxxx_add_rag_documents_pgvector.py`

### 6.3 Document builders

**New file:** `backend/app/services/rag_documents.py`

```python
def build_transaction_doc(tx: Transaction) -> str: ...
def build_merchant_doc(stats: MerchantStats) -> str: ...
def build_period_doc(summary: dict) -> str: ...

def doc_fingerprint(tx: Transaction) -> str:
    """Hash of fields that invalidate the doc when changed."""
```

**Transaction doc template:**

```text
{transaction_date} | {type} | {currency} {amount} | {merchant} | {category} | {payment_method}
```

**Fingerprint inputs (transaction):** `amount`, `merchant_normalized`, `category`, `transaction_date`, `status`, `type`.

Skip indexing when `status = deleted`.

### 6.4 Embedding service

**New file:** `backend/app/services/embeddings.py`

- Call Gemini embedding REST API (`text-embedding-004`, 768 dimensions).
- Batch up to N texts per request (respect rate limits).
- Retry on 429/503 (mirror `gemini.py` fallback pattern if multiple models exist).
- Return `list[float]` normalized for cosine distance.

**Config:**

```env
GEMINI_EMBEDDING_MODEL=text-embedding-004
# Uses existing GEMINI_API_KEY
```

### 6.5 Indexer service

**New file:** `backend/app/services/rag_indexer.py`

```python
async def upsert_transaction_doc(session, *, user: User, tx: Transaction) -> None: ...
async def delete_transaction_doc(session, *, user_id: UUID, tx_id: UUID) -> None: ...
async def rebuild_merchant_doc(session, *, user: User, merchant_normalized: str) -> None: ...
async def rebuild_period_doc(session, *, user: User, year_month: str) -> None: ...
async def reindex_user(session, *, user_id: UUID) -> ReindexStats: ...
```

**Hooks (call after commit):**

| Event | Action |
|-------|--------|
| Ingest creates transaction | `upsert_transaction_doc` |
| `PATCH /transactions/{id}` | `upsert_transaction_doc` (fingerprint changed) |
| Soft delete transaction | `delete_transaction_doc` |
| Monthly summary recompute | `rebuild_period_doc` for affected month |

Hook from `ingest.py` and `transactions.py` via try/except — index failure must **not** fail ingest (log + metric; cron backfill repairs).

### 6.6 Retrieval service

**New file:** `backend/app/services/rag_retrieval.py`

```python
async def retrieve(
    session,
    *,
    user_id: UUID,
    query_text: str,
    limit: int = 10,
    doc_types: list[str] | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
) -> list[RagHit]:
    """Embed query → cosine search → filter user_id → return hits with similarity score."""
```

Always filter `user_id` — no cross-user retrieval.

Optional metadata filter on `period_from` / `period_to` for date-scoped questions.

### 6.7 Background jobs

**New route:** `POST /internal/jobs/reindex-rag`

```python
class ReindexRagRequest(BaseModel):
    user_id: UUID | None = None   # None = all users with recent activity
    full: bool = False            # rebuild merchant + period docs too
```

**Cron (optional, weekly):** full merchant/period rollup reindex for active users.

Add to Cloud Scheduler after deploy (`make scheduler` pattern in README).

### 6.8 RAG exit criteria

- [ ] pgvector enabled on local + Supabase
- [ ] Every active transaction has a `rag_documents` row
- [ ] Update/delete keeps index consistent
- [ ] Retrieval returns relevant docs for manual test queries (“fuel spending”, “KFC”)
- [ ] Indexer never reads `raw_ingestions.raw` or `sms_source`
- [ ] Reindex job completes for migrated users

---

## 7. Intelligence layer (chat + smart insights)

### 7.1 Signal detector (SQL, no RAG)

**New file:** `backend/app/services/spending_signals.py`

Pure SQL over `analytics.py` helpers. Detects:

| Signal | Rule (initial) |
|--------|----------------|
| `category_spike` | Category spend > 1.3× trailing 3-month average |
| `new_recurring` | Merchant with `is_recurring` first seen in period |
| `merchant_concentration` | Single merchant > 25% of period debit spend |
| `weekend_skew` | Fri–Sun spend > 1.5× weekday average |
| `large_one_off` | Single debit > 2× user's median debit (min 3 txns) |
| `net_negative_swing` | Net worse vs equal-length prior window |

Output:

```python
@dataclass
class SpendingSignal:
    signal_type: str
    severity: float          # 0–1 for ranking
    params: dict             # category, merchant, amounts, dates
    suggested_question: str  # LLM-polished or template
```

### 7.2 Smart insight cards

**New file:** `backend/app/services/rag_insights.py`  
**New table:** `rag_insight_cache` (mirror `ai_summaries` shape)

```sql
CREATE TABLE rag_insight_cache (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date_from       DATE NOT NULL,
    date_to         DATE NOT NULL,
    cards           JSONB NOT NULL,   -- [{ title, body, signal_type, citation_ids[] }]
    model           TEXT NOT NULL,
    transaction_count INT NOT NULL,
    source_updated_at TIMESTAMPTZ,
    generated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, date_from, date_to)
);
```

**Endpoint:** `GET /insights/smart-cards?from=&to=`

Pipeline per top 2–4 signals:

1. Run signal detector
2. Retrieve supporting `rag_documents`
3. Call analytics for exact numbers (tool)
4. Gemini generates card copy (2–3 sentences, facts only)
5. Cache with same invalidation as narrative

### 7.3 Chat API

**New router:** `backend/app/api/routes/chat.py`

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/chat/suggestions?from=&to=` | Top 5 questions from signals (cached) |
| `POST` | `/chat/ask` | User question → answer + citations |

**Request `POST /chat/ask`:**

```json
{
  "question": "Why did my fuel spending jump?",
  "from": "2026-03-01",
  "to": "2026-03-31"
}
```

**Response:**

```json
{
  "answer": "Your fuel spending rose to PKR 18,400, 58% above your 3-month average...",
  "citations": [
    {
      "transaction_id": "uuid",
      "date": "2026-03-06",
      "amount": 5990.0,
      "merchant": "PSO RANGERS",
      "category": "Fuel"
    }
  ],
  "confidence": "high",
  "source": "gemini",
  "model": "gemini-3.1-flash-lite"
}
```

**New file:** `backend/app/services/chat_rag.py`

Pipeline:

1. **Guardrail** — reject off-topic (weather, investments, legal advice), insufficient data (< N txns)
2. **Intent router** — `navigation` → redirect message (“Use Activity filter for KFC”); `analytics` → tools first; `explanation` → RAG + tools
3. **Tools** — wrap `get_range_summary`, category breakdown, merchant stats
4. **Retrieve** — top-k from `rag_retrieval`
5. **Generate** — strict prompt (see §7.4)
6. **Rate limit** — per user (reuse `rate_limit.py` pattern)

**Optional later:** `chat_messages` table for history (user_id, role, content, created_at).

### 7.4 Prompt templates

**Chat system prompt (sketch):**

```text
You answer questions about the user's personal spending in NovaSpend.
Use ONLY facts from the retrieved documents and tool outputs below.
Mention specific merchants and amounts when available.
Do not invent transactions, budgets, or financial advice.
If the data is insufficient, say so.
Currency: {currency}. Period: {date_from} to {date_to}.
```

**Smart card prompt:** same discipline as existing `insights_narrative._PROMPT` — 2–3 sentences, no bullets, no greeting.

### 7.5 Intelligence exit criteria

- [ ] `/chat/suggestions` returns 5 relevant questions for seeded test user
- [ ] `/chat/ask` returns cited answer for “why did X category increase”
- [ ] Guardrail rejects off-topic questions
- [ ] `/insights/smart-cards` cached and invalidates on new transactions
- [ ] Rate limits enforced on `/chat/ask`
- [ ] No raw SMS in any prompt or log line

---

## 8. Implementation order (checklist)

Follow this order. Encryption blocks **production** chat; RAG infra can start after §8.0.

### 8.0 Design & scaffolding (Week 1)

- [ ] Approve this doc
- [ ] Add `FIELD_ENCRYPTION_*` to config + `.env.example`
- [ ] Implement `field_crypto.py` + unit tests
- [ ] Implement `sms_source.py` helpers + unit tests
- [ ] Draft Alembic migration for pgvector + `rag_documents` (don't deploy RAG yet)

### 8.1 Phase E1 — Encryption (Week 1–2)

- [ ] Wire encrypt into `ingest.py`
- [ ] Wire encrypt into `firestore_migrate.py`
- [ ] Decrypt in review + transaction detail API paths
- [ ] Stop returning `sms_source.raw` in list endpoints (if currently included)
- [ ] `scripts/backfill_encrypt_raw.py`
- [ ] Run backfill on staging Supabase
- [ ] Update `tests/test_ingest.py`, `tests/test_review.py`, add `tests/test_field_crypto.py`
- [ ] Deploy to Cloud Run; set `FIELD_ENCRYPTION_KEY`
- [ ] Run backfill on prod

**Gate:** E1 exit criteria (§5.7) before enabling chat in prod.

### 8.2 Phase R1 — RAG foundation (Week 2–3, parallel after 8.0)

- [ ] Alembic: pgvector + `rag_documents`
- [ ] Model `RagDocument`
- [ ] `embeddings.py` + `rag_documents.py` + `rag_indexer.py`
- [ ] Hook indexer into ingest + transaction update/delete
- [ ] `rag_retrieval.py` + integration tests
- [ ] `POST /internal/jobs/reindex-rag`
- [ ] Reindex migrated users on staging

**Gate:** R1 exit criteria (§6.8).

### 8.3 Phase R2 — Signals + smart cards (Week 4)

- [ ] `spending_signals.py` + tests
- [ ] `rag_insights.py` + `rag_insight_cache` migration
- [ ] `GET /insights/smart-cards` route
- [ ] Cache invalidation tests (mirror `test_analytics.py` narrative tests)

### 8.4 Phase R3 — Chat (Week 5)

- [ ] `chat_rag.py`
- [ ] `GET /chat/suggestions`, `POST /chat/ask`
- [ ] Rate limits + guardrails
- [ ] `tests/test_chat_rag.py`

### 8.5 Phase R4 — Hardening (Week 6)

- [ ] Decrypt audit log (optional table or structured log field)
- [ ] Key rotation runbook + script skeleton
- [ ] Cost monitoring (embedding + generate calls per user)
- [ ] Load test retrieval latency on Supabase
- [ ] Document ops in `backend/README.md`

---

## 9. API reference (new endpoints)

### `GET /chat/suggestions`

| Param | Required | Description |
|-------|----------|-------------|
| `from` | yes | ISO date |
| `to` | yes | ISO date |

Response:

```json
{
  "suggestions": [
    { "question": "Why did fuel spending jump this month?", "signal_type": "category_spike" }
  ],
  "source": "cache"
}
```

### `POST /chat/ask`

Body: `{ "question": string, "from"?: string, "to"?: string }`

Errors: `400` off-topic / insufficient data; `429` rate limited; `503` Gemini unavailable.

### `GET /insights/smart-cards`

Same date params as `/analytics/narrative`.

Response:

```json
{
  "cards": [
    {
      "title": "Fuel up 58%",
      "body": "...",
      "signal_type": "category_spike",
      "citations": [{ "transaction_id": "...", "date": "...", "amount": 0, "merchant": "..." }]
    }
  ],
  "source": "gemini",
  "model": "..."
}
```

### `POST /internal/jobs/reindex-rag`

Header: `X-Cron-Secret`. Body: `{ "user_id"?: uuid, "full"?: bool }`.

---

## 10. File map

| Area | New / changed files |
|------|---------------------|
| **Encryption** | `app/services/field_crypto.py`, `app/services/sms_source.py` |
| | `app/core/config.py`, `.env.example` |
| | `app/services/ingest.py`, `transactions.py`, `firestore_migrate.py` |
| | `app/api/product_schemas.py`, `routes/review.py` |
| | `scripts/backfill_encrypt_raw.py` |
| | `tests/test_field_crypto.py`, `tests/test_sms_source.py` |
| **RAG core** | `app/db/models/rag_document.py` |
| | `app/services/embeddings.py`, `rag_documents.py`, `rag_indexer.py`, `rag_retrieval.py` |
| | `alembic/versions/*_add_rag_documents_pgvector.py` |
| | `app/api/routes/jobs.py` (reindex endpoint) |
| | `tests/test_rag_indexer.py`, `tests/test_rag_retrieval.py` |
| **Intelligence** | `app/services/spending_signals.py`, `rag_insights.py`, `chat_rag.py` |
| | `app/db/models/rag_insight_cache.py` |
| | `app/api/routes/chat.py`, extend or add `insights` routes |
| | `app/api/product_schemas.py` (ChatOut, SmartCardsOut, ...) |
| | `tests/test_spending_signals.py`, `tests/test_chat_rag.py` |
| **Docs** | This file, `backend/README.md` link |

---

## 11. Testing strategy

| Layer | Tests |
|-------|-------|
| Crypto | Round-trip, wrong AAD fails, legacy plaintext dual-read, tampered blob |
| Ingest | Stored ciphertext; parse still works; review decrypts |
| Indexer | Upsert on create, update fingerprint change, delete removes doc |
| Retrieval | Same-user only; date filter; cosine ranking sanity |
| Signals | Seeded txs → expected signal types |
| Chat | Guardrail rejects; cited answer contains only seeded merchants |
| Cache | Smart cards + suggestions invalidate when tx count changes |

Use `FIELD_ENCRYPTION_ENABLED=true` in test env with fixed test key in `conftest.py`.

Gemini calls: stub in unit tests; one optional integration test with real key in CI (skipped by default).

---

## 12. Deployment checklist

### Encryption deploy

1. Generate `FIELD_ENCRYPTION_KEY` → Cloud Run secret
2. Deploy API with dual-read code
3. `python scripts/backfill_encrypt_raw.py` against Supabase (staging first)
4. Smoke: ingest new SMS → DB has `v1:` blob → review shows plaintext
5. Prod backfill during low traffic

### RAG deploy

1. `alembic upgrade head` on Supabase (enables pgvector)
2. Deploy indexer hooks
3. `POST /internal/jobs/reindex-rag` for all users (or per-user after migrate)
4. Enable `/insights/smart-cards` internally
5. Enable `/chat/*` after E1 gate passed

### Local dev

```bash
# pgvector on Homebrew Postgres 16
brew install pgvector
psql novaspend_dev -c 'CREATE EXTENSION IF NOT EXISTS vector;'

# .env
FIELD_ENCRYPTION_KEY=$(openssl rand -base64 32)
GEMINI_API_KEY=...
```

---

## 13. Security & privacy

- Raw SMS never logged after encryption deploy (audit ingest logs).
- Decrypt only in request handlers that need it; never pass decrypted raw to RAG or analytics.
- Chat prompts include retrieved doc text + structured facts only.
- Rate limit `/chat/ask` to prevent embedding abuse.
- `FIELD_ENCRYPTION_KEY` rotation requires reencrypt backfill — document before prod.
- Supabase: rely on existing TLS + RLS not required (app enforces `user_id` in SQL).

---

## 14. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Lost encryption key | Backup key in secret manager; no recovery of ciphertext without key |
| Indexer lag / failure | Async hook + weekly reindex job; ingest never fails on index error |
| Bad retrieval → wrong answer | Tool-augmented RAG; strict prompt; citations; confidence flag |
| Embedding cost at scale | Cache suggestions/cards; batch embed; skip re-embed if fingerprint unchanged |
| pgvector latency | HNSW index; limit k≤10; user_id filter first |
| Legacy plaintext rows | Dual-read until backfill 100%; monitor `NOT LIKE 'v1:%'` count |

---

## 15. One-page summary

1. **Encrypt** only `raw_ingestions.raw` and `sms_source.raw` (Option A). Structured columns stay plain.
2. **Index RAG** from structured columns into Supabase **pgvector** — no separate vector DB.
3. **Ship encryption before prod chat.**
4. **Signals (SQL)** drive suggested questions and smart cards; **RAG + tools** answer and explain.
5. **Phases:** E1 encrypt → R1 index → R2 smart cards → R3 chat → R4 harden.
6. **Reuse patterns** from `ai_summaries` caching and `gemini.py` retries.

---

## 16. Related docs

- [backend-migration-plan.md](./backend-migration-plan.md) — Postgres / Supabase / Cloud Run
- [insights-dashboard-plan.md](./insights-dashboard-plan.md) — Flutter Insights layout (Phase 4 narrative done)
- `backend/app/services/insights_narrative.py` — existing Gemini narrative cache pattern
- `backend/app/services/ingest.py` — ingest write path for encryption hooks
- `backend/app/db/models/transaction.py` — structured fields for RAG docs

---

## 17. Open questions (resolve in 8.0)

| # | Question | Default if unset |
|---|----------|------------------|
| 1 | Return `sms_source.raw` on transaction list? | **No** — detail + review only |
| 2 | Store chat history in Postgres? | **No** for MVP |
| 3 | Minimum transactions for chat? | **10** active txns |
| 4 | Replace `/analytics/narrative` with smart cards? | **No** — keep both; cards are additive |
| 5 | Per-user vs app-wide DEK for MVP? | **App-wide DEK** |
