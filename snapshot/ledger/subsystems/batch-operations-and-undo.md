# Batch Operations & Undo

## Overview

Multi-file batch operations for tagging and metadata editing, with an undo system that reverts both database changes and resulting filename regenerations. Includes rename atomicity for partial failure handling.

## Status

**Current state:** In progress
**Last updated:** 2026-04-03

## Components

| Component | Role | Part Number | Ref |
|-----------|------|-------------|-----|
| BatchOperations.swift | Batch operation logic and undo state | — | Services/BatchOperations.swift |
| BatchOperationsPanel.swift | Batch action UI controls | — | Views/Library/BatchOperationsPanel.swift |

## Connections

| Connects To | Interface | Notes |
|-------------|-----------|-------|
| Library & Search | Multi-selection | Selected samples are targets for batch ops |
| Data Layer | SwiftData models | Reads/writes sample metadata and tags |
| Import & Filename Encoding | FilenameEncoder | Triggers filename regeneration after changes |

## Design Notes

Batch tagging is additive (adds tags without removing existing ones). Batch metadata editing is replacement (overwrites, with "mixed values" warning). Rename atomicity: capture state, apply DB changes, rename files sequentially; if a rename fails, revert that sample's DB change, surface error, continue with remaining files.

Undo captures pre-operation state. Cmd+Z reverts data + filenames. Single-level undo for v1. Stack cleared on quit. If reverse rename fails during undo, roll back DB for affected sample only.

## Open Questions

- Multi-level undo: expand if single-level proves insufficient
