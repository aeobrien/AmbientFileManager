# FoodTracker — Project Conventions

## Overview

FoodTracker is a frictionless, personal calorie and macro tracker built on a fork of OpenNutriTracker (Flutter). It adds exercise-adjusted allowances (via Apple Health), LLM-assisted food label capture and recipe creation (via Claude API), quick-add estimates, and ADHD-friendly design throughout. Local-first, single-user, no subscriptions.

## Architecture

**Base:** Forked from [OpenNutriTracker](https://github.com/simonoppowa/OpenNutriTracker) (GPL-3.0)
**Framework:** Flutter 3.41.2 (Dart 3.11.0)
**Pattern:** Clean Architecture + BLoC (Business Logic Component) for state management
**Dependency Injection:** get_it
**Database:** drift (SQLite) — migrated from Hive in Phase 5
**Target Platform:** iOS (iPhone 14 Pro, iOS 26.2.1)
**IDE:** Xcode 16.3 (via `ios/Runner.xcworkspace`)
**Minimum iOS:** 15.5
**Bundle ID:** com.aeobrien.foodtracker
**Team ID:** 5R2D4Y969H

## Current Project State

**Stage:** Stage 2 — Feature development
**Current Phase:** Phase 6 (next to start)
**Phases complete:** 0 (dev env), 1 (smoke test), 2 (audit), 3 (roadmap), 4 (strip & clean), 5 (DB migration)

## Package Layers

```
Features (home, diary, add_meal, scanner, quick_add, recipes, settings, onboarding)
    |
BLoCs (state management per feature)
    |
Use Cases (business logic operations)
    |
Repositories (abstract data access)
    |
    ├── Data Sources
    │       ├── Local DB (drift/SQLite)
    │       ├── OFF API (Open Food Facts)
    │       ├── FDC API (FoodData Central)
    │       ├── Claude API (LLM)
    │       └── HealthKit (health plugin + native Swift)
    │
    └── Domain (entities, enums, calculations — NO dependencies)
```

## Build & Test Commands

```bash
# Install dependencies
flutter pub get

# Run code generation (drift, JSON serialization, envied)
dart run build_runner build --delete-conflicting-outputs

# Build iOS (compile check, no signing)
flutter build ios --debug --no-codesign

# Run on connected iPhone (Mirador, wireless)
flutter run -d 00008120-001255D9216B401E --debug

# Run all tests
flutter test

# Run tests for a specific file
flutter test test/path/to/test_file.dart

# Open in Xcode (for signing, capabilities, native code)
open ios/Runner.xcworkspace

# After adding iOS plugins (HealthKit, etc.)
cd ios && pod install --repo-update && cd ..
```

## Code Style

### Naming
- **Files:** `snake_case.dart` (matching primary type name)
- **Classes:** `PascalCase`
- **Variables/functions:** `camelCase`
- **BLoC events:** `PascalCaseEvent` (e.g., `LoadItemsEvent`)
- **BLoC states:** `PascalCaseState` (e.g., `HomeLoadedState`)
- **Test files:** `*_test.dart` in `test/` mirroring `lib/` structure
- **Database tables (drift):** `snake_case` table names, `camelCase` column names in Dart

### Commits
- Format: `Phase N: [summary of what this delivers]`
- Branches: `phase-N/name`

### Logging
- Use the `logging` package (already configured in the project)
- Named loggers per class: `final log = Logger('ClassName');`
- Levels: `fine` for debug info, `warning` for recoverable issues, `severe` for errors
- **Never use `print()` or `debugPrint()` directly** — always use Logger
- Log entry to important operations (API calls, database writes, state transitions)

### Testing
- Framework: `flutter_test` (built-in) + `mockito` for mocks
- **Every new public method gets a test**
- Edge cases to always cover: empty inputs, null/optional fields, boundary values, error states
- Domain logic: pure unit tests, no mocking needed
- BLoC tests: test state transitions for each event
- Repository tests: mock the data source
- Widget tests: verify rendering and interaction

### Data Models
- **Domain entities** live in `core/domain/entity/` — pure Dart, no framework dependencies
- **Database models** live in drift table definitions — separate from domain entities
- **DTOs** for API responses live in feature-specific `data/dto/` directories
- **Mapping:** Repository layer converts between DB models ↔ domain entities
- **Nutrition values** always stored as per-100g in the database
- **Timestamps** stored as UTC, day boundary applied in queries

### Views/UI
- No business logic in widgets — delegate to BLoCs
- Macro bars and calorie displays: **never use red/error colours for overages**
- Overage text: "X over target" in neutral styling
- Every screen should be self-contained (no "remember the number from the previous screen")
- Provide immediate feedback on every user action (snackbar, animation, number update)

## Key Files

| File | Purpose |
|------|---------|
| `ROADMAP.md` | Master development plan |
| `WORKFLOW.md` | Development cycle and debugging protocol |
| `CLAUDE.md` | This file — project conventions |
| `docs/session-log.md` | What was built per session |
| `docs/manual-tests/` | Manual test briefs and results |
| `docs/audit/codebase-audit.md` | Phase 2 codebase audit |
| `FoodTracker-VisionStatement-v2.md` | Product vision |
| `FoodTracker-TechnicalBrief-v2.md` | Technical specification |

## Mistakes to Avoid

1. **Don't open `ios/Runner.xcodeproj`** — always open `ios/Runner.xcworkspace` (CocoaPods requires the workspace).
2. **Don't edit generated files** — `.g.dart` files are auto-generated by `build_runner`. Edit the source and re-run generation.
3. **Don't skip `flutter pub get` after changing dependencies** — also re-run `build_runner` if drift tables, Hive models, or JSON-serializable classes change.
4. **Don't hardcode API keys** — the project is pushed to GitHub. Claude API key goes in flutter_secure_storage, FDC key in .env via envied.
5. **Don't use original `hive`/`hive_generator` packages** — abandoned, incompatible with modern Dart. We use `hive_ce`/`hive_ce_generator` until Hive is fully removed in Phase 5.
6. **Long-press on text fields crashes on iOS 26** — Flutter framework bug in `RenderEditable.selectWord`. Not fixable from app code.
7. **Don't use red/error colours for calorie overages** — this is shame-based visual language. Use neutral styling throughout.
8. **Don't add streak mechanics or guilt-inducing language** — every day is a blank slate. Missing days are normal, not failures.
9. **Don't use locale-dependent date formatting for storage keys** — store dates as ISO 8601 or integer timestamps. Locale-dependent keys caused data integrity issues in the original app.
10. **Don't embed food data in log entries** — always reference food_items by ID. Store a computed snapshot for historical accuracy, but the food reference enables correction propagation.
