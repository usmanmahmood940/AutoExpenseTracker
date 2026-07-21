# NovaSpend

Flutter client for Auto Expense Tracker — an automatic expense tracker
that turns bank SMS alerts (parsed by Gemini via the Cloud Functions in
[`../functions`](../functions)) into a searchable, insight-rich
transaction feed.

## Stack

- **Flutter** / Dart `^3.12.2`
- **State management:** `provider` (`ChangeNotifier` view models)
- **DI:** `get_it` (see `lib/core/di/injection.dart`)
- **Backend:** Firebase Auth, Firestore, Cloud Functions, App Check, FCM

## Architecture

Each feature under `lib/features/<feature>/` follows clean architecture:

```
presentation/  → domain/ ← data/
  pages/         entities/     datasource/
  widgets/       repositories/ models/
  provider/      usecases/     repository_impl.dart
```

`presentation` depends on `domain`; `data` implements `domain`
repositories. `domain` stays free of Flutter/Provider/l10n imports so
business rules stay testable in plain Dart.

Full conventions (layer boundaries, file naming, DI wiring) are documented
in [`.cursor/rules/novaspend-architecture.mdc`](../.cursor/rules/novaspend-architecture.mdc).
Localization and UI/UX conventions live alongside it in the same
`.cursor/rules/` directory — read those before adding UI copy or new
screens.

## Getting started

```bash
flutter pub get
flutter run
```

The app expects a configured Firebase project (`lib/firebase_options.dart`,
generated via `flutterfire configure`) and a deployed backend — see the
root [`README.md`](../README.md) for Cloud Functions setup and secrets.

## Useful commands

```bash
flutter analyze         # Static analysis (flutter_lints)
flutter test             # Unit + widget tests in test/
flutter gen-l10n         # Regenerate lib/l10n/app_localizations*.dart
                          # after editing lib/l10n/app_en.arb
```

## Project layout

```
lib/
├── main.dart                # Firebase/App Check bootstrap, DI, notifications
├── app.dart                 # MaterialApp + AuthGate
├── core/                    # DI, theming, shared widgets, errors, services
├── features/
│   ├── auth/                # Login, signup, OTP, password reset
│   ├── transactions/        # Main feed, transaction detail/edit
│   ├── search/               # Merchant/text search
│   ├── analytics/            # Monthly insights
│   ├── merchants/             # Per-merchant summary + history
│   ├── settings/              # Settings, review queue, language
│   └── categories/            # Category repository used by the
│                                 transaction edit picker (no standalone
│                                 categories screen — see PRD)
└── l10n/                     # ARB source + generated localizations
```

See [`docs/mvp-revamp-prd.md`](../docs/mvp-revamp-prd.md) and
[`docs/mvp-revamp-tasks.md`](../docs/mvp-revamp-tasks.md) for the current
product direction and phased rollout status.
