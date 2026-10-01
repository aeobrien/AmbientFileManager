# Tag Management

## Overview

CRUD interface for tag groups and tags. Enforces code uniqueness, handles cascade deletion, and triggers filename regeneration when codes are renamed.

## Status

**Current state:** In progress
**Last updated:** 2026-04-03

## Components

| Component | Role | Part Number | Ref |
|-----------|------|-------------|-----|
| TagManagerView.swift | Main tag management UI | — | Views/TagManager/TagManagerView.swift |
| TagGroupFormSheet.swift | Create/edit tag group form | — | Views/TagManager/TagGroupFormSheet.swift |
| TagFormSheet.swift | Create/edit tag form | — | Views/TagManager/TagFormSheet.swift |

## Connections

| Connects To | Interface | Notes |
|-------------|-----------|-------|
| Data Layer | SwiftData models | Creates/edits TagGroup and Tag entities |
| Import & Filename Encoding | Code rename cascade | Code renames trigger filename regeneration for affected samples |
| Library & Search | Tag filters | Tags appear as filter criteria in the library |

## Design Notes

Codes are 2-3 alphanumeric characters. Group codes must be globally unique; tag codes must be unique within their group. Renaming a code triggers filename regeneration for all affected samples with a confirmation warning showing the count. Deleting a group cascades to delete all its tags.

## Open Questions

- None currently
