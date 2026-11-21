# Audition

## Overview

In-app audio playback with pitch shifting via sample rate adjustment (AVAudioEngine + AVAudioUnitVarispeed). Allows auditioning files at different pitches without leaving the app.

## Status

**Current state:** In progress
**Last updated:** 2026-04-03

## Components

| Component | Role | Part Number | Ref |
|-----------|------|-------------|-----|
| AudioPlayer.swift | AVAudioEngine playback wrapper | — | Services/AudioPlayer.swift |
| AudioPlayerView.swift | Transport controls and pitch shift UI | — | Views/Audition/AudioPlayerView.swift |

## Connections

| Connects To | Interface | Notes |
|-------------|-----------|-------|
| Library & Search | Selected sample | Plays the currently selected sample |
| Inbox & Processing | Selected sample | Can also audition from inbox |
| Data Layer | Vault file path | Reads audio files from vault directory |

## Design Notes

Audio chain: AVAudioPlayerNode -> AVAudioUnitVarispeed -> output. Pitch shifted in semitone increments: rate = 2^(semitones/12). This is sample-rate shifting, not time-stretched pitch correction — speed changes proportionally with pitch.

Transport: play, pause, stop, scrub. Pitch offset displayed as semitone count (e.g. "+2", "-3", "0"). Engine stopped when not playing to avoid resource waste.

Compressed formats (MP3, M4A) may exhibit audible artifacts when pitch-shifted — expected behaviour.

## Open Questions

- None currently
