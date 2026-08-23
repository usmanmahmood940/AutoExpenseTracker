# NovaSpend Backend & Firebase Migration Plan

**Status:** Phase F dual-run (2026-08-23) — traffic on FastAPI + Supabase; Firebase idle as rollback  
**Target stack:** FastAPI (Cloud Run) + PostgreSQL (Cloud SQL or Supabase) + Firebase Auth (identity) + FCM (push delivery)  
**App:** NovaSpend (Flutter)

This plan moves product data and business APIs off Firestore/Cloud Functions onto a proper backend, while keeping Firebase for identity and push unless you later choose to replace those too.

> **Where to start:** [§6 Migration order](#6-migration-order-checklist-you-can-follow) is the authoritative sequence. [§5](#5-backend-build-plan-correct-order) explains each phase in detail; [§15](#15-one-page-summary) is the short version. If they ever conflict, §6 wins.

---

## 1. Goals

- Flutter becomes **UI-only** (no complex Firestore queries, no business rules).
- Backend owns **auth APIs**, **transactions**, **search**, **stats**, **ingest**, **settings**, **jobs**.
- Fix Firestore limitations (e.g. date range + sort by amount) via SQL.
- Scale API and DB independently of app store releases.
- Clear cutover: migrate → dual-run → remove Firebase pieces safely.

---

## 2. Target architecture

```text
┌─────────────────────────────────────────────────────────┐
│ Flutter (NovaSpend)                                     │
│  - Screens / Provider                                   │
│  - Secure token storage                                 │
│  - FCM token registration → backend                     │
└─────────────────────┬───────────────────────────────────┘
                      │ HTTPS + Bearer token
                      ▼
┌─────────────────────────────────────────────────────────┐
│ FastAPI on Cloud Run                                    │
│  /auth/*   /me/*   /transactions/*   /search/*          │
│  /merchants/*   /analytics/*   /ingest   /review/*      │
└──────────────┬──────────────────────────┬───────────────┘
               │                          │
               ▼                          ▼
┌──────────────────────────┐   ┌──────────────────────────┐
│ PostgreSQL               │   │ Firebase (thin)          │
│  users, transactions,    │   │  Auth (password vault +  │
│  ingestions, categories, │   │    ID tokens)            │
│  summaries, settings,    │   │  FCM (send push only)    │
│  devices, otps           │   └──────────────────────────┘
└──────────────────────────┘
               ▲
               │ workers / cron
┌──────────────────────────┐
│ Background jobs          │
│  aggregates, cleanup,    │
│  exports, recurring      │
└──────────────────────────┘
```

### Auth model (backend-managed, Firebase underneath)

| Concern | Owner |
|--------|--------|
| Login / signup / forgot / reset / change password APIs | **FastAPI** |
| Password storage & ID token crypto | **Firebase Auth** |
| App user profile, prefs, roles | **Postgres** |
| Flutter talks to | **Only your `/auth/*` and product APIs** (not Firebase Auth SDK for product flows) |

---

## 3. Inventory: today vs after migration

### 3.1 What exists on Firebase today

| Area | Today |
|------|--------|
| Auth | Firebase Auth + Cloud Functions OTP (signup/reset) + `ensureUserProfile` |
| DB | Firestore: transactions, raw_ingestions, categories, monthlySummaries, settings/meta, merchant overrides |
| APIs | Callables/HTTP: `listTransactions`, `getPeriodStats`, `ingestTransactionForUser`, auth OTP helpers |
| Triggers | `onUserTransactionWritten` (aggregates), `onUserTransactionCreatedNotify` (FCM) |
| Client reads | Search, merchant, review, categories, monthly summary listeners |
| Push | FCM + token on user doc |
| Other | App Check on function calls |

### 3.2 What moves to backend

| Move to FastAPI + Postgres |
|----------------------------|
| All transaction CRUD + list/search/filter/sort/paging |
| Period stats / analytics / highlights |
| Ingest webhook + Gemini parse + dedup |
| Review queue |
| Categories + merchant overrides + merchant summary |
| User profile + settings |
| Auth façade: signup, login, forgot, reset, change password, logout, `/me` |
| Device token storage for push |
| Background jobs (aggregates, cleanup, exports) |
| Notification *decision* logic (when to notify) |

### 3.3 What stays on Firebase (phase 1 hybrid)

| Stay | Reason |
|------|--------|
| Firebase Auth | Identity provider; backend verifies tokens |
| FCM | Best mobile push; backend sends via Admin SDK |
| Firebase project | Same GCP project can host Cloud Run |

### 3.4 What gets removed from Firebase (after cutover)

See [Section 8](#8-post-migration-firebase-cleanup).

---

## 4. Repository / project layout (suggested)

```text
AutoExpenseTracker/
├── NovaSpend/                 # Flutter app (existing)
├── functions/                 # Legacy Firebase Functions (shrink → delete)
├── backend/                   # NEW
│   ├── app/
│   │   ├── main.py
│   │   ├── api/               # routers: auth, transactions, ...
│   │   ├── core/              # config, security, firebase admin
│   │   ├── db/                # session, models, migrations
│   │   ├── services/          # auth, ingest, analytics, push
│   │   └── workers/           # optional jobs
│   ├── alembic/
│   ├── tests/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── README.md
└── docs/
    └── backend-migration-plan.md   # this file
```

---

## 5. Backend build plan (correct order)

Gating rules (these prevent the common ordering mistakes):

- Flutter auth work starts only after **Phase B** is testable in Swagger (`/docs`).
- Flutter product screens start only after **Phase C**.
- Shortcuts/webhook work needs **Phase D**, not just A–C.
- **Nothing in production points at the backend until Phase F data migration has run.** Phases E and D are exercised against **dev/staging** first.

### Phase A — Foundation (week 1)

**Deliverables**

- [x] Create `backend/` FastAPI project
- [x] Docker + local run (`uvicorn`)
- [x] Postgres (local Homebrew for day-to-day; **Supabase** for Cloud Run) + Alembic
- [x] Config via env (DB URL, Firebase project, secrets)
- [x] Firebase Admin SDK init (verify ID tokens, manage users)
- [x] Health: `GET /health`
- [x] Deploy empty app to **Cloud Run** (CI optional later) — `https://novaspend-api-h7asbihbya-el.a.run.app`
- [x] CORS + structured logging + error envelope

**Postgres core tables (minimum)**

- [x] `users` (`id`, `firebase_uid` UNIQUE, email, display_name, currency, created_at, …)
- [x] `auth_otps` (purpose, code_hash, expires_at, attempts) — if keeping OTP flows
- [x] `devices` (user_id, fcm_token, platform)

**Exit criteria:** Cloud Run URL live; `/docs` opens; DB migrations apply cleanly. ✅ (2026-08-21)

---

### Phase B — Auth APIs (week 1–2) — **done (deployed)**

Backend owns the surface; Firebase stores credentials.

| Method | Path | Behavior |
|--------|------|----------|
| POST | `/auth/signup` | Validate → create Firebase user → create Postgres profile → optional email verify/OTP |
| POST | `/auth/login` | Server-side password sign-in (Identity Toolkit) → return tokens + user |
| POST | `/auth/forgot-password` | Rate-limit → send OTP/link |
| POST | `/auth/verify-reset-otp` | Verify OTP |
| POST | `/auth/reset-password` | Admin set password → revoke refresh tokens |
| POST | `/auth/change-password` | Require Bearer + verify old password → update → revoke |
| POST | `/auth/logout` | Optional revoke refresh tokens |
| GET | `/me` | Verify Bearer → return Postgres profile |
| PATCH | `/me` | Update profile/settings |
| POST | `/me/devices` | Register FCM token → `devices` row |
| DELETE | `/me/devices/{token}` | Unregister on logout / token rotation |

**Also**

- [x] Rate limits on login/OTP/forgot — sliding window, per email and per IP (`auth_rate_limits`)
- [x] Secure OTP storage (hash, TTL, max attempts) — `auth_otps`, HMAC-hashed codes
- [x] Port logic from existing Functions: `sendEmailOtp`, `completeEmailOtpSignup`, password reset OTP, `ensureUserProfile`

**Implementation note:** `POST /auth/signup` in the table above is split into
two calls to mirror the OTP-gated flow the Functions had: `POST
/auth/signup/otp` (send the code) then `POST /auth/signup` (verify the code +
create the account). Two new tables support the parts Firestore's `authTemp`/
`authRateLimits` collections used to cover: `password_reset_sessions` (the
token minted by `verify-reset-otp`) and `auth_rate_limits`.

**Why `/me/devices` ships here, not in Phase D:** the Phase D push worker reads the `devices` table, but today Flutter writes `fcmTokens` onto the Firestore user doc (`PushNotificationService`) and `onUserTransactionCreatedNotify` reads it from there. The endpoint must exist (and the app must populate it) before the Postgres worker can become the only notification path, or push goes silent.

**Exit criteria:** Swagger can signup → login → `/me` → change password → forgot/reset without Flutter. ✅ Verified locally and on Cloud Run.

---

### Phase C — Transactions & stats APIs (week 2–4) — **done (deployed)**

**Schema (align with current Firestore fields where possible)**

- [x] `transactions`
- [x] `raw_ingestions`
- [x] `categories` (global + user) — **seed the default set in this phase** (migration or seed script)
- [x] `merchant_category_overrides`
- [ ] `monthly_summaries` — optional here; Phase D populates it. `GET /analytics/summary` is live SQL.

Seeding categories in C matters because Home tiles resolve colors through `CategoryColorBinder`, which streams categories today. If the table is empty until the Flutter categories screen is cut over (last), migrated Home screens lose their colors.

**APIs**

| Method | Path | Replaces |
|--------|------|----------|
| GET | `/transactions` | `listTransactions` (dateFrom/dateTo, sortBy, orderBy, cursor) ✅ |
| GET | `/transactions/{id}` | detail ✅ |
| PATCH | `/transactions/{id}` | update ✅ |
| DELETE | `/transactions/{id}` | soft delete ✅ |
| POST | `/transactions/{id}/review` | mark reviewed ✅ |
| GET | `/transactions/search` | Firestore search ✅ |
| GET | `/period-stats` | `getPeriodStats` — **live SQL over `transactions`**, no worker dependency ✅ |
| GET | `/analytics/summary` | monthly summary reads (live SQL now, materialized later) ✅ |
| GET | `/merchants/{key}` | merchant summary ✅ |
| GET | `/merchants/{key}/transactions` | merchant list ✅ |
| GET | `/review` | needs_review + ingestions ✅ |
| GET/POST | `/categories` | category datasources ✅ |

**SQL advantage:** `WHERE date BETWEEN … ORDER BY amount DESC LIMIT …` works natively.

**Compute stats live in this phase.** `getPeriodStats` scans transactions today, so plain SQL reproduces it. Do not make C's exit criteria depend on materialized `monthly_summaries`, or C blocks on the Phase D workers.

**Also shipped with C (needed by Review / Insights, not a separate phase):**
`POST /transactions` (manual create + optional `ingestion_id`) and `GET /analytics/summaries`. Amount sort **with** a date range is allowed (the SQL advantage over Firestore).

**Exit criteria:** All list/search/stats behaviors match current app via curl/Swagger, using seeded categories and hand-inserted transaction rows. ✅ Verified locally (`make check`); deployed to Cloud Run + Supabase (2026-08-21).

---

### Phase D — Ingest & workers (week 3–5, dev/staging only) — **done (deployed)**

Build and verify these against **dev**. Shortcuts now hit `POST /ingest` (Phase F freeze, 2026-08-23). `ingestTransactionForUser` stays deployed for rollback.

- [x] `POST /ingest` (or `/webhooks/sms`) — port `ingestTransactionForUser` (Gemini, dedup, normalize)
- [x] Auth for webhook (`X-User-Id` or signed secret — document in `docs/webhooks.md`)
- [x] Worker/cron: recompute period summaries (replace `onUserTransactionWritten`)
- [x] Worker: send FCM on new tx (replace `onUserTransactionCreatedNotify`) using Admin messaging + `devices` table
- [x] Worker: OTP/doc cleanup (replace `cleanupExpiredAuthDocs`) — `make scheduler` creates the Cloud Scheduler jobs

**Leave `onUserTransactionCreatedNotify` deployed.** The Postgres push worker only becomes the sole notify path after the app registers tokens via `POST /me/devices` (Phase E step 1) and production has cut over. Until then the two paths cover different data sources, so disabling the trigger early means no push for production users.

**Exit criteria:** on dev, a Shortcut/SMS call creates Postgres rows, aggregates recompute, and the worker sends push to a device registered through `/me/devices`. ✅ APIs + workers deployed to Cloud Run (2026-08-21); Cloud Scheduler + full ingest/push smoke still optional before Flutter cutover.

---

### Phase E — Flutter API client (week 4–6, can overlap D)

**Pre-E checklist (2026-08-21):** steps 1–4 are live on Cloud Run + Supabase
`https://novaspend-api-h7asbihbya-el.a.run.app/docs`). Step 5 ran 2026-08-21
(`make migrate-firestore SUPABASE=1`): 4 users, 343 transactions, 45 ingestions,
9 monthly summaries copied into Supabase. Re-run is idempotent.

**Runs against the dev/staging Cloud Run URL with dev data already migrated ([§6](#6-migration-order-checklist-you-can-follow) step 5).** A migrated screen pointed at an empty database looks identical to a broken screen, which makes this phase impossible to verify otherwise. It can overlap Phase D, but not Phase C — the screens need those APIs.

- [x] Add `ApiClient` (Dio/http) + secure token storage
- [x] Feature datasources call FastAPI instead of Firestore/Functions
- [x] Auth UI → `/auth/*` only (stop product flows on Firebase Auth SDK) — email/password OTP paths; Google/Apple still Firebase
- [x] Feature flags / remote config optional: `use_backend_v1=true` for staged rollout (`AppConstants.kUseBackendV1`, default on)
- [x] Keep architecture: `presentation → domain → data` (new remote datasource)

**Order inside Flutter (cutover order)**

1. Auth + `/me` + FCM token → `POST /me/devices` ✅ (2026-08-21)
2. Home — period stats **and** transactions list in one flag (`HomeProvider` loads both together; a half-migrated Home is extra work for no benefit) ✅
3. Search ✅
4. Merchant ✅
5. Review ✅
6. Categories / settings — the *screens* go last; category *data* was already seeded in Phase C ✅ (`GET/POST /categories`, Settings webhook → `/ingest`)
7. Confirm client-triggered ingest paths (if any) target the new URL ✅ (Settings copies FastAPI `/ingest` when `kUseBackendV1`)

**Exit criteria:** App works against **dev** Cloud Run with Firestore reads disabled for migrated features. ✅ Code path: `kUseBackendV1` (default true) routes product screens through FastAPI. Step 5 data migrate is still required for Home to show historical Firestore rows.

**Exit criteria:** App works against **dev** Cloud Run with Firestore reads disabled for migrated features.

---

### Phase F — Data migration & production cutover (week 6–7)

**Do not skip backups.** Run the same migration script twice: once against **dev** (before Phase E, [§6](#6-migration-order-checklist-you-can-follow) step 5) and once against **production** here.

1. Export Firestore collections (or Admin SDK dump script) — `scripts/migrate_firestore.py` reads live via Admin SDK.
2. Transform → Postgres (UUID document ids kept; Firestore auto-ids → UUIDv5).
3. Migrate users: ensure every Firebase Auth user has a Postgres `users` row (`firebase_uid`).
4. Migrate transactions, ingestions, categories, overrides, summaries, settings.
5. Validate counts + spot-check amounts per uid.

**Optional dual-write (decide in [§13](#13-decisions-to-lock-before-coding), and it belongs *before* the freeze)**

If you want a longer, lower-risk transition, have `ingestTransactionForUser` write Firestore **and** call `POST /ingest` for a few days ahead of the freeze. This is what makes Review-on-API safe early. Dual-**write** is not the same as the dual-**run** in [§7](#7-dual-run--rollback), which is just idle Firebase kept as a rollback target after cutover.

**Freeze window — everything below happens in one session, in this order**

- [x] Announce short write freeze or accept last-minute delta sync — last-minute delta accepted (Shortcut already on `/ingest`)
- [x] Final incremental sync — `make migrate-firestore SUPABASE=1` on 2026-08-23 (+1 tx; 400 already present)
- [x] Validate counts again post-sync — users 4=4; tx Firestore 345 / Postgres 346 (Postgres ahead from live ingest); summaries 9=9. Ingestions 47 vs 7 (old rows skipped on unique/FK; new ingest writes Postgres)
- [x] Flip Flutter **and** Shortcuts/webhook to backend URLs **together** — Flutter `kUseBackendV1` default on; Shortcut webhook updated by owner
- [x] Switch push to the Postgres worker; stop `onUserTransactionCreatedNotify` — `POST /ingest` calls `notify_new_transaction` (`devices` table). Firestore trigger stays **deployed but idle** (no new Firestore writes). Do not delete until step 12
- [ ] Monitor errors 48–72h — **started 2026-08-23** (step 11)

Flipping Shortcuts before the migration would split history: new transactions in Postgres, everything older in Firestore, and a migration that then has to special-case the gap or double-count it. Flipping Flutter before the migration shows users an empty app.

**Exit criteria:** Production traffic on Postgres; Firestore no longer required for reads/writes.

---

## 6. Migration order (checklist you can follow)

Use this as the single sequence — it overrides the phase letters and the summary in [§15](#15-one-page-summary) if they ever disagree. Do not jump ahead.

Steps 1–9 touch **dev/staging only**. Production keeps running on Firestore/Functions untouched until step 10.

| Step | Work | Env | Done when |
|------|------|-----|-----------|
| 0 | Lock [§13](#13-decisions-to-lock-before-coding) decisions; create `backend/` folder; pick Postgres host | — | Decisions recorded in §13 table |
| 1 | Phase A foundation + Cloud Run | dev | `/health` public, migrations apply |
| 2 | Phase B auth APIs **+ `/me/devices`** | dev | Swagger signup → login → `/me` works |
| 3 | Phase C transactions/search/stats APIs **+ seed categories** | dev | Swagger list/search/stats works on live SQL |
| 4 | Phase D ingest + workers | dev | Dev ingest → Postgres rows, aggregates, push |
| 5 | Migrate **dev** Firestore → Postgres (same script you'll use in prod) | dev | Ran 2026-08-21: 4 users, 343 txs, 45 ingestions, 9 summaries on Supabase |
| 6 | Flutter: `ApiClient` + Auth + `/me` + device registration | dev | Login/signup on API, token in `devices` |
| 7 | Flutter: Home (stats **and** list, one flag) | dev | No `listTransactions` / `getPeriodStats` calls |
| 8 | Flutter: search, merchant, review, categories, settings screens | dev | No client Firestore for those |
| 9 | Point **dev** Shortcuts/webhook at new ingest URL; rehearse the cutover | dev | Owner updated Shortcut + verified Home history (2026-08-23) |
| 10 | **Production:** migrate data → validate → freeze → flip Flutter + Shortcuts + push together | **prod** | Live on backend 2026-08-23 ([§5 Phase F](#phase-f--data-migration--production-cutover-week-67)) |
| 11 | Dual-run monitoring (Firebase idle, as rollback) | prod | **In progress** — keep Functions deployed 3–7 days |
| 12 | Firebase cleanup ([§8](#8-post-migration-firebase-cleanup)) | prod | Unused services removed/disabled |

**Optional dual-write**, if chosen, starts a few days *before* step 10 — not at step 11.

---

## 7. Dual-run & rollback

Two different things, often confused:

| Term | When | What it means |
|------|------|---------------|
| **Dual-write** | *Before* cutover (optional) | Ingest writes Firestore **and** calls `POST /ingest`, so both stores stay current |
| **Dual-run** | *After* cutover, 3–7 days | Backend is the only writer; Firebase sits deployed but idle as a rollback target |

### Dual-run (recommended 3–7 days, step 11)

- Backend is primary and the only source of truth.
- Keep Firestore Functions **deployed but unused** (or read-only) for emergency.
- Feature flag in app: fallback only if you explicitly support it (prefer not to dual-read; dual-write is harder).

### Rollback triggers

- Data loss / incorrect balances
- Ingest failure rate spike
- Auth lockouts

### Rollback actions

1. Flip Flutter flag / release previous build pointing at Functions/Firestore.
2. Point webhook back to `ingestTransactionForUser`.
3. Re-enable `onUserTransactionCreatedNotify` so push keeps working on the Firestore path.
4. Reconcile any transactions written to Postgres during the window back into Firestore (small volume if you roll back fast — this is the main reason to keep the window short).
5. Do **not** delete Firebase data until cleanup phase.
6. Fix forward; re-attempt cutover.

---

## 8. Post-migration Firebase cleanup

Only after production has been stable on the backend and you no longer need Firestore as fallback.

### 8.1 Remove from Flutter (`NovaSpend`)

| Remove / stop using | Notes |
|---------------------|--------|
| `cloud_firestore` package & all `Firestore*Datasource` | After every feature uses API |
| Direct callable usage for list/stats/auth OTP | Replaced by FastAPI |
| Firebase Auth SDK for signup/login/reset | Keep **only if** you still use it for token refresh; prefer backend-issued/passed tokens only |
| Firestore listeners (monthly summary, categories streams) | Poll or refresh via API |
| App Check client wiring **if** APIs no longer require it | Optional keep for abuse |

**Keep in Flutter (hybrid)**

- `firebase_core` (if still using Auth/FCM)
- `firebase_auth` — only if you still store/refresh Firebase ID tokens client-side
- `firebase_messaging` — FCM receive + getToken → `POST /me/devices`

If you later leave Firebase Auth entirely, remove Auth SDK too and use your own JWT refresh.

### 8.2 Remove / disable Cloud Functions

Delete or stop deploying (order: confirm zero traffic in logs first):

| Function | Replaced by |
|----------|-------------|
| `listTransactions` | `GET /transactions` |
| `getPeriodStats` | `GET /period-stats` |
| `ingestTransactionForUser` | `POST /ingest` |
| `onUserTransactionWritten` | SQL worker / triggers |
| `onUserTransactionCreatedNotify` | Push worker |
| `sendEmailOtp`, `completeEmailOtpSignup`, … | `/auth/*` |
| `ensureUserProfile` | `/auth/signup` + `/me` |
| `cleanupExpiredAuthDocs` | Backend cron |

**How**

```bash
# After confirming unused in Firebase console → Functions → Logs
firebase functions:delete listTransactions --region asia-south1
# …repeat per function
# Or remove exports from functions/src/index.ts and deploy empty/minimal set
```

Eventually delete the `functions/` package or leave a stub README pointing to `backend/`.

### 8.3 Firestore cleanup

1. Export final backup (GCS).
2. Lock rules to deny all client access:

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

3. After retention period (e.g. 30–90 days), delete collections or the Firestore database.
4. Remove composite indexes you no longer need (optional cost cleanup).

### 8.4 What NOT to delete in Firebase (phase 1)

| Keep | Until |
|------|--------|
| Firebase Authentication users | You migrate identity elsewhere |
| FCM / Cloud Messaging | You change push provider |
| GCP project + Cloud Run | Always (hosting backend) |
| App Check | You replace abuse controls |

### 8.5 Optional later: leave Firebase Auth too

Only after backend auth is solid:

1. Introduce Supabase Auth or local password hashing + JWT.
2. Migrate users (password reset forced or hash import if possible).
3. Remove `firebase_auth` from Flutter.
4. Disable Firebase Authentication in console.

---

## 9. API conventions (implement once, reuse)

- Base URL: `https://api.<domain>` → Cloud Run
- Auth header: `Authorization: Bearer <firebase_id_token>`
- Errors: `{ "detail": "...", "code": "..." }`
- Pagination: prefer `limit` + `cursor` (or `offset` for amount-sorted windows)
- Dates: `YYYY-MM-DD`, timezone documented (client local dates like today)
- Money: decimal/numeric in Postgres; never float for storage
- OpenAPI: FastAPI `/docs` is the contract for Flutter + QA

---

## 10. Security checklist

- [x] All product routes require verified token (`CurrentUser` on `/me`, `/transactions`, `/period-stats`, `/analytics`, `/merchants`, `/review`, `/categories`)
- [x] Webhook routes use `X-User-Id` (Function parity) and optional `X-Ingest-Secret` (Phase D)
- [x] Rate limit `/auth/login`, OTP, forgot-password
- [x] Passwords never logged
- [x] Change-password revokes other sessions
- [ ] Postgres least-privilege DB user for the API
- [ ] Secrets in Secret Manager / env — not in git
- [ ] HTTPS only

---

## 11. Success metrics

| Metric | Target |
|--------|--------|
| Client Firestore reads (prod) | → ~0 for product features |
| Cloud Functions invocations (legacy) | → 0 after cleanup |
| List + sort by amount within date range | Works via SQL |
| Auth flows | 100% via `/auth/*` |
| Ingest success rate | ≥ previous baseline |
| p95 API latency (list/stats) | Define SLO (e.g. < 500ms) |

---

## 12. Rough timeline (indicative)

| Weeks | Focus | Steps ([§6](#6-migration-order-checklist-you-can-follow)) |
|-------|--------|-------|
| 1–2 | Foundation + Auth APIs + `/me/devices` | 0–2 |
| 2–4 | Transactions, search, stats (live SQL) | 3 |
| 3–5 | Ingest + workers on dev | 4 |
| 4 | Dev data migration (unblocks Flutter) | 5 |
| 4–6 | Flutter cutover on dev (feature by feature) | 6–9 |
| 6–7 | Prod migration + freeze + cutover | 10 |
| 7 | Dual-run | 11 |
| 7–8 | Firebase cleanup | 12 |

The overlap between ingest (weeks 3–5) and Flutter (weeks 4–6) is fine because both target dev. Only step 10 touches production.

Adjust for team size; one developer may stretch this.

---

## 13. Decisions to lock before coding

1. **Postgres host:** Cloud SQL vs Supabase  
2. **Tokens:** pass through Firebase ID/refresh tokens vs mint your own JWT after login  
3. **IDs:** keep Firestore string IDs vs new UUIDs + mapping table  
4. **Domain:** custom domain for Cloud Run  
5. **OTP email:** keep current provider vs new  
6. **Dual-write:** yes/no during transition — decide before building Phase D ingest, since "yes" means the legacy Function also calls `POST /ingest`  

Record answers in this section when decided:

| Decision | Choice | Date |
|----------|--------|------|
| Postgres host | **Dev:** local Homebrew Postgres 16. **Staging/prod (Cloud Run):** Supabase Postgres | 2026-08-21 |
| Token strategy | **Pass-through Firebase ID tokens.** `/auth/login` and `/auth/signup` return the Identity Toolkit `idToken`/`refreshToken` pair as-is; the client sends `idToken` as the Bearer token and refreshes it the normal Identity Toolkit way. No backend-issued session token. | 2026-08-21 |
| ID strategy | Keep Firestore UUID document ids. Auto-ids (`doc()`) become a stable UUIDv5 (`app.services.firestore_migrate.stable_uuid`) so a second run is idempotent. `users.firebase_uid` is the Firestore user doc id. | 2026-08-21 |
| Dual-write | **No.** Freeze-window cutover (Phase F): migrate, then flip Flutter + Shortcuts together. Dev copies data with `make migrate-firestore SUPABASE=1` instead of dual-writing ingest. | 2026-08-21 |

---

## 14. Related docs

- `docs/webhooks.md` — Function URL (prod) and FastAPI `POST /ingest` (dev)  
- `docs/mvp-revamp-prd.md` / `docs/mvp-revamp-tasks.md` — product context  
- `.cursor/rules/novaspend-architecture.mdc` — keep Flutter layer boundaries when adding API datasources  

---

## 15. One-page summary

1. Build FastAPI + Postgres on Cloud Run.  
2. Ship `/auth/*` + `/me/devices` (Firebase under the hood).  
3. Ship transactions/search/stats APIs (live SQL) with categories seeded.  
4. Ship ingest + workers, verified on dev.  
5. Migrate **dev** data → Postgres, then point the Flutter app at dev and cut screens over feature by feature.  
6. **Production:** migrate data first, then flip Flutter + Shortcuts + push in one freeze window.  
7. Dual-run with Firebase idle; stabilize 3–7 days.  
8. Delete Functions, lock/delete Firestore, keep Auth + FCM until you outgrow them.

The order that matters most: **data before traffic.** Never point production clients or webhooks at the backend before its tables are populated.
