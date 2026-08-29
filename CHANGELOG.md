# Changelog

All notable changes to Popperpig Raid Call.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

First complete build: M0 through M7 of the technical plan.

### Added

- **NOW / NEXT HUD.** The current step and the one after it, so a mechanic can be called
  before it lands rather than after. Full controls for lead and assist, a compact
  read-only strip for everyone else.
- **Mount Hyjal** — 5 encounters, all 32 waves, with the words to say on each.
- **Black Temple** — 9 encounters, phase-driven, plus named trash packs.
- **Detection.** Instance identity, a self-classifying wave counter, NPC-id harvesting
  from the combat log, and boss-health phase thresholds. Every chain terminates in manual
  control, which always works.
- **Call board.** One click, one sentence, out to the raid. Per-step calls come from the
  encounter data; the standing set is always there. Calling a wipe needs a second click.
- **Rate limiter.** 1 chat message per 1.5s hard cap, addon traffic on its own budget.
  Nothing is ever dropped silently.
- **Readiness board.** Flask, food, alive, in range and soulstones at a glance, with a
  click-to-whisper offender list and a one-line announcement. Doubles as wipe recovery.
- **Assignments and briefings.** Live roster, positions dropped onto a room diagram,
  pushed to the raid. Each raider sees only their own slot.
- **Sync.** State, assignments and briefings shared across the raid, with permission
  verified on receive and late joiners catching themselves up.
- **Profile export string**, so assignments can be handed to someone else.
- `/pprc scan`, which prints the raw world state and every NPC id seen — the tool for
  correcting `Data/` from a real raid night.

### Notes

- **No external libraries.** No Ace3, no LibDeflate. Fewer taint surfaces and nothing to
  fetch.
- **All game data ships unverified.** Wave compositions, NPC ids and spell details were
  authored from knowledge rather than read off a live 2.5.6 client. `/pprc debug` counts
  what is still unconfirmed. See [SPIKES.md](SPIKES.md).
- Positioning diagrams are drawn at runtime from coordinate tables rather than from TGA
  textures, so they scale with the frame and a correction is a coordinate edit.
