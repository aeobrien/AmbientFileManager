# AmbientFileManager — Vision Statement

## What This Is

AmbientFileManager is a personal asset management system for organising, tagging, auditioning, and exporting ambient music files. It serves a growing library of audio samples created for live ambient sound bath performances, therapeutic music work, and other creative projects — currently approaching a hundred files and expected to keep growing.

The core problem it solves is this: as the library grows, it becomes increasingly difficult to know what you have, find what you need, and pull together the right collection of files for a specific purpose. Manual file management and mental tracking don't scale.

## What It Does

The system handles five core functions:

**Import and organise.** Audio files are brought into a managed vault through an import workflow. The system supports both quick-dump mode (get files in now, tag later) and detailed processing mode (tag on import). Files in the vault live in a flat folder structure — all organisational intelligence lives in metadata and filenames, not folder hierarchy. This avoids the rigidity of nested folders, which can only express one organisational dimension at a time, while the tagging system is inherently multi-dimensional. An inbox mechanism tracks files that still need attention (see below).

**Tag and describe.** Every file carries a small set of fixed properties — name, musical key, tempo, and version number — plus a flexible tagging system for everything else. Emotional qualities, instrumentation, project-specific groupings, section markers, and any other categorisation all live in tags. Tags are organised into named groups (e.g., a "Sound Bath" group containing section tags like Arrival and Calm, or a "Generative App" group with its own vocabulary). Tags from any group can be applied to any file. The tagging system is the primary extensibility mechanism: adding a new tag group or tag is trivial and requires no structural changes. As the creative practice evolves, the tagging vocabulary evolves with it.

**Browse, search, and filter.** The library can be browsed, searched, and filtered so that finding the right files is fast and intuitive. Users can search by name and tag, filter by any combination of metadata (key, tempo) and tags, and combine multiple filter criteria (e.g., "all files in Cmaj tagged with both SB-AR and AF-BR"). Filters should compose naturally — narrowing progressively as criteria are added — so that building a specific selection feels fluid rather than mechanical.

**Audition.** Files can be played back directly within the system so you can confirm what you're looking at without leaving the app. Files can also be auditioned at different pitches via simple playback speed manipulation, shifted by semitone increments. This is not time-stretched pitch shifting — it's basic sample rate adjustment, meaning playback speed changes proportionally with pitch. Note that this technique may produce audible artifacts on compressed audio formats (MP3, M4A); lossless formats (WAV, AIFF) are unaffected.

**Export.** Files can be exported as collections for use by other systems. This means selecting a set of files based on tags or other criteria and exporting them with configurable folder structure. Files are exported in their original format; format conversion is deferred to a later phase. The system doesn't need to know what the downstream consumer is — it just needs to produce the right files in the right shape.

### The Inbox

The inbox is the landing zone for quick-dump imports. Any file imported without full metadata and tagging lands here automatically. The inbox is a dedicated view that surfaces all unprocessed files, making it easy to see what still needs attention and work through it in batches. Processing a file means assigning its metadata and tags, at which point it leaves the inbox and joins the main library. Partial processing is allowed — a file can be tagged incrementally over multiple sessions, and the user explicitly marks it as processed when satisfied. The system imposes no minimum completeness rules — a file can be marked as processed with as little or as much metadata as the user sees fit.

### Pitch-Shifted Export

Export may include pitch-shifted variants rendered as new audio files on disk. For example, exporting a drone at its original pitch plus versions at +2 and -3 semitones would produce three separate files. This is a significant feature that requires offline audio rendering and is deferred to a later phase. It is not required for initial completion.

## What It Isn't

This is not a DAW, an audio editor, or a performance tool. It doesn't handle mixing, effects processing, sequencing, or real-time playback of multiple files. It doesn't know about the internal structure of any particular project — it doesn't understand sound bath sections or performance set constraints. All domain-specific knowledge lives in the tagging system, configured by the user.

It is also not the generative music system. That is a separate project. This system may feed files into it, but the two are decoupled.

## Guiding Principles

**Portability through filenames.** Metadata is encoded into filenames using short hierarchical codes so that organisational information travels with the file. If the database disappears, the filenames alone should communicate key properties of each file to a human reader. This is a pragmatic resilience measure, not full recoverability — the filenames are designed for human readability, not guaranteed machine parsing. The tag codes are only meaningful if you know the codebook, so the system should be able to export a reference file listing all tag groups and codes alongside the vault. This operates within the 255-character filename limit.

**Flexibility over structure.** The system should never impose a fixed organisational scheme. Tags, tag groups, and their associated codes are user-defined and can be added, renamed, or restructured at any time. The creative practice is evolving and the system must evolve with it.

**Low friction.** Every interaction should respect the reality that managing hundreds of files is tedious. Batch operations are essential — tagging, renaming, exporting should all work on multiple files at once. The import workflow should make it easy to dump files in quickly and process them later. Common operations should be keyboard-accessible. The system should reduce organisational overhead, not create it.

**Simplicity.** The underlying concept is straightforward — database and file management with audio playback. The implementation should stay proportional to that. Resist feature creep toward audio workstation territory.

## Scope and Constraints

The initial library is approaching 100 files. The system should handle growth comfortably into the hundreds or low thousands without performance issues.

Most files are free-time (no fixed tempo), but some have fixed tempos that need tracking. Key signature is relevant for most files.

The filename encoding system uses 2-3 character hierarchical codes. The specific coding scheme is defined in the technical brief.

The system serves one user. There are no collaboration, sharing, or multi-user requirements.

## Definition of Done

The system is complete when it can:
- Import audio files into a managed vault, renaming them automatically with encoded metadata
- Track and surface unprocessed files in a dedicated inbox view
- Apply and manage user-defined tags organised into named groups
- Filter and search the library by name, tags, metadata, and any combination thereof
- Browse the full library with sorting and filtering in a clear, navigable interface
- Play back any file within the application
- Audition files at pitch-shifted intervals via playback speed adjustment
- Export filtered selections of files to a chosen directory with configurable folder structure, encoded filenames, and optional codebook reference file
- Delete files from the vault
- Perform all tagging, renaming, and export operations in batch
- Undo batch operations that modify metadata or rename files

**Example workflow:** Before a sound bath performance, open the app, filter by the SB-AR tag in Cmaj, audition three candidates to confirm they're right, select them, and export to a folder — all within a couple of minutes and without leaving the application.
