# NovaSpend MVP Revamp — Implementation Tasks

Sequenced, actionable tasks only. Each task should be completable and verifiable before moving to the next.

**Reference:** Full product plan in [mvp-revamp-prd.md](./mvp-revamp-prd.md)

---

## Phase A — Remove & Simplify

### A1. Update bottom navigation
- [x] Change tabs in `MainShellPage` from Feed | Insights | Review | Settings → **Home | Search | Insights | Settings**
- [x] Update tab icons and labels in l10n (`app_en.arb`)
- [x] Wire Search tab to a placeholder page initially

### A2. Remove Budgets from app
- [x] Remove `BudgetsPage` route from Settings
- [x] Remove budgets link from `SettingsPage`
- [x] Unregister budget providers/use cases from `injection.dart` (keep files, stop wiring)
- [x] Remove budget notification setup if triggered from app startup
- [x] Verify app builds and runs without budgets

### A3. Remove Categories management page
- [x] Remove `CategoriesPage` route from Settings
- [x] Remove categories link from `SettingsPage`
- [x] Keep category domain layer for transaction edit picker only
- [x] Verify category picker still works in transaction detail edit

### A4. Demote Review tab
- [x] Remove Review from bottom navigation
- [x] Keep `ReviewPage` accessible via Settings → Advanced → "Fix parsing issues"
- [x] Add route/navigation from Settings to existing `ReviewPage`

### A5. Simplify Insights page
- [x] Remove multi-month trend line chart from `InsightsPage`
- [x] Remove bar chart (spent vs income)
- [x] Remove category pie/donut chart
- [x] Keep: month picker, spent/received/net header, top merchants list
- [x] Add simple horizontal category bars (top 5, no `fl_chart`)

### A6. Trim Settings page
- [x] Reorganize into sections: Account, Privacy, Setup, Advanced, About
- [x] Move CSV export under Advanced (collapsed)
- [x] Move Review link under Advanced
- [x] Remove Categories and Budgets links

---

## Phase B — Home Revamp

### B1. Rename Feed → Home
- [x] Rename `FeedPage` → `HomePage` (file + class + imports)
- [x] Rename `FeedProvider` → `HomeProvider` (or keep provider name if too disruptive — document choice)
- [x] Update l10n strings: "Feed" → "Home"

### B2. Add period header toggle
- [x] Add Today | This Week | This Month toggle above timeline
- [x] Default selection: **This Week**
- [x] Show spent + received totals in `BalanceHeader` for selected period
- [x] Read totals from `monthlySummaries` when period = This Month; aggregate client-side for Today/Week

### B3. Add Review banner on Home
- [x] Create `ReviewBanner` widget in `core/widgets/` or `transactions/presentation/widgets/`
- [x] Show banner only when pending review count > 0
- [x] Tap banner → navigate to `ReviewPage`
- [x] Dismissible for current session (optional)

### B4. Improve Home empty state
- [x] Update empty state copy per PRD
- [x] Add CTA linking to Settings setup section
- [x] Keep iOS Shortcut onboarding reference

### B5. Merchant tap on list tile
- [x] Make merchant name tappable on `TransactionListTile`
- [x] Navigate to Merchant Page (placeholder until Phase C)

---

## Phase C — Schema & Backend Prep

### C1. Extend shared schema
- [x] Add to `shared/types/schema.ts`:
  - `merchantNormalized: string`
  - `isRecurring: boolean`
  - `recurringGroupId?: string`
- [x] Add `AiSummary` interface
- [x] Add `RecurringPattern` interface
- [x] Mirror fields in Flutter `TransactionEntity` and model

### C2. Merchant normalization on ingest
- [x] Add `normalizeMerchant()` utility in Cloud Functions
- [x] Set `merchantNormalized` on every new transaction in ingest pipeline
- [x] Write backfill script for existing transactions (one-time)

### C3. Firestore indexes
- [x] Add composite indexes to `firestore.indexes.json`:
  - `merchantNormalized ASC, transactionDate DESC`
  - `isRecurring ASC, transactionDate DESC`
  - `type ASC, periodEnd DESC` on `aiSummaries`
- [x] Deploy indexes: `npm run deploy:rules`

### C4. Firestore security rules
- [x] Add read/write rules for `users/{uid}/aiSummaries/{id}`
- [x] Add read rules for `users/{uid}/recurringPatterns/{id}` (client read-only)
- [x] Deploy updated rules

---

## Phase D — Merchant Page

### D1. Create merchants feature module
- [x] Add `features/merchants/domain/entities/merchant_summary_entity.dart`
- [x] Add `features/merchants/domain/repositories/merchant_repository.dart`
- [x] Add use cases: `GetMerchantTransactions`, `GetMerchantSummary`
- [x] Add data layer: Firestore datasource + repository impl
- [x] Register in `injection.dart`

### D2. Build Merchant Page UI
- [x] Create `MerchantPage` with `AdaptiveScaffold`
- [x] Header: merchant name, total spent, visit count, average
- [x] This month summary card
- [x] Paginated transaction list (reuse `TransactionListTile`)
- [x] Tap row → `TransactionDetailPage`

### D3. Wire navigation
- [x] Connect Home merchant tap → `MerchantPage`
- [x] Connect Search result merchant tap → `MerchantPage`
- [x] Pass `merchantNormalized` key as route argument

---

## Phase E — Search

### E1. Create search feature module
- [x] Add `features/search/domain/repositories/search_repository.dart`
- [x] Add use case: `SearchTransactions`
- [x] Add data layer: Firestore queries (merchant prefix, category, type, date range)
- [x] Register in `injection.dart`

### E2. Build Search Page UI
- [x] Create `SearchPage` with sticky search bar
- [x] Recent searches chips (persist in `shared_preferences`)
- [x] Quick filter chips: This month, Debits, Credits, Subscriptions
- [x] Results list with count header
- [x] Empty and no-results states

### E3. Implement search queries
- [x] Text search: filter by `merchantNormalized` prefix or client-side merchant/category match
- [x] Quick filters: map to structured Firestore queries
- [x] Subscriptions filter: `isRecurring == true`
- [x] Paginate results (50 per page)

### E4. Replace Search placeholder tab
- [x] Wire Search tab in `MainShellPage` to `SearchPage`
- [x] Verify search → detail → back flow

---

## Phase F — Transaction Detail Simplify

### F1. Read-only default view
- [ ] Redesign detail page: merchant + amount hero, category chip, metadata
- [ ] Collapse raw SMS behind expandable section
- [ ] Hide parse confidence from UI

### F2. Edit as bottom sheet
- [ ] Move edit fields into modal bottom sheet (not inline form)
- [ ] Fields: merchant, category (defaults only), type, "Remember for merchant"
- [ ] Remove any budget-related UI from detail

---

## Phase G — Recurring & Subscriptions

### G1. Recurring detection Cloud Function
- [ ] Create `onTransactionWrittenDetectRecurring` trigger
- [ ] Detect pattern: same `merchantNormalized` + similar amount + ~30 day interval
- [ ] Require 3+ occurrences before marking `isRecurring: true`
- [ ] Write/update `users/{uid}/recurringPatterns/{merchantKey}`

### G2. Flutter recurring data layer
- [ ] Add repository to read `recurringPatterns`
- [ ] Add entity/model for `RecurringPattern`

### G3. Subscriptions section in Insights
- [ ] Add "Subscriptions" section below category bars
- [ ] List: merchant name, average amount, last date
- [ ] Tap → Merchant Page
- [ ] Hide section when no recurring patterns exist

### G4. Search subscriptions filter
- [ ] Wire "Subscriptions" quick filter chip to `isRecurring` query
- [ ] Verify end-to-end after G1 is deployed

---

## Phase H — AI Summaries

### H1. AI summary Cloud Functions
- [ ] Create `generateWeeklySummary` (scheduled: Monday 8am user timezone or fixed)
- [ ] Create `generateMonthlySummary` (scheduled: 1st of month)
- [ ] Aggregate transactions for period → prompt Gemini → write `aiSummaries` doc
- [ ] Include specific merchants and amounts in prompt for non-generic output

### H2. Flutter AI summary data layer
- [ ] Add `AiSummaryEntity` + model
- [ ] Add repository: `GetAiSummary(type, period)`
- [ ] Register in DI

### H3. AI summary card in Insights
- [ ] Show narrative card at top of Insights (current month / current week)
- [ ] Loading skeleton while fetching
- [ ] Hide card if no summary generated yet

### H4. Weekly summary push notification
- [ ] Extend `onUserTransactionCreatedNotify` or add new CF to send weekly summary push
- [ ] Deep link opens Insights tab
- [ ] Copy: one sentence + "Tap to see more"

---

## Phase I — Polish & L10n

### I1. L10n strings
- [ ] Add all new copy to `app_en.arb` (Home, Search, Merchant, Insights, banners)
- [ ] Run codegen: `flutter gen-l10n`
- [ ] Replace any hardcoded strings introduced during revamp

### I2. Animations
- [ ] Add `AnimatedSwitcher` on Home period toggle balance change
- [ ] List insert fade for new transactions (250ms)
- [ ] Respect `MediaQuery.disableAnimations`

### I3. Final QA pass
- [ ] Home → Detail → Merchant → back flows
- [ ] Search → Detail → Merchant flows
- [ ] Insights month navigation + AI card + subscriptions
- [ ] Settings → Review → confirm/dismiss
- [ ] Empty states (no transactions, no search results, no subscriptions)
- [ ] Dark mode check on all new screens
- [ ] iOS + Android smoke test

### I4. Cleanup dead code
- [ ] Remove unused budget UI imports/routes
- [ ] Remove unused chart widgets from analytics if no longer referenced
- [ ] Remove or archive complex `transaction_filter_sheet` if fully replaced by Search

---

## Dependency Order Summary

```
A (Remove & Simplify)
  ↓
B (Home Revamp)
  ↓
C (Schema & Backend) ──→ G (Recurring) ──→ G4
  ↓                           ↓
D (Merchant Page) ←───────────┘
  ↓
E (Search)
  ↓
F (Detail Simplify)
  ↓
H (AI Summaries) — can start after C, parallel with D/E
  ↓
I (Polish)
```

**Suggested parallel tracks after Phase A:**
- Track 1: B → D (Home + Merchant)
- Track 2: C → G (Backend + Subscriptions)
- Track 3: E + F (Search + Detail)
- Merge → H → I

---

## Out of Scope (P1 — do not build in this sequence)

- Natural language search
- Duplicate detection UI
- Month-over-month comparison cards
- Gmail/Android SMS ingestion
- Widgets
- Demo data toggle
