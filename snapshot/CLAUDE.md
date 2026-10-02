# AmbientFileManager — Project Conventions

## Overview

AmbientFileManager is a personal asset management system for organising, tagging, auditioning, and exporting ambient music files. macOS native app built with SwiftUI and SwiftData. Single-user, no external dependencies, no network requirements.

## Architecture

**Framework:** SwiftUI
**Persistence:** SwiftData (SQLite-backed)
**Audio:** AVFoundation (AVAudioEngine + AVAudioUnitVarispeed)
**Target Platform:** macOS 14+
**IDE:** Xcode
**External Dependencies:** None

## Current Project State

**Current Phase:** Phase 1 (not yet started)
**Phases complete:** None

## Project Structure

```
AmbientFileManager/
    Models/          — SwiftData model definitions (Sample, TagGroup, Tag)
    Views/           — SwiftUI views, organised by feature area
        Library/     — Library browser, filter bar, table
        Inbox/       — Inbox view and processing UI
        Import/      — Import confirmation, mode selection
        Export/      — Export configuration and flow
        TagManager/  — Tag and tag group CRUD
        Audition/    — Playback controls and pitch shift UI
        Settings/    — Vault configuration
        Shared/      — Reusable components (inspector panel, etc.)
    Services/        — Non-UI logic
        FilenameEncoder.swift    — Filename generation from metadata
        VaultManager.swift       — File operations (copy, rename, trash)
        AudioPlayer.swift        — AVAudioEngine playback wrapper
        ExportService.swift      — Export orchestration
        ImportService.swift      — Import orchestration
        UndoManager.swift        — Batch operation undo state
    App/             — App entry point, WindowGroup, ModelContainer setup
```

This structure is a starting point. Adjust as needed during implementation, but keep the separation between Models, Views, and Services clean.

## Key Files

| File | Purpose |
|------|---------|
| `ROADMAP.md` | Phase-by-phase development plan |
| `WORKFLOW.md` | Development cycle and debugging protocol |
| `CLAUDE.md` | This file — project conventions |
| `AmbientFileManager — Vision Statement.md` | Product vision |
| `AmbientFileManager — Technical Brief.md` | Technical specification |

## Build & Run

```bash
# Build from command line
xcodebuild -scheme AmbientFileManager -configuration Debug build

# Run from Xcode
# Cmd+R
```

## Code Style

### Naming

- **Files:** `PascalCase.swift` (matching primary type name)
- **Types/Protocols:** `PascalCase`
- **Variables/functions:** `camelCase`
- **SwiftData models:** `PascalCase`, stored properties as `camelCase`
- **Views:** `PascalCase` with `View` suffix (e.g. `LibraryView`, `InboxView`)
- **Services:** `PascalCase` with descriptive suffix (e.g. `VaultManager`, `FilenameEncoder`)

### Commits

- Format: `Phase N: [summary of what this delivers]`
- Branches: `phase-N/name`
- One commit per phase (squash if needed)

### SwiftUI

- Keep views focused — extract subviews when a view body exceeds ~50 lines
- Use `@Query` for SwiftData fetches in views where appropriate
- Use `@Observable` classes for non-SwiftData state (e.g. FilterState, AudioPlayer)
- Prefer `NavigationSplitView` for the sidebar-detail layout

### SwiftData

- All queries should use `#Predicate` macros — do not load all records and filter in memory
- Relationships: use SwiftData's built-in relationship management
- Deletions: handle cascade behaviour explicitly (e.g. deleting a TagGroup deletes its Tags)

### File Operations

- Always use `FileManager` for file operations (copy, move, rename, trash)
- Use `FileManager.trashItem(at:resultingItemURL:)` for deletion (Trash, not hard delete)
- Validate vault directory accessibility before file operations
- Handle errors per-file in batch operations (don't fail the whole batch on one error)

### Audio

- Use `AVAudioEngine` → `AVAudioPlayerNode` → `AVAudioUnitVarispeed` → output
- Semitone calculation: rate = 2^(semitones/12)
- Stop and reset the engine when not playing (don't leave it running)

## Mistakes to Avoid

1. **Don't auto-increment version numbers on import collision** — version is semantic (real variants of the same sound). Prompt the user to choose: rename, increment, or skip.
2. **Don't use AVAudioPlayer for pitch shifting** — its `rate` property does time-pitch correction, not sample-rate shifting. Use `AVAudioEngine` + `AVAudioUnitVarispeed`.
3. **Don't use folder hierarchy in the vault** — the vault is flat. All organisation lives in the database and filenames.
4. **Don't allow non-deterministic filenames** — tag codes must be sorted alphabetically in filenames. Same metadata must always produce the same filename.
5. **Don't silently skip failed file renames in batch operations** — report per-file failures and keep each sample's DB record in sync with its actual filename.
6. **Don't load all samples and filter in memory** — use SwiftData predicates for queries.
7. **Don't proceed to the next phase without manual testing** — this is the most important workflow rule. See WORKFLOW.md.
8. **Don't treat tag application as replacement in batch operations** — batch tagging is additive. Batch metadata editing (key, tempo) is replacement with confirmation.
9. **Don't hard-delete files** — use `FileManager.trashItem` so the user can recover from Finder.
10. **Don't skip the 255-character filename validation** — warn the user, don't silently truncate.
