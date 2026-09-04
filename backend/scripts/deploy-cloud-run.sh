#!/usr/bin/env bash
# Deploy NovaSpend API to Cloud Run.
#
# Loads SUPABASE_DATABASE_URL from backend/.env and sets Cloud Run env vars
# directly (no Secret Manager). Special characters in the DB password are
# handled via --env-vars-file.
set -euo pipefail

PROJECT="${PROJECT:-auto-expense-tracker-2026}"
REGION="${REGION:-asia-south1}"
SERVICE="${SERVICE:-novaspend-api}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LEGACY_SECRET="${LEGACY_SECRET:-novaspend-database-url}"

gcloud config set project "$PROJECT" >/dev/null
cd "$ROOT"

ENV_FILE="$(mktemp -t novaspend-cloudrun-env.XXXXXX.yaml)"
cleanup() { rm -f "$ENV_FILE"; }
trap cleanup EXIT

.venv/bin/python - "$ENV_FILE" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import quote, unquote

from dotenv import dotenv_values

out = Path(sys.argv[1])
env = dotenv_values(".env")

raw = (env.get("SUPABASE_DATABASE_URL") or "").strip().strip('"').strip("'")
if not raw:
    raise SystemExit("SUPABASE_DATABASE_URL is missing from backend/.env")

for prefix in ("postgresql+asyncpg://", "postgres://", "postgresql://"):
    if raw.startswith(prefix):
        rest = raw[len(prefix) :]
        break
else:
    raise SystemExit("SUPABASE_DATABASE_URL must be a postgresql:// URL")

userinfo, hostpart = rest.rsplit("@", 1)
user, password = userinfo.split(":", 1)
password = unquote(password)
user = unquote(user)

# Direct db.<ref>.supabase.co is IPv6-only — rewrite to session pooler.
m = re.search(r"db\.([a-z0-9]+)\.supabase\.co", hostpart)
if m:
    ref = m.group(1)
    user = f"postgres.{ref}"
    host = "aws-0-ap-southeast-1.pooler.supabase.com:5432"
elif "pooler.supabase.com" in hostpart:
    host = hostpart.split("/")[0].split("?")[0]
    if not user.startswith("postgres.") and m is None:
        # already pooler; keep user as provided
        pass
else:
    host = hostpart.split("/")[0].split("?")[0]

database_url = (
    f"postgresql+asyncpg://{quote(user, safe='')}:{quote(password, safe='')}"
    f"@{host}/postgres?ssl=require"
)

# YAML-ish env file for gcloud --env-vars-file (quote values safely).
def yq(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'

def require(name: str) -> str:
    value = (env.get(name) or "").strip().strip('"').strip("'")
    if not value:
        raise SystemExit(f"{name} is missing from backend/.env")
    return value

firebase_web_api_key = require("FIREBASE_WEB_API_KEY")
otp_hash_secret = require("OTP_HASH_SECRET")
field_encryption_key = require("FIELD_ENCRYPTION_KEY")
resend_api_key = require("RESEND_API_KEY")
resend_from_email = (env.get("RESEND_FROM_EMAIL") or "").strip().strip('"').strip("'")
if not resend_from_email:
    resend_from_email = "NovaSpend <onboarding@resend.dev>"

lines = [
    'ENVIRONMENT: "dev"',
    'FIREBASE_PROJECT_ID: "auto-expense-tracker-2026"',
    'DOCS_ENABLED: "true"',
    'LOG_JSON: "true"',
    'SERVICE_NAME: "novaspend-api"',
    f"DATABASE_URL: {yq(database_url)}",
    f"FIREBASE_WEB_API_KEY: {yq(firebase_web_api_key)}",
    f"OTP_HASH_SECRET: {yq(otp_hash_secret)}",
    f"FIELD_ENCRYPTION_KEY: {yq(field_encryption_key)}",
    f"RESEND_API_KEY: {yq(resend_api_key)}",
    f"RESEND_FROM_EMAIL: {yq(resend_from_email)}",
]
for name in ("GEMINI_API_KEY", "CRON_SECRET", "INGEST_SHARED_SECRET"):
    value = (env.get(name) or "").strip().strip('"').strip("'")
    if value:
        lines.append(f"{name}: {yq(value)}")
lines.append("")
out.write_text("\n".join(lines))
out.chmod(0o600)

print("database=" + re.sub(r"(://[^:]+:)([^@]+)(@)", r"\1***\3", database_url))
print("phase_b_env=FIREBASE_WEB_API_KEY,OTP_HASH_SECRET,FIELD_ENCRYPTION_KEY,RESEND_API_KEY,RESEND_FROM_EMAIL")
PY

echo "Deploying $SERVICE to Cloud Run ($REGION) — secrets from .env as plain env vars…"

# If DATABASE_URL was previously mounted from Secret Manager, clear that binding
# before setting a string env var (Cloud Run rejects type changes in one step).
gcloud run services update "$SERVICE" \
  --project="$PROJECT" \
  --region="$REGION" \
  --remove-secrets=DATABASE_URL \
  --quiet >/dev/null 2>&1 || true

gcloud run deploy "$SERVICE" \
  --project="$PROJECT" \
  --region="$REGION" \
  --source="$ROOT" \
  --allow-unauthenticated \
  --port=8080 \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=5 \
  --timeout=540 \
  --clear-secrets \
  --env-vars-file="$ENV_FILE" \
  --quiet

if gcloud secrets describe "$LEGACY_SECRET" --project="$PROJECT" >/dev/null 2>&1; then
  echo "Deleting legacy Secret Manager secret: $LEGACY_SECRET"
  gcloud secrets delete "$LEGACY_SECRET" --project="$PROJECT" --quiet
fi

URL="$(gcloud run services describe "$SERVICE" --project="$PROJECT" --region="$REGION" --format='value(status.url)')"
echo
echo "Deployed: $URL"
echo "Health:   $URL/health"
echo "Docs:     $URL/docs"
echo "Ready:    $URL/health/ready"
