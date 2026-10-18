# Decision Log

Decisions are recorded when there was a genuine choice between alternatives. Routine implementation details do not need entries.

| # | Date | Decision | Alternatives | Rationale | Impacts |
|---|------|----------|-------------|-----------|---------|
| 1 | 2026-03-25 | Version numbers are strictly semantic, not collision-avoidance | Auto-increment on collision | Prevents confusion between real variants and filesystem bookkeeping | Import workflow |
| 2 | 2026-03-25 | AVAudioEngine + AVAudioUnitVarispeed for playback | AVAudioPlayer.rate | AVAudioPlayer.rate does time-pitch correction, not sample-rate shifting | Audition |
| 3 | 2026-03-25 | Tags are the extensibility mechanism, not dynamic schema | Dynamic metadata fields | Fixed metadata + flexible tags is simpler and covers all use cases | Data Layer |
| 4 | 2026-03-25 | Filenames are human-readable, not machine-parseable | Machine-parseable filenames | Pragmatic resilience; full recovery from filenames alone is not supported in v1 | Import, Export |
| 5 | 2026-03-25 | Deletion uses system Trash, not hard delete | Hard delete | Provides recovery window without building in-app trash | Library |
| 6 | 2026-03-25 | Export codebook includes full vocabulary | Export-specific codes only | More useful; the codebook is a reference for the entire library | Export |
| 7 | 2026-03-25 | Multi-tag folder grouping resolved by alphabetical first | Duplicate files into each folder | Simple, deterministic, no file duplication | Export |
| 8 | 2026-03-25 | Single-level undo for v1 | Multi-level undo | Keeps implementation simple; expand if needed | Batch Operations & Undo |
| 9 | 2026-03-25 | Text search covers sample names and tag names | Sample names only | Users expect "Arrival" to find tagged files, not just named ones | Library & Search |
