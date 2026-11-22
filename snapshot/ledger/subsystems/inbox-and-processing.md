# Inbox & Processing

## Overview

Dedicated view for unprocessed files (quick-dump imports). Allows assigning metadata and tags incrementally, then marking files as processed to move them into the main library.

## Status

**Current state:** In progress
**Last updated:** 2026-04-03

## Components

| Component | Role | Part Number | Ref |
|-----------|------|-------------|-----|
| InboxView.swift | Inbox table and processing UI | — | Views/Inbox/InboxView.swift |

## Connections

| Connects To | Interface | Notes |
|-------------|-----------|-------|
| Data Layer | isProcessed flag | Filters to isProcessed==false |
| Import & Filename Encoding | Quick-dump imports | New unprocessed files land here |
| Library & Search | Processed files | Marking as processed moves files to library |

## Design Notes

Same table layout as library but filtered to unprocessed files. Sidebar badge shows unprocessed count. No minimum completeness rules — user decides when a file is "done." Batch mark-as-processed supported. All metadata changes trigger filename regeneration.

## Open Questions

- None currently
