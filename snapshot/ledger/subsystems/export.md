# Export

## Overview

Exports filtered selections of files to a user-chosen directory with configurable folder structure (flat or tag-based grouping) and optional codebook reference file.

## Status

**Current state:** In progress
**Last updated:** 2026-04-03

## Components

| Component | Role | Part Number | Ref |
|-----------|------|-------------|-----|
| ExportService.swift | Export orchestration | — | Services/ExportService.swift |
| ExportFlowView.swift | Export configuration UI | — | Views/Export/ExportFlowView.swift |

## Connections

| Connects To | Interface | Notes |
|-------------|-----------|-------|
| Library & Search | Filtered selection | Receives samples from current filter/selection |
| Data Layer | Tag vocabulary | Codebook export reads all tag groups and tags |
| Tag Management | Tag groups | Tag-based folder grouping uses tag group structure |

## Design Notes

ExportConfiguration: destinationPath, folderGrouping (.flat or .byTagGroup), includeCodebook. Files exported in original format — no format conversion in v1. Multi-tag ambiguity resolved alphabetically (first tag in grouping group). Samples with no matching tag go to "Ungrouped" folder. Codebook.json contains full vocabulary, not just tags used in the export.

Pitch-shifted export (rendering new audio files at different pitches) is deferred to a later phase. Will require offline AVAudioEngine rendering.

## Open Questions

- Pitch-shifted export timeline depends on downstream system requirements
- Folder structure options may evolve as needs become clearer
