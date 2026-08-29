# Spikes

Runtime questions about the 2.5.6 client, and what we found.

**None of these block development.** Every uncertain capability has both branches coded
behind `Core/Adapter.lua`, so a spike confirms which tier went active and lets the dead
branch be deleted with evidence — it does not unlock the work.

Record results against a build number. `/pprc debug` prints the resolved tier for every
chain; `/pprc scan` prints the raw values.

---

## Status

| # | Question | Status | Result |
| --- | --- | --- | --- |
| S1 | Does `UnitPosition` return coordinates for raid units inside an instance? | **not run** | Expected no. Nothing depends on it — the plan already assumes static diagrams, and `UI/PosMap.lua` draws from fixed coordinates. |
| S2 | Does Hyjal's world state expose a wave *number*, or only enemies remaining? | **self-resolving — evidence for tier 1** | Answers itself at runtime. Guides describe a wave counter that, after wave 8, is *replaced* by a display reading **"Invading Enemies = 1"** — which reads as a genuine wave counter (classifier tier 1) rather than an enemies-remaining count. Confirm in game; see the note below. |
| S3 | Do `boss1`–`boss5` exist? Does `ENCOUNTER_START` fire? | **self-resolving** | Answers itself. `ENCOUNTER_START` is probed with `pcall` at load; boss tokens resolve lazily on the first real encounter. |
| S4 | Can an addon call `SetRaidTarget()` with assist, in and out of combat? | **not run** | Fallback already shipped: `PosMap:ApplyMarks` reports failures and prints a macro to use instead. |
| S5 | Is `C_ChatInfo.SendAddonMessage` present? Is `RAID` valid? | **self-resolving** | Probed at load. `/pprc debug` prints `C_ChatInfo`, `global`, or `none`. Legacy global is the coded fallback. |
| S6 | `SendChatMessage` RAID_WARNING throttle ceiling | **not run** | The limiter ships regardless at 1 message / 1.5s. Only tighten it if a real disconnect is seen. |
| S7 | How often is `UnitGroupRolesAssigned` actually `NONE` in a PUG? | **observational** | Handled by display, not detection: an unset role renders as `— unset —` and is never inferred from class. |

---

## Note on S2 — "Invading Enemies = 1"

Multiple guides state that once the eighth wave dies, the wave counter disappears and is
replaced by a display reading `Invading Enemies = 1`, roughly a minute before the boss
reaches the base.

Two consequences if that holds in 2.5.6:

1. It is evidence the counter really does count **waves up**, not enemies down, which is
   the classifier's tier 1 and the best case for `Core/Detect.lua`.
2. The *disappearance* of the counter is itself a boss-incoming signal, about a minute of
   warning. Nothing uses that yet. It would be a natural addition to the encounter
   boundary chain — but only after `/pprc scan` confirms the world state actually behaves
   this way, rather than on the strength of a guide.

---

## Provenance — how the current data was checked

Read this before trusting anything below as settled.

The correction pass in this repo was done **without access to primary sources**. The
environment's egress proxy blocks wowhead, warcraft.wiki.gg, warcrafttavern, icy-veins and
every comparable site, for both direct fetches and the agent's page reader. Everything was
established from **search-engine summaries** of those pages.

That is strong enough to prove something is wrong — it caught a reversed Kaz'rogal call
and a structurally wrong Illidan phase model — and mostly strong enough to establish what
is right. But it is second-hand, and on the wave structure two summaries flatly
contradicted each other before a third settled it.

So: the boss mechanics have been corrected and are believed accurate, but they carry
`verified = false` for the same reason everything else does. **Confirmed in game beats
confirmed by search.** Flip the flags only from a live clear.

---

## Recording a result

After a raid night with `/pprc debug` on:

```
### <date> — build 2.5.6 (<build number from /pprc debug>)

S2: wave chain resolved to <tier 1 / tier 2 / tier 3>
    world state slot <n>, raw values: <paste from /pprc scan>

S3: boss tokens <present / absent>
    ENCOUNTER_START <registers / does not register>

S5: addon messaging via <C_ChatInfo / global>
```

Then delete the branch that turned out to be dead — with evidence, not a guess.

---

## Data corrections

Everything in `Data/` ships as `verified = false`. `/pprc scan` prints every NPC id seen
with its creature name and flags the ones missing from `Data/`.

Paste those here as they are confirmed, then update the data files and flip the flag:

```
### NPC ids confirmed — build 2.5.6

  17767   Rage Winterchill          in Data/     confirmed
  99999   Some Trash Mob            NOT IN Data/ -> add to Data/Hyjal.lua
```

Black Temple trash is the weakest area. Packs whose id is unknown deliberately carry no
`npcIDs` at all rather than a guess — a wrong id surfaces the wrong card mid-pull, while
an unkeyed pack simply means the RL clicks Next, which always works. **Fill those in from
a real scan, not from memory.**

Buff names in `Data/Consumables.lua` are worth confirming too: a wrong name shows as a
false negative on the readiness board. `/pprc scan` includes your own current buffs with
their exact names.
