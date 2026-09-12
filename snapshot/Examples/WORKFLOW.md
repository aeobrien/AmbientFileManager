# FoodTracker — Development Workflow

## Module Development Cycle

Every phase follows this exact cycle:

### 1. Build
- Create branch `phase-N/name`
- Implement all sub-modules
- Follow conventions in CLAUDE.md

### 2. Auto-Test
- Write unit tests for all new public API (where applicable — Stage 1 phases may not add code)
- Run tests: `flutter test`
- All tests must pass before proceeding

### 3. Integrate
- Run code generation if models changed: `flutter pub run build_runner build --delete-conflicting-outputs`
- Build the full app: `flutter build ios`
- Fix any integration issues

### 4. Manual Test Brief
- Write test brief at `docs/manual-tests/phase-N-name.md`
- Include: prerequisites, step-by-step instructions, expected outcomes, pass criteria
- User performs manual testing and provides feedback

### 5. Commit
- Only after both auto-tests and manual tests pass
- Commit message: `Phase N: [what this phase delivers]`
- Update session log at `docs/session-log.md`

---

## Stage 1 Workflow Variation

Phases 0-2 are setup and audit phases, not feature phases. The cycle is adjusted:

- **Phase 0 (Environment Setup):** Build → verify on device → commit. No tests to write. Manual test = "app launches."
- **Phase 1 (Smoke Test):** No code changes. Deliverable is the smoke test document. No commit to code — commit the test results document.
- **Phase 2 (Codebase Audit):** No code changes. Deliverable is the audit document. Commit the audit.
- **Phase 3 (Stage 2 Roadmap):** Update ROADMAP.md, CLAUDE.md, WORKFLOW.md. Commit the updated plans.

From Stage 2 (Phase 4 onward), the full 5-step cycle applies to every phase.

---

## Debugging Protocol

When a build or test fails:

1. Read the full error message
2. Identify the root cause (don't guess)
3. Fix the cause, not the symptom
4. Re-run the specific failing test
5. Re-run the full test suite
6. Re-build the app
7. Only proceed when everything passes

---

## Flutter-Specific Notes

### Code generation
Many files in this project are auto-generated (Hive adapters, JSON serialization, envied environment bindings). If you see errors related to `.g.dart` files or missing generated code:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### iOS-specific
- Always open `ios/Runner.xcworkspace` (not `.xcodeproj`)
- After adding new plugins that require native setup (e.g., HealthKit), you may need to run `cd ios && pod install --repo-update`
- HealthKit, camera, and notification permissions are configured in Xcode's Signing & Capabilities and in `Info.plist`

### Hot reload vs. full rebuild
- Dart code changes: hot reload works (fast, preserves state)
- Native iOS code changes (Swift in `ios/Runner/`): requires full rebuild (`flutter run`)
- New dependencies or plugin changes: requires `flutter pub get` + possibly `pod install`
