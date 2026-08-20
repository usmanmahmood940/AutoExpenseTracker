# NovaSpend Backend & Firebase Migration Plan

**Status:** Planning document (follow in order)  
**Target stack:** FastAPI (Cloud Run) + PostgreSQL (Cloud SQL or Supabase) + Firebase Auth (identity) + FCM (push delivery)  
**App:** NovaSpend (Flutter)

This plan moves product data and business APIs off Firestore/Cloud Functions onto a proper backend, while keeping Firebase for identity and push unless you later choose to replace those too.

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

Do **not** migrate Flutter until Phase A–C APIs exist and are tested in Swagger (`/docs`).

### Phase A — Foundation (week 1)

**Deliverables**

- [ ] Create `backend/` FastAPI project
- [ ] Docker + local run (`uvicorn`)
- [ ] Postgres (local Docker or Supabase/Cloud SQL) + Alembic
- [ ] Config via env (DB URL, Firebase project, secrets)
- [ ] Firebase Admin SDK init (verify ID tokens, manage users)
- [ ] Health: `GET /health`
- [ ] Deploy empty app to **Cloud Run** (CI optional later)
- [ ] CORS + structured logging + error envelope

**Postgres core tables (minimum)**

- `users` (`id`, `firebase_uid` UNIQUE, email, display_name, currency, created_at, …)
- `auth_otps` (purpose, code_hash, expires_at, attempts) — if keeping OTP flows
- `devices` (user_id, fcm_token, platform)

**Exit criteria:** Cloud Run URL live; `/docs` opens; DB migrations apply cleanly.

---

### Phase B — Auth APIs (week 1–2)

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

**Also**

- [ ] Rate limits on login/OTP/forgot
- [ ] Secure OTP storage (hash, TTL, max attempts)
- [ ] Port logic from existing Functions: `sendEmailOtp`, `completeEmailOtpSignup`, password reset OTP, `ensureUserProfile`

**Exit criteria:** Swagger can signup → login → `/me` → change password → forgot/reset without Flutter.

---

### Phase C — Transactions & stats APIs (week 2–4)

**Schema (align with current Firestore fields where possible)**

- `transactions`
- `raw_ingestions`
- `categories` (global + user)
- `merchant_category_overrides`
- `monthly_summaries` (or replace with SQL views later)

**APIs**

| Method | Path | Replaces |
|--------|------|----------|
| GET | `/transactions` | `listTransactions` (dateFrom/dateTo, sortBy, orderBy, cursor/offset) |
| GET | `/transactions/{id}` | detail |
| PATCH | `/transactions/{id}` | update |
| DELETE | `/transactions/{id}` | soft delete |
| POST | `/transactions/{id}/review` | mark reviewed |
| GET | `/transactions/search` | Firestore search |
| GET | `/period-stats` | `getPeriodStats` |
| GET | `/analytics/summary` | monthly summary reads |
| GET | `/merchants/{key}` | merchant summary |
| GET | `/merchants/{key}/transactions` | merchant list |
| GET | `/review` | needs_review + ingestions |
| GET/POST | `/categories` | category datasources |

**SQL advantage:** `WHERE date BETWEEN … ORDER BY amount DESC LIMIT …` works natively.

**Exit criteria:** All list/search/stats behaviors match current app via curl/Swagger.

---

### Phase D — Ingest & workers (week 3–5)

- [ ] `POST /ingest` (or `/webhooks/sms`) — port `ingestTransactionForUser` (Gemini, dedup, normalize)
- [ ] Auth for webhook (`X-User-Id` or signed secret — document in `docs/webhooks.md`)
- [ ] Worker/cron: recompute period summaries (replace `onUserTransactionWritten`)
- [ ] Worker: send FCM on new tx (replace `onUserTransactionCreatedNotify`) using Admin messaging + `devices` table
- [ ] Worker: OTP/doc cleanup (replace `cleanupExpiredAuthDocs`)

**Exit criteria:** Shortcut/SMS ingest creates Postgres rows; push still works.

---

### Phase E — Flutter API client (week 4–6, can overlap C/D)

- [ ] Add `ApiClient` (Dio/http) + secure token storage
- [ ] Feature datasources call FastAPI instead of Firestore/Functions
- [ ] Auth UI → `/auth/*` only (stop product flows on Firebase Auth SDK)
- [ ] Feature flags / remote config optional: `use_backend_v1=true` for staged rollout
- [ ] Keep architecture: `presentation → domain → data` (new remote datasource)

**Order inside Flutter (cutover order)**

1. Auth + `/me`
2. Home period stats
3. Home / transactions list
4. Search
5. Merchant
6. Review
7. Categories / settings
8. Ingest path (if client-triggered) / confirm Shortcuts hit new URL

**Exit criteria:** App works against Cloud Run with Firestore reads disabled for migrated features.

---

### Phase F — Data migration (week 5–7)

**Do not skip backups.**

1. Export Firestore collections (or Admin SDK dump script).
2. Transform → Postgres (preserve IDs or map `firestore_id` → uuid).
3. Migrate users: ensure every Firebase Auth user has a Postgres `users` row (`firebase_uid`).
4. Migrate transactions, ingestions, categories, overrides, summaries, settings.
5. Validate counts + spot-check amounts per uid.
6. Dual-write period (optional): Functions write Firestore **and** call backend, or backend is source of truth only after freeze.

**Freeze window**

- [ ] Announce short write freeze or accept last-minute delta sync
- [ ] Final incremental sync
- [ ] Flip Flutter / Shortcuts to backend URLs
- [ ] Monitor errors 48–72h

**Exit criteria:** Production traffic on Postgres; Firestore no longer required for reads/writes.

---

## 6. Migration order (checklist you can follow)

Use this as the single sequence. Do not jump ahead.

| Step | Work | Done when |
|------|------|-----------|
| 0 | Read this doc; create `backend/` repo folder; pick Postgres host | Decision recorded |
| 1 | Phase A foundation + Cloud Run | `/health` public |
| 2 | Phase B auth APIs | Swagger auth works |
| 3 | Phase C transactions + stats APIs | Swagger list/search/stats works |
| 4 | Phase D ingest + workers | Ingest + push + aggregates on Postgres |
| 5 | Seed/migrate **dev** Firebase project → Postgres | Dev app can run on backend |
| 6 | Flutter: Auth → backend | Login/signup on API |
| 7 | Flutter: Home stats + list → backend | No `listTransactions` / `getPeriodStats` from app |
| 8 | Flutter: Search, merchant, review, settings → backend | No client Firestore for those |
| 9 | Point Shortcuts/webhook to new ingest URL | New txs only in Postgres |
| 10 | Production data migration + freeze + cutover | Live on backend |
| 11 | Dual-run monitoring | Stable 3–7 days |
| 12 | Firebase cleanup ([§8](#8-post-migration-firebase-cleanup)) | Unused services removed/disabled |

---

## 7. Dual-run & rollback

### Dual-run (recommended 3–7 days)

- Backend is primary.
- Keep Firestore Functions **deployed but unused** (or read-only) for emergency.
- Feature flag in app: fallback only if you explicitly support it (prefer not to dual-read; dual-write is harder).

### Rollback triggers

- Data loss / incorrect balances
- Ingest failure rate spike
- Auth lockouts

### Rollback actions

1. Flip Flutter flag / release previous build pointing at Functions/Firestore.
2. Point webhook back to `ingestTransactionForUser`.
3. Do **not** delete Firebase data until cleanup phase.
4. Fix forward; re-attempt cutover.

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

- [ ] All product routes require verified token
- [ ] Webhook routes use shared secret / signed requests
- [ ] Rate limit `/auth/login`, OTP, forgot-password
- [ ] Passwords never logged
- [ ] Change-password revokes other sessions
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

| Weeks | Focus |
|-------|--------|
| 1–2 | Foundation + Auth APIs |
| 2–4 | Transactions, search, stats |
| 3–5 | Ingest + workers |
| 4–6 | Flutter cutover (feature by feature) |
| 5–7 | Prod migration + dual-run |
| 7–8 | Firebase cleanup |

Adjust for team size; one developer may stretch this.

---

## 13. Decisions to lock before coding

1. **Postgres host:** Cloud SQL vs Supabase  
2. **Tokens:** pass through Firebase ID/refresh tokens vs mint your own JWT after login  
3. **IDs:** keep Firestore string IDs vs new UUIDs + mapping table  
4. **Domain:** custom domain for Cloud Run  
5. **OTP email:** keep current provider vs new  
6. **Dual-write:** yes/no during transition  

Record answers in this section when decided:

| Decision | Choice | Date |
|----------|--------|------|
| Postgres host | _TBD_ | |
| Token strategy | _TBD_ | |
| ID strategy | _TBD_ | |
| Dual-write | _TBD_ | |

---

## 14. Related docs

- `docs/webhooks.md` — update ingest URL when Phase D ships  
- `docs/mvp-revamp-prd.md` / `docs/mvp-revamp-tasks.md` — product context  
- `.cursor/rules/novaspend-architecture.mdc` — keep Flutter layer boundaries when adding API datasources  

---

## 15. One-page summary

1. Build FastAPI + Postgres on Cloud Run.  
2. Ship `/auth/*` (Firebase under the hood).  
3. Ship transactions/search/stats/ingest APIs.  
4. Point Flutter + Shortcuts at the API.  
5. Migrate Firestore data → Postgres.  
6. Stabilize.  
7. Delete Functions, lock/delete Firestore, keep Auth + FCM until you outgrow them.
