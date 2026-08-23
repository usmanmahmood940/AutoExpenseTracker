# NovaSpend Backend

FastAPI + PostgreSQL service that is taking over product data and business logic
from Firestore and Cloud Functions. Firebase stays the identity provider (it
stores passwords and issues ID tokens) and the push transport (FCM).

Plan of record: [`../docs/backend-migration-plan.md`](../docs/backend-migration-plan.md).
Follow section 6 (Migration order). Phases A–F freeze are done (2026-08-23):
Flutter + Shortcuts hit this service; Firestore/Functions stay deployed as
rollback for a few days (step 11).

## Status

| Phase | Scope | State |
|-------|-------|-------|
| A | Foundation: config, logging, errors, DB, migrations, health, Cloud Run + Supabase | **done** |
| B | `/auth/*`, `/me`, `/me/devices` | **done (deployed)** |
| C | Transactions, search, stats, categories, review | **done (deployed)** |
| D | Ingest + workers | **done (deployed)** |
| E | Flutter ApiClient (dev) | **done** (needs step 5 data before Home looks real) |
| F | Prod migrate + freeze + cutover | **dual-run** (step 11) |

## Requirements

- Python 3.12 (`brew install python@3.12`) — 3.14 is not used because some
  database and gRPC wheels still lag behind it
- PostgreSQL 16 (`brew install postgresql@16`)

## First-time setup

```bash
cd backend

brew services start postgresql@16
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"

# Role and databases (dev + test)
psql -d postgres -c "CREATE ROLE novaspend WITH LOGIN PASSWORD 'novaspend' CREATEDB;"
createdb -O novaspend novaspend_dev
createdb -O novaspend novaspend_test

make venv
make install
cp .env.example .env

make migrate
make test
make run      # http://127.0.0.1:8000/docs
```

`make help` lists every target.

## Configuration

All settings come from the environment (`.env` locally). See
[`.env.example`](.env.example) for the full list. Notes:

- `DATABASE_URL` accepts `postgresql://` or `postgres://`; the `+asyncpg` driver
  is added automatically, so a connection string pasted from Cloud SQL or
  Supabase works unedited.
- Firebase credentials resolve in this order: `GOOGLE_APPLICATION_CREDENTIALS`,
  then Application Default Credentials (`gcloud auth application-default login`
  locally, the runtime service account on Cloud Run).
- Firebase initialization is **non-fatal**. Without credentials the service still
  boots and `/health` still passes; `/health/ready` reports `firebase:
  unconfigured` and auth-dependent routes return `503 auth_unavailable`.
- `FIREBASE_WEB_API_KEY` (the public "web" key from `firebase_options.dart`, not
  a service-account secret) is required for `/auth/login` and
  `/auth/change-password` — they call Identity Toolkit's
  `signInWithPassword` because the Admin SDK cannot check a password itself.
- `RESEND_API_KEY`/`RESEND_FROM_EMAIL` send the OTP mail for
  signup/forgot-password. Leave them unset locally: the OTP is logged
  (`email_not_sent_dev_fallback`) instead of emailed, so Swagger can drive the
  whole signup/reset flow with no Resend account.
- `GEMINI_API_KEY` is required for a real SMS parse on `POST /ingest`. Unset,
  ingest still writes a `raw_ingestions` row with `needs_parse`.
- `CRON_SECRET` protects `/internal/jobs/*`. Unset is allowed only when
  `ENVIRONMENT=local`. After a Cloud Run deploy: `make scheduler` (03:00 and
  03:15 Asia/Karachi).
- Firestore → Postgres copy (plan §6 step 5): `make migrate-firestore SUPABASE=1 DRY_RUN=1` then the same without `DRY_RUN`.
- `INGEST_SHARED_SECRET` is optional extra webhook auth. Unset keeps Function
  parity (`X-User-Id` only).

## Layout

```
app/
├── main.py            # app factory, middleware, lifespan
├── api/
│   ├── deps.py        # DbSession, AppSettings, CurrentIdentity
│   └── routes/        # one module per resource group
├── core/
│   ├── config.py      # Settings
│   ├── errors.py      # AppError hierarchy + handlers
│   ├── firebase.py    # Admin SDK lifecycle, token verification
│   ├── logging.py     # JSON (deployed) / text (local)
│   └── middleware.py  # request id + access log
├── db/
│   ├── base.py        # DeclarativeBase, mixins, naming convention
│   ├── models/
│   └── session.py     # async engine + request-scoped session
├── services/          # business logic: otp, rate_limit, mailer,
│                      # identity_toolkit, firebase_users, user_profile,
│                      # reset_session, devices, transactions, period_stats,
│                      # analytics, merchants, review, categories, ingest,
│                      # gemini, push
└── workers/           # cleanup-auth, monthly_summaries recompute
alembic/               # migrations
tests/
```

## Endpoints

| Method | Path | Notes |
|--------|------|-------|
| GET | `/health` | Liveness. Touches nothing, so it stays green during an outage. Use for Cloud Run probes. |
| GET | `/health/ready` | Checks Postgres and Firebase. `503` when either is down. |
| GET | `/docs` | Swagger UI — the contract for Flutter and QA. |
| POST | `/auth/signup/otp` | Send a signup verification code (logged, not emailed, if `RESEND_API_KEY` is unset). |
| POST | `/auth/signup` | Verify the code → create the Firebase user + Postgres profile → sign in. |
| POST | `/auth/login` | Password sign-in via Identity Toolkit → tokens + profile. |
| POST | `/auth/forgot-password` | Send a reset code (always looks successful — no account enumeration). |
| POST | `/auth/verify-reset-otp` | Verify the reset code → one-time `reset_token`. |
| POST | `/auth/reset-password` | Spend the `reset_token` → set the new password → revoke sessions. |
| POST | `/auth/change-password` | Bearer + old password verified via Identity Toolkit → new password → revoke sessions. |
| POST | `/auth/logout` | Revoke the current refresh-token family. |
| GET | `/me` | The caller's Postgres profile (self-healing: creates it on first sight). |
| PATCH | `/me` | Update profile/settings fields (only the ones sent). |
| POST | `/me/devices` | Register an FCM token; moves it if another account already held it. |
| DELETE | `/me/devices/{token}` | Unregister a token. Idempotent. |
| GET | `/transactions` | List (date range, sort by date/amount, cursor, optional aggregates + filters). |
| GET | `/transactions/search` | Merchant prefix or scan across merchant/category/bank. |
| POST | `/transactions` | Manual create (optional `ingestion_id` to complete a `needs_parse` row). |
| GET | `/transactions/{id}` | Detail. |
| PATCH | `/transactions/{id}` | Update; also upserts a merchant category override. |
| DELETE | `/transactions/{id}` | Soft delete (`status = deleted`). |
| POST | `/transactions/{id}/review` | Mark reviewed (`status = active`, set `reviewed_at`). |
| GET | `/period-stats` | Live SQL totals + highlights + week/month comparison. Replaces `getPeriodStats`. |
| GET | `/analytics/summary` | Live SQL monthly summary (`year_month=YYYY-MM`). |
| GET | `/analytics/summaries` | Recent months that have transactions (`limit`, default 6). |
| GET | `/merchants/{key}` | Merchant spend summary. |
| GET | `/merchants/{key}/transactions` | That merchant's transactions. |
| GET | `/review` | `needs_review` txs + `needs_parse` / `duplicate` ingestions. |
| GET | `/categories` | Seeded defaults + the caller's custom categories. |
| POST | `/ingest` | SMS/email webhook. Auth is `X-User-Id` (Firebase UID), not Bearer. Same JSON as the Cloud Function. Alias: `POST /webhooks/sms`. |
| POST | `/internal/jobs/cleanup-auth` | Delete expired OTPs / reset sessions / stale rate limits. `X-Cron-Secret` when `CRON_SECRET` is set. |
| POST | `/internal/jobs/recompute-summaries` | Rebuild `monthly_summaries` from live SQL. |

Paths deliberately carry no `/v1` prefix, matching the API tables in the
migration plan. `/auth/*` is public. `POST /ingest` authenticates with
`X-User-Id` (and optional `X-Ingest-Secret`). Job routes use `X-Cron-Secret`.
Everything else requires `Authorization: Bearer <Firebase ID token>`.

## Conventions

**Errors.** Every failure returns `{"detail": "...", "code": "..."}`. Raise a
subclass of `AppError` (`NotFoundError`, `ConflictError`, `UnauthorizedError`, …)
rather than `HTTPException`, so the `code` stays stable for client-side
localization. Unhandled exceptions log a traceback and return a generic
`internal_error` — internals are never returned to a client.

**Logging.** JSON on deployed environments (Cloud Logging parses `severity`),
plain text locally. Every line carries a `requestId`, taken from `X-Request-Id`
or Cloud Run's `X-Cloud-Trace-Context`, and returned in the response headers.
`/health` traffic logs at DEBUG to keep probe noise out of the stream.

**Database.** Async SQLAlchemy 2.0 with asyncpg. Sessions come from the
`DbSession` dependency; commits are explicit in the service layer. Money uses
`Numeric`, never float.

## Migrations

```bash
make migrate                     # upgrade head
make revision m="add budgets"    # autogenerate, then review it
make downgrade                   # back off one
make reset                       # base then head
```

Always read a generated migration before applying it, and run `make check` —
it fails on any drift between the models and the applied schema, which is the
cheapest way to catch a model change that never became a migration.

## Deploying to Cloud Run

**Postgres host:** Supabase (see §13 of the migration plan). Local Homebrew Postgres remains for day-to-day `make run`.

### One-time: create a Supabase project

1. Open https://supabase.com/dashboard/new/auto-expense-tracker and create a free project (region closest to `asia-south1`, e.g. Mumbai / Singapore).
2. Project Settings → Database → **Connection string** → URI.
3. Prefer the **Session pooler** URI (port `5432`) or **Transaction pooler** (port `6543`) for Cloud Run. Copy the password you set at project creation.
4. Paste it as `DATABASE_URL` when deploying (the script normalizes `postgresql://` → `postgresql+asyncpg://` and adds `ssl=require`).

### Apply migrations to Supabase

Prefer the **session pooler** URI (IPv4). Direct `db.<ref>.supabase.co` is often
IPv6-only and fails from many networks / Cloud Run.

```bash
# From backend/ — use the pooler host, URL-encode special chars in the password:
DATABASE_URL='postgresql+asyncpg://postgres.<ref>:<password>@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres?ssl=require' \
  .venv/bin/alembic upgrade head
```

### Deploy

Reads `SUPABASE_DATABASE_URL` from `backend/.env` and sets it on Cloud Run as a
normal environment variable (no Secret Manager).

```bash
make deploy
```

Live service (Phases A–D):

- https://novaspend-api-h7asbihbya-el.a.run.app/health  
- https://novaspend-api-h7asbihbya-el.a.run.app/docs  
- Auth: `/auth/*`, `/me`, `/me/devices`  
- Product: `/transactions`, `/period-stats`, `/analytics/*`, `/categories`, `/merchants/*`, `/review`  
- Ingest/jobs: `/ingest`, `/internal/jobs/*`  

Copy Firestore history into that database (step 5) before expecting Home to
show existing transactions:

```bash
make migrate-firestore SUPABASE=1 DRY_RUN=1
make migrate-firestore SUPABASE=1
make scheduler    # optional; daily cleanup + summary recompute
```


`make deploy` runs [`scripts/deploy-cloud-run.sh`](scripts/deploy-cloud-run.sh):
builds via Cloud Build, copies env from `.env`, clears any old secret mounts,
and prints the service URL.

Point the startup probe at `/health` (not `/health/ready`, or a database blip
will roll back a good revision).

<details>
<summary>Cloud SQL note (not used — we chose Supabase)</summary>

For Cloud SQL you would add `--add-cloudsql-instances` and use a socket URL:
`postgresql+asyncpg://user:pass@/dbname?host=/cloudsql/PROJECT:REGION:INSTANCE`.
</details>

## Production checklist (before real traffic)

- [ ] Split database roles: migrations run as the owner, the API connects as a
      DML-only role. Dev intentionally uses one role for convenience:

      ```sql
      CREATE ROLE novaspend_api LOGIN PASSWORD '...';
      GRANT CONNECT ON DATABASE novaspend TO novaspend_api;
      GRANT USAGE ON SCHEMA public TO novaspend_api;
      GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO novaspend_api;
      ALTER DEFAULT PRIVILEGES IN SCHEMA public
        GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO novaspend_api;
      ```

- [ ] `DOCS_ENABLED=false` if the OpenAPI schema should not be public
- [x] Secrets live in `backend/.env` locally and as Cloud Run env vars (Secret Manager not used for now)
- [x] Rate limiting on auth routes (Phase B) — sliding-window limits on OTP send/verify and login, per email and per IP; see `app/services/rate_limit.py`
- [ ] Set `OTP_HASH_SECRET`, `RESEND_API_KEY`, `RESEND_FROM_EMAIL`, `FIREBASE_WEB_API_KEY` before Phase B goes to dev/staging/prod (see Configuration above)
- [x] A cleanup job for expired `auth_otps` / `password_reset_sessions` / `auth_rate_limits` rows (`POST /internal/jobs/cleanup-auth`)
