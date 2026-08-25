# Legacy Cloud Functions (retired)

NovaSpend APIs now live in [`../backend`](../backend) (FastAPI on Cloud Run +
Postgres). Firebase is used only for **Authentication** and **FCM**.

Deployed functions were deleted in migration step 12 (2026-08-25). The TypeScript
in `src/` is kept as a reference archive — **do not deploy this package**.

See [`docs/backend-migration-plan.md`](../docs/backend-migration-plan.md) §8 and
[`docs/webhooks.md`](../docs/webhooks.md) for the live ingest URL.
