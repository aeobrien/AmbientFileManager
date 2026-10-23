# FoodTracker Roadmap

## Overview

This roadmap covers the full development of FoodTracker, built on a fork of OpenNutriTracker.

**Stage 1 (Phases 0-3): COMPLETE** — Environment setup, smoke test, codebase audit, and this roadmap.

**Stage 2 (Phases 4-15): DETAILED BELOW** — Strip unwanted dependencies, migrate database, build all new features, polish.

---

## Module Dependency Graph (Post-Audit)

```
Features (home, diary, add_meal, scanner, quick_add, recipes, settings, onboarding)
    |
BLoCs (state management per feature)
    |
Use Cases (business logic operations)
    |
Repositories (abstract data access)
    |
    ├── Data Sources (drift/SQLite tables, API clients)
    │       ├── Local DB (drift — foods, intakes, recipes, daily_stats, config)
    │       ├── OFF API (Open Food Facts — barcode + search)
    │       ├── FDC API (FoodData Central — search fallback)
    │       ├── Claude API (LLM — label extraction, recipe parsing)
    │       └── HealthKit (via health plugin + native Swift channel)
    │
    └── Domain (entities, enums, calculation logic — NO dependencies)
            ├── Allowance model (base + earned × multiplier)
            ├── Nutrition math (per-100g → grams, recipe per-serving)
            ├── Macro validation (Atwater consistency check)
            └── Weekly aggregation
```

**Key change from existing architecture:** The Hive key-value store is replaced by drift (type-safe SQLite). Supabase and Sentry are removed. A standalone FoodItem table replaces the denormalised food-embedded-in-intake pattern.

---

## Stage 1: COMPLETE

| Phase | Status | Summary |
|-------|--------|---------|
| 0: Dev Environment | Done | Flutter 3.41.2, hive→hive_ce migration, app builds and runs on device |
| 1: Smoke Test | Done | Barcode works, search broken (Supabase), app intuitive and fast |
| 2: Codebase Audit | Done | See `docs/audit/codebase-audit.md` |
| 3: Stage 2 Roadmap | Done | This document |

---

## Stage 2: Feature Development

### Phase 4: Strip & Clean — "Remove what we don't need"

**Branch:** `phase-4/strip-and-clean`
**Package(s):** core, features/add_meal, features/settings, features/profile
**Depends on:** Phase 3

#### Sub-modules

- 4.1 **Remove Supabase** — Delete SpFdcDataSource and its DTOs, remove Supabase.initialize() from locator, route FDC search through direct API, remove supabase_flutter from pubspec, remove env vars.
- 4.2 **Remove Sentry** — Remove all Sentry.captureException() calls (keep Logger.severe), remove SentryFlutter.init() from main.dart, remove sentry_flutter from pubspec, remove SENTRY_DNS env var.
- 4.3 **Remove shame-based visuals** — Remove red calendar dot logic in TrackedDayEntity, remove red summary card colours in diary, remove BMI display from profile page. Replace with neutral styling.
- 4.4 **Fix search** — Verify OFF product search and FDC search work after Supabase removal. Fix barcode-not-found dead end (add "search by name" fallback option).
- 4.5 **Clean env.dart** — Only FDC_API_KEY should remain. Simplify the envied configuration.

#### Deliverables

- [ ] App builds and runs without Supabase or Sentry
- [ ] Food search works (both OFF and FDC tabs)
- [ ] No red/shame styling anywhere in the app
- [ ] BMI removed from profile
- [ ] Barcode "not found" now offers text search fallback
- [ ] 5+ unit tests for FDC API response parsing

#### Manual Test Brief

- Search for "chicken" — results appear
- Search for "banana" — results appear
- Scan a barcode that isn't in OFF — verify "search instead" option appears
- Open diary, go to a past day — verify no red dots or red cards
- Open profile — verify no BMI display

---

### Phase 5: Database Migration — "Hive to drift/SQLite"

**Branch:** `phase-5/database-migration`
**Package(s):** core/data, new: database/
**Depends on:** Phase 4

#### Sub-modules

- 5.1 **Add drift dependency** — Add drift, sqlite3_flutter_libs, drift_dev to pubspec. Configure build_runner for drift code generation.
- 5.2 **Design drift schema** — Create table definitions for:
  - `food_items` (id, source, barcode, name, brand, serving_size_grams, nutrition_per_100g [kcal, protein, carbs, fat, fibre, sugar, salt], last_used_at, last_used_grams, user_verified, corrected_at)
  - `recipes` (id, name, servings, source, cached_nutrition_per_serving)
  - `recipe_ingredients` (id, recipe_id, food_item_id, grams)
  - `log_entries` (id, timestamp, meal_slot, type [food/recipe/quickAdd], food_item_id, recipe_id, grams_or_servings, quick_add_kcal, quick_add_protein, quick_add_carbs, quick_add_fat, quick_add_label, snapshot_kcal, snapshot_protein, snapshot_carbs, snapshot_fat, source_item_corrected, is_draft)
  - `daily_stats` (date, intake_kcal, intake_protein, intake_carbs, intake_fat, active_calories, active_calories_last_updated, base_target, exercise_multiplier)
  - `config` (key-value for app settings: calorie target, macro targets, day boundary, theme, units, exercise multiplier, Claude API key)
- 5.3 **Implement DAOs** — Data access objects for each table with typed queries: entries by date, food items by recency, weekly aggregation, food search by name (FTS5).
- 5.4 **Implement repositories** — New repository implementations backed by drift, matching existing repository interfaces where possible.
- 5.5 **Migrate existing data** — One-time migration: read all Hive boxes, write to SQLite. Extract embedded MealDBOs into standalone food_items. Map IntakeDBOs to log_entries with snapshots.
- 5.6 **Update locator.dart** — Wire new drift-backed repositories into the DI container. Remove Hive registrations.
- 5.7 **Remove Hive** — Once migration is verified, remove hive_ce, hive_ce_flutter, hive_ce_generator from pubspec. Delete all DBO files and Hive data sources.

#### Deliverables

- [ ] Drift schema defined with all tables
- [ ] DAOs with typed queries (no full scans)
- [ ] FTS5 index on food_items.name for local search
- [ ] One-time Hive → SQLite migration runs successfully
- [ ] All existing features work with new database backend
- [ ] 20+ unit tests for DAOs and migration logic
- [ ] App builds, runs, and passes all tests

#### Key Decisions

- Date storage: UTC timestamps, day boundary applied in queries (WHERE timestamp >= day_start AND timestamp < next_day_start)
- Food item deduplication: match on barcode (if present) or name+brand combo
- Migration runs automatically on first launch after update

#### Manual Test Brief

- Launch app — verify existing logged data appears correctly
- Log a new food via barcode — verify it appears in diary and daily totals
- Check recents — verify they populate from the new food_items table
- Export data — verify export still works with new backend

---

### Phase 6: Core Domain — "The calculation engine"

**Branch:** `phase-6/core-domain`
**Package(s):** core/domain
**Depends on:** Phase 5

#### Sub-modules

- 6.1 **Allowance model** — `allowance = base_target + (active_calories × multiplier)`, `remaining = allowance - intake`. Pure functions, no side effects.
- 6.2 **Macro scaling** — When allowance increases, scale macro targets proportionally. Support per-macro override (e.g., fixed protein, scaled carbs/fat).
- 6.3 **Day boundary logic** — Given a timestamp and a configurable day-start hour (default 2 AM), return the "logical date" for that timestamp.
- 6.4 **Meal slot suggestion** — Given a timestamp, suggest a meal slot (breakfast/lunch/dinner/snack) based on configurable time ranges.
- 6.5 **Macro/calorie consistency validation** — `calculated = (P×4) + (C×4) + (F×9)`. Adjust for fibre if available: `(C-fibre)×4 + fibre×2`. Flag >15% deviation as "review recommended", >40% as "likely error".
- 6.6 **Recipe nutrition calculation** — Given ingredients (food_item + grams) and servings count, compute per-serving nutrition.
- 6.7 **Weekly aggregation** — Sum daily stats over 7 days. Compute weekly remaining vs. weekly target.
- 6.8 **DailyStats recomputation** — Recompute a day's stats from all log entries (used for reconciliation and after food corrections).

#### Deliverables

- [ ] All calculation functions implemented as pure, testable functions
- [ ] 40+ unit tests covering: normal cases, edge cases (zero intake, zero exercise, over-target, negative remaining), boundary values (exactly at target, midnight vs 2am boundary)
- [ ] No UI, no database access — pure domain logic only

#### Manual Test Brief

- N/A (pure logic, tested via unit tests only)

---

### Phase 7: Today Dashboard + Allowance UI — "The screen you see every day"

**Branch:** `phase-7/today-dashboard`
**Package(s):** features/home, core/presentation
**Depends on:** Phase 6

#### Sub-modules

- 7.1 **Allowance breakdown display** — Show: Base target → Earned calories (+) → Today's allowance (=) → Consumed (-) → Remaining. Clear, glanceable layout.
- 7.2 **Neutral overage display** — If remaining < 0, show "X over target" in the same calm visual style. No red, no warning icons.
- 7.3 **Weekly context line** — Optional line below remaining: "This week: Y under/over target".
- 7.4 **Macro progress bars** — Horizontal progress bars for protein/carbs/fat showing intake/target. Partially filled = encouragement, not judgement.
- 7.5 **Meal-grouped log** — Today's entries grouped by meal slot (breakfast/lunch/dinner/snack), auto-assigned by time but editable. Keep the existing card-based layout but improve information density.
- 7.6 **Today's date display** — Show today's date on the dashboard (currently missing).
- 7.7 **Calendar dot cleanup** — Calendar dots should clear when all food/activities for a day are deleted (currently the dot persists even with zeroed-out daily stats).
- 7.8 **Home page delete confirmation** — Replace the long-press drag-to-delete on the home page with a confirmation dialog (matching the diary page pattern). Current UX: long-press shows delete icon at bottom, but releasing scrolls back to top.
- 7.7 **Instant load from DailyStats** — Dashboard reads from materialised daily_stats table. No recomputation on every screen load.

#### Deliverables

- [ ] Today screen shows full allowance breakdown
- [ ] Neutral overage display (no red/shame)
- [ ] Weekly context line
- [ ] Macro progress bars
- [ ] Today's date visible
- [ ] Screen loads instantly from cached stats
- [ ] 10+ widget tests

#### Manual Test Brief

- Open app — verify allowance breakdown is visible and correct
- Log food until over target — verify "X over target" in neutral styling
- Check macro bars update after logging
- Verify screen loads instantly (no spinner)

---

### Phase 8: Friction Foundations — "Make logging fast"

**Branch:** `phase-8/friction-foundations`
**Package(s):** features/home, features/add_meal, features/meal_detail
**Depends on:** Phase 7

#### Sub-modules

- 8.1 **Portion memory** — When logging a food, default to last-used quantity for that food_item. Store last_used_grams on food_items table.
- 8.2 **Quick increment buttons** — On quantity entry: +10g, +50g, ½ serving, 1 serving, "whole pack" (if serving_size known).
- 8.3 **Improved defaults** — Default quantity = last-used or 1 serving (not 100g).
- 8.4 **Favourites system** — Star/pin foods for persistent quick-access. Show favourites section on add_meal screen above recents.
- 8.5 **Improved recents** — Deduplicated, sorted by last use, shows food name + last-used amount. One-tap re-log with same amount.
- 8.6 **Inline editing** — Tap a logged entry on the home screen → adjust grams inline (not a full-screen navigation).
- 8.7 **Swipe to delete with undo** — Swipe a log entry to delete, show undo snackbar for 5 seconds.
- 8.8 **Draft state persistence** — If user starts logging but navigates away, save in-progress state. Restore on return.
- 8.9 **Meal slot auto-suggestion** — Pre-select meal slot based on time of day (configurable). Dismissible, not mandatory.

#### Deliverables

- [ ] Portion memory works (log rice at 150g, next time defaults to 150g)
- [ ] Quick increment buttons on quantity entry
- [ ] Favourites system (star, unstar, favourites section)
- [ ] Recents deduplicated and one-tap re-log
- [ ] Inline edit on home screen
- [ ] Swipe delete with undo
- [ ] Draft persistence across app switches
- [ ] 15+ unit tests for new logic
- [ ] 5+ widget tests for new UI components

#### Manual Test Brief

- Log rice at 200g. Log rice again — verify default is 200g.
- Star a food. Open add_meal — verify it appears in favourites section.
- Start logging a food, switch to another app, come back — verify draft restored.
- Swipe a log entry — verify delete + undo works.

---

### Phase 9: Apple Health Integration — "Exercise earns food"

**Branch:** `phase-9/apple-health`
**Package(s):** new: integrations/healthkit, features/home, core/data
**Depends on:** Phase 7

#### Sub-modules

- 9.1 **Add health plugin** — Add `health` package to pubspec. Configure HealthKit entitlement in Xcode.
- 9.2 **Permission flow** — On first launch (or from settings), request HealthKit permission for Active Energy Burned. Handle denial gracefully (allowance = base target, no error states).
- 9.3 **Read active calories** — Read today's Active Energy Burned from HealthKit. Sum all samples for the day.
- 9.4 **Apply multiplier** — `earned = active_calories × multiplier` (default 0.75, configurable in settings).
- 9.5 **Cache in DailyStats** — Write active_calories and active_calories_last_updated to daily_stats table. Today screen reads from cache.
- 9.6 **Foreground refresh** — On app foreground, re-read HealthKit and update cache. Today screen updates without manual refresh.
- 9.7 **Native background observer (stretch)** — If feasible: add Swift platform channel code in AppDelegate.swift for HKObserverQuery + enableBackgroundDelivery. If not feasible: rely on foreground polling.
- 9.8 **Update Today screen** — Show earned calories in the allowance breakdown. Show "last updated X min ago" if data is stale.

#### Deliverables

- [ ] HealthKit permission request works
- [ ] Active calories read and displayed in allowance breakdown
- [ ] Multiplier applied (default 75%)
- [ ] Data refreshes on app foreground
- [ ] Graceful fallback if permissions denied
- [ ] 10+ unit tests for multiplier logic and DailyStats update
- [ ] Integration test with mocked HealthKit data

#### Manual Test Brief

- Launch app — accept HealthKit permission
- Go for a walk — verify "earned calories" updates within minutes of returning to app
- Change multiplier in settings — verify allowance recalculates
- Deny HealthKit permission — verify app still works (allowance = base target)

---

### Phase 10: Quick-Add Estimate — "The escape hatch"

**Branch:** `phase-10/quick-add`
**Package(s):** new: features/quick_add, core/data
**Depends on:** Phase 5

#### Sub-modules

- 10.1 **Quick-add screen** — Tap "Quick Add" → enter kcal (required) → optional protein/carbs/fat → optional label → optional meal slot → save. Target: <5 seconds.
- 10.2 **Quick-add log entry** — Creates a log_entry with type=quickAdd, no food_item_id, snapshot populated from entered values.
- 10.3 **Visual distinction** — Quick-add entries shown in daily log with a subtle icon/badge so user can identify and optionally replace them later.
- 10.4 **Quick-add from home** — Prominent "Quick Add" button accessible from the home screen (no more than 1 tap to reach).

#### Deliverables

- [ ] Quick-add flow works end to end
- [ ] Quick-add entries appear in log and count toward daily totals
- [ ] Visually distinct from food/recipe entries
- [ ] Accessible in ≤1 tap from home
- [ ] 10+ unit tests
- [ ] 3+ widget tests

#### Manual Test Brief

- Tap Quick Add → enter 500 kcal → save. Verify: appears in log, daily total updated.
- Quick-add with label "pub lunch" → verify label shows in log.
- Time from tap to saved: under 5 seconds.

---

### Phase 11: LLM Label Capture — "Add it once, never again"

**Branch:** `phase-11/llm-label-capture`
**Package(s):** new: integrations/claude_api, new: features/label_capture, core/data
**Depends on:** Phase 10

#### Sub-modules

- 11.1 **Claude API client** — HTTP client for Claude API. User's API key read from settings. Strip EXIF from images before sending. Handle: success, network error, invalid response, rate limit.
- 11.2 **Photo capture flow** — Camera screen for nutrition label photo (required) + optional front-of-pack photo. Uses camera plugin or mobile_scanner's camera.
- 11.3 **LLM extraction** — Send photo(s) to Claude with system prompt specifying JSON schema. Parse response into structured nutrition data.
- 11.4 **Client-side validation** — Atwater consistency check on extracted data. Flag confidence levels. Highlight missing fields.
- 11.5 **Confirmation UI** — Editable form showing extracted data. Validation warnings highlighted. User taps "Looks right" or edits fields.
- 11.6 **Save as FoodItem** — Save confirmed data to food_items table. Associate barcode if available. Food is immediately loggable.
- 11.7 **"Not found" flow integration** — When barcode scan fails: offer "Take photo of label" as primary action alongside "Search by name".
- 11.8 **Offline fallback** — If offline: capture photo locally, create draft quick-add placeholder, queue for processing. When online: process, notify user, offer to update the placeholder.

#### Deliverables

- [ ] Claude API integration works (with user's API key)
- [ ] Photo → extraction → validation → confirm → save flow works end to end
- [ ] EXIF stripped from photos
- [ ] Validation catches obviously wrong extractions
- [ ] Offline fallback queues photo for later processing
- [ ] Barcode "not found" now offers photo capture
- [ ] 15+ unit tests (API client, validation, parsing)
- [ ] Integration test with sample label images

#### Manual Test Brief

- Scan a barcode not in OFF → take photo of label → verify extraction → confirm → log the food
- Rescan same barcode → verify food is now found locally
- Turn on airplane mode → scan unknown barcode → verify quick-add placeholder created
- Enter wrong API key in settings → verify graceful error message

---

### Phase 12: Recipes + LLM Recipe Builder — "Carbonara is one tap"

**Branch:** `phase-12/recipes`
**Package(s):** new: features/recipes, integrations/claude_api, core/data
**Depends on:** Phase 11

#### Sub-modules

- 12.1 **Manual recipe builder** — Search ingredients → set grams per ingredient → set servings → compute per-serving nutrition → save recipe.
- 12.2 **LLM text-to-recipe** — Paste "200g pasta, 100g pancetta, 2 eggs, 50g parmesan" → Claude parses ingredients → resolve each against food_items/OFF → show matches → confirm → save.
- 12.3 **LLM URL-to-recipe** — Paste recipe URL → fetch page → Claude extracts ingredients → same resolution flow → save.
- 12.4 **Recipe logging** — One-tap log a recipe. Adjust servings (½, 1, 1.5, 2). Snapshot nutrition at time of logging.
- 12.5 **Recipe management** — View, edit, delete recipes. Editing does NOT retroactively change past logs unless user explicitly triggers recompute.
- 12.6 **Recipes in recents/favourites** — Recipes appear alongside foods in recents and favourites lists.

#### Deliverables

- [ ] Manual recipe creation works
- [ ] LLM text-to-recipe works
- [ ] LLM URL-to-recipe works for common recipe sites
- [ ] One-tap recipe logging with portion adjustment
- [ ] Recipes appear in recents/favourites
- [ ] Past logs unaffected by recipe edits (snapshot behaviour)
- [ ] 15+ unit tests
- [ ] 5+ widget tests

#### Manual Test Brief

- Create "Carbonara" from typed ingredients → verify per-serving nutrition
- Log carbonara → verify appears in daily log with correct nutrition
- Edit carbonara recipe → verify past log unchanged
- Re-log carbonara → verify 1 tap from recents

---

### Phase 13: Notifications + Weekly View — "Gentle nudges and the bigger picture"

**Branch:** `phase-13/notifications-weekly`
**Package(s):** new: features/weekly, new: integrations/notifications, features/settings
**Depends on:** Phase 7

#### Sub-modules

- 13.1 **Local notification scheduling** — Configurable meal-time reminders (defaults: breakfast 9am, lunch 1pm, dinner 7pm). Warm, non-judgmental language: "Lunchtime — want to log something?"
- 13.2 **Notification deep link** — Tapping notification opens app to logging screen with meal slot pre-selected.
- 13.3 **Notification settings** — Per-meal toggle, time configuration, master toggle. In settings screen.
- 13.4 **Weekly summary view** — 7-day view showing: daily calorie totals, daily target, daily net (under/over), weekly total, weekly trend. Neutral styling throughout.
- 13.5 **Weekly context on Today screen** — "This week: X under/over target" line on the dashboard.

#### Deliverables

- [ ] Notifications fire at configured times
- [ ] Tapping notification opens correct logging context
- [ ] Per-meal and master notification toggles work
- [ ] Weekly view shows 7-day summary
- [ ] Weekly context line on Today screen
- [ ] 5+ unit tests
- [ ] 3+ widget tests

#### Manual Test Brief

- Set lunch notification for 2 minutes from now → verify it fires with correct message
- Tap notification → verify app opens to lunch logging
- Disable lunch notification → verify it stops
- Open weekly view → verify 7-day data is correct

---

### Phase 14: Settings & Configuration — "Make it yours"

**Branch:** `phase-14/settings`
**Package(s):** features/settings, core/data
**Depends on:** Phases 9, 10, 11, 13

#### Sub-modules

- 14.1 **Calorie target setting** — Manual entry with optional "calculate for me" based on body stats.
- 14.2 **Macro target setting** — Set in grams. Toggle for proportional scaling with allowance. Per-macro override (e.g., lock protein).
- 14.3 **Exercise multiplier** — Slider or input, 0-100%, default 75%.
- 14.4 **Day boundary** — Hour picker, default 2 AM.
- 14.5 **Claude API key** — Secure text input, stored in flutter_secure_storage (not in SQLite).
- 14.6 **HealthKit permissions** — Status display + link to system settings.
- 14.7 **Data export** — JSON + CSV export. Import from JSON.
- 14.8 **Theme** — Light/dark/system.
- 14.9 **Units** — Metric/imperial.

#### Deliverables

- [ ] All settings accessible and functional
- [ ] Changes take effect immediately (no restart required)
- [ ] API key stored securely
- [ ] Export produces valid JSON and CSV
- [ ] Import restores data correctly (round-trip test)
- [ ] 10+ unit tests

#### Manual Test Brief

- Change calorie target → verify Today screen updates
- Change exercise multiplier → verify allowance recalculates
- Export → delete app → reinstall → import → verify all data restored

---

### Phase 15: Polish + UX Audit — "Does it feel right?"

**Branch:** `phase-15/polish`
**Package(s):** All
**Depends on:** All previous phases

#### Sub-modules

- 15.1 **Vision statement audit** — Walk through every principle in the vision statement. Verify each is met.
- 15.2 **Timing tests** — Log food (barcode): <10 seconds. Add missing food (LLM): <60 seconds. Quick-add: <5 seconds. Recipe re-log: <10 seconds.
- 15.3 **Shame-language audit** — Scan every screen for red/warning styling, judgmental language, streak mechanics.
- 15.4 **ADHD-friendliness audit** — Working memory support (every screen self-contained), state preservation (drafts survive interruption), completion signals (feedback on every action), decision fatigue (minimal choices per interaction).
- 15.5 **Edge cases** — Empty days, first launch after gap, huge log counts, no HealthKit, no network, wrong API key, malformed OFF data.
- 15.6 **Performance** — Today screen loads from cache. No spinners on common paths. Barcode scan is instant.
- 15.7 **Retroactive logging** — Verify logging for yesterday uses identical workflows to today.

#### Deliverables

- [ ] UX audit document at `docs/manual-tests/phase-15-ux-audit.md`
- [ ] All timing targets met
- [ ] No shame language found
- [ ] All edge cases handled gracefully
- [ ] Performance targets met

#### Manual Test Brief

This IS the manual test. The user works through the full audit checklist.

---

## Decision Log

| # | Decision | Rationale | Date |
|---|----------|-----------|------|
| 1 | Configurable exercise multiplier, default 75% | Apple Watch calorie estimates have ~25-30% mean error | 2026-02-20 |
| 2 | Fork and diverge from OpenNutriTracker | Personal tool, freedom to restructure | 2026-02-20 |
| 3 | Macro targets scale proportionally (with per-macro override) | Flexible dieting strategies (e.g., fixed protein on keto) | 2026-02-20 |
| 4 | User enters own Claude API key in settings | Can't bundle key in GitHub-hosted code | 2026-02-20 |
| 5 | Day boundary configurable, default 2 AM | Night-owl eating patterns | 2026-02-20 |
| 6 | Strip EXIF from photos, no privacy notice | Personal-use app, good practice | 2026-02-20 |
| 7 | "Earned calories" language retained | User-tested, works for their motivational context | 2026-02-20 |
| 8 | Two-stage roadmap | De-risks building on unfamiliar codebase | 2026-02-20 |
| 9 | Migrate Hive → drift/SQLite | Hive lacks relational queries, indexes, FTS. Every planned feature requires workarounds. | 2026-02-20 |
| 10 | Remove Supabase | Used for one FDC search path. Direct API exists. Conflicts with local-first. | 2026-02-20 |
| 11 | Remove Sentry | No DSN configured. All errors already logged via Logger. | 2026-02-20 |
| 12 | Keep BLoC architecture, modify UI content | Architecture is solid. UI needs content changes, not structural rebuilds. | 2026-02-20 |
