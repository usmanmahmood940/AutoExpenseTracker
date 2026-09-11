# AI Chatbot + Agent — Implementation Record

This document records what was built for the Agent + Semantic Layer + Typed Tools + Proposal/Confirm architecture. It is an implementation log, not the original plan file.

**Decision:** Gemini interprets and proposes; the semantic layer maps language to domain concepts; typed tools run SQLAlchemy; existing transaction services enforce business rules; PostgreSQL remains the source of truth. RAG is not used for transaction totals or mutations.

---

## Architecture summary

```text
Flutter Ask / Confirm
        ↓
FastAPI (/chat/ask facade → /agent/chat, /agent/proposals/*)
        ↓
Agent orchestrator (Gemini tool loop, max ~5 iterations)
        ↓
┌─────────────────┬──────────────────┬────────────────────┐
│ Semantic layer  │ Read tools       │ Write proposal     │
│ merchant_concepts│ SQL aggregates   │ tools (no mutate)  │
└────────┬────────┴────────┬─────────┴─────────┬──────────┘
         └─────────────────┼───────────────────┘
                           ↓
              Domain services (transactions.*)
                           ↓
                    Supabase / Postgres
```

**Auth rule:** `user_id` always comes from the authenticated session (`CurrentUser`), never from LLM tool arguments.

---

## Phase 1 — Semantic layer

### Database

- Migration: `backend/alembic/versions/g2b3c4d5e6f7_add_merchant_concepts.py`
- Tables:
  - `merchant_concepts` — global `merchant_normalized` → `concepts text[]`, GIN index
  - `merchant_concept_overrides` — per-user concept overrides (same idea as category overrides)

### Models / seed

- `backend/app/db/models/merchant_concept.py` — `MerchantConcept`, `MerchantConceptOverride`
- `backend/app/db/seeds/concepts.py` — closed vocabulary, aliases, known merchant bootstrap (LESCO → electricity, KFC → fast_food, etc.)

### Services

- `backend/app/services/semantic/`
  - `__init__.py` — resolve merchants for concepts, seed/upsert helpers, override precedence
  - `question_resolver.py` — question → closed concepts (deterministic first, Gemini fallback)
  - `enrichment.py` — write-time / offline Gemini classify + `backfill_merchant_concepts`
- Backfill script: `backend/scripts/backfill_merchant_concepts.py`
- Job: `POST /internal/jobs/enrich-merchant-concepts`

### Integration

- Ingest / create paths call enrichment after commit (alongside the old RAG hook)
- `chat_rag._resolve_terms` prefers concept → merchant resolution over raw `ILIKE` topic expansion

### Tests

- `backend/tests/test_semantic_layer.py`

---

## Phase 2 — Typed read tools + orchestrator

### Package

`backend/app/services/agent/`

| File | Role |
|------|------|
| `tool_schemas.py` | Gemini function declarations (read + write tools) |
| `read_tools.py` | `query_transactions`, `aggregate_spending`, `list_settlements`, `get_transaction`, `search_transaction_candidates` |
| `write_tools.py` | Propose-only builders + `persist_proposal` |
| `orchestrator.py` | Bounded tool loop, guardrails, rate limit, traces |
| `executor.py` | Confirm-time atomic execution |

### Routes

- `POST /agent/chat` — primary agent endpoint (`backend/app/api/routes/agent.py`)
- Registered in `backend/app/main.py`

### Config

- `chat_use_agent` (default `true`) — `/chat/ask` delegates to the agent
- `agent_chat_limit_per_user` (default `10`) — stricter than ordinary chat ask

---

## Phase 3 — RAG retired from the transaction write path

- `rag_indexer.index_after_commit` is a **no-op** (stub kept for import safety / dual-run)
- `/chat/ask` facades to the agent when `chat_use_agent` is enabled
- Suggestions (`/chat/suggestions`) and spending signals remain SQL-based
- Vector retrieval modules may still exist on disk but are not required for Ask totals

---

## Phase 4 — Proposal system + Flutter confirmation UX

### Backend

- Migration: `backend/alembic/versions/h3c4d5e6f7a8_add_agent_proposals.py`
- Tables: `agent_proposals`, `agent_traces`
- Endpoints:
  - `GET /agent/proposals/{id}`
  - `POST /agent/proposals/{id}/confirm` — body `{ "idempotency_key": "..." }`
  - `POST /agent/proposals/{id}/reject`
- Write tools only append steps; no DB mutation during the agent loop
- Chat response may include structured `proposal` JSON

### Flutter

- Entity: `NovaSpend/lib/features/chat/domain/entities/agent_proposal_entity.dart`
- `ChatAnswerEntity` extended with optional `proposal`
- API parse: `chatAnswerFromApi` in `api_json.dart`
- Datasource confirm/reject against `/agent/proposals/...`
- UI: `agent_proposal_sheet.dart` — Review / Confirm / Cancel from structured steps
- Ask page wires a **Review changes** CTA when a pending proposal is present
- L10n keys: `askProposalTitle`, `askProposalConfirm`, `askProposalCancel`, `askProposalReview`, `askProposalApplied`, `askProposalRejected`

---

## Phase 5 — Action execution

- `executor.py` runs confirmed steps in one transactional flow:
  - `create` (local refs `t1`, `t3`, …)
  - `settle` / `unsettle` / `unmerge`
- Domain validation stays in transaction settle/unmerge logic (currency, status, amount rules)
- Stale protection via stored `updated_at` snapshots when referencing existing rows
- Idempotent confirm via `idempotency_key`
- Failures mark proposal `failed` and roll back

---

## Phase 6 — Observability + evaluation

- `agent_traces` rows: question, answer, model, tool_calls, proposal_id, latency_ms
- Eval / regression: `backend/tests/test_agent_eval.py`
  - Concept mapping cases
  - Aggregate spending for electricity
  - Merged-status query
  - Create + settle proposal atomicity
  - Expired proposal rejection

---

## Key API surface

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/chat/ask` | Ask (facade → agent when enabled) |
| GET | `/chat/suggestions` | Signal-based suggestion chips |
| POST | `/agent/chat` | Direct agent chat |
| GET | `/agent/proposals/{id}` | Load proposal |
| POST | `/agent/proposals/{id}/confirm` | Execute after user approval |
| POST | `/agent/proposals/{id}/reject` | Discard proposal |
| POST | `/internal/jobs/enrich-merchant-concepts` | Cron/backfill concepts |

---

## Apply locally / in deployed DB

```bash
cd backend
.venv/bin/python scripts/alembic_supabase.py upgrade head

# Optional: classify existing merchants missing concepts
.venv/bin/python -m scripts.backfill_merchant_concepts
```

Run focused tests:

```bash
cd backend
.venv/bin/pytest tests/test_semantic_layer.py tests/test_agent_eval.py -q
```

---

## Explicitly not built (deferred)

- RAG for unstructured bills / PDFs
- MCP tool exposure
- Embedding a huge concept vocabulary in-process (only if the closed list outgrows prompts)
- Dropping the `rag_documents` table (left for a later cleanup after dual-run)

---

## Principle (unchanged)

> Let Gemini understand, plan, and propose. Let the semantic layer translate language into the domain. Let typed tools retrieve data. Let existing domain services enforce business rules. Let PostgreSQL remain the source of truth. Let the user approve mutations before execution.
