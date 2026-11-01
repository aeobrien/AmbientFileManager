# Import & Filename Encoding

## Overview

Handles importing audio files into the vault via drag-and-drop or file picker, in quick-dump or detailed mode. Generates deterministic encoded filenames from sample metadata and tags.

## Status

**Current state:** In progress
**Last updated:** 2026-04-03

## Components

| Component | Role | Part Number | Ref |
|-----------|------|-------------|-----|
| ImportFlowView.swift | Import confirmation and mode selection UI | — | Views/Import/ImportFlowView.swift |
| FilenameEncoder.swift | Generates encoded filenames from metadata | — | Services/FilenameEncoder.swift |
| FilenameDecoder.swift | Parses encoded filenames back to metadata | — | Services/FilenameDecoder.swift |

## Connections

| Connects To | Interface | Notes |
|-------------|-----------|-------|
| Data Layer | Sample creation | Creates Sample records with metadata |
| Tag Management | Tag application | Detailed mode allows tagging on import |
| Inbox & Processing | isProcessed flag | Quick-dump sets isProcessed=false, detailed sets true |
| Library & Search | New samples appear | Processed imports visible immediately in library |

## Design Notes

Filename format: `{Name}_{Key}_{Tempo}bpm_{TagCodes}_{Version}.{ext}`. Tag codes sorted alphabetically for determinism. Nil fields omitted. Names sanitised to alphanumeric + hyphens only. 255-character limit validated.

Supported formats: WAV, AIFF, MP3, M4A, CAF, FLAC. Files are copied into the vault, never moved. Original filename preserved on the Sample record.

Duplicate handling prompts user to rename, increment version, or skip — never auto-increments.

## Open Questions

- None currently
