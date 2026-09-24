# AmbientFileManager — Ledger

> A personal asset management system for organising, tagging, auditioning, and exporting ambient music files on macOS.

## Status

**Lane:** personal
**Phase:** Prototyping
**Last updated:** 2026-04-03

## Subsystems

| Subsystem | Status | Doc |
|-----------|--------|-----|
| Data Layer | In progress | [link](subsystems/data-layer.md) |
| Tag Management | In progress | [link](subsystems/tag-management.md) |
| Import & Filename Encoding | In progress | [link](subsystems/import-and-filename-encoding.md) |
| Library & Search | In progress | [link](subsystems/library-and-search.md) |
| Inbox & Processing | In progress | [link](subsystems/inbox-and-processing.md) |
| Audition | In progress | [link](subsystems/audition.md) |
| Batch Operations & Undo | In progress | [link](subsystems/batch-operations-and-undo.md) |
| Export | In progress | [link](subsystems/export.md) |

## Key Decisions

See [decisions/LOG.md](decisions/LOG.md) for the full decision log.

## Open Questions

- Pitch-shifted export timeline: when will downstream systems require rendered pitch-shifted files?
- Export folder structure options may evolve as downstream system requirements become clearer
- Undo depth: single-level for v1, expand to multi-level if needed

## Notes

Project uses a 9-phase roadmap (see ROADMAP.md). Code exists across all major subsystems but no phases have been formally tested and signed off yet. Tag persistence bug was fixed on 2026-04-02 (missing model container and no explicit saves).
