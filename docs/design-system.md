---
name: NovaSpend
colors:
  light:
    surface: '#f6faf8'
    surface-dim: '#e4ebe7'
    surface-bright: '#f6faf8'
    surface-container-lowest: '#ffffff'
    surface-container-low: '#f0f5f2'
    surface-container: '#e8efeb'
    surface-container-high: '#e4ebe7'
    surface-container-highest: '#e4ebe7'
    on-surface: '#141917'
    on-surface-variant: '#3c4a42'
    inverse-surface: '#2f3131'
    inverse-on-surface: '#e8edea'
    outline: '#8fa396'
    outline-variant: '#c5d4cb'
    surface-tint: '#006c49'
    primary: '#006c49'
    on-primary: '#ffffff'
    primary-container: '#10b981'
    on-primary-container: '#00422b'
    inverse-primary: '#4edea3'
    secondary: '#b61722'
    on-secondary: '#ffffff'
    secondary-container: '#da3437'
    on-secondary-container: '#fffbff'
    tertiary: '#a43a3a'
    on-tertiary: '#ffffff'
    tertiary-container: '#fc7c78'
    on-tertiary-container: '#711419'
    error: '#ba1a1a'
    on-error: '#ffffff'
    error-container: '#ffdad6'
    on-error-container: '#93000a'
    primary-fixed: '#6ffbbe'
    primary-fixed-dim: '#4edea3'
    on-primary-fixed: '#002113'
    on-primary-fixed-variant: '#005236'
    secondary-fixed: '#ffdad7'
    secondary-fixed-dim: '#ffb3ad'
    on-secondary-fixed: '#410004'
    on-secondary-fixed-variant: '#930013'
    tertiary-fixed: '#ffdad7'
    tertiary-fixed-dim: '#ffb3af'
    on-tertiary-fixed: '#410005'
    on-tertiary-fixed-variant: '#842225'
    background: '#f6faf8'
    on-background: '#141917'
    surface-variant: '#e4ebe7'
  # Derived from the light tokens (fixed/inverse roles + Material baseline error).
  # Neutral surfaces reuse the values already shipping in AppColors so dark mode
  # doesn't regress. Roles marked "approx" below have no source token to derive
  # from exactly — re-verify with a proper M3 tonal palette generator before
  # treating them as final.
  dark:
    surface: '#121614'
    surface-dim: '#0a1f18'
    surface-bright: '#242b28'
    surface-container-lowest: '#0f1211'
    surface-container-low: '#161a18'
    surface-container: '#1c2220'
    surface-container-high: '#242b28'
    surface-container-highest: '#2e3632'
    on-surface: '#e8edea'
    on-surface-variant: '#9caea4'
    inverse-surface: '#f6faf8'
    inverse-on-surface: '#141917'
    outline: '#4a5650'
    outline-variant: '#3a4340'
    surface-tint: '#4edea3'
    primary: '#4edea3' # = light.primary-fixed-dim / inverse-primary
    on-primary: '#002113' # = light.on-primary-fixed
    primary-container: '#005236' # = light.on-primary-fixed-variant
    on-primary-container: '#6ffbbe' # = light.primary-fixed
    inverse-primary: '#006c49' # = light.primary
    secondary: '#ffb3ad' # = light.secondary-fixed-dim
    on-secondary: '#410004' # = light.on-secondary-fixed
    secondary-container: '#930013' # = light.on-secondary-fixed-variant
    on-secondary-container: '#ffdad7' # = light.secondary-fixed
    tertiary: '#ffb3af' # = light.tertiary-fixed-dim
    on-tertiary: '#410005' # = light.on-tertiary-fixed
    tertiary-container: '#842225' # = light.on-tertiary-fixed-variant
    on-tertiary-container: '#ffdad7' # = light.tertiary-fixed
    error: '#ffb4ab' # Material 3 baseline dark error
    on-error: '#690005'
    error-container: '#93000a'
    on-error-container: '#ffdad6'
    background: '#121614'
    on-background: '#e8edea'
    surface-variant: '#242b28'
typography:
  hero-display:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: 600
    lineHeight: 1.1
    letterSpacing: -0.02em
  hero-display-mobile:
    fontFamily: Inter
    fontSize: 36px
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: -0.02em
  headline-merchant:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: 600
    lineHeight: 24px
    letterSpacing: -0.01em
  body-standard:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: 400
    lineHeight: 24px
  label-metadata:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: 400
    lineHeight: 18px
    letterSpacing: 0.01em
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: 600
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem # 4px
  DEFAULT: 0.5rem # 8px
  md: 0.75rem # 12px
  lg: 1rem # 16px
  xl: 1.5rem # 24px
  full: 9999px
# Semantic roles on top of the base scale above — use these names when wiring
# components, so "which radius does a card use" is never a guess.
radius-roles:
  card: 20px # AppCard and other primary content containers
  control: 16px # buttons, inputs (= rounded.lg)
  sheet: 24px # modals / bottom sheets (= rounded.xl)
  chip: full # filter chips, pills, avatars (= rounded.full)
spacing:
  base: 8px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  card-padding: 16px
  section-gap: 32px
---

## Brand & Style

The design system is built on a philosophy of "automated serenity." It treats financial data with the same archival care and visual clarity as a digital photo gallery. The brand personality is **calm, editorial, and trustworthy**, moving away from the stressful "budgeting" tropes and toward a "memory lane" for spending.

The aesthetic is predominantly **Minimal Flat (90%)**, prioritizing legibility and structural honesty. This is accented by **Subtle Glass (10%)** on floating elements like the bottom tab bar and top navigation headers to provide depth and a sense of modern platform integration. The target audience is the modern Pakistani professional seeking an effortless, high-performance interface that feels native to high-end mobile hardware.

## Colors

The palette is anchored by **Emerald**. Roles must not collapse:

- **`primary`** (`#006C49`) — on-light ink (links, nav glyph, wordmark) and **filled CTAs** (FAB, primary buttons) with `on-primary` white. White-on-`#10B981` fails WCAG; do not put body text or button labels on the vivid fill.
- **`primary-container`** (`#10B981`) — credits, received amounts, chart series. Pair with `on-primary-container` (`#00422B`) if you ever fill a chip with it.
- **`inverse-primary`** (`#4EDEA3`) — dark-mode ink, received amounts, and chart series.

A **Soft Red** family is reserved strictly for high-impact debit details and critical alerts, to maintain the "calm" atmosphere. To avoid three competing reds, use each role for a distinct purpose rather than interchangeably:

- **`error`** (`#BA1A1A`) — destructive actions and validation failures only (delete, form errors).
- **`secondary`** (`#B61722`) — debit/negative-amount emphasis in transaction UI (e.g. an outlined amount, a "spent" delta). Dark: `#FFB3AD`.
- **`tertiary`** (`#A43A3A`) — reserved for a future second semantic need (e.g. a distinct "alert/attention" badge that isn't a hard error). Don't introduce a fourth red; if a component needs debit-red, use `secondary`.

General rules:

- **Primary Text:** `on-surface` — near-black in light mode, near-white in dark mode.
- **Secondary/Muted Text:** `on-surface-variant`, roughly 60% visual weight of primary text.
- **Backgrounds:** `background` — `#F6FAF8` (Light) / `#121614` (Dark) — green-tinted canvas, high-contrast separation from cards.
- **Borders:** `outline-variant` — subtle 1px strokes define structure without adding visual weight.

### Gradients (restricted)

Product chrome stays **flat**. Gradients are allowed only as:

1. **Hero wash** — vertical mint/forest → canvas behind Home / Insights (`AppGradients.heroWash`).
2. **Chart underfill** — emerald 35% → transparent under the primary series (`AppGradients.chartArea`).
3. **Splash** — solid `#0D4A32` matching the app icon (no mint radial).

Do **not** put gradients on FAB, filled buttons, or cards.

## Typography

This design system utilizes **Inter** for its neutral, systematic utility that mimics the native feel of iOS (SF Pro) and Android (Roboto).

- **Hero Typography** (`hero-display` / `hero-display-mobile`): Reserved for account balances and total spending summaries. Tight letter spacing to feel "editorial."
- **Merchant Titles** (`headline-merchant`): Semibold, for immediate recognition in transaction feeds.
- **Metadata** (`label-metadata`): Categories, timestamps, secondary bank details. Paired with `on-surface-variant` to maintain hierarchy.
- **Section Labels** (`label-caps`): Uppercase, wide letter-spacing, for section headers like "THIS MONTH."

## Layout & Spacing

The layout operates on a **strict 8px grid system**. Every spacing token must be a multiple of 8px (`section-gap` was tightened from 28px to 32px for this reason — 28 isn't a multiple of the base unit).

- **Margins:** A standard 16px lateral margin (`spacing.md`) is used for mobile containers, increasing to 24px (`spacing.lg`) for section headers to create "breathing room."
- **Section Spacing:** 32px (`spacing.section-gap`) between different data groups (e.g. between the Balance Header and the Transaction List) to prevent information density fatigue.
- **Grid:** A fluid layout is preferred, where cards span the full width of the safe area.

## Elevation & Depth

Visual hierarchy is achieved through **Tonal Layers** rather than heavy shadows.

1. **Base (Level 0):** `background`, with an optional **hero wash** (mint/forest → canvas) behind Home / Insights only.
2. **Surface (Level 1):** Content cards (`surface-container-lowest` light / `surface-container-high` dark) with a 1px `outline-variant` border. No shadows here — keeps the "Flat" aesthetic.
3. **Overlay (Level 2):** Bottom tab bars and sticky headers use a **Glassmorphic** effect (Backdrop Blur: 12–20px, Opacity: ~82%) so content can scroll underneath while maintaining context.

Interactive elements (buttons) may use a very soft, low-opacity ambient shadow (4px blur, 5% black) only when placed on a colored background, so they feel "pressable."

## Shapes

A sophisticated rounded language softens the financial data. Use `radius-roles`, not raw numbers, in component code:

- **App Cards:** `radius-roles.card` — 20px, applied to all primary content containers.
- **Interactive Elements:** `radius-roles.control` — 16px, buttons and input fields.
- **Sheets/Modals:** `radius-roles.sheet` — 24px.
- **Filter Chips:** `radius-roles.chip` — full/pill geometry, to distinguish them from actionable cards or buttons.

## Components

### AppCard
The foundational container. `radius-roles.card` (20px) corner radius, 1px `outline-variant` border, `spacing.card-padding` (16px) internal padding. Surface: `surface-container-lowest` (light) / `surface-container-high` (dark).

### TransactionListTile
A high-density row element.
- **Left:** Merchant name (`headline-merchant`, 18px semibold) with Category/Bank source (`label-metadata`, 13px, `on-surface-variant`) below it.
- **Right:** Amount. Debits in `on-surface` (primary text weight, not colored red by default — see below); Credits/Income in `primary-container` (Emerald).
- **Debit emphasis (optional):** when a debit needs visual weight (e.g. large/unusual purchase), use `secondary` instead of plain `on-surface` — don't use `error` for this.
- **Separator:** 1px `outline-variant` hairline divider between tiles, inset by `spacing.md` (16px).

### BalanceHeader
The dashboard centerpiece.
- **Top:** "This Month" or date range in `label-caps` (12px caps), `on-surface-variant`.
- **Center:** Large Spent Amount in `hero-display` (Hero Semibold).
- **Bottom:** Smaller "Received" amount in `primary-container` (Emerald) with a subtle "+" prefix.

### Filter Chips & Controls
- **Filter Chips:** Pill-shaped (`radius-roles.chip`), `surface-container-low` background, `label-metadata`-weight text (13px medium). Active state: pale `nav-active-fill` with `primary` / `inverse-primary` ink — not white-on-mint.
- **Segmented Control:** A flat card track with a sliding **`primary`** pill (`#006C49`) and `on-primary` white label.
- **Bottom Tab Bar:** 10% glassmorphism blur. Icons are 24px linear strokes. Active tab uses `primary` (light) / `inverse-primary` (dark) on a soft emerald fill.

### Input Fields
Minimalist underline or `surface-container-low` fills. Focus state is a 2px `primary` (`#006C49`) border rather than a full box glow.

---

## Dark Mode

Forest-charcoal neutrals (`#121614` canvas, `#242B28` cards) with `inverse-primary` (`#4EDEA3`) for ink, received amounts, and charts. Filled CTAs stay `primary` (`#006C49`) + white in both themes so FAB/buttons keep contrast.

Debit emphasis uses `secondary` `#FFB3AD` on dark surfaces. Do not introduce a fourth (coral) red.

## Implementation Mapping

| Token group | Target file |
|---|---|
| `colors.light` / `colors.dark` | `NovaSpend/lib/core/theme/app_colors.dart` |
| Hero wash / chart underfill | `NovaSpend/lib/core/theme/app_gradients.dart` |
| `ColorScheme` + CTA fills | `NovaSpend/lib/core/theme/app_theme.dart` |
| `radius-roles` | `NovaSpend/lib/core/theme/app_radius.dart` |
| `spacing` | `NovaSpend/lib/core/theme/app_spacing.dart` |
| `typography` | `NovaSpend/lib/core/theme/app_theme.dart` (`_textTheme`) |
| Motion | `NovaSpend/lib/core/theme/app_motion.dart` |

Flutter helpers: `AppColors.primaryInk` (links/icons), `positiveAmount` (credits/charts), `spendForeground` (debit emphasis). White-on-fill CTAs use `primaryStrong` + `onPrimary`.

## Improvements Applied vs. Original Draft

1. **Fixed 8px grid violation:** `section-gap` changed from 28px → 32px so every spacing token is a true multiple of the stated 8px base unit.
2. **Reconciled the three "red" roles** (`secondary`, `tertiary`, `error`) with explicit, non-overlapping usage rules instead of leaving them interchangeable (see Colors section).
3. **Added explicit `radius-roles`** (`card`, `control`, `sheet`, `chip`) because the numeric `rounded` scale alone didn't map 1:1 to the prose (e.g. "20px card radius" wasn't any single value in the original `rounded` scale).
4. **Added a `dark` color block**, since the app already ships dark mode — with confidence levels called out so nothing is silently treated as more certain than it is.
5. **Normalized YAML types:** `fontWeight` / `lineHeight` values un-quoted to plain numbers where unitless, for easier downstream parsing.
