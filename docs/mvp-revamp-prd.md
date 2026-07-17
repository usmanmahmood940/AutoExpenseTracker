# NovaSpend MVP Revamp — Product Requirements Document

**Version:** 1.0  
**Date:** July 17, 2026  
**Status:** Draft for review  
**Scope:** Client app revamp on top of existing Firestore + AI ingestion pipeline  
**Constraint:** Preserve existing coding architecture (`presentation → domain ← data`) and UI system (90% minimal / 10% glass, `#10B981` accent, `AppCard`, `BalanceHeader`, etc.)

---

## Executive Summary

NovaSpend today is a capable auto-expense tracker with budgets, category management, analytics charts, and a Review tab. That shape puts it closer to traditional finance apps than to the product vision in this document.

**The revamp reframes NovaSpend as:**

> **"Google Photos, but for bank transactions."**

Users open the app, instantly understand where their money went, and close it. No wallets, no budgets, no accounting setup.

**What stays:** Flutter clean architecture, Firebase/Firestore, iOS Shortcuts ingestion, Gemini parsing, biometric lock, merchant overrides, review flow (repositioned), existing design tokens.

**What goes (MVP):** Budgets, budget notifications, category CRUD as a primary feature, dashboard-style analytics, CSV export prominence, complex filter sheets.

**What gets added:** Narrative home, merchant-centric exploration, natural-language search, AI weekly summaries, subscription/recurring detection, calm monthly story view.

---

## 1. Product Vision

### Problem

Bank transaction SMS messages contain all the data users need, but the format is hostile to human understanding at scale. After hundreds of messages, users cannot answer:

- Where did my money go this month?
- How much did I spend on food?
- What was my biggest purchase?
- How much have I spent at KFC?
- What subscriptions renewed recently?

### Ideal User

**Primary:** Urban professionals in Pakistan (PKR, Meezan/HBL/MCB/UBL SMS) who receive 50–300 bank SMS per month and want clarity without effort.

**Secondary:** Anyone who tried Mint/YNAB/spreadsheet tracking and quit because manual entry felt like a second job.

**Psychographic:** "I don't want to manage money. I want to understand it."

### Why Weekly Use

Users return because NovaSpend tells them a **story**, not a spreadsheet:

1. Push notification: *"You spent Rs. 12,400 this week — mostly Food & Dining."*
2. Open app → see today's activity + this week's narrative
3. Search *"KFC"* or *"subscriptions"* and get instant answers
4. End of month → one calm summary: *"Rs. 45,000 out, Rs. 120,000 in. Top merchant: Daraz."*

The habit loop is **curiosity**, not **obligation**.

### Differentiation

| Traditional Expense Trackers | NovaSpend (Revamped) |
|------------------------------|----------------------|
| Manual entry first | Zero entry — SMS already parsed |
| Budgets & goals as core | Understanding as core |
| Dashboard with 8 charts | One number + one sentence |
| Categories you manage | Categories you discover |
| Accounting language | Plain language |
| Setup before value | Value on first open |

**Opinionated stance:** If a feature requires the user to "configure" before they "understand," it does not belong in MVP.

---

## 2. Core User Journey

```
Bank SMS arrives
    ↓
iOS Shortcut → webhook → Gemini → Firestore (existing pipeline, out of scope)
    ↓
Push: "Rs. 1,250 at KFC"
    ↓
User opens app (optional — value exists without opening)
    ↓
HOME: "Today: Rs. 3,400 spent" + recent activity timeline
    ↓
Tap transaction → detail with merchant, category, raw SMS (read-only by default)
    ↓
Tap merchant name → Merchant Page (all visits, total spent, trend)
    ↓
Search: "food this month" → filtered results + AI one-liner
    ↓
INSIGHTS tab: "This month" narrative card + top merchants + subscriptions
    ↓
Close app (< 30 seconds typical session)
```

### Journey Principles

1. **First open after setup:** Show real transactions immediately — never an empty dashboard.
2. **Correction is rare:** Merchant override exists but is buried in detail — not a daily workflow.
3. **Review is exception handling:** Low-confidence parses surface as inline badges, not a permanent 4th tab.
4. **Search is a first-class destination:** Users think in questions, not filters.

---

## 3. MVP Feature List

### P0 — Must Ship

| Feature | Why | User Value | Complexity | Status |
|---------|-----|------------|------------|--------|
| **Home (Timeline)** | Primary "open and understand" screen | See today + recent activity in 3 seconds | Medium — refactor `FeedPage` | MVP |
| **Today / This Week header** | Answers "what happened recently?" | Instant context without charts | Low — uses `monthlySummaries` + client aggregation | MVP |
| **Transaction Detail** | Trust + occasional correction | Verify parse, fix merchant/category once | Low — simplify existing page | MVP |
| **Search** | Core question-answering | "KFC", "subscriptions", "last Friday" | High — new feature + indexes | MVP |
| **Merchant Page** | Recurring question: "how much at X?" | Total spent, visit count, timeline | Medium — new screen, query by merchant | MVP |
| **Monthly Summary (Insights)** | "What changed this month?" | Narrative + top 5 merchants, no chart wall | Medium — simplify `InsightsPage` | MVP |
| **AI Weekly Summary** | Habit driver | Plain-English recap every Monday | Medium — Cloud Function + cached doc | MVP |
| **Subscription Detection** | High-value passive insight | Surfaces Netflix, Jazz, etc. automatically | Medium — extend `recurring_detector.dart` + CF | MVP |
| **Settings (minimal)** | Setup + privacy | Shortcut setup, biometrics, account | Low — trim existing | MVP |
| **Review inline** | Parse quality without a tab | Badge on home + dedicated list from settings | Low — demote `ReviewPage` | MVP |

### P1 — Soon After MVP

| Feature | Why | Complexity | Status |
|---------|-----|------------|--------|
| Natural language search ("how much on food?") | Differentiator | High | Future |
| Duplicate detection UI | Trust in data | Medium | Future |
| Spending comparison ("vs last month") | Context without budgets | Low | Future |
| Account filter chips | Multi-account users | Low — keep simplified version | Future |
| Gmail ingestion (Phase 3) | Android parity path | High | Future |

### Explicitly Removed from MVP

| Feature | Reason |
|---------|--------|
| **Budgets** | Violates product philosophy; creates obligation |
| **Budget notifications** | Anxiety driver, not understanding driver |
| **Categories CRUD page** | Users don't want to manage taxonomy |
| **Multi-chart analytics** | Dashboard overload |
| **Complex filter sheet** | Replace with search |
| **CSV export (prominent)** | Accounting feature; move to Settings > Advanced |
| **Review as main tab** | Exception handling, not daily use |

---

## 4. Screen-by-Screen UX

### Navigation Revamp

**Current:** Feed | Insights | Review | Settings (4 tabs)  
**Proposed:** **Home | Search | Insights | Settings** (4 tabs)

Review moves to: Home banner (if items pending) + Settings > "Fix parsing issues"

---

### 4.1 Home

**Purpose:** Answer "what's happening with my money?" in under 10 seconds.

**Layout (top → bottom):**

```
┌─────────────────────────────────────┐
│  This week                          │
│  Rs. 18,420 spent                   │  ← BalanceHeader variant
│  Rs. 120,000 received               │
├─────────────────────────────────────┤
│  [Review banner — if pending]       │  ← dismissible, links to review list
├─────────────────────────────────────┤
│  Today · Rs. 2,150                  │  ← DaySectionHeader
│  ┌─────────────────────────────┐    │
│  │ KFC              -Rs. 1,250 │    │  ← TransactionListTile
│  │ Food & Dining               │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ JazzCash         -Rs. 900  │    │
│  └─────────────────────────────┘    │
├─────────────────────────────────────┤
│  Yesterday · Rs. 4,300              │
│  ...                                │
└─────────────────────────────────────┘
```

**Components:**
- `BalanceHeader` — period toggle: Today | This Week | This Month (default: This Week)
- `ReviewBanner` — only when `needs_review` count > 0
- Existing `DaySectionHeader` + `TransactionListTile`
- Pull-to-refresh
- Infinite scroll (keep pagination)

**Empty state:**
> "No transactions yet"  
> "Set up the iOS Shortcut to start seeing your spending automatically."  
> [Setup guide link → Settings]

**Interactions:**
- Tap row → Transaction Detail
- Tap merchant name on row → Merchant Page
- Swipe down → refresh
- Period toggle → re-query aggregates (client-side from stream or summary doc)

**Navigation:** Default tab on app open.

---

### 4.2 Transaction Detail

**Purpose:** Verify a transaction; correct rarely.

**Layout:**

```
┌─────────────────────────────────────┐
│  ← Back                             │
│                                     │
│  KFC                                │  ← merchant, large
│  -Rs. 1,250                         │  ← amount, debit red / credit green
│  Food & Dining                      │  ← category chip (read-only default)
│  Feb 14 · 2:34 PM · Meezan ****1234 │
├─────────────────────────────────────┤
│  [Edit]                             │  ← secondary action, not primary
├─────────────────────────────────────┤
│  Original SMS                       │
│  "MCB: Rs. 1,250 spent at KFC..."   │  ← collapsible
└─────────────────────────────────────┘
```

**Edit mode (sheet, not full page):**
- Merchant name
- Category (picker from defaults only — no custom category creation)
- Type (debit/credit)
- "Remember for this merchant" toggle → `merchantCategoryOverrides`

**Remove from detail:** Budget impact, notes field, split, tags.

---

### 4.3 Search

**Purpose:** Answer specific questions about spending history.

**Layout:**

```
┌─────────────────────────────────────┐
│  🔍  Search transactions            │  ← sticky search bar
├─────────────────────────────────────┤
│  Recent searches                    │  ← chips: KFC, Netflix, Fuel
│  [KFC] [Netflix] [Salary]           │
├─────────────────────────────────────┤
│  Quick filters                      │
│  [This month] [Debits] [Credits]    │
│  [Subscriptions]                    │
├─────────────────────────────────────┤
│  Results (42)                       │
│  ┌─────────────────────────────┐    │
│  │ KFC · Feb 14      -Rs. 1,250│    │
│  └─────────────────────────────┘    │
│  ...                                │
└─────────────────────────────────────┘
```

**Search behavior (MVP):**
- Text match on `merchant`, `category`, `bank` (Firestore prefix/range queries)
- Quick filter chips map to structured queries
- "Subscriptions" chip → filter `isRecurring: true` (new field)

**Future (P1):** Natural language → Gemini query translation → Firestore query.

**Empty state:**
> "Search by merchant, category, or bank"  
> Examples: "KFC", "Food", "Meezan"

**Navigation:** Tab 2; also reachable via Home search icon (optional shortcut).

---

### 4.4 Merchant Page

**Purpose:** "How much have I spent at KFC?"

**Layout:**

```
┌─────────────────────────────────────┐
│  ← Back                             │
│                                     │
│  🍔 KFC                             │
│  Rs. 8,750 total · 7 visits         │
│  Avg Rs. 1,250 per visit            │
├─────────────────────────────────────┤
│  This month: Rs. 3,750 (3 visits)   │  ← AppCard summary
├─────────────────────────────────────┤
│  All transactions                   │
│  Feb 14 · -Rs. 1,250                │
│  Jan 28 · -Rs. 1,500                │
│  ...                                │
└─────────────────────────────────────┘
```

**Data source:** Query `transactions` where `merchantNormalized == key`, ordered by date desc.

**Interactions:**
- Tap transaction → Detail
- No edit merchant from here (edit on detail only)

---

### 4.5 Monthly Summary (Insights Tab)

**Purpose:** "What changed this month?" — one screen, not a dashboard.

**Layout:**

```
┌─────────────────────────────────────┐
│  ← February 2026 →                  │  ← month picker
│                                     │
│  Rs. 45,200 spent                   │  ← BalanceHeader
│  Rs. 120,000 received               │
│  Net +Rs. 74,800                    │
├─────────────────────────────────────┤
│  ✨ AI Summary                      │  ← AppCard, narrative text
│  "You spent 12% more than last      │
│   month. Food & Dining was your     │
│   biggest category. Daraz had 5     │
│   purchases totaling Rs. 9,200."    │
├─────────────────────────────────────┤
│  Top merchants                      │
│  1. Daraz          Rs. 9,200        │
│  2. KFC            Rs. 3,750        │
│  3. Shell          Rs. 2,800        │
├─────────────────────────────────────┤
│  By category                        │  ← simple horizontal bars, max 5
│  Food & Dining  ████████  Rs. 12k   │
│  Shopping       ██████    Rs. 9k    │
│  Fuel           ████      Rs. 5k    │
├─────────────────────────────────────┤
│  Subscriptions (3)                  │
│  Netflix · Rs. 1,500/mo · Feb 1     │
│  Jazz · Rs. 500/mo · Feb 5          │
└─────────────────────────────────────┘
```

**Remove from current Insights:**
- Multi-month trend line chart
- Bar chart (spent vs income side-by-side)
- Category pie/donut chart

**Keep (simplified):**
- One horizontal bar list for categories (top 5 only)
- Top merchants list
- Month navigation

---

### 4.6 AI Summaries

The AI weekly summary appears:
1. As a card at top of Insights when viewing current month
2. As a push notification on Monday morning
3. Cached in `users/{uid}/aiSummaries/{periodId}`

**Example copy:**
> "Last week you spent Rs. 18,420 across 23 transactions. Your biggest purchase was Rs. 5,000 at JazzCash. Food spending was up compared to the week before."

No chat UI in MVP. One-way narrative only.

---

### 4.7 Settings

**Purpose:** Setup, privacy, account — nothing else.

**Sections:**

```
Account
  - Email, sign out, delete account

Privacy
  - Biometric lock toggle

Setup
  - iOS Shortcut guide
  - Copy UID + webhook URL
  - Sync status (last synced, last merchant)

Advanced (collapsed)
  - Export CSV
  - Fix parsing issues → Review list
  - Language

About
  - Version
```

**Remove from Settings prominence:**
- Categories page link
- Budgets page link

**Delete entirely (MVP):** `BudgetsPage`, `CategoriesPage` as nav destinations. Category picker remains in transaction edit only.

---

## 5. Information Architecture

### Primary Dimensions

```
Timeline (default)     → chronological, day-grouped
Merchant               → normalized merchant key
Category               → read-only taxonomy (AI-assigned)
Type                   → debit | credit
Period                 → today | week | month | custom
Recurring              → subscription / repeat flag
Search                 → cross-cutting query layer
```

### Data Hierarchy

```
User
└── Transactions (source of truth)
    ├── grouped by day (Home)
    ├── grouped by merchant (Merchant Page)
    ├── grouped by category (Insights bars)
    └── filtered by search (Search)

Derived (Cloud Functions)
└── monthlySummaries/{YYYY-MM}
    ├── totals, byCategory, byMerchant
    └── used for Insights + Home header

Derived (Cloud Functions, new)
└── aiSummaries/{periodId}
    ├── weekly | monthly
    └── narrative text + metadata

Derived (client or CF, new)
└── recurringPatterns/{merchantKey}
    ├── interval, lastAmount, lastDate
    └── powers Subscriptions section
```

### Mental Model for Users

| User question | IA answer |
|---------------|-----------|
| "What did I spend today?" | Home + Today toggle |
| "How much at KFC?" | Search → Merchant Page |
| "What changed this month?" | Insights |
| "Any subscriptions?" | Insights → Subscriptions |
| "Was this parsed correctly?" | Transaction Detail → Edit |

---

## 6. AI Features

### MVP (Genuinely Useful)

| Feature | Implementation | Why not gimmick |
|---------|----------------|-----------------|
| **SMS parsing** | Existing Gemini pipeline | Foundation — already shipped |
| **Auto-categorization** | Existing + merchant overrides | Reduces manual work over time |
| **Weekly narrative summary** | CF: aggregate last 7 days → Gemini → cache | Answers "what happened?" in plain English |
| **Monthly narrative summary** | Same pattern, monthly | Powers Insights card |
| **Subscription detection** | Pattern: same merchant + similar amount + ~30 day interval | High user value, low interaction |
| **Merchant normalization** | CF on ingest: "KFC Lahore" → "KFC" | Enables merchant page accuracy |

### P1 (Future)

| Feature | Notes |
|---------|-------|
| Natural language search | "how much did I spend on food last month?" → query plan |
| Duplicate detection | Same amount + merchant + date window → flag |
| Spending anomaly alerts | "Unusually large purchase: Rs. 50,000 at..." |
| Trend explanations | "Fuel spending up 40% vs last month" |

### Explicitly Avoid (Gimmicks)

- Chatbot financial advisor
- "AI budget recommendations"
- Predictive "you will run out of money"
- Gamification ("spending score")
- Voice assistant integration

---

## 7. UX Principles

### The 10-Second Rule

Every primary screen must answer its core question within 10 seconds of opening:

| Screen | Core question | Answer element |
|--------|---------------|----------------|
| Home | What's happening? | This week spent + today's list |
| Search | Did I spend on X? | Results list |
| Insights | How was this month? | Spent/received + AI sentence |
| Merchant | How much at X? | Total + visit count |

### Cognitive Load Reduction

1. **One hero number per screen** — never two competing balances
2. **Plain language** — "spent" not "debited"; "received" not "credited"
3. **Progressive disclosure** — raw SMS collapsed; edit behind button
4. **No empty charts** — hide sections with no data
5. **Consistent tile pattern** — same `TransactionListTile` everywhere

### Avoiding Overwhelm

| Do | Don't |
|----|-------|
| Show top 5 merchants | Show all 47 merchants |
| One AI paragraph | Three AI insights cards |
| Search replaces filters | 6-filter bottom sheet |
| Review as banner | Review as permanent tab |
| Categories as labels | Categories as things to manage |

### Trust & Privacy UX

- Biometric lock (keep)
- Masked account numbers (keep)
- Raw SMS always accessible (transparency)
- Parse confidence hidden from users — use Review flow instead
- No social features, no sharing by default

---

## 8. Visual Design Direction

**Align with existing NovaSpend system** — no redesign of tokens.

### Design Language

- **Reference:** Apple Health (calm data), Apple Wallet (transaction tiles), Google Photos (automatic organization)
- **Not reference:** Mint, YNAB, bank apps with 12 widgets

### Color Philosophy

- Keep single accent `#10B981` — positive/income/trends only
- Debits: neutral text, not aggressive red (red only on amount in detail)
- Background: generous white/dark space
- No category color rainbow — categories are text labels, not visual categories

### Typography

- Hero amounts: `displayLarge` (36–48sp) via `BalanceHeader`
- Merchant names: `titleMedium`, semibold
- Metadata (date, bank): `bodySmall`, tertiary color
- AI narrative: `bodyLarge`, relaxed line height

### Card Design

- `AppCard` for all grouped content
- `AppRadius.lg` (20px)
- 16px internal padding minimum
- No glass on transaction rows — glass only on search bar (optional, one per screen)

### Motion

- Tab switch: 300ms ease-out (existing)
- List insert: 250ms fade (new transaction from push)
- Period toggle on Home: `AnimatedSwitcher` on balance
- No bounce on money values
- Respect reduced motion

### Empty States

- Illustration: none (keep text-only, calm)
- Always include one action (Setup Shortcut / Try searching)
- Tone: helpful, not alarming ("No transactions yet" not "You're missing data!")

---

## 9. Future Roadmap

Features that extend "understanding" without becoming a budgeting app:

| Phase | Feature | Rationale |
|-------|---------|-----------|
| **Phase 3** | Gmail/Android SMS ingestion | Platform parity |
| **Phase 4** | Natural language search | Question-answering moat |
| **Phase 5** | Month-over-month comparison cards | Context without budgets |
| **Phase 6** | Household view (read-only sharing) | Couples asking "where did money go?" |
| **Phase 7** | Export to PDF summary | Tax season, not daily use |
| **Phase 8** | Widget (iOS/Android) | "This week: Rs. X" on home screen |
| **Phase 9** | Smart alerts | "Netflix renewed", "Large purchase detected" |
| **Never** | Budgets, investments, debt, splits | Violates philosophy |

---

## 10. Technical Considerations

### Firestore Structure (Evolution)

**Keep unchanged:**
- `users/{uid}/transactions/{id}` — source of truth
- `users/{uid}/monthlySummaries/{YYYY-MM}` — aggregates
- `users/{uid}/merchantCategoryOverrides/{key}`
- `users/{uid}/raw_ingestions/{id}`

**Add for MVP:**

```typescript
// users/{uid}/transactions/{id} — new fields
{
  merchantNormalized: string;   // "kfc" — indexed
  isRecurring: boolean;         // subscription detector
  recurringGroupId?: string;    // links related recurring txns
}

// users/{uid}/aiSummaries/{periodId}
{
  type: 'weekly' | 'monthly';
  periodStart: Timestamp;
  periodEnd: Timestamp;
  narrative: string;            // plain English
  generatedAt: Timestamp;
  model: string;
}

// users/{uid}/recurringPatterns/{merchantKey}
{
  merchantDisplay: string;
  averageAmount: number;
  currency: string;
  intervalDays: number;         // ~30 for monthly
  lastTransactionId: string;
  lastDate: Timestamp;
  transactionCount: number;
}
```

**Deprecate (don't delete yet):**
- `users/{uid}/budgets/` — stop writing; hide UI
- `users/{uid}/categories/` (user-created) — stop creating; use defaults only

### Indexes (add to `firestore.indexes.json`)

```
transactions: merchantNormalized ASC, transactionDate DESC
transactions: isRecurring ASC, transactionDate DESC
transactions: category ASC, transactionDate DESC  (may exist)
aiSummaries: type ASC, periodEnd DESC
```

### Offline Strategy

- Enable Firestore persistence (likely already on)
- Home timeline: serve cached stream immediately, sync in background
- Insights: cache last viewed `monthlySummary` + `aiSummary` in memory
- Search: requires network for full history (acceptable MVP tradeoff)

### Pagination

- Keep existing cursor pagination on Home (50 per page)
- Merchant page: paginate if > 50 transactions
- Search results: paginate, max 100 visible before "refine search"

### Search Strategy

**MVP (structured):**
1. User types query
2. If matches known merchant prefix → `merchantNormalized` range query
3. Else → array-contains or category equality + client-side filter on merchant text
4. Quick filter chips → predefined Firestore queries

**P1 (NL search):**
1. User types natural language
2. CF `translateSearchQuery` → Gemini → `{ filters: {...} }`
3. Execute structured query
4. Return results + optional AI one-liner

### Performance

- Home header aggregates: read `monthlySummaries` doc (1 read) not aggregate client-side
- Merchant page: composite index on `merchantNormalized + transactionDate`
- AI summaries: pre-computed by CF, never generated on client open
- Subscription list: read `recurringPatterns` collection (small, ~5–20 docs)

### Cloud Functions to Add

| Function | Trigger | Purpose |
|----------|---------|---------|
| `onTransactionWrittenDetectRecurring` | transaction write | Update `recurringPatterns` |
| `generateWeeklySummary` | scheduled (Mon 8am) | Write `aiSummaries` |
| `generateMonthlySummary` | scheduled (1st of month) | Write `aiSummaries` |
| `normalizeMerchant` | on ingest (extend existing) | Set `merchantNormalized` |

### Flutter Architecture Changes

| Current | Revamp |
|---------|--------|
| `features/budgets/` | Remove from DI + nav |
| `features/categories/` presentation page | Remove; keep domain for picker |
| `features/analytics/` | Rename mentally to `insights/` — simplify pages |
| `features/transactions/feed_page` | Refactor → `home_page` |
| New: `features/search/` | Search page + provider + use cases |
| New: `features/merchants/` | Merchant page + repository |
| `review_page` | Move under settings; keep provider |

---

## 11. Success Metrics

### North Star

**Weekly Active Users who view Insights or Search** — measures "understanding" behavior, not just notification opens.

### Primary Metrics

| Metric | Target (MVP +90 days) | Why |
|--------|----------------------|-----|
| D1 retention | > 40% | Setup → first value |
| W1 retention | > 25% | Habit forming |
| Time to first insight | < 5 sec after transactions exist | Speed promise |
| Search usage (% WAU) | > 30% | Question-answering works |
| Merchant page views | > 20% of sessions | Exploration depth |
| Review completion rate | > 80% within 7 days | Data quality |
| Session duration | 15–45 sec median | Quick understanding, not doom-scrolling |

### Secondary Metrics

- Push notification tap rate (weekly summary)
- AI summary card expand/read rate
- Subscription section engagement
- Edit rate per transaction (< 5% = good parsing)

### Anti-Metrics (do not optimize)

- Time in app (longer ≠ better)
- Features configured
- Budgets created (feature removed)
- Categories created (feature removed)

---

## 12. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **AI summaries feel generic** | Users ignore Insights tab | Ground summaries in specific merchants/amounts; regenerate if user edits transactions |
| **Search returns poor results** | Core feature fails | Ship structured search first; merchant normalization on ingest |
| **Removing budgets alienates power users** | Negative reviews | Budgets were never core to vision; communicate "understanding app" positioning |
| **Empty app before Shortcut setup** | Churn at onboarding | Strong empty state + setup guide; consider demo data toggle |
| **Subscription detection false positives** | Trust erosion | Require 3+ occurrences before showing; allow dismiss |
| **iOS-only ingestion** | Android users can't use app | Clear platform messaging; Gmail phase prioritized on roadmap |
| **Parse errors accumulate** | Bad data → bad insights | Review banner on Home; weekly email digest of pending reviews (future) |
| **Firestore search limits** | No full-text search | MVP: prefix + category filters; P1: Algolia or CF-backed search index |
| **Over-engineering AI** | Slow, expensive, gimmicky | Cache all summaries; one CF call per period max |
| **Feature creep back to budgeting** | Product identity lost | PRD gate: "Does this help understand spending without setup?" |

---

## Open Decisions

1. **Navigation change:** Home | Search | Insights | Settings — approved?
2. **Review demotion:** Banner + Settings link instead of tab — approved?
3. **Budgets:** Hard delete UI now, keep Firestore data — approved?
4. **AI summaries:** Cloud Function cost acceptable for weekly generation per user?
5. **Search MVP:** Structured text search first, NL search in P1 — approved?
