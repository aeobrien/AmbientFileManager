# AmbientFileManager — Development Roadmap

## Overview

This roadmap covers the full implementation of AmbientFileManager as described in the Vision Statement and Technical Brief.

**9 phases**, each self-contained and manually testable before proceeding to the next. No phase is skipped. No phase is merged with the next without the user confirming that manual testing has passed.

---

## Dependency Graph

```
Phase 1: Project Setup + Data Model + Vault
    |
Phase 2: Tag Management
    |
Phase 3: Import + Filename Encoding
    |
    ├── Phase 4: Library Browser + Search/Filter
    │       |
    │       ├── Phase 5: Inbox + Processing
    │       |
    │       ├── Phase 6: Audition
    │       |
    │       └── Phase 7: Batch Operations + Undo
    │               |
    │               ├── Phase 8: Export
    │               |
    │               └── Phase 9: Deletion, Keyboard Shortcuts, Polish
```

Phases 5, 6, and 7 all depend on Phase 4 but are independent of each other. Phases 8 and 9 depend on Phase 7.

---

## Phase 1: Project Setup, Data Model, and Vault Configuration

**Branch:** `phase-1/setup-and-data-model`
**Depends on:** Nothing

### What This Phase Delivers

A launchable macOS app with the SwiftData schema in place and vault directory configuration working. No features yet — just the skeleton that everything else builds on.

### Sub-modules

- 1.1 **Create Xcode project** — New SwiftUI macOS app targeting macOS 14+. Configure project settings, bundle identifier, and SwiftData.
- 1.2 **Define SwiftData models** — Implement the three core entities: `Sample`, `TagGroup`, `Tag`, with all fields and relationships as specified in the Technical Brief. Include `originalFilename` on Sample.
- 1.3 **Vault configuration** — On first launch, prompt the user to choose a vault directory. Store the path in UserDefaults (or SwiftData config). Show the current vault path in a minimal settings view. Allow changing the vault location.
- 1.4 **Sidebar navigation shell** — Implement the sidebar-detail layout with placeholder views for Library, Inbox, and Tag Manager. Only the sidebar and navigation structure need to work — content views are stubs.

### Deliverables

- [ ] App builds and launches on macOS 14+
- [ ] SwiftData schema compiles with all three entities and relationships
- [ ] Vault directory picker works (choose, display, change)
- [ ] Sidebar navigation shows Library, Inbox, Tag Manager with placeholder content
- [ ] Vault path persists across app restarts

### Manual Test Brief

- Launch the app — verify it opens without errors
- First launch prompts for vault directory — select a folder, confirm it's displayed
- Quit and relaunch — verify the vault path is remembered
- Change the vault path in settings — verify the new path is displayed
- Click Library, Inbox, Tag Manager in the sidebar — verify each shows a distinct placeholder view

---

## Phase 2: Tag Management

**Branch:** `phase-2/tag-management`
**Depends on:** Phase 1

### What This Phase Delivers

A working tag management interface where the user can create, rename, and delete tag groups and tags with full code uniqueness enforcement.

### Sub-modules

- 2.1 **Tag Manager view** — List of tag groups, expandable to show tags within each group. Each group and tag displays its name and code.
- 2.2 **Create tag group** — Form to enter name and code. Code uniqueness enforced globally (reject duplicates with feedback).
- 2.3 **Create tag** — Form to enter name and code within a group. Code uniqueness enforced within the group.
- 2.4 **Rename tag group and tag** — Edit name (no side effects) and code (with warning about affected samples — zero at this stage, but the warning infrastructure should exist).
- 2.5 **Delete tag group and tag** — Confirmation dialog showing affected sample count (zero at this stage). Deleting a group deletes all its tags.
- 2.6 **Validation** — Codes must be 2-3 alphanumeric characters. Names must be non-empty. Reject invalid input with clear feedback.

### Deliverables

- [ ] Tag Manager view displays tag groups and their tags
- [ ] Create tag group with name and unique code
- [ ] Create tag within a group with name and unique code
- [ ] Rename tag group name and code
- [ ] Rename tag name and code
- [ ] Delete tag (with confirmation)
- [ ] Delete tag group and all its tags (with confirmation)
- [ ] Code uniqueness enforced (group codes global, tag codes within group)
- [ ] Invalid input rejected with feedback (empty name, code too short/long, duplicate code)

### Manual Test Brief

- Open Tag Manager — verify it's empty initially
- Create a tag group "Sound Bath" with code "SB" — verify it appears
- Create tags "Arrival" (AR) and "Calm" (CA) inside it — verify they appear under the group
- Create a second group "Affect" with code "AF" — verify it appears
- Try to create another group with code "SB" — verify it's rejected with a message
- Try to create a tag with code "AR" inside "Sound Bath" — verify it's rejected
- Create a tag with code "AR" inside "Affect" — verify it succeeds (same code, different group)
- Rename "Sound Bath" to "Sound Bath Sessions" — verify the name changes, code stays "SB"
- Rename the code "SB" to "SS" — verify it changes (and the warning about affected samples appears, showing 0)
- Delete the tag "Calm" — verify confirmation dialog, then verify it's gone
- Delete the group "Affect" — verify confirmation warns about deleting all tags within, then verify it's gone with all its tags

---

## Phase 3: Import Workflow and Filename Encoding

**Branch:** `phase-3/import-and-filenames`
**Depends on:** Phase 2

### What This Phase Delivers

The ability to import audio files into the vault via drag-and-drop or file picker, in both quick-dump and detailed modes. Filenames are generated from metadata using the encoding scheme.

### Sub-modules

- 3.1 **Filename encoding engine** — Pure function: given a Sample's metadata and tags, produce the encoded filename. Implement sanitisation (alphanumeric + hyphens only), deterministic tag ordering (alphabetical by group code, then tag code), version formatting, and omission of nil fields. Validate against the 255-character limit.
- 3.2 **File picker import** — Standard macOS open panel for selecting files or folders. Recursive audio file collection from folders. Filter to supported formats (WAV, AIFF, MP3, M4A, CAF, FLAC — based on AVFoundation support).
- 3.3 **Drag and drop import** — Drop target on the application window. Same recursive collection and format filtering.
- 3.4 **Import confirmation view** — Modal/sheet showing all discovered audio files. Support individual and batch select/deselect, select all/deselect all. Reject non-audio files with feedback.
- 3.5 **Quick-dump mode** — Copy selected files into the vault with sanitised filenames and version numbers. Create Sample records with `isProcessed = false`. Store original filename.
- 3.6 **Detailed mode** — Walk the user through assigning name, key, tempo, and tags for each file (or batch). Generate full encoded filenames. Create Sample records with `isProcessed = true`.
- 3.7 **Duplicate/collision handling** — On filename collision, prompt the user to rename, increment version (if it's genuinely a new variant), or skip. Never auto-increment version silently.

### Deliverables

- [ ] Filename encoding produces correct output for all field combinations (full metadata, partial, empty)
- [ ] Filenames are deterministic (same input always produces same output)
- [ ] File picker imports audio files into the vault
- [ ] Drag and drop imports audio files into the vault
- [ ] Import confirmation view with select/deselect controls
- [ ] Non-audio files rejected with feedback
- [ ] Quick-dump mode: files copied, minimal filenames, `isProcessed = false`
- [ ] Detailed mode: files copied with full encoded filenames, `isProcessed = true`
- [ ] Collision handling prompts user (rename / increment version / skip)
- [ ] Original filename preserved on Sample record
- [ ] Files in vault match their database records

### Manual Test Brief

- Prepare a test folder with 3-4 audio files (WAV and/or AIFF) and one non-audio file (e.g. a .txt)
- Use the file picker to select the folder — verify all audio files appear in the confirmation list, the .txt is rejected
- Deselect one file, confirm — verify only the selected files are imported
- Choose quick-dump mode — verify files appear in the vault with sanitised names and `_v01` suffix
- Import another batch using drag and drop — verify the drop target works and the confirmation view appears
- Choose detailed mode — assign a name, key (e.g. Cmaj), and a tag (e.g. SB-AR) to one file — verify the vault filename matches the encoding scheme (e.g. `My-Drone_Cmaj_SB-AR_v01.wav`)
- Import a file with the same name as an existing vault file — verify the collision dialog appears with rename/version/skip options
- Choose "increment version" — verify the file is imported as `v02`
- Check the vault directory in Finder — verify all files are present with correct names
- Verify original filenames are stored (visible in a later phase, but check the database if possible)

---

## Phase 4: Library Browser and Search/Filter

**Branch:** `phase-4/library-browser`
**Depends on:** Phase 3

### What This Phase Delivers

The main library view — a filterable, sortable table of all samples with text search, metadata filters, and tag filters. This is the screen the user will spend the most time on.

### Sub-modules

- 4.1 **Library table view** — Sortable table showing: name, key, tempo, tag summary (comma-separated tag names), date imported. Default sort: name ascending.
- 4.2 **Sort controls** — Clickable column headers to sort by name, key, tempo, date imported. Toggle ascending/descending.
- 4.3 **Text search** — Search field that filters by sample name and tag name. Case-insensitive, partial match. Updates results in real time.
- 4.4 **Metadata filters** — Filter controls for key (multi-select), tempo (range or free-time-only), and processed status (processed / unprocessed / all).
- 4.5 **Tag filters** — Collapsible sections per tag group, each showing its tags as toggles. OR within group, AND across groups. Visual grouping makes the logic intuitive.
- 4.6 **Filter composition** — All filters compose with AND logic. The table updates in real time as filters change.
- 4.7 **FilterState implementation** — Observable object capturing UI state and generating SwiftData predicates. Database-backed queries by default.
- 4.8 **Sample inspector** — Selecting a sample shows a detail panel with all metadata, tags, and the vault filename. Read-only for now (editing comes in Phase 7).
- 4.9 **Row selection** — Single and multi-select rows in the table (multi-select used by later phases for batch operations).

### Deliverables

- [ ] Library view shows all samples in a sortable table
- [ ] Sort by name, key, tempo, date imported (ascending/descending)
- [ ] Text search filters by sample name and tag name in real time
- [ ] Key filter (multi-select)
- [ ] Tempo filter (range and free-time-only)
- [ ] Processed status filter
- [ ] Tag filters with OR-within-group, AND-across-group logic
- [ ] All filters compose together (AND)
- [ ] Sample inspector shows full detail for selected sample
- [ ] Multi-row selection works

### Manual Test Brief

- Import several test files (if not already present from Phase 3) with different keys, tempos, and tags
- Open the Library view — verify all samples appear in a table sorted by name
- Click the "Key" column header — verify samples sort by key. Click again — verify descending.
- Type a sample name in the search bar — verify the table filters in real time
- Type a tag name (e.g. "Arrival") — verify samples carrying that tag appear
- Clear the search, then select "Cmaj" in the key filter — verify only Cmaj samples show
- With the key filter active, also toggle a tag (e.g. SB-AR) — verify the results narrow further (AND logic)
- Toggle two tags within the same group (e.g. SB-AR and SB-CA) — verify results broaden within that group (OR logic)
- Select the "free-time only" tempo filter — verify only nil-tempo samples show
- Click a sample row — verify the inspector panel shows its full metadata, tags, and filename
- Select multiple rows (Shift+click or Cmd+click) — verify multi-selection highlights correctly

---

## Phase 5: Inbox and Processing Workflow

**Branch:** `phase-5/inbox`
**Depends on:** Phase 4

### What This Phase Delivers

A dedicated inbox view for unprocessed files, with the ability to assign metadata and tags and mark files as processed.

### Sub-modules

- 5.1 **Inbox view** — Same table layout as the library, but filtered to `isProcessed == false` only. Displays in the sidebar under "Inbox" with a badge showing the unprocessed count.
- 5.2 **Inline metadata editing** — From the inbox (or inspector), edit a sample's name, key, and tempo. Changes trigger filename regeneration.
- 5.3 **Inline tag application** — From the inbox (or inspector), apply or remove tags on a sample. Changes trigger filename regeneration.
- 5.4 **Mark as processed** — Button to set `isProcessed = true` on a sample, triggering filename regeneration. The sample disappears from the inbox and appears in the library (if not already visible due to the "all" status filter).
- 5.5 **Batch mark as processed** — Select multiple inbox files and mark them all as processed in one action.
- 5.6 **Inbox badge** — Sidebar badge showing the count of unprocessed files. Updates in real time as files are processed or imported.

### Deliverables

- [ ] Inbox view shows only unprocessed samples
- [ ] Inbox badge count in sidebar
- [ ] Edit sample name, key, tempo from inbox — filename regenerates
- [ ] Apply and remove tags from inbox — filename regenerates
- [ ] Mark single sample as processed — disappears from inbox
- [ ] Batch mark as processed
- [ ] No minimum completeness rules — a file can be marked processed with no tags
- [ ] Vault filenames stay in sync with database after every edit

### Manual Test Brief

- Quick-dump import 3 files (from Phase 3) — verify they appear in the inbox with a badge count of 3
- Select one file in the inbox — edit its name to "Test Drone" — verify the vault file is renamed to match
- Set the key to "Cmaj" — verify the filename updates (e.g. `Test-Drone_Cmaj_v01.wav`)
- Apply the tag SB-AR — verify the filename updates to include `SB-AR`
- Mark this file as processed — verify it disappears from the inbox, badge drops to 2
- Verify the file now appears in the Library view
- Select the remaining 2 files — batch mark as processed — verify inbox is now empty, badge gone
- Check the vault directory in Finder — verify all filenames match their database state

---

## Phase 6: Audition

**Branch:** `phase-6/audition`
**Depends on:** Phase 4

### What This Phase Delivers

In-app audio playback with pitch shifting via sample rate adjustment.

### Sub-modules

- 6.1 **AVAudioEngine setup** — Configure `AVAudioEngine` with `AVAudioPlayerNode` and `AVAudioUnitVarispeed` for playback.
- 6.2 **Play/pause/stop** — Standard transport controls. Play the currently selected sample in the library or inbox.
- 6.3 **Scrub/seek** — A progress bar showing playback position. Click or drag to seek.
- 6.4 **Pitch shifting** — Adjust `AVAudioUnitVarispeed` rate in semitone increments. Display current offset (e.g. "+3", "-2", "0"). Controls to shift up and down by one semitone.
- 6.5 **Transport UI** — Playback controls integrated into the library/inbox views (inline or as a persistent panel at the bottom). Show currently playing file name, playback position, and pitch offset.
- 6.6 **Playback state management** — Stop playback when selecting a different file. Handle file-not-found gracefully (vault file missing).

### Deliverables

- [ ] Play any sample from the library or inbox
- [ ] Pause and resume playback
- [ ] Stop playback
- [ ] Scrub/seek to any position in the file
- [ ] Shift pitch up by semitone increments
- [ ] Shift pitch down by semitone increments
- [ ] Pitch offset displayed (e.g. "+2 semitones")
- [ ] Speed changes proportionally with pitch (not time-stretched)
- [ ] Selecting a different file stops the current playback
- [ ] Missing file handled gracefully (error message, not crash)

### Manual Test Brief

- Select a sample in the library — press play — verify audio plays
- Press pause — verify audio stops. Press play — verify it resumes from the same position.
- Press stop — verify audio stops and position resets to the beginning.
- Drag the scrub bar to the middle — verify playback jumps to that position.
- Shift pitch up by +2 semitones — verify the audio plays higher and faster. Verify the UI shows "+2".
- Shift pitch down by -3 semitones — verify the audio plays lower and slower. Verify the UI shows "-3".
- Reset pitch to 0 — verify original speed and pitch.
- Select a different sample while audio is playing — verify the first stops.
- Temporarily rename a vault file in Finder, then try to play it — verify the app shows an error rather than crashing. Rename it back.

---

## Phase 7: Batch Operations and Undo

**Branch:** `phase-7/batch-and-undo`
**Depends on:** Phase 4

### What This Phase Delivers

Multi-file batch operations for tagging and metadata editing, plus an undo system that reverts both database changes and the resulting filename regenerations.

### Sub-modules

- 7.1 **Batch tag application** — Select multiple samples, apply one or more tags. Additive: existing tags are preserved. Filename regeneration for all affected files.
- 7.2 **Batch tag removal** — Select multiple samples, remove one or more tags from all of them. Filename regeneration.
- 7.3 **Batch metadata editing** — Select multiple samples, set key or tempo. Replacement semantics: overwrites existing values. When selected files have mixed values, UI shows "mixed" placeholder and requires confirmation before overwriting. Filename regeneration.
- 7.4 **Rename atomicity** — When a batch operation triggers filename regeneration across multiple files: capture state, apply DB changes, rename files sequentially. If a rename fails, revert the DB change for that sample, surface the error, continue with remaining files.
- 7.5 **Undo system** — Capture pre-operation state before any batch operation. Cmd+Z reverts the database changes and triggers reverse filename regeneration. Scope: batch tag add/remove, batch metadata edit, mark as processed. Single-level undo (one operation). Stack cleared on quit.
- 7.6 **Undo filesystem safety** — If a reverse rename fails during undo, roll back the DB change for the affected sample, surface the error, leave successfully reverted files in their reverted state.
- 7.7 **Tag code rename cascade** — When a tag or tag group code is renamed (from Phase 2), trigger filename regeneration for all affected samples. Use the same atomicity and undo patterns.

### Deliverables

- [ ] Batch apply tags to multiple samples (additive)
- [ ] Batch remove tags from multiple samples
- [ ] Batch set key on multiple samples (replacement with mixed-value warning)
- [ ] Batch set tempo on multiple samples (replacement with mixed-value warning)
- [ ] Filenames regenerate correctly after every batch operation
- [ ] Rename atomicity: partial failures handled per-file, not all-or-nothing
- [ ] Cmd+Z undoes the last batch operation (data + filenames revert)
- [ ] Undo handles filesystem failures gracefully
- [ ] Tag code rename triggers filename regeneration across all affected samples

### Manual Test Brief

- Select 3 samples in the library. Batch-apply the tag SB-AR — verify all 3 filenames now include `SB-AR`.
- Cmd+Z — verify all 3 filenames revert to their previous state and the tag is removed from all 3.
- Select 3 samples with different keys. Batch-set key to "Dmin" — verify the "mixed values" warning appears. Confirm — verify all 3 now show "Dmin" and filenames update.
- Cmd+Z — verify all 3 revert to their original keys.
- Batch-apply a tag, then batch-set a key (two separate operations). Cmd+Z — verify only the key change is undone (single-level undo).
- Select 2 samples. Batch-remove a tag — verify the tag is removed from both and filenames update.
- Go to Tag Manager (Phase 2). Rename a tag code (e.g. "AR" to "AV") — verify all samples carrying that tag have their filenames regenerated with the new code.
- Check the vault in Finder after each operation — verify filenames match database state.

---

## Phase 8: Export

**Branch:** `phase-8/export`
**Depends on:** Phase 7

### What This Phase Delivers

Export filtered selections of files to a user-chosen directory, with flat or tag-based folder structure and optional codebook.

### Sub-modules

- 8.1 **Export flow UI** — Sheet/modal triggered from the library view. Shows the currently selected/filtered files. Configure destination, folder structure, and codebook inclusion.
- 8.2 **ExportConfiguration** — `destinationPath: URL`, `folderGrouping: .flat | .byTagGroup(TagGroup)`, `includeCodebook: Bool`.
- 8.3 **Flat export** — Copy all selected files to the destination directory, preserving vault filenames.
- 8.4 **Tag-based folder grouping** — Create subdirectories based on a selected tag group. Files placed in folders by their tag in that group. If a sample has multiple tags in the grouping group, use the first alphabetically. If a sample has no tag in the grouping group, place it in a root-level "Ungrouped" folder.
- 8.5 **Codebook export** — Generate `codebook.json` containing the full tag vocabulary (all groups, all tags, all codes) and write it to the export destination.
- 8.6 **Export progress** — Show progress for large exports. Handle errors (disk full, permissions) gracefully.

### Deliverables

- [ ] Export flow accessible from the library view
- [ ] Flat export copies files with vault filenames to chosen directory
- [ ] Tag-based folder grouping creates correct subdirectories
- [ ] Multi-tag ambiguity resolved (first alphabetically)
- [ ] Samples with no matching tag go to "Ungrouped" folder
- [ ] Codebook.json includes full tag vocabulary
- [ ] Errors handled gracefully (disk full, permissions, missing vault files)

### Manual Test Brief

- Filter the library to a subset (e.g. all Cmaj files). Open the export flow — verify the correct files are listed.
- Choose flat export to a test directory — verify all files appear in the directory with their vault filenames.
- Delete the export, then re-export with tag-based grouping by "Sound Bath" — verify subdirectories (e.g. `AR/`, `CA/`) are created with the correct files inside.
- Verify a file with no Sound Bath tag appears in an "Ungrouped" folder.
- Verify a file with two Sound Bath tags (e.g. AR and CA) appears in only one folder (the alphabetically first one).
- Enable codebook export — verify `codebook.json` is created and contains all tag groups and tags.
- Open `codebook.json` — verify it's valid JSON and lists the full vocabulary, not just the tags used in this export.

---

## Phase 9: Deletion, Keyboard Shortcuts, and Polish

**Branch:** `phase-9/deletion-and-polish`
**Depends on:** Phase 8

### What This Phase Delivers

The final phase: sample deletion, keyboard shortcuts for common operations, and a full audit against the Vision Statement's Definition of Done.

### Sub-modules

- 9.1 **Single sample deletion** — Delete a sample: confirmation dialog, move file to system Trash, remove database record.
- 9.2 **Batch deletion** — Select multiple samples, delete all with a single confirmation showing count.
- 9.3 **Keyboard shortcuts** — Implement keyboard shortcuts for: play/pause (Space), stop (Escape), pitch up/down (Up/Down arrows during audition), import (Cmd+I), delete (Cmd+Backspace), mark as processed (Cmd+Return), select all (Cmd+A).
- 9.4 **Missing file detection** — On library load or when accessing a sample, detect if the vault file is missing. Surface a visual indicator in the table rather than silently failing.
- 9.5 **Vault unavailable handling** — If the vault directory is inaccessible (e.g. external drive disconnected), show a clear error and prevent operations that require vault access.
- 9.6 **Vision statement audit** — Walk through every item in the Definition of Done. Verify each is met. Walk through the example workflow. Identify and fix any gaps.

### Deliverables

- [ ] Delete single sample (confirmation, Trash, DB removal)
- [ ] Batch delete multiple samples
- [ ] Keyboard shortcuts for all listed operations
- [ ] Missing vault files indicated in the library table
- [ ] Vault unavailable state handled gracefully
- [ ] Every item in the Definition of Done is satisfied
- [ ] Example workflow ("filter by SB-AR in Cmaj, audition, export") works end to end

### Manual Test Brief

- Select a sample — press Cmd+Backspace — verify confirmation dialog. Confirm — verify sample gone from library and file in system Trash.
- Select 3 samples — Cmd+Backspace — verify confirmation shows "3 files". Confirm — verify all removed.
- Open Trash in Finder — verify deleted files are recoverable.
- Test keyboard shortcuts: Space to play/pause, Escape to stop, Up/Down for pitch shift, Cmd+I opens import, Cmd+Return marks inbox file as processed, Cmd+A selects all in library.
- Temporarily rename a vault file in Finder — refresh the library — verify a "missing file" indicator appears on that sample. Rename it back.
- Change the vault path to a non-existent directory — verify the app shows a clear error and doesn't crash.
- **Full workflow test:** Create tag group "Sound Bath" with tags "Arrival" and "Calm". Import 5 test files in detailed mode — give 3 the key Cmaj and tag SB-AR, give 2 others Fmin and SB-CA. Filter the library by SB-AR + Cmaj. Audition one file. Pitch shift it +2 semitones to check. Export the filtered set to a directory with tag-based folder grouping. Verify the exported files and structure are correct. This should take under 2 minutes once familiar with the interface.

---

## Decision Log

| # | Decision | Rationale | Date |
|---|----------|-----------|------|
| 1 | Version numbers are strictly semantic, not collision-avoidance | Prevents confusion between real variants and filesystem bookkeeping | 2026-03-25 |
| 2 | AVAudioEngine + AVAudioUnitVarispeed for playback | AVAudioPlayer.rate does time-pitch correction, not sample-rate shifting | 2026-03-25 |
| 3 | Tags are the extensibility mechanism, not dynamic schema | Fixed metadata fields + flexible tags is simpler and covers all use cases | 2026-03-25 |
| 4 | Filenames are human-readable, not machine-parseable | Pragmatic resilience; full recovery from filenames alone is not supported in v1 | 2026-03-25 |
| 5 | Deletion uses system Trash, not hard delete | Provides recovery window without building in-app trash | 2026-03-25 |
| 6 | Export codebook includes full vocabulary | More useful than export-specific codes; the codebook is a reference for the entire library | 2026-03-25 |
| 7 | Multi-tag folder grouping ambiguity resolved by alphabetical first | Simple, deterministic, no file duplication | 2026-03-25 |
| 8 | Single-level undo for v1 | Keeps implementation simple; expand to multi-level if needed | 2026-03-25 |
| 9 | Text search covers sample names and tag names | Users expect "Arrival" in the search bar to find tagged files, not just named ones | 2026-03-25 |
