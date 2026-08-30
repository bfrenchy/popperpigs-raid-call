# Popperpig Raid Call

A raid-leader command surface for TBC Classic Anniversary (2.5.6, `Interface: 20506`),
covering Mount Hyjal and Black Temple.

Not a boss mod. A Hyjal boss dies in three minutes; the twenty minutes around it —
forming, checking flasks, explaining a mechanic, assigning corners, recovering from a
wipe, rebuffing, re-pulling — is where the raid leader actually spends the evening.
Boss mods own the three minutes. This owns the twenty.

| Phase of the night | Who owns it |
| --- | --- |
| Trash and waves | **Popperpig Raid Call** |
| Pre-pull readiness | **Popperpig Raid Call** |
| Pre-pull briefing and positions | **Popperpig Raid Call** |
| In-fight ability timers | DBM / BigWigs — *not us* |
| What the RL says out loud | **Popperpig Raid Call** |
| Wipe recovery | **Popperpig Raid Call** |
| Loot | RCLootCouncil / CLM — *not us* |

**Scope rule, enforced throughout.** Anything with a countdown to an incoming ability
belongs to DBM. Anything involving loot belongs to RCLootCouncil. This addon never draws
in DBM's bar zone and never touches loot.

---

## Installing

The repository directory is `popperpigs-raid-call`, but the in-game folder must be
`PopperpigRaidCall` to match the `.toc`. Getting that wrong is the usual reason an addon
silently fails to appear, so there is a script:

```bash
scripts/install.sh                    # auto-detect, copy
scripts/install.sh --link             # auto-detect, symlink — edit in place
scripts/install.sh "/path/to/AddOns"  # explicit target
```

`--link` is the one to use while developing: edit in the repo, `/reload` in game.

**Where the AddOns folder is.** TBC Anniversary runs out of the `_classic_` flavour
directory. `_classic_era_` is Classic Era, a different client — installing there means
the addon never appears and nothing explains why.

- Windows — `C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\`
- macOS — `/Applications/World of Warcraft/_classic_/Interface/AddOns/`

If your launcher shows a different flavour for Anniversary, use whichever it actually
launches. To install by hand, copy `PopperpigRaidCall.toc`, `Core/`, `Data/` and `UI/`
into a folder named exactly `PopperpigRaidCall`.

### Smoke test, in order

1. Enable **Popperpig Raid Call** at character select. Tick *Load out of date AddOns* if
   the client flags the interface version.
2. `/pprc debug` — prints the capability table. **Zero Lua errors here is the bar.** It
   also names which detection tier went active for each chain.
3. `/pprc test hyjal_winterchill` — walks all 8 waves solo, no raid or instance needed.
   This covers roughly 80% of the logic including all of the UI.
4. Drag the HUD somewhere you like, `/reload`, confirm it stayed put.
5. `/pprc echo` — **run the first live night this way.** Calls print to your own chat
   frame and go nowhere near the raid, so a bug cannot spam 24 people.
6. Two-box when you have a second account: one takes lead, check the sync dot goes green,
   then `/reload` the non-leader and confirm they catch back up.

---

## Commands

| Command | Does |
| --- | --- |
| `/pprc` | Toggle the HUD |
| `/pprc test <encounter>` | Walk an encounter solo. No argument lists them all |
| `/pprc stop` | Leave test mode |
| `/pprc next` · `/pprc back` | Advance or rewind a step |
| `/pprc board` | Call board |
| `/pprc mobs` | Pack breakdown for the current wave — abilities, kicks, dispels, kill priority |
| `/pprc rules` | Trash rules for the base you are on |
| `/pprc ready` | Readiness board |
| `/pprc assign` | Assignment panel |
| `/pprc brief` | Pre-pull briefing |
| `/pprc config` | Settings, including the profile export string |
| `/pprc echo` | Local echo — nothing reaches the raid |
| `/pprc say <text>` | One line through the throttle |
| `/pprc check` | Readiness summary, one line |
| `/pprc sync` | Who is running it, and who is out of date |
| `/pprc debug` | Capability table, active detection tiers, unverified data count |
| `/pprc scan` | Live world state and every NPC id seen — the data-correction tool |
| `/pprc log` | Recent debug log |
| `/pprc lock` · `/pprc reset` | Frame dragging and positions |

---

## About the data

Data carries its provenance, in three states:

| State | Means | HUD |
| --- | --- | --- |
| `verified = true` | Confirmed against the live 2.5.6 client | clean |
| `source = "..."` | A cited document says so | clean |
| neither | Authored from knowledge, unbacked | `unverified` tag |

**Mount Hyjal comes from [Jurdi's Mount Hyjal Cheat Sheet](https://www.twitch.tv/jurdijd)**
— all 32 waves at exact mob counts, per-mob abilities, boss numbers and the positioning
diagrams, transcribed with credit. That is a raid-tested document rather than a guide
summary, so those steps carry `source = "jurdi"` and render clean. It is still not the same
claim as "the game confirmed it", which is why `verified` stays false and `/pprc scan`
remains the way to close that last gap.

**Black Temple is still unbacked** and says so on every step. Its boss mechanics went
through a research pass that found real errors — including an Illidan phase model that was
structurally wrong — but that ran on search-engine summaries rather than primary sources.
See [SPIKES.md](SPIKES.md) for the provenance and its limits.

NPC ids are unconfirmed everywhere, including Hyjal: they are not in the cheat sheet.

Black Temple trash ids are the least confident of all. Packs whose id could not be stood
behind carry **no** npcIDs rather than a plausible-looking guess: an unkeyed pack means
the RL clicks Next, which always works, while a wrong id would surface the wrong card
mid-pull.

`/pprc scan` is the correction path. It prints the raw world-state returns and every NPC
id seen with its creature name, flagging the ones missing from `Data/`. One clear night
produces the paste that fixes the files properly — record it in [SPIKES.md](SPIKES.md)
against the build number, then flip the flags to `true`.

`/pprc debug` counts what is still unverified, so the gap stays visible rather than
quietly becoming folklore.

---

## Publishing to CurseForge

The automation is built. These steps need your CurseForge account, so nothing publishes
until you do them:

1. Create a CurseForge author account and submit the project. Approval is usually under
   a day.
2. Copy the numeric **Project ID** from the project page into the `.toc`. There is a
   commented placeholder near the top:
   `## X-Curse-Project-ID: 000000`
3. Generate an API token in your CurseForge account settings.
4. Add it to this repository as the secret **`CF_API_KEY`**
   (*Settings → Secrets and variables → Actions*).
5. Tag a release:
   ```bash
   git tag -a v0.1.0 -m "First release"
   git push origin v0.1.0
   ```

`.github/workflows/release.yml` then runs the syntax check and full test suite, builds
the zip from `.pkgmeta`, substitutes the tag into `@project-version@`, attaches it to a
GitHub Release, and uploads to CurseForge.

Without `CF_API_KEY` the CurseForge upload is skipped and the **GitHub Release still
publishes** — which is what gives testers a download link while approval is pending.

One thing to check on the first tagged run: the packager infers the game flavour from the
interface version, and TBC Anniversary at 20506 is newer than most examples were written
against. If it guesses wrong, the fix is an explicit `-g` flag in the workflow, but that
can only be confirmed from the first run's logs.

---

## Development

```bash
sudo apt-get install -y lua5.1

find . -name '*.lua' -print0 | xargs -0 -n1 luac5.1 -p   # syntax
lua5.1 Tests/run.lua                                     # test suite
```

`Tests/stubs.lua` is a headless stand-in for the parts of the client the addon touches,
so everything runs without the game. **The suite runs twice**: once against a modern API
surface (`C_Timer`, `C_ChatInfo`, `C_UnitAuras`, `C_WorldStateInfo`) and once with all of
it stripped to the legacy globals. Both passes must be green — that is what makes the
degradation chains a tested claim rather than a written one.

CI runs both plus a check that every file the `.toc` names actually exists, since a `.toc`
pointing at a missing file is a silent partial load in game.

### Architecture

```
Core/Adapter.lua      ← THE ONLY FILE THAT TOUCHES BLIZZARD APIs
Core/Init.lua           namespace, event bus, timers, profiles, debug log
Core/Codec.lua          wire format for sync, with chunking
Core/RateLimit.lua      outbound throttle, chat and addon lanes
Core/StateMachine.lua   step state and the data registry
Core/Detect.lua         instance, wave classifier, NPC harvest, phases
Core/Roster.lua         group, roles, readiness, assignments
Core/Comm.lua           sync and the receive-side permission gate
Data/                   pure tables, zero logic
UI/                     plain frames, no secure templates, cannot taint
```

2.5.6 backported Midnight-era nameplate and raid-frame code and broke a lot of addons on
release. Every Blizzard call funnels through `Adapter.lua` so a future 2.5.7 doing it
again is a one-file fix. Three rules run through that file: probe with `pcall` so a
missing API is a branch and not an error; read return values by type and content rather
than fixed position so a shifted signature does not silently change what is parsed; and
terminate every chain in manual control.

Capabilities are deliberately tri-state — `true`, `false`, and `nil` for *cannot tell*.
The readiness board has to show an unknown as unknown rather than as a red cross, so that
distinction survives all the way down to the adapter.

**No Ace3, no LibDeflate.** `Init.lua` covers what AceAddon/AceEvent/AceDB would have,
`Codec.lua` covers AceSerializer, and sync uses `C_ChatInfo.SendAddonMessage` directly.
Fewer taint surfaces, nothing to fetch, and every line is covered by the suite.

---

## Credits

Mount Hyjal wave data, boss numbers and positioning come from **Jurdi's Mount Hyjal Cheat
Sheet** — [twitch.tv/jurdijd](https://www.twitch.tv/jurdijd),
[YouTube guide](https://www.youtube.com/watch?v=v7CgKFX45iw). Used with credit; the
strategies are his work, not ours.

## Licence

MIT. See [LICENSE](LICENSE).
