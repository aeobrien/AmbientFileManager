# AmbientFileManager — Development Workflow

## Phase Development Cycle

Every phase follows this exact cycle. No exceptions.

### 1. Build

- Create branch `phase-N/name`
- Implement all sub-modules for the phase
- Follow conventions in CLAUDE.md

### 2. Compile and Run

- Build the app in Xcode: `Cmd+B` or `xcodebuild`
- Fix any compiler errors
- Launch the app and verify it doesn't crash on startup

### 3. Manual Test Brief

- Present the user with the manual test checklist from ROADMAP.md
- User performs manual testing on the running app
- User reports results: pass, fail, or issues found

### 4. Fix

- If manual testing surfaces issues, fix them
- Rebuild, re-test the specific fix
- Return to step 3 for re-verification

### 5. Commit

- Only after manual tests pass
- Commit message: `Phase N: [what this phase delivers]`
- Do not proceed to the next phase until the user confirms

---

## Critical Rule: Phase Gates

**Do not start the next phase until the user has confirmed that manual testing has passed for the current phase.**

This is the single most important workflow rule. Each phase builds on the last. Uncaught problems in early phases compound into harder problems later. The manual test brief exists precisely to catch issues early.

If I (Claude Code) finish building a phase, I present the manual test checklist and wait. I do not start the next phase. I do not "get ahead" by building the next phase while the user tests.

---

## Debugging Protocol

When a build fails or a test reveals an issue:

1. Read the full error message or bug report
2. Identify the root cause — do not guess
3. Fix the cause, not the symptom
4. Rebuild the app
5. Verify the specific fix
6. Re-run the full manual test brief for the current phase
7. Only proceed when everything passes

---

## SwiftUI / macOS Specific Notes

### Building

```bash
# Build from command line
xcodebuild -scheme AmbientFileManager -configuration Debug build

# Or use Xcode: Cmd+B to build, Cmd+R to run
```

### SwiftData

- Model changes may require deleting the app's container to reset the database during development (the schema is not stable until all phases are complete)
- If SwiftData migration errors occur, delete `~/Library/Containers/<bundle-id>/` and relaunch
- Always test with fresh data after schema changes

### File System

- The vault directory requires read/write permissions — if using a sandboxed app, ensure the vault directory is accessible via security-scoped bookmarks
- macOS sandboxing may affect drag-and-drop and file picker behaviour — test both paths
- File operations (copy, rename, trash) should use `FileManager` APIs, not shell commands

### Audio

- `AVAudioEngine` must be started before playback and stopped when not in use
- Audio session configuration may not be needed on macOS (unlike iOS), but test playback with system audio settings
- Test with both WAV and AIFF files at minimum; test MP3 if available
