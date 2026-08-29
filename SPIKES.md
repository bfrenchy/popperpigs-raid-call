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
| S2 | Does Hyjal's world state expose a wave *number*, or only enemies remaining? | **self-resolving** | Answers itself. `Core/Detect.lua` classifies each world-state number by behaviour over 3+ updates and reports the tier. |
| S3 | Do `boss1`–`boss5` exist? Does `ENCOUNTER_START` fire? | **self-resolving** | Answers itself. `ENCOUNTER_START` is probed with `pcall` at load; boss tokens resolve lazily on the first real encounter. |
| S4 | Can an addon call `SetRaidTarget()` with assist, in and out of combat? | **not run** | Fallback already shipped: `PosMap:ApplyMarks` reports failures and prints a macro to use instead. |
| S5 | Is `C_ChatInfo.SendAddonMessage` present? Is `RAID` valid? | **self-resolving** | Probed at load. `/pprc debug` prints `C_ChatInfo`, `global`, or `none`. Legacy global is the coded fallback. |
| S6 | `SendChatMessage` RAID_WARNING throttle ceiling | **not run** | The limiter ships regardless at 1 message / 1.5s. Only tighten it if a real disconnect is seen. |
| S7 | How often is `UnitGroupRolesAssigned` actually `NONE` in a PUG? | **observational** | Handled by display, not detection: an unset role renders as `— unset —` and is never inferred from class. |

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
