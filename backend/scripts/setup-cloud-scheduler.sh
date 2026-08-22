#!/usr/bin/env bash
# Create Cloud Scheduler jobs for Phase D workers (dev/staging).
# Safe to re-run: existing jobs are updated in place.
#
# Requires: gcloud auth, CRON_SECRET in backend/.env
set -euo pipefail

PROJECT="${PROJECT:-auto-expense-tracker-2026}"
LOCATION="${LOCATION:-asia-south1}"
SERVICE_URL="${SERVICE_URL:-https://novaspend-api-h7asbihbya-el.a.run.app}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT"
CRON_SECRET="$("$ROOT/.venv/bin/python" - <<'PY'
from dotenv import dotenv_values
value = (dotenv_values(".env").get("CRON_SECRET") or "").strip().strip('"').strip("'")
if not value:
    raise SystemExit("CRON_SECRET is missing from backend/.env")
print(value)
PY
)"

gcloud config set project "$PROJECT" >/dev/null

upsert_job() {
  local name="$1"
  local schedule="$2"
  local path="$3"
  local args=(
    --location="$LOCATION"
    --schedule="$schedule"
    --time-zone="Asia/Karachi"
    --uri="${SERVICE_URL}${path}"
    --http-method=POST
    --headers="X-Cron-Secret=${CRON_SECRET},Content-Type=application/json"
    --message-body="{}"
  )
  if gcloud scheduler jobs describe "$name" --location="$LOCATION" >/dev/null 2>&1; then
    gcloud scheduler jobs update http "$name" "${args[@]}"
  else
    gcloud scheduler jobs create http "$name" "${args[@]}"
  fi
}

# Cloud Run stays publicly reachable; job routes require X-Cron-Secret.
upsert_job novaspend-cleanup-auth "0 3 * * *" "/internal/jobs/cleanup-auth"
upsert_job novaspend-recompute-summaries "15 3 * * *" "/internal/jobs/recompute-summaries"

echo "Scheduler jobs:"
gcloud scheduler jobs list --location="$LOCATION" \
  --filter="name:(novaspend-cleanup-auth OR novaspend-recompute-summaries)"
