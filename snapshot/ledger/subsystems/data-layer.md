# Data Layer

## Overview

SwiftData models and persistence for the core entities: Sample, TagGroup, and Tag. Provides the schema, relationships, and query/filter infrastructure that all other subsystems depend on. Includes vault directory configuration and storage.

## Status

**Current state:** In progress
**Last updated:** 2026-04-03

## Components

| Component | Role | Part Number | Ref |
|-----------|------|-------------|-----|
| Sample.swift | Core audio file entity | — | Models/Sample.swift |
| Tag.swift | Individual tag entity | — | Models/Tag.swift |
| TagGroup.swift | Tag group entity | — | Models/TagGroup.swift |
| KeyHelper.swift | Musical key definitions | — | Models/KeyHelper.swift |
| VaultManager.swift | Vault directory file operations | — | Services/VaultManager.swift |

## Connections

| Connects To | Interface | Notes |
|-------------|-----------|-------|
| Tag Management | SwiftData relationships | TagGroup → Tag one-to-many, Tag → Sample many-to-many |
| Import & Filename Encoding | Sample creation | Import creates Sample records in the database |
| Library & Search | SwiftData predicates | FilterState generates predicates against the schema |
| All subsystems | ModelContainer | Shared container configured at app entry point |

## Design Notes

Three core entities: Sample (audio file record), TagGroup (named collection of related tags), Tag (individual tag). Tags from any group can be applied to any sample — group membership organises the UI, not the data.

Vault is a single flat directory on disk. Location is user-configured and stored in UserDefaults. Files are always copied into the vault on import.

SwiftData backed by SQLite. All queries use `#Predicate` macros rather than loading all records and filtering in memory.

Tag persistence bug was fixed on 2026-04-02 — tags were disappearing due to missing model container configuration and no explicit saves.

## Open Questions

- Schema migration strategy once the app reaches stable state
