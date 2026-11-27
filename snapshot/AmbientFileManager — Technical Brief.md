# AmbientFileManager — Technical Brief

## Technology Stack

- **UI Framework:** SwiftUI (macOS only)
- **IDE:** Xcode
- **Persistence:** SwiftData
- **Audio:** AVFoundation (AVAudioEngine)
- **Deployment Target:** macOS 14+ (required for SwiftData)
- **External Dependencies:** None

The application targets macOS desktop only. There are no iOS, iPadOS, or cross-platform requirements. The entire stack stays within Apple's native ecosystem, keeping the dependency footprint at zero and simplifying maintenance.

Development will be primarily carried out by Claude Code, with Xcode as the build and project management environment.

## Data Model

### Core Entities

**Sample** — the central entity representing a single audio file in the vault.
- `id`: UUID (unique identifier, used internally)
- `name`: String (the human-readable sample name, e.g. "Warm Drone")
- `originalFilename`: String (the filename as it existed before import, preserved for provenance)
- `key`: String, optional (musical key signature, e.g. "Cmaj", "Fmin" — nil for percussive/atonal files)
- `tempo`: Int, optional (BPM — nil for free-time files)
- `version`: Int (a semantic version distinguishing variants of the same sound — e.g. a re-recorded or re-processed version of "Warm Drone" would be v02. Defaults to 1. See Import for collision handling.)
- `isProcessed`: Bool (false for quick-dump imports awaiting tagging)
- `dateImported`: Date
- `fileExtension`: String (e.g. "wav", "aiff")
- `tags`: relationship to Tag (many-to-many)

**TagGroup** — a named collection of related tags, used for UI organisation.
- `id`: UUID
- `name`: String (e.g. "Sound Bath", "Generative App", "Affect")
- `code`: String (2-3 character short code for filename encoding, e.g. "SB", "GA", "AF")
- `tags`: relationship to Tag (one-to-many)

**Tag** — an individual tag belonging to a group.
- `id`: UUID
- `name`: String (e.g. "Arrival", "Calm", "Bright")
- `code`: String (2-3 character short code for filename encoding, e.g. "AR", "CA", "BR")
- `group`: relationship to TagGroup (many-to-one)
- `samples`: relationship to Sample (many-to-many)

### Design Notes

Tags from any group can be applied to any sample — group membership organises the UI, not the data. The tagging system is fully user-defined: tag groups, tags, and their associated codes can be created, renamed, and restructured at any time. Adding a new tag group or tag requires no schema changes — it's just new data.

The `code` fields on TagGroup and Tag are user-defined short identifiers used exclusively for filename encoding. They must be unique within their scope (group codes globally unique, tag codes unique within their group), enforced at creation and rename time.

The fixed metadata fields on Sample (name, key, tempo, version) are the only structured properties beyond tags. All other categorisation — emotional qualities, instrumentation, project associations, section markers — is expressed through the tag system. This is a deliberate design choice: the tag system is the extensibility mechanism, not a dynamic schema.

## Tag Management

### CRUD Operations

Tag groups and tags can be created, renamed, and deleted through a dedicated tag management interface.

**Creating** a tag group or tag requires a name and a unique code. The app enforces code uniqueness at creation time (group codes globally, tag codes within their group).

**Renaming** a tag or tag group name is a database-only change with no side effects. Renaming a tag or tag group *code* triggers filename regeneration for every affected sample, since codes are embedded in filenames. The app should display the number of affected files and require confirmation before proceeding.

**Deleting** a tag removes it from all samples that carry it and triggers filename regeneration for those samples. Deleting a tag group deletes all tags within it, with the same cascading behaviour. Both operations require confirmation showing the number of affected samples.

## Filename Encoding

Filenames are derived artifacts, always generated from database state. They are never manually edited. When a sample's metadata or tags change, the app regenerates the filename automatically.

### Format

```
{Sample-Name}_{Key}_{Tempo}bpm_{TagCodes}_{Version}.{ext}
```

- **Sample name:** Mixed case, words separated by hyphens. Only alphanumeric characters and hyphens are permitted; any other characters in the user-provided name are stripped or replaced with hyphens. Leading/trailing hyphens and consecutive hyphens are collapsed. E.g. `Warm-Drone`
- **Key:** Musical key signature. E.g. `Cmaj`, `Fmin`. Omitted if nil.
- **Tempo:** BPM with `bpm` suffix. E.g. `120bpm`. Omitted if nil.
- **Tag codes:** Hierarchical codes in `GroupCode-TagCode` format, sorted alphabetically by group code then tag code within group. Multiple tags separated by underscores. E.g. `AF-BR_SB-AR`
- **Version:** `v` prefix with zero-padded number. E.g. `v01`, `v02`
- **Blocks** are separated by underscores.
- **Omitted fields** are simply absent — no placeholder tokens.

### Deterministic Ordering

Tag codes in filenames are always sorted alphabetically (by group code first, then tag code within group). This guarantees that the same metadata always produces the same filename, regardless of the order in which tags were applied.

### Examples

A fully tagged sample:
```
Warm-Drone_Cmaj_AF-WM_SB-AR_v01.wav
```

A free-time percussive sample with minimal tagging:
```
Soft-Rain-Texture_SB-CA_v01.wav
```

An unprocessed quick-dump import (no tags or metadata yet):
```
Soft-Rain-Texture_v01.wav
```

### Constraints

All filenames must stay within the 255-character OS limit. Given the encoding scheme and realistic tag counts, this should not be a practical concern, but the filename generation logic should validate length and warn if a sample's metadata would exceed the limit, suggesting the user reduce tags or shorten the name.

### Filename Recovery

Filenames are designed for human readability, not guaranteed machine parsing. Rebuilding a database from filenames alone is not a supported feature in v1. The tag codes in filenames are only meaningful with the codebook, which is why the app supports exporting a codebook reference file (see Export).

## Vault Structure

The vault is a single flat directory on disk. There are no subfolders. All organisational intelligence lives in the database and is reflected in filenames — never in folder hierarchy.

The vault location is user-configured (chosen on first launch or in settings). Files are always copied into the vault on import — originals are not moved or modified.

## Import Workflow

### Input Mechanisms

Two input methods, both leading to the same workflow:
1. **Drag and drop** — files or folders dragged onto the application window.
2. **File/folder picker** — standard macOS open panel for selecting individual files or folders.

When folders are selected or dragged, the app recursively collects all audio files within them.

### Supported Audio Formats

The system accepts common audio formats for import: WAV, AIFF, MP3, M4A, CAF, and FLAC. The definitive list may be adjusted during implementation based on AVFoundation codec support. Note that compressed formats (MP3, M4A) may exhibit audible artifacts when pitch-shifted via sample rate adjustment; this is expected behaviour and not a bug. The library is expected to be predominantly lossless formats (WAV, AIFF), so compressed-format edge cases should be handled correctly but do not warrant extensive polish.

### Confirmation Step

Before any files are copied into the vault, the user is presented with a list of all files to be imported. This list supports:
- Individual selection and deselection
- Batch selection and deselection of multiple files
- Select all / deselect all

Non-audio files are rejected at this stage with clear feedback. The user confirms the final selection before proceeding.

### Import Modes

After confirmation, the user chooses one of two modes:

**Quick-dump mode:** All selected files are copied into the vault immediately. They are assigned a minimal filename (original name cleaned up and sanitised per the encoding rules, version number appended) and created in the database with `isProcessed = false`. The original filename is preserved in the `originalFilename` field. They appear in the inbox for later processing.

**Detailed mode:** The user is walked through tagging each file — assigning name, key, tempo, tags. The full encoded filename is generated and the file is copied into the vault with `isProcessed = true`. This should support batch application of shared properties (e.g. applying the same tag group to all files in an import batch) to reduce repetitive work.

### Duplicate Handling

On import, the system checks for filename collisions in the vault. If a collision is detected, the import pauses and prompts the user to resolve the conflict. The user is presented with the existing file's details alongside the new file and can choose to:
- **Rename** the new file (change the sample name to differentiate it)
- **Increment version** (if the new file is genuinely a new variant of the same sound)
- **Skip** the file (do not import)

Version numbers are strictly semantic — they represent real variants of the same sound, not filesystem bookkeeping. The system never auto-increments version numbers silently.

## Inbox

The inbox is a dedicated view that shows all samples where `isProcessed == false`. It is the primary entry point for processing quick-dump imports.

### Processing Workflow

From the inbox, the user can:
- Select one or more unprocessed files
- Assign or edit metadata (name, key, tempo)
- Apply tags
- Mark files as processed

Processing can be incremental — a file can be partially tagged in one session and finished later. The file remains in the inbox until the user explicitly marks it as processed, which sets `isProcessed = true` and triggers a full filename regeneration. The system imposes no minimum completeness rules — a file can be marked as processed with as little or as much metadata as the user sees fit.

Batch processing is supported: selecting multiple inbox files and applying shared metadata or tags in one operation, then marking the batch as processed.

### Inbox Indicators

The inbox should display a count of unprocessed files, visible from the main navigation so the user always knows whether there are files waiting for attention.

## Deletion

Samples can be deleted from the vault individually or in batch. Deletion removes the file from disk and the record from the database.

### Workflow

Deletion requires explicit confirmation. For batch deletions, the confirmation dialog should display the number of files to be deleted. Deleted files are moved to the system Trash (via `FileManager.trashItem`) rather than hard-deleted, giving the user a recovery window through the macOS Trash.

Deletion is not covered by the in-app undo system, since the filesystem operation (trashing) has its own recovery path.

## Search and Filtering

### Text Search

The library supports free-text search across sample names and tag names. Searching for "Arrival" will match both a sample named "Arrival Drone" and any sample carrying a tag named "Arrival." Search is case-insensitive and matches partial strings.

### Metadata Filters

Samples can be filtered by:
- **Key:** select one or more key signatures (e.g. Cmaj, Fmin)
- **Tempo:** range filter (e.g. 90-120 BPM) or "free-time only" (nil tempo)
- **Processed status:** processed, unprocessed, or all

### Tag Filters

Tags can be toggled on or off as filter criteria. When multiple tags are selected:
- **Within the same tag group:** OR logic (e.g. selecting both "Arrival" and "Calm" from the Sound Bath group matches files with either tag)
- **Across different tag groups:** AND logic (e.g. selecting "Arrival" from Sound Bath and "Bright" from Affect matches only files with both)

This within-OR / across-AND model is intuitive for the domain: "show me files that are (Arrival or Calm) and (Bright)."

### Filter Composition

All filter types compose together: text search, metadata filters, and tag filters are combined with AND logic. The library view updates in real time as filters are adjusted, progressively narrowing the displayed results.

### Implementation

Filtering is driven by a `FilterState` struct (or observable object) that captures the current UI filter selections and generates a compound SwiftData `Predicate` for querying. Database-backed predicate queries should be the default approach rather than loading all records and filtering in memory.

## Audition

Audio playback uses `AVAudioEngine` with `AVAudioUnitVarispeed`. This combination provides true sample-rate-based pitch shifting where playback speed changes proportionally with pitch — which is the desired behaviour (not time-stretched pitch correction).

### Core Requirements

- **Single-file playback** within the app for any file in the vault.
- **Pitch-shifted audition** via `AVAudioUnitVarispeed` rate adjustment. Pitch is shifted in semitone increments (up or down). One semitone up = rate x 2^(1/12) ~ 1.0595. One semitone down = rate x 2^(-1/12) ~ 0.9439.
- **Transport controls:** play, pause, stop, scrub.
- The UI should display the current pitch offset in semitones relative to the original (e.g. "+3", "-2", "0").

## Export Module

### Phase One: Basic Export

The initial export implementation provides:

- **File selection:** Any filtered set of samples from the library (using the same filter system described above).
- **Destination:** User-chosen directory via standard macOS save panel.
- **Folder structure:** The user can choose between a flat export (all files in one directory) or tag-based folder grouping, where a selected tag group determines the folder hierarchy. If a sample has multiple tags within the chosen grouping tag group, it is placed in the folder of the first tag alphabetically. The sample is not duplicated across folders.
- **Filenames:** Exported files retain their vault-encoded filenames.
- **Format:** Files are exported in their original format. Format conversion (e.g. WAV to MP3) is out of scope for v1.
- **Codebook export:** The export can optionally include a `codebook.json` file listing the full tag vocabulary — all tag groups, tags, and their codes — so that the encoded filenames remain interpretable outside the app regardless of which tags appear in the specific export.

### Export Configuration

```
ExportConfiguration {
    destinationPath: URL
    folderGrouping: .flat | .byTagGroup(TagGroup)
    includeCodebook: Bool
}
```

### Deferred: Pitch-Shifted Export

Rendering pitch-shifted variants to disk as new audio files requires an offline rendering pipeline using `AVAudioEngine` in offline/manual rendering mode. This is significantly more complex than playback pitch shifting and is deferred to a later phase. The export module's architecture should accommodate this addition without requiring changes to the core application.

### Interface Contract

The rest of the application hands the export module:
- A filtered set of `Sample` objects (from the search/filter system)
- An `ExportConfiguration` describing the export parameters

The export module produces files on disk in the specified shape. This clean boundary means export capabilities can be extended independently.

## UI Architecture

### Primary Views

The application uses a sidebar-detail layout as its primary navigation structure.

**Sidebar:**
- **Library** — the main sample browser (default view)
- **Inbox** — unprocessed files awaiting tagging (with badge count)
- **Tag Manager** — create, edit, and delete tag groups and tags

**Library View (detail pane):**
- A filterable, sortable table of samples showing key columns: name, key, tempo, tag summary, date imported
- **Default sort:** name ascending. Available sort options: name, key, tempo, date imported, tag count.
- **Filter bar** at top with text search field, metadata filter controls, and tag group filter sections. Tag groups are presented as collapsible sections within the filter area, each displaying its tags as toggles. This keeps the filter UI scannable even with many groups and tags, while making the OR-within-group / AND-across-group logic visually obvious (tags within a visible group are alternatives; separate groups are additive constraints).
- Multi-select support for batch operations
- Inline or panel-based audition controls (play, stop, scrub, pitch shift) for the selected sample

**Inbox View (detail pane):**
- Same table layout as the library view but filtered to unprocessed files only
- Metadata editing and tag application controls for selected files
- "Mark as Processed" action (single and batch)

**Sample Inspector:**
- A detail panel or sheet for viewing and editing a single sample's full metadata and tags
- Accessible from the library or inbox by selecting a sample

**Import Flow:**
- Modal or sheet-based flow triggered by drag-and-drop or the file picker
- Steps: file list confirmation, mode selection (quick-dump / detailed), per-file or batch tagging (detailed mode only), import execution

**Export Flow:**
- Modal or sheet triggered from the library view with a current selection or filter active
- Steps: review selected files, configure destination and folder structure, optional codebook inclusion, export execution

**Tag Manager:**
- List of tag groups, expandable to show tags within each group
- Create, rename, delete operations with confirmation for destructive actions
- Display of affected sample counts for rename/delete operations

### Keyboard Shortcuts

Common operations should have keyboard shortcuts to support efficient single-user workflow. Specific bindings will be determined during implementation, but the following operations should be keyboard-accessible at minimum:
- Play / pause / stop (e.g. Space, Escape)
- Pitch shift up / down (e.g. Up/Down arrows when audition is active)
- Import (e.g. Cmd+I)
- Delete (e.g. Cmd+Backspace)
- Mark as processed (e.g. Cmd+Return)
- Select all / deselect all (Cmd+A / Cmd+Shift+A)

### Batch Operations

Batch capability is a first-class concern, not an afterthought. The following operations must support multi-file selection:
- **Tagging:** additive by default — applying tags to a batch adds them to all selected samples without removing existing tags. A separate "remove tag" batch action strips specified tags.
- **Metadata editing:** replacement semantics — setting key on a batch overwrites any existing key on all selected samples. When selected files have mixed existing values, the UI should indicate this (e.g. "mixed" placeholder) and require explicit confirmation before overwriting.
- **Filename regeneration:** triggered automatically when metadata changes, but may also be invoked manually across the library (e.g. after a tag code rename).
- **Export:** selecting multiple files for export.
- **Import confirmation:** selecting/deselecting files before import.
- **Mark as processed:** batch-mark inbox files as processed.
- **Deletion:** batch-delete with confirmation.

## Undo

Batch operations that modify metadata or tags support undo. Because filenames are derived from database state, undoing a metadata or tag change automatically triggers a reverse filename regeneration — the filenames revert as a consequence of the data reverting, not as an independent operation.

The undo system captures the previous state of all affected samples before a batch operation executes, allowing the user to revert with Cmd+Z.

Scope for v1:
- Undo for batch tag application and removal
- Undo for batch metadata edits (key, tempo, name changes)
- Undo for "mark as processed" (batch and single)

File-level operations (import, export, delete) are not covered by the in-app undo system. Import and export are additive operations; deletion uses the system Trash for recovery. The undo stack is cleared when the application is quit.

### Undo and Filesystem Safety

When an undo operation triggers filename regeneration, it is possible for the OS-level rename to fail (e.g. permissions issue, disk full). If a rename fails during undo, the app should:
- Roll back the database change for the affected sample (keep it in its pre-undo state)
- Surface a clear error identifying which file(s) could not be renamed
- Leave successfully renamed files in their reverted state

This prevents a partial undo from leaving the database and filesystem out of sync.

## Rename Atomicity

Any operation that triggers filename regeneration across multiple files (batch metadata edits, tag code renames, undo) should follow a consistent pattern:
1. Capture the current state of all affected samples
2. Apply the database changes
3. Rename files on disk sequentially
4. If any rename fails: revert the database changes for the failed sample, surface the error, and continue processing remaining files

The goal is that each individual sample remains internally consistent (its database record matches its filename on disk) even if a batch operation partially fails. Successfully processed files in the batch are not rolled back.

## Architecture Notes

### Separation of Concerns

The application divides into five clear areas:
1. **Data layer** — SwiftData models, query/filter logic, undo state capture
2. **Import module** — file discovery, confirmation UI, vault copying, filename generation
3. **Audition module** — AVAudioEngine playback with pitch shifting
4. **Export module** — file selection, folder structure generation, codebook export
5. **Tag management** — CRUD operations on tags and tag groups, cascade handling

These should be kept reasonably decoupled so that changes to one area (particularly export, which will evolve) don't ripple through the rest.

### Performance

The library is expected to grow from ~100 files into the hundreds or low thousands. SwiftData with a local SQLite store handles this scale trivially. No special optimisation is needed at this scale, but queries should use predicates rather than loading the full dataset and filtering in memory.

### Error Handling

Key error scenarios to handle gracefully:
- Import of non-audio files (reject with clear feedback at confirmation stage)
- Filename length exceeding 255 characters (warn and suggest reducing tags or shortening name)
- Vault directory becoming unavailable (e.g. external drive disconnected)
- Import filename collisions (prompt user to rename, increment version, or skip)
- Missing vault files (sample exists in database but file is missing from disk — surface in UI rather than silently failing)
- Rename failure during batch operations or undo (see Rename Atomicity)

## Open Questions

- **Pitch-shifted export timeline:** When will downstream systems require rendered pitch-shifted files? This determines when the offline rendering pipeline is needed.
- **Export folder structures:** The specific folder grouping options for export may evolve as downstream system requirements become clearer. Phase one supports flat and single-tag-group grouping.
- **Undo depth:** How many operations should the undo stack retain? Initial implementation can use a simple single-level undo, expanding to multi-level if needed.
