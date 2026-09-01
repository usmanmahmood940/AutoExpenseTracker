#!/usr/bin/env bash
# Deploy NovaSpend legal pages and landing site to Firebase Hosting.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${FIREBASE_PROJECT:-auto-expense-tracker-2026}"

cd "$ROOT"
firebase deploy --only hosting --project "$PROJECT"

echo
echo "Live URLs:"
echo "  https://${PROJECT}.web.app/privacy"
echo "  https://${PROJECT}.web.app/terms"
echo "  https://${PROJECT}.firebaseapp.com/privacy"
