# Insights dashboard

Insights is a **period story**: mix, merchants, and what changed. It is not a Mint-style chart wall. Home stays the glance + feed. Activity stays search-by-date.

## Target layout

```
[ This month | Last month | This year ]

        Net  +PKR 50,759
        ↑ 15% vs previous period

  Spent 149,952     Received 200,711     42 txns

  ── Spend over time ─────────────────────
  Line chart (hidden if fewer than 3 points)

  ── What changed ────────────────────────
  One narrative paragraph (Gemini when cached,
  otherwise a rule-based template).

  ── Where money went ────────────────────
  Top 5 category bars: icon, name, % of spent, amount

  ── Top merchants ───────────────────────
  Rank, initials, amount, visit count → Merchant page

  ── Recurring ───────────────────────────
  Merchant, count, average, last date → Merchant page
  (hidden when empty)
```

Month chevrons remain for arbitrary months when a month preset is selected. Custom ranges stay on Activity.

## Phases

### Phase 1 — Polish with existing APIs

Keep `GET /analytics/summary?year_month=`. Flutter only.

- Load current + previous month summaries in parallel.
- Hero net + vs-previous when previous spent is non-zero.
- Secondary KPIs: spent, received, transaction count.
- Category bars use catalog avatars/colors and **% of total spent**.
- Tap category → Activity with that category + the Insights date range.
- Top merchants: rank, initials, amount; tap → Merchant page.
- Copy: Spent / Received (not Debit / Credit).

### Phase 2 — Rule-based narrative

One card from the two summaries:

- Spend % vs previous period
- Top category share
- Top merchant amount

Hide when the period is empty. Not three competing insight tiles.

### Phase 3 — Range + trend

- `GET /analytics/range?from=&to=` — same totals as monthly summary for an inclusive range (This year = YTD).
- `GET /analytics/trend?from=&to=&bucket=day|week` — debit per bucket. Default: day if the range is ≤45 days, else week.
- Comparison for a range: previous window of equal length.
- Flutter: This year chip + `fl_chart` line chart (accent series, muted grid). Hide if fewer than 3 non-zero points.
- No donut.

### Phase 4 — Recurring + Gemini (FastAPI)

App reads FastAPI, not Firestore `aiSummaries` / `recurringPatterns`. No new Cloud Functions. No Monday push.

- `GET /analytics/recurring?from=&to=` — debit merchants flagged `is_recurring` or with 2+ similar amounts.
- `GET /analytics/narrative?from=&to=` — Gemini paragraph with specific merchants/amounts, cached in Postgres. Flutter uses it when present; otherwise the Phase 2 template.
- Additive `by_merchant_stats` on summary/range (amount + visit count) so Insights does not N+1 merchant summaries.
- Activity already supports `subscriptions_only`; surface it on the filter sheet.

## File map

| Area | Files |
|------|--------|
| Flutter Insights | `NovaSpend/lib/features/analytics/` |
| Analytics HTTP | `NovaSpend/lib/core/http/api_json.dart` |
| Backend | `backend/app/services/analytics.py`, `backend/app/api/routes/analytics.py` |
| Narrative cache | `backend/app/db/models/ai_summary.py` + Alembic |
| Tests | `NovaSpend/test/insights_math_test.dart`, `backend/tests/test_analytics.py` |

## Out of scope

- Category donut / pie
- Four equal KPI tiles as the hero (net stays the hero)
- Insights notification bell / profile chrome
- Custom date range on Insights (Activity owns that)
- Monday weekly summary push
- Cloud Functions for AI or recurring patterns
