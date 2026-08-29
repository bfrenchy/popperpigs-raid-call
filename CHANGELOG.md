# Changelog

All notable changes to Popperpig Raid Call.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed — read this one first

- **Kaz'rogal: the mana call was backwards.** The call board said *"SPEND YOUR MANA"* and
  the briefing told casters to spend down before the pull. Mark of Kaz'rogal detonates on
  **insufficient** mana — so following that button would have detonated a raid's entire
  caster core at once. It now says to keep mana up, pot and rune through it, and only run
  clear if you are about to bottom out. It also carries the hunter (Aspect of the Viper)
  and druid (Cat Form) outs. **If you ran an earlier build, tell your raid.**
- **Illidan's phases were structurally wrong.** Demon form was gated at 30%; it is not
  health-gated at all. Phases 3 and 4 alternate on a timer until 30%, and 30% starts phase
  5 — Shadow Prison stunning the raid for ~30s, then Maiev's Shadow Traps, which are the
  actual burn window. Shadow Demons moved to demon form where they belong, and the
  checklist now asks for **capped** fire resistance on flame tanks rather than "where you
  have it".
- **Naj'entus: the spine call addressed the wrong person.** The impaled player is stunned
  and cannot free themselves. A nearby raider clicks the spine, and *that* raider receives
  the throwable one.
- **Rage Winterchill specifics.** The 20-yard figure belongs to Death and Decay, not Frost
  Nova; Frost Armor is +3000 armor, +75 frost resistance and a 25%/50% melee slow, not
  just "slower threat".

### Added

- The HUD now shows an **unverified** tag on any step whose data has not been confirmed
  against a live client, so a wave composition is never mistaken for settled fact.
- Regression tests pinning the above: a tripwire that fails if the Kaz'rogal reversal ever
  returns in any of its plausible phrasings, and an Illidan test asserting that exactly two
  transitions are health-gated and demon form is not one of them.

### Still unverified

Wave-by-wave compositions across all 32 Hyjal waves remain unconfirmed and are pending a
raid-leader source. The mob roster is known to be incomplete — Crypt Fiends, Deathknights,
Shades, Felguards and Infernals all appear in the waves and are missing from the data.

---

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
