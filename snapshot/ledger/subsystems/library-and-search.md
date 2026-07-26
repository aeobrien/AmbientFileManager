# Library & Search

## Overview

The main library browser — a filterable, sortable table of all samples with text search, metadata filters, and tag filters. The primary view the user interacts with.

## Status

**Current state:** In progress
**Last updated:** 2026-04-03

## Components

| Component | Role | Part Number | Ref |
|-----------|------|-------------|-----|
| LibraryView.swift | Main library table and filter UI | — | Views/Library/LibraryView.swift |
| SampleInspectorView.swift | Detail panel for selected sample | — | Views/Library/SampleInspectorView.swift |

## Connections

| Connects To | Interface | Notes |
|-------------|-----------|-------|
| Data Layer | SwiftData predicates | FilterState generates compound predicates |
| Tag Management | Tag filters | Tags appear as toggleable filter criteria |
| Audition | Selected sample | Currently selected sample can be played |
| Batch Operations & Undo | Multi-selection | Selected samples are targets for batch ops |
| Export | Filtered selection | Current filter/selection feeds into export |

## Design Notes

Filter composition: text search + metadata filters + tag filters, all combined with AND logic. Tag filters use OR within a group, AND across groups. FilterState is an observable object that generates SwiftData predicates. Table updates in real time as filters change.

Sort options: name, key, tempo, date imported. Default sort: name ascending.

## Open Questions

- None currently
