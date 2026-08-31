# Changelog

All notable changes to Popperpig Raid Call.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed — the installer looked in the wrong folder

`scripts/install.sh` only ever probed the `_classic_` flavour directory, but the
Anniversary client installs to **`_anniversary_`**. Auto-detection therefore failed on a
normal Anniversary install, and the README pointed at the wrong path too, so following it
by hand put the addon somewhere the client never reads.

Detection is now generated from roots × flavours rather than a hand-written list of full
paths, with `_anniversary_` tried first and `_classic_` kept as a fallback. It prints
which flavour it matched. `_classic_era_` is still deliberately never picked — that is
Classic Era, a different client, and silently installing there is worse than failing to
detect.

### Black Temple rebuilt from cosmophile's guide

All nine encounters rewritten with **spell IDs and exact numbers**, plus the complete
trash route, per-boss assignment templates and WeakAura links. Both raids are now sourced,
so the `unverified` tag should not appear in normal play.

- **`/pprc route`** — the Black Temple trash path: numbered pulls matching the guide's own
  numbering, compositions, handling notes, and the skips flagged explicitly. "Which pack
  are we *not* pulling" is what goes wrong when half the raid has read the guide.
- **`/pprc wa`** — WeakAura links for the current encounter plus the general packs, so
  Shahraz's Fatal Attraction aura is in front of you on that pull.
- **Assignment templates** (`Data/Roles.lua`) drive a role list in the assignment panel —
  Illidan's flame tanks and their healers, Reliquary's five-deep tank order and interrupt
  rotation, the Council's four tanks including the mage. Encounters with roles but no
  diagram are now pushable; previously a push was refused for lack of a map.
- `brief` entries carry **`spellID`** — the first machine-checkable game data in the repo.

- **Positioning diagrams rebuilt** from the guide's own screenshots, so every Black Temple
  encounter now has a map — Bloodboil, Reliquary and the Council were naming layouts that
  did not exist, which rendered as a blank panel with no error. Akama gained one.
  **Illidan gets a layout per phase**: phase 2 is a kiting pattern, phase 4 is a 20-yard
  exclusion zone, and calling either off the phase 1 picture would put people in the wrong
  place. There is now a test that every `posmap` named anywhere resolves.
- Diagrams can draw a **line** as well as a ring — Gurtogg's soak line, which the three
  ranged groups rotate across, and the Eye Blast trail cutting through Illidan's phase 2.
- Two shapes I had invented lost to the guide: Teron had **four corners** where the guide
  draws **two drop points** at the top of the stairs, and Shahraz had four scatter spots
  where the guide has **two named stacks** (melee under the statue's hand, ranged under
  the fish statue).

Corrections the guide forced, roughly by cost:

- **Supremus**: it is **Hateful Strike (41926)**, not "Hurtful", and it hits whoever has
  the **most health** among 2nd/3rd on threat — a healthy DPS eats it whenever the offtank
  is low. Phases are a flat 60s and **threat drops returning to phase 1**.
- **Naj'entus**: popping the shield fires **Tidal Burst for 8,500 to the whole raid**. Hold
  the spine until everyone is above 8,501. The old data never mentioned the burst.
- **Akama**: add roles were backwards — Sorcerers **cannot be tanked**, the healers are
  **Spiritbinders**. Plus doorway tanks and the 60-second phase 2 window.
- **Illidan**: **Shear (41032)** cuts max health 60% and cannot miss; the counter is Shield
  Block, not the tank swap previously called for. **Draw Soul heals him 100k**.
  **Uncaged Wrath** was missing and is an instant wipe at 25 yards.
- **Shahraz**: tanks are **exempt** from shadow resistance. Saber Lash granting immunity to
  Fatal Attraction is why three tanks stack. "Prismatic Aura" was wrong twice over.
- **Council**: **Zerevor must be tanked by a mage** — the fight's defining setup, absent.
- **Bloodboil / Reliquary**: the soak rotation, Insignificance as a threat *snapshot*, and
  no threat table or healing in Reliquary phase 1.

Phase 5's Shadow Prison claim came from a web summary the guide does not corroborate, so
it is gone rather than kept on weaker evidence.

### Mount Hyjal rebuilt from a real raid-leader source

All 32 waves now carry their **exact compositions** from
[Jurdi's Mount Hyjal Cheat Sheet](https://www.twitch.tv/jurdijd), replacing compositions
that had been authored from recall and were largely wrong. Fel Hounds, Felstalkers,
Infernals and Crypt Fiends appear in the waves and had been missing entirely.

- **New pack panel** (`/pprc mobs`) — the mobs in the current wave with their abilities,
  kick and dispel flags and kill priority, sorted priority-first. `/pprc rules` prints the
  trash rules for the base you are on, including the Mind Control trick that drops combat
  without triggering the next wave.
- **Positioning diagrams rebuilt** from the sheet's screenshots, and they can now draw a
  labelled radius ring — Azgalor's 30-yard Rain of Fire circle and Kaz'rogal's 12-yard War
  Stomp radius, which are the two fights where "am I inside or outside" *is* the mechanic.
- **Provenance is now three-state.** `verified` still means the live client confirmed it;
  `source` means a cited document does. The HUD's `unverified` tag fires only when a step
  has neither, so Hyjal renders clean and Black Temple still flags. `/pprc debug` reports
  the split.

Boss corrections the sheet forced: Anetheron's **Vampiric Aura** (he heals 300% of melee
damage taken — healing debuffs are mandatory) was missing entirely, and Carrion Swarm cuts
healing by 75% rather than "halving" it; his Infernals are **not tauntable**. Kaz'rogal's
Malevolent Cleave is **23,000 split across targets and needs three tanks stacked** — the
old text told melee to stand behind him and dropped the requirement. Azgalor's Rain of Fire
**leaves a DoT that keeps ticking after you leave the fire**, which the sheet names as the
wipe cause. Archimonde's **Soul Charge** was absent: every death hits the raid for 4500 plus
a class-dependent effect.

It also corrected one of my own corrections — I had moved the 20-yard figure off Frost Nova
onto Death and Decay. Both are 20 yards. There is now a test for it.

### Fixed — read this one first

- **Kaz'rogal: the mana call was backwards.** The call board said *"SPEND YOUR MANA"* and
  the briefing told casters to spend down before the pull. Mark of Kaz'rogal detonates on
  **insufficient** mana — so following that button would have detonated a raid's entire
  caster core at once. It now says to keep mana up, pot and rune through it, and only run
  clear if you are about to bottom out. It also carries the hunter (Aspect of the Viper)
  and druid (Cat Form) outs. **If you ran an earlier build, tell your raid.**
- **Illidan's phases were structurally wrong.** Demon form was gated at 30%; it is not
  health-gated at all. Phases 3 and 4 alternate on a timer until 30%, and 30% starts phase
  5 with Maiev's traps, which are the actual burn window. Shadow Demons moved to demon form
  where they belong, and the checklist now asks for **capped** fire resistance on flame
  tanks rather than "where you have it". (The phase 5 detail was refined again when
  cosmophile's guide arrived — see above.)
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

NPC ids everywhere — neither guide lists them, and `/pprc scan` during a live clear is the
way to close that.

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
