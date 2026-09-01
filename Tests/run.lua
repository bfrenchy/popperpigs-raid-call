-- Tests/run.lua
--
-- Headless test suite. Loads every file listed in the .toc, in .toc order,
-- against the stubbed client in Tests/stubs.lua.
--
--   lua5.1 Tests/run.lua
--
-- The suite runs twice: once against a modern API surface (C_Timer,
-- C_ChatInfo, C_UnitAuras, C_WorldStateInfo) and once with all of it stripped
-- down to the legacy globals. Both passes must go green, which is what makes
-- the plan's degradation chains a tested claim rather than a written one.

local ROOT = arg[0]:match("^(.*)/Tests/run%.lua$") or "."
package.path = ROOT .. "/Tests/?.lua;" .. package.path

local stubs = require("stubs")

-- ---------------------------------------------------------------------------
-- Tiny test framework
-- ---------------------------------------------------------------------------

local passed, failed, currentGroup = 0, 0, ""
local failures = {}

local function group(name) currentGroup = name end

local function it(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        failures[#failures + 1] = string.format("%s :: %s\n      %s", currentGroup, name, tostring(err))
        io.write("  FAIL  ", currentGroup, " :: ", name, "\n")
    end
end

local function eq(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            label or "value", tostring(expected), tostring(actual)), 2)
    end
end

local function truthy(value, label)
    if not value then error((label or "value") .. ": expected truthy, got " .. tostring(value), 2) end
end

local function falsy(value, label)
    if value then error((label or "value") .. ": expected falsy, got " .. tostring(value), 2) end
end

local function isNil(value, label)
    if value ~= nil then error((label or "value") .. ": expected nil, got " .. tostring(value), 2) end
end

-- ---------------------------------------------------------------------------
-- Loader: read the .toc and load its files in order
-- ---------------------------------------------------------------------------

local function tocFiles()
    local files = {}
    local fh = assert(io.open(ROOT .. "/PopperpigRaidCall.toc", "r"))
    for line in fh:lines() do
        line = line:gsub("\r$", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and not line:match("^#") and line:match("%.lua$") then
            files[#files + 1] = (line:gsub("\\", "/"))
        end
    end
    fh:close()
    return files
end

local function loadAddon(env)
    local addon = {}
    for _, relative in ipairs(tocFiles()) do
        local path = ROOT .. "/" .. relative
        local chunk, err = loadfile(path)
        if not chunk then error("failed to load " .. relative .. ": " .. tostring(err)) end
        chunk("PopperpigRaidCall", addon)
    end
    env.fire("ADDON_LOADED", "PopperpigRaidCall")
    return addon
end

-- Fresh stubbed client + freshly loaded addon for each scenario, so no test
-- can pass because of state another test left behind.
local function scenario(opts, fn)
    _G.PopperpigRaidCallDB = nil
    _G.PopperpigRaidCall = nil
    local env = stubs.install(opts)
    env.units.player = { name = "Popperpig", class = "WARRIOR", guid = "Player-0-0001", rank = 2, hp = 100, hpMax = 100 }
    local addon = loadAddon(env)
    local ok, err = pcall(fn, addon, env)
    env.restore()
    if not ok then error(err, 0) end
end

-- ===========================================================================
-- Suites
-- ===========================================================================

local function suiteAdapter(profile, opts)
    group("Adapter [" .. profile .. "]")

    it("loads with no error and exposes the namespace", function()
        scenario(opts, function(addon)
            truthy(addon.Adapter, "Adapter")
            truthy(addon.Cap, "Cap")
            eq(_G.PopperpigRaidCall, addon, "global namespace")
        end)
    end)

    it("parses an NPC ID out of a Creature GUID", function()
        scenario(opts, function(addon)
            eq(addon.Adapter:NPCID("Creature-0-1234-534-0000-17767-0000AB"), 17767, "winterchill")
            eq(addon.Adapter:NPCID("Creature-0-3113-564-29906-22887-000136DF"), 22887, "najentus")
        end)
    end)

    it("parses Vehicle and Pet GUIDs with the same call", function()
        scenario(opts, function(addon)
            eq(addon.Adapter:NPCID("Vehicle-0-1234-534-0000-17767-0000AB"), 17767, "vehicle")
            eq(addon.Adapter:NPCID("Pet-0-1234-534-0000-17767-0000AB"), 17767, "pet")
        end)
    end)

    it("returns nil rather than a guess for player and malformed GUIDs", function()
        scenario(opts, function(addon)
            isNil(addon.Adapter:NPCID("Player-4795-01C1BE1D"), "player guid")
            isNil(addon.Adapter:NPCID("nonsense"), "garbage")
            isNil(addon.Adapter:NPCID(nil), "nil")
            isNil(addon.Adapter:NPCID(12345), "number")
        end)
    end)

    it("reads world state numbers regardless of which return holds them", function()
        scenario(opts, function(addon, env)
            -- Digits in return 3 rather than return 1: a signature shift must
            -- not change what we parse.
            env.worldStateUI = { { 1, "Interface\\Icons\\x", "Enemies Remaining: 12" } }
            local nums = addon.Adapter:WorldStateNumbers()
            eq(#nums, 1, "count")
            eq(nums[1], 12, "value")
        end)
    end)

    it("reads world state numbers out of a localized label", function()
        scenario(opts, function(addon, env)
            -- German label, same digits. Parsing %d+ is locale-independent.
            env.worldStateUI = { { "Welle 7", 0, 0 } }
            local nums = addon.Adapter:WorldStateNumbers()
            eq(nums[1], 7, "wave number")
        end)
    end)

    it("returns an empty list, not an error, when world state is unreadable", function()
        _G.PopperpigRaidCallDB = nil
        _G.PopperpigRaidCall = nil
        local env = stubs.install({ modern = opts.modern, worldState = "none" })
        env.units.player = { name = "Popperpig", class = "WARRIOR", guid = "Player-0-0001" }
        local addon = loadAddon(env)
        falsy(addon.Cap.worldState, "capability")
        eq(addon.Cap.worldStateSource, "none", "source")
        eq(#addon.Adapter:WorldStateNumbers(), 0, "numbers")
        env.restore()
    end)

    it("treats an unregisterable event as a branch, not an error", function()
        _G.PopperpigRaidCallDB = nil
        _G.PopperpigRaidCall = nil
        local env = stubs.install({
            modern = opts.modern,
            worldState = opts.worldState,
            missingEvents = { ENCOUNTER_START = true, NAME_PLATE_UNIT_ADDED = true },
        })
        env.units.player = { name = "Popperpig", class = "WARRIOR", guid = "Player-0-0001" }
        local addon = loadAddon(env)
        falsy(addon.Cap.encounterEvents, "ENCOUNTER_START probed absent")
        falsy(addon.Cap.nameplates, "nameplates probed absent")
        falsy(addon:On("ENCOUNTER_START", function() end), "On() reports failure")
        truthy(addon:On("PLAYER_REGEN_DISABLED", function() end), "available event still works")
        env.restore()
    end)

    it("resolves a boss unit from target when boss tokens are absent", function()
        scenario(opts, function(addon, env)
            env.units.target = { name = "Rage Winterchill", guid = "Creature-0-1-534-0-17767-1", hp = 50, hpMax = 100 }
            local unit, via = addon.Adapter:GetBossUnit(17767)
            eq(unit, "target", "unit")
            eq(via, "target", "source")
            eq(addon.Adapter:BossHealthPct(17767), 50, "health pct")
        end)
    end)

    it("returns nil health rather than a fake 100 when no boss unit resolves", function()
        scenario(opts, function(addon)
            isNil(addon.Adapter:BossHealthPct(17767), "health with no source")
        end)
    end)

    it("finds a buff by name whatever position it is returned in", function()
        scenario(opts, function(addon, env)
            env.units.raid1 = {
                name = "Aeliswyn", class = "MAGE", guid = "Player-0-1",
                auras = { { name = "Arcane Intellect", spellId = 27126 },
                          { name = "Flask of Blinding Light", spellId = 28521 } },
            }
            env.groupSize, env.inRaid = 1, true
            local lookup = { ["Flask of Blinding Light"] = true }
            local has = addon.Adapter:UnitHasAura("raid1", lookup)
            eq(has, true, "flask found")
            eq(addon.Adapter:UnitHasAura("raid1", { ["Flask of Fortification"] = true }), false, "absent flask")
        end)
    end)

    it("reports rank by name through GetRaidRosterInfo", function()
        scenario(opts, function(addon, env)
            env.buildRaid({
                { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true },
                { name = "Sollura",   class = "PALADIN", rank = 1 },
                { name = "Kethran",   class = "HUNTER",  rank = 0 },
            })
            eq(addon.Adapter:RankOf("Popperpig"), 2, "leader")
            eq(addon.Adapter:RankOf("Sollura"), 1, "assist")
            eq(addon.Adapter:RankOf("Kethran"), 0, "raider")
            eq(addon.Adapter:RankOf("Sollura-Otherrealm"), 1, "realm-qualified name")
            eq(addon.Adapter:RankOf("Nobody"), 0, "not in raid")
        end)
    end)

    it("gates broadcast on lead or assist", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 0, isPlayer = true } })
            falsy(addon.Adapter:CanBroadcast(), "plain raider may not broadcast")
            env.units.player.rank = 1
            truthy(addon.Adapter:CanBroadcast(), "assist may broadcast")
        end)
    end)

    it("builds unit tokens for raid, party and solo", function()
        scenario(opts, function(addon, env)
            env.inRaid, env.groupSize = true, 3
            local units = addon.Adapter:GroupUnits()
            eq(#units, 3, "raid count"); eq(units[1], "raid1", "raid token")

            env.inRaid, env.groupSize = false, 3
            units = addon.Adapter:GroupUnits()
            eq(units[1], "player", "party includes player"); eq(units[2], "party1", "party token")

            env.groupSize = 0
            units = addon.Adapter:GroupUnits()
            eq(#units, 1, "solo count"); eq(units[1], "player", "solo token")
        end)
    end)

    it("reads the instance map id", function()
        scenario(opts, function(addon, env)
            env.instance = { name = "The Battle for Mount Hyjal", mapID = 534 }
            local mapID, name = addon.Adapter:InstanceMapID()
            eq(mapID, 534, "map id")
            eq(name, "The Battle for Mount Hyjal", "name")
        end)
    end)

    it("reports a capability table naming the resolved source", function()
        scenario(opts, function(addon)
            local lines = addon.Adapter:CapabilityReport()
            truthy(#lines > 5, "report has content")
            local blob = table.concat(lines, "\n")
            truthy(blob:find("world state"), "mentions world state")
            truthy(blob:find(addon.Cap.worldStateSource, 1, true), "names the source it resolved")
        end)
    end)
end

local function suiteCore(profile, opts)
    group("Core [" .. profile .. "]")

    it("fills defaults without clobbering saved values", function()
        _G.PopperpigRaidCallDB = {
            profiles = { ["Popperpig-Testrealm"] = { locked = true, hudScale = 1.4 } },
        }
        _G.PopperpigRaidCall = nil
        local env = stubs.install(opts)
        env.units.player = { name = "Popperpig", class = "WARRIOR", guid = "Player-0-1" }
        local addon = loadAddon(env)
        eq(addon.db.locked, true, "existing value preserved")
        eq(addon.db.hudScale, 1.4, "existing scale preserved")
        eq(addon.db.localEcho, false, "missing default filled")
        truthy(type(addon.db.frames) == "table", "nested default filled")
        env.restore()
    end)

    it("bounds the debug log ring buffer", function()
        scenario(opts, function(addon)
            for i = 1, 320 do addon:Log("line %d", i) end
            eq(#addon.logBuffer, 200, "ring size")
            truthy(addon.logBuffer[200]:find("line 320"), "newest retained")
            falsy(addon.logBuffer[1]:find("line 1 "), "oldest dropped")
        end)
    end)

    it("dispatches signals and survives a broken listener", function()
        scenario(opts, function(addon)
            local seen = {}
            addon:Listen("TEST_SIG", function() error("boom") end)
            addon:Listen("TEST_SIG", function(v) seen[#seen + 1] = v end)
            addon:Fire("TEST_SIG", 42)
            eq(#seen, 1, "second listener still ran")
            eq(seen[1], 42, "payload")
        end)
    end)

    it("survives a handler that errors on a game event", function()
        scenario(opts, function(addon, env)
            local ran = 0
            addon:On("PLAYER_REGEN_DISABLED", function() error("bad handler") end)
            addon:On("PLAYER_REGEN_DISABLED", function() ran = ran + 1 end)
            env.fire("PLAYER_REGEN_DISABLED")
            eq(ran, 1, "later handler still ran")
        end)
    end)

    it("runs a delayed callback on whichever timer path exists", function()
        scenario(opts, function(addon, env)
            local fired = 0
            addon:After(2, function() fired = fired + 1 end)
            env.advance(1, addon)
            eq(fired, 0, "not yet due")
            env.advance(2, addon)
            eq(fired, 1, "fired once")
            env.advance(5, addon)
            eq(fired, 1, "did not repeat")
        end)
    end)

    it("runs a repeating ticker and cancels it", function()
        scenario(opts, function(addon, env)
            local ticks = 0
            local handle = addon:Ticker(1, function() ticks = ticks + 1 end)
            env.advance(1, addon); env.advance(1, addon); env.advance(1, addon)
            eq(ticks, 3, "ticked each interval")
            handle:Cancel()
            env.advance(5, addon)
            eq(ticks, 3, "stopped after cancel")
        end)
    end)

    it("compares versions numerically for the handshake", function()
        scenario(opts, function(addon)
            truthy(addon:VersionNumber("v1.2.3") > addon:VersionNumber("v1.2.2"), "patch")
            truthy(addon:VersionNumber("v1.3.0") > addon:VersionNumber("v1.2.99"), "minor")
            truthy(addon:VersionNumber("dev") > addon:VersionNumber("v9.9.9"), "dev sorts highest")
            eq(addon:VersionNumber("garbage"), 0, "unparseable")
        end)
    end)
end

local function suiteState(profile, opts)
    group("StateMachine [" .. profile .. "]")

    it("registers Hyjal with 5 encounters and 32 waves", function()
        scenario(opts, function(addon)
            local hyjal = addon.Instances.hyjal
            truthy(hyjal, "instance registered")
            eq(hyjal.mapID, 534, "map id")
            eq(#hyjal.order, 5, "encounter count")

            local waves = 0
            for _, encounterID in ipairs(hyjal.order) do
                local encounter = addon:GetEncounter(encounterID)
                truthy(encounter, encounterID .. " present")
                for _, step in ipairs(encounter.steps) do
                    if step.wave then waves = waves + 1 end
                end
            end
            eq(waves, 32, "total waves across the instance")
        end)
    end)

    -- This test used to assert `byNPC[17916]` was indexed -- it encoded the bug
    -- rather than catching it. Ghoul 17916 appears in 24 Hyjal wave steps, so a
    -- single-slot map resolved it to whichever registered last, and in a live
    -- raid the combat log shuffled the HUD between Azgalor's waves 2, 7 and 8
    -- while the raid stood in one of them.
    it("keys detection on boss ids only, never on shared trash ids", function()
        scenario(opts, function(addon)
            local hyjal = addon.Instances.hyjal
            eq(hyjal.byNPC[17767].encounter, "hyjal_winterchill", "winterchill boss id keys")
            eq(hyjal.byNPC[17968].encounter, "hyjal_archimonde", "archimonde boss id keys")

            -- Not merely deduplicated: a wave's mob list never claims a key at
            -- all, because composition says what you are fighting, not where
            -- you are. So the ghoul cannot move state...
            isNil(hyjal.byNPC[17916], "ghoul CANNOT move state")
            -- ...but is still on file, so /pprc scan does not cry "not in Data/"
            -- at a mob we deliberately chose not to key off.
            truthy(hyjal.knownNPC[17916], "and is still known to the scan report")
        end)
    end)

    -- ambiguousNPC is empty against the shipped data, by design. It is the net
    -- for a future edit that keys two different steps off one id -- the exact
    -- mistake that cost a raid night -- so it is tested on a fixture.
    it("refuses to key one id to two different steps", function()
        scenario(opts, function(addon)
            addon:RegisterInstance({
                id = "fx_dupe", name = "Fixture",
                order = { "fx_a" },
                encounters = {
                    fx_a = {
                        name = "Fixture", steps = {
                            { id = "one", label = "One", advance = "npc_id", npcID = 4242 },
                            { id = "two", label = "Two", advance = "npc_id", npcID = 4242 },
                        },
                    },
                },
            })
            local def = addon.Instances.fx_dupe
            truthy(def.ambiguousNPC[4242], "conflict recorded")
            isNil(def.byNPC[4242], "and the id is disarmed rather than picking a winner")
            truthy(def.knownNPC[4242], "still known")
        end)
    end)

    it("leaves no wave step reachable by a shared mob id", function()
        scenario(opts, function(addon)
            for _, instance in pairs(addon.Instances) do
                for npcID, target in pairs(instance.byNPC) do
                    if target.step then
                        local encounter = addon:GetEncounter(target.encounter)
                        local step = encounter.steps[target.step]
                        eq(step.advance, addon.ADVANCE.NPC_ID,
                            string.format("%d keys %s/%s, which advances on npc_id",
                                npcID, target.encounter, step.id))
                    end
                end
            end
        end)
    end)

    -- The exact shape of the live failure, replayed.
    it("holds position while a mixed Azgalor wave churns through the log", function()
        scenario(opts, function(addon, env)
            env.instance = { name = "The Battle for Mount Hyjal", mapID = 534 }
            addon.Detect:CheckZone()
            addon.State:Set("hyjal_azgalor", 3, "local")

            -- One wave, three mob types, all shared across the instance.
            for _ = 1, 5 do
                env.combatLog("SPELL_DAMAGE", "Creature-0-1-534-0-17916-1", "Ghoul",
                    "Player-0-1", "Popperpig")
                env.combatLog("SPELL_DAMAGE", "Creature-0-1-534-0-17897-1", "Crypt Fiend",
                    "Player-0-1", "Popperpig")
                env.combatLog("SPELL_DAMAGE", "Creature-0-1-534-0-17899-1", "Shadowy Necromancer",
                    "Player-0-1", "Popperpig")
            end

            eq(addon.State.encounterID, "hyjal_azgalor", "still on Azgalor")
            eq(addon.State.stepIndex, 3, "still on the wave the raid is actually fighting")
        end)
    end)

    it("still lets a boss appearing mid-trash surface its encounter", function()
        scenario(opts, function(addon, env)
            env.instance = { name = "The Battle for Mount Hyjal", mapID = 534 }
            addon.Detect:CheckZone()
            addon.State:Set("hyjal_azgalor", 3, "local")

            env.combatLog("SPELL_DAMAGE", "Creature-0-1-534-0-17842-1", "Azgalor",
                "Player-0-1", "Popperpig")
            eq(addon.State.encounterID, "hyjal_azgalor", "same encounter")
            truthy(addon.State.stepIndex > 3, "moved forward onto the boss step")
        end)
    end)

    it("stops moving the HUD entirely when auto-advance is off", function()
        scenario(opts, function(addon, env)
            env.instance = { name = "The Battle for Mount Hyjal", mapID = 534 }
            addon.Detect:CheckZone()
            addon.State:Set("hyjal_azgalor", 3, "local")
            addon.db.autoAdvance = false

            -- Even a boss id, which is a legitimate unambiguous key.
            env.combatLog("SPELL_DAMAGE", "Creature-0-1-534-0-17842-1", "Azgalor",
                "Player-0-1", "Popperpig")
            eq(addon.State.stepIndex, 3, "detection held its hands up")

            -- The RL still drives, which is the point of the switch.
            addon.State:Advance("local")
            eq(addon.State.stepIndex, 4, "manual control unaffected")
        end)
    end)

    it("says on the debug report when waves will not move by themselves", function()
        scenario(opts, function(addon, env)
            env.instance = { name = "The Battle for Mount Hyjal", mapID = 534 }
            addon.Detect:CheckZone()
            local report = table.concat(addon.Detect:TierReport(), "\n")
            -- Unclassified waves are the documented fallback, not a fault -- but
            -- an RL who does not know that thinks the addon is dead.
            truthy(report:find("waves are on manual", 1, true), "the report says so plainly")
            truthy(report:find("disarmed as ambiguous", 1, true), "and reports the npc key count")
        end)
    end)

    it("never lets detection drag the night backwards", function()
        scenario(opts, function(addon)
            addon.State:Set("hyjal_azgalor", 6, "local")
            falsy(addon.Detect:MayAdvanceTo({ encounter = "hyjal_azgalor", step = 2 }),
                "a stale id cannot rewind the HUD mid-fight")
            truthy(addon.Detect:MayAdvanceTo({ encounter = "hyjal_azgalor", step = 8 }),
                "forward is fine")
            truthy(addon.Detect:MayAdvanceTo({ encounter = "hyjal_archimonde", step = 1 }),
                "a different fight is always allowed")
        end)
    end)

    -- Mark of Kaz'rogal detonates on INSUFFICIENT mana, so low mana is what
    -- kills you. This data once told the raid to spend their mana before the
    -- pull, which would have detonated the entire caster core at once. These
    -- two tests exist purely so that cannot come back.
    it("tells the raid to keep mana up on Kaz'rogal, never to dump it", function()
        scenario(opts, function(addon)
            local kazrogal = addon:GetEncounter("hyjal_kazrogal")
            local boss
            for _, step in ipairs(kazrogal.steps) do
                if step.id == "boss" then boss = step end
            end

            local text = boss.call .. " " .. table.concat(boss.warn, " ")
            for _, entry in ipairs(boss.brief or {}) do text = text .. " " .. entry.text end
            local lowered = text:lower()

            truthy(lowered:find("keep mana up", 1, true) or lowered:find("high mana", 1, true),
                "says to keep mana up")
            truthy(lowered:find("explode", 1, true) or lowered:find("detonat", 1, true),
                "explains the consequence")

            -- The reversal, in the forms it could plausibly reappear in.
            falsy(lowered:find("spend your mana", 1, true), "no 'spend your mana'")
            falsy(lowered:find("spend down", 1, true), "no 'spend down'")
            falsy(lowered:find("dump your mana", 1, true), "no 'dump your mana'")
            falsy(lowered:find("burn mana down", 1, true), "no 'burn mana down'")
        end)
    end)

    it("gives the hunter and druid outs, and the run-out instruction", function()
        scenario(opts, function(addon)
            local kazrogal = addon:GetEncounter("hyjal_kazrogal")
            local boss
            for _, step in ipairs(kazrogal.steps) do
                if step.id == "boss" then boss = step end
            end

            local briefText = ""
            for _, entry in ipairs(boss.brief or {}) do briefText = briefText .. " " .. entry.text end
            truthy(briefText:find("Aspect of the Viper", 1, true), "hunter out")
            truthy(briefText:find("Cat Form", 1, true), "druid out")
            truthy(briefText:find("600 mana", 1, true), "states the drain rate")
            truthy(boss.call:lower():find("run out", 1, true), "tells whoever will pop to leave the stack")
        end)
    end)

    it("splits data provenance three ways so drift stays visible", function()
        scenario(opts, function(addon)
            local hyjal = addon.Instances.hyjal
            truthy(hyjal.total > 0, "steps counted")

            -- Hyjal now comes from Jurdi's cheat sheet: sourced, but still not
            -- confirmed against the live client. Those are different claims and
            -- the registry keeps them apart.
            eq(hyjal.sourced, hyjal.total, "every Hyjal step is sourced")
            eq(hyjal.unverified, 0, "none left unbacked")
            eq(hyjal.verified, 0, "and none claims live-client confirmation")

            -- Black Temple is now sourced from cosmophile's guide.
            local bt = addon.Instances.blacktemple
            eq(bt.sourced, bt.total, "every Black Temple step is sourced")
            eq(bt.unverified, 0, "none left unbacked")

            -- A step with no source at all still counts as unbacked, so the
            -- distinction keeps working for anything added later.
            addon:RegisterInstance({
                id = "prov_fixture", mapID = 7777, name = "Fixture", order = { "pf" },
                encounters = { pf = { name = "Fixture", steps = {
                    { id = "sourced", label = "A", advance = "manual", source = "somebody" },
                    { id = "bare",    label = "B", advance = "manual" },
                } } },
            })
            local fixture = addon.Instances.prov_fixture
            eq(fixture.sourced, 1, "sourced step counted")
            eq(fixture.unverified, 1, "bare step still counted as unbacked")
        end)
    end)

    it("walks all 8 Winterchill waves with correct NOW and NEXT", function()
        scenario(opts, function(addon)
            local State = addon.State
            truthy(State:StartTest("hyjal_winterchill"), "test mode started")

            local step = State:Current()
            eq(step.id, "wave1", "starts on wave 1")
            eq(State:Next().id, "wave2", "next is wave 2")

            for expected = 2, 8 do
                truthy(State:Advance("local"), "advanced to wave " .. expected)
                eq(State:Current().id, "wave" .. expected, "now wave " .. expected)
            end

            truthy(State:Advance("local"), "advanced to boss")
            eq(State:Current().id, "boss", "lands on the boss step")
            isNil(State:Next(), "nothing after the boss")
            eq(State:StepCount(), 9, "8 waves plus the boss")
        end)
    end)

    it("rewinds and clamps at both ends instead of falling off", function()
        scenario(opts, function(addon)
            local State = addon.State
            State:StartTest("hyjal_winterchill")

            falsy(State:Back("local"), "cannot go back from step 1")
            eq(State.stepIndex, 1, "still on step 1")

            State:GoToStep(9, "local")
            falsy(State:Advance("local"), "cannot advance past the last step")
            eq(State.stepIndex, 9, "still on the last step")

            State:Back("local")
            eq(State:Current().id, "wave8", "rewound one step")
        end)
    end)

    it("maps a wave number to its step within the current encounter", function()
        scenario(opts, function(addon)
            local State = addon.State
            State:StartTest("hyjal_anetheron")

            truthy(State:GoToWave(6, "detect"), "jumped to wave 6")
            eq(State:Current().id, "wave6", "correct step")
            eq(State:Current().detail, "6 Ghouls, 2 Abominations, 4 Shadowy Necromancers", "correct data")

            -- Waves restart per encounter, so 9 is meaningless here.
            falsy(State:GoToWave(9, "detect"), "unknown wave refused")
            eq(State:Current().id, "wave6", "state unchanged after a refused jump")
        end)
    end)

    it("jumps to the encounter an NPC belongs to", function()
        scenario(opts, function(addon)
            local State = addon.State
            local hyjal = addon.Instances.hyjal
            State:SetInstance(hyjal)
            State:SetEncounter("hyjal_winterchill", "local")

            truthy(State:GoToNPC(17842, hyjal, "detect"), "azgalor id recognised")
            eq(State.encounterID, "hyjal_azgalor", "switched encounter")

            falsy(State:GoToNPC(999999, hyjal, "detect"), "unknown id ignored")
            eq(State.encounterID, "hyjal_azgalor", "state unchanged")
        end)
    end)

    it("fires STATE_CHANGED once per real change and never for a no-op", function()
        scenario(opts, function(addon)
            local State, fires = addon.State, 0
            addon:Listen("STATE_CHANGED", function() fires = fires + 1 end)

            State:StartTest("hyjal_winterchill")
            eq(fires, 1, "one fire for the initial set")

            State:Advance("local")
            eq(fires, 2, "one fire per advance")

            State:GoToStep(2, "local")
            eq(fires, 2, "setting the same step fired nothing")
        end)
    end)

    it("carries the change source so remote updates are not echoed back", function()
        scenario(opts, function(addon)
            local State, sources = addon.State, {}
            addon:Listen("STATE_CHANGED", function(_, source) sources[#sources + 1] = source end)

            State:StartTest("hyjal_winterchill")
            State:Advance("local")
            State:Advance("remote")

            eq(sources[2], "local", "local change tagged")
            eq(sources[3], "remote", "remote change tagged")
        end)
    end)

    it("refuses an unknown encounter rather than blanking state", function()
        scenario(opts, function(addon)
            local State = addon.State
            State:StartTest("hyjal_winterchill")
            falsy(State:SetEncounter("does_not_exist", "local"), "refused")
            eq(State.encounterID, "hyjal_winterchill", "state preserved")
        end)
    end)

    it("treats solo and test as controller, and a plain raider as not", function()
        scenario(opts, function(addon, env)
            local State = addon.State
            env.groupSize = 0
            truthy(State:IsController(), "solo drives its own state")

            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 0, isPlayer = true } })
            falsy(State:IsController(), "plain raider does not drive")

            env.units.player.rank = 1
            truthy(State:IsController(), "assist drives")

            env.units.player.rank = 0
            State.testMode = true
            truthy(State:IsController(), "test mode always drives")
        end)
    end)
end

local function suiteHUD(profile, opts)
    group("HUD [" .. profile .. "]")

    it("builds and renders the current step from data", function()
        scenario(opts, function(addon)
            truthy(addon.HUD.frame, "frame built")
            addon.State:StartTest("hyjal_winterchill")
            addon.HUD:Refresh()

            eq(addon.HUD.nowTitle:GetText(), "Wave 1", "NOW title")
            eq(addon.HUD.nowDetail:GetText(), "10 Ghouls", "NOW detail")
            truthy(addon.HUD.nowCall:GetText():find("Ghouls only", 1, true), "spoken call rendered")
            truthy(addon.HUD.nextTitle:GetText():find("Wave 2", 1, true), "NEXT title")
        end)
    end)

    it("flags a step backed by nothing, and only that", function()
        scenario(opts, function(addon)
            -- Both raids are sourced now, so the unbacked case needs a fixture.
            addon:RegisterInstance({
                id = "tag_fixture", mapID = 7778, name = "Fixture", order = { "tf" },
                encounters = { tf = { name = "Fixture", steps = {
                    { id = "bare", label = "Bare step", advance = "manual" },
                } } },
            })

            addon.State:StartTest("tf")
            addon.HUD:Refresh()
            eq(addon.HUD.unverifiedTag:GetText(), "unverified", "flagged when unbacked")

            -- Real data comes from cited guides, so it renders clean. Tagging
            -- sourced data would train people to ignore the tag.
            addon.State:StartTest("hyjal_winterchill")
            addon.HUD:Refresh()
            eq(addon.HUD.unverifiedTag:GetText(), "", "no tag on Hyjal (jurdi)")

            addon.State:StartTest("bt_najentus")
            addon.HUD:Refresh()
            eq(addon.HUD.unverifiedTag:GetText(), "", "no tag on Black Temple (cosmophile)")

            -- And live-client confirmation clears it too.
            addon.State:StartTest("tf")
            addon.State:Current().verified = true
            addon.HUD:Refresh()
            eq(addon.HUD.unverifiedTag:GetText(), "", "no tag on confirmed data")
        end)
    end)

    it("shows no unverified tag when there is no step at all", function()
        scenario(opts, function(addon)
            addon.HUD:Refresh()
            eq(addon.HUD.unverifiedTag:GetText(), "", "nothing to flag")
        end)
    end)

    it("shows a usable empty state with no encounter", function()
        scenario(opts, function(addon)
            addon.HUD:Refresh()
            eq(addon.HUD.nowTitle:GetText(), "No encounter loaded", "empty title")
            truthy(addon.HUD.nowDetail:GetText():find("pprc test", 1, true), "points at /pprc test")
        end)
    end)

    it("labels the advance button with position in the encounter", function()
        scenario(opts, function(addon)
            addon.State:StartTest("hyjal_winterchill")
            addon.HUD:Refresh()
            eq(addon.HUD.advanceBtn._label:GetText(), "ADVANCE (1/9)", "step counter")
            addon.State:Advance("local")
            eq(addon.HUD.advanceBtn._label:GetText(), "ADVANCE (2/9)", "counter follows state")
        end)
    end)

    it("disables back on the first step and advance on the last", function()
        scenario(opts, function(addon)
            addon.State:StartTest("hyjal_winterchill")
            addon.HUD:Refresh()
            truthy(addon.HUD.backBtn._disabled, "back disabled at the start")
            falsy(addon.HUD.advanceBtn._disabled, "advance enabled at the start")

            addon.State:GoToStep(9, "local")
            truthy(addon.HUD.advanceBtn._disabled, "advance disabled at the end")
            falsy(addon.HUD.backBtn._disabled, "back enabled at the end")
        end)
    end)

    it("hides the controls for a raider who cannot drive", function()
        scenario(opts, function(addon, env)
            addon.State:StartTest("hyjal_winterchill")
            addon.State.testMode = false
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 0, isPlayer = true } })
            addon.HUD:Refresh()
            falsy(addon.HUD.controls:IsShown(), "controls hidden for a raider")

            env.units.player.rank = 2
            addon.HUD:Refresh()
            truthy(addon.HUD.controls:IsShown(), "controls shown for the leader")
        end)
    end)

    it("names the instance and encounter in the title bar", function()
        scenario(opts, function(addon)
            addon.State:StartTest("hyjal_azgalor")
            addon.HUD:Refresh()
            local title = addon.HUD.frame.title:GetText()
            truthy(title:find("MOUNT HYJAL", 1, true), "instance named")
            truthy(title:find("AZGALOR", 1, true), "encounter named")
        end)
    end)

    it("redraws itself when state changes without being asked", function()
        scenario(opts, function(addon)
            addon.State:StartTest("hyjal_kazrogal")
            -- No explicit Refresh: the signal bus should have driven it.
            eq(addon.HUD.nowTitle:GetText(), "Wave 1", "rendered from the signal")
            addon.State:GoToStep(9, "local")
            eq(addon.HUD.nowTitle:GetText(), "Kaz'rogal", "followed the change")
        end)
    end)
end

local function suiteCommands(profile, opts)
    group("Commands [" .. profile .. "]")

    it("registers the slash command", function()
        scenario(opts, function(addon)
            eq(_G.SLASH_POPPERPIGRAIDCALL1, "/pprc", "slash token")
            truthy(type(_G.SlashCmdList["POPPERPIGRAIDCALL"]) == "function", "handler installed")
        end)
    end)

    it("starts an encounter from /pprc test", function()
        scenario(opts, function(addon)
            addon.Commands:Run("test hyjal_kazrogal")
            eq(addon.State.encounterID, "hyjal_kazrogal", "encounter loaded")
            truthy(addon.State.testMode, "test mode on")
            truthy(addon.HUD.frame:IsShown(), "HUD shown")
        end)
    end)

    it("lists encounters when /pprc test is given no argument", function()
        scenario(opts, function(addon, env)
            addon.Commands:Run("test")
            local blob = table.concat(env.printed, "\n")
            truthy(blob:find("hyjal_winterchill", 1, true), "lists a known encounter")
            isNil(addon.State.encounterID, "did not start anything")
        end)
    end)

    it("rejects an unknown encounter without changing state", function()
        scenario(opts, function(addon, env)
            addon.Commands:Run("test hyjal_winterchill")
            addon.Commands:Run("test not_a_boss")
            local blob = table.concat(env.printed, "\n")
            truthy(blob:find("no such encounter", 1, true), "explains the failure")
            eq(addon.State.encounterID, "hyjal_winterchill", "state untouched")
        end)
    end)

    it("advances and rewinds from chat", function()
        scenario(opts, function(addon)
            addon.Commands:Run("test hyjal_winterchill")
            addon.Commands:Run("next")
            addon.Commands:Run("next")
            eq(addon.State:Current().id, "wave3", "advanced twice")
            addon.Commands:Run("back")
            eq(addon.State:Current().id, "wave2", "rewound once")
        end)
    end)

    it("reports an unknown command instead of erroring", function()
        scenario(opts, function(addon, env)
            addon.Commands:Run("frobnicate")
            truthy(table.concat(env.printed, "\n"):find("unknown command", 1, true), "explained")
        end)
    end)

    it("prints the capability table and the unverified count on /pprc debug", function()
        scenario(opts, function(addon, env)
            addon.Commands:Run("test hyjal_winterchill")
            addon.Commands:Run("debug")
            local blob = table.concat(env.printed, "\n")
            truthy(blob:find("world state", 1, true), "capability table printed")
            truthy(blob:find("verified", 1, true) and blob:find("sourced", 1, true)
                and blob:find("unbacked", 1, true), "provenance split printed")
            truthy(blob:find("Jurdi", 1, true), "and the source is credited")
            truthy(addon.debugEnabled, "debug toggled on")
        end)
    end)

    it("survives a handler that throws", function()
        scenario(opts, function(addon, env)
            addon.Commands.handlers["boom"] = function() error("kaboom") end
            addon.Commands:Run("boom")
            truthy(table.concat(env.printed, "\n"):find("command failed", 1, true), "reported, not thrown")
        end)
    end)
end

local function suiteRateLimit(profile, opts)
    group("RateLimit [" .. profile .. "]")

    -- The plan's M2 acceptance bar, stated as a test.
    it("ten rapid calls produce no disconnect and no silent drop", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true } })

            for i = 1, 10 do addon.RateLimit:SendCall("call " .. i) end

            -- One went out immediately; the other nine are queued, not lost.
            eq(#env.chat, 1, "only one message hit the wire in the first instant")
            eq(addon.RateLimit:QueueDepth("chat"), 9, "the rest are queued")
            eq(addon.RateLimit.lanes.chat.dropped, 0, "nothing dropped")

            -- Drain, and confirm every single one arrives.
            for _ = 1, 200 do env.advance(0.1, addon) end
            eq(#env.chat, 10, "all ten delivered")
            eq(addon.RateLimit:QueueDepth("chat"), 0, "queue empty")
        end)
    end)

    it("never exceeds one chat message per 1.5s", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true } })
            for i = 1, 6 do addon.RateLimit:SendCall("call " .. i) end
            for _ = 1, 200 do env.advance(0.1, addon) end

            eq(#env.chat, 6, "all delivered")
            for i = 2, #env.chat do
                local gap = env.chat[i].at - env.chat[i - 1].at
                truthy(gap >= 1.5 - 1e-9, string.format("gap %d was %.2fs", i, gap))
            end
        end)
    end)

    it("collapses a duplicate that is still queued, but allows a deliberate repeat", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true } })

            addon.RateLimit:SendCall("SPREAD", "spread")   -- goes out at once
            addon.RateLimit:SendCall("SPREAD", "spread")   -- queued
            addon.RateLimit:SendCall("SPREAD", "spread")   -- collapsed into the above
            eq(addon.RateLimit:QueueDepth("chat"), 1, "double-click collapsed")

            for _ = 1, 60 do env.advance(0.1, addon) end
            eq(#env.chat, 2, "the deliberate repeat still went out")
        end)
    end)

    it("drops loudly, with a count, once the queue is full", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true } })
            for i = 1, 40 do addon.RateLimit:SendCall("call " .. i) end

            truthy(addon.RateLimit.lanes.chat.dropped > 0
                or table.concat(env.printed, "\n"):find("dropped", 1, true),
                "overflow was reported")
            eq(addon.RateLimit:QueueDepth("chat"), addon.RateLimit.lanes.chat.maxQueue, "queue capped")
            truthy(table.concat(env.printed, "\n"):find("dropped", 1, true), "the RL was told in chat")
        end)
    end)

    it("routes to raid warning with assist, /raid without, echo when solo", function()
        scenario(opts, function(addon, env)
            env.groupSize = 0
            eq(addon.RateLimit:ChatChannel(), "ECHO", "solo echoes")

            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 0, isPlayer = true } })
            eq(addon.RateLimit:ChatChannel(), "RAID", "no assist degrades to /raid")

            env.units.player.rank = 1
            eq(addon.RateLimit:ChatChannel(), "RAID_WARNING", "assist gets raid warning")

            addon.db.localEcho = true
            eq(addon.RateLimit:ChatChannel(), "ECHO", "echo mode overrides everything")
        end)
    end)

    it("sends nothing to the server in local echo mode", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true } })
            addon.db.localEcho = true

            for i = 1, 5 do addon.RateLimit:SendCall("call " .. i) end
            for _ = 1, 60 do env.advance(0.1, addon) end

            eq(#env.chat, 0, "nothing reached the raid")
            truthy(table.concat(env.printed, "\n"):find("[echo]", 1, true), "echoed locally instead")
        end)
    end)

    it("keeps addon traffic on its own budget, away from the chat lane", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true } })

            addon.RateLimit:SendCall("a call")
            for i = 1, 5 do addon.RateLimit:SendAddon("PPRC", "sync " .. i, "RAID") end

            eq(addon.RateLimit:QueueDepth("chat"), 0, "chat lane unaffected")
            for _ = 1, 60 do env.advance(0.1, addon) end
            eq(#env.addonMessages, 5, "sync traffic delivered on its own lane")
        end)
    end)
end

local function suiteCallBoard(profile, opts)
    group("CallBoard [" .. profile .. "]")

    it("renders this step's calls from data", function()
        scenario(opts, function(addon)
            addon.State:StartTest("hyjal_winterchill")
            addon.State:GoToStep(6, "local")   -- wave6: FAP NOW / OT PEEL
            addon.CallBoard:Refresh()

            eq(addon.CallBoard.stepButtons[1]._label:GetText(), "FAP NOW", "first step call")
            eq(addon.CallBoard.stepButtons[2]._label:GetText(), "MAX 2 PER TANK", "second step call")
            eq(addon.CallBoard.stepButtons[3]._label:GetText(), "PEEL 3 ABOMS OUT", "third step call")
            falsy(addon.CallBoard.stepButtons[4]:IsShown(), "unused buttons hidden")
        end)
    end)

    it("sends a step call through the throttle", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true } })
            addon.State:StartTest("hyjal_winterchill")
            addon.State.testMode = false
            addon.State:GoToStep(6, "local")
            addon.CallBoard:Refresh()

            addon.CallBoard.stepButtons[1]:GetScript("OnClick")(addon.CallBoard.stepButtons[1])
            eq(#env.chat, 1, "one message sent")
            eq(env.chat[1].msg, "FAP NOW", "the step's own words")
            eq(env.chat[1].channel, "RAID_WARNING", "as a raid warning")
        end)
    end)

    it("requires a second click to call a wipe", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true } })
            addon.CallBoard:Refresh()

            local wipeButton
            for _, b in ipairs(addon.CallBoard.standingButtons) do
                if b._call.id == "wipe" then wipeButton = b end
            end
            truthy(wipeButton, "wipe button exists")

            wipeButton:GetScript("OnClick")(wipeButton)
            eq(#env.chat, 0, "first click sent nothing")
            eq(wipeButton._label:GetText(), "CONFIRM?", "button asks for confirmation")

            wipeButton:GetScript("OnClick")(wipeButton)
            eq(#env.chat, 1, "second click sent it")
            truthy(env.chat[1].msg:find("WIPE IT", 1, true), "the wipe call")
        end)
    end)

    it("disarms an unconfirmed wipe after a few seconds", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true } })
            addon.CallBoard:Refresh()

            local wipeButton
            for _, b in ipairs(addon.CallBoard.standingButtons) do
                if b._call.id == "wipe" then wipeButton = b end
            end

            wipeButton:GetScript("OnClick")(wipeButton)
            env.advance(5, addon)
            eq(wipeButton._label:GetText(), "WIPE", "disarmed itself")

            wipeButton:GetScript("OnClick")(wipeButton)
            eq(#env.chat, 0, "a later single click does not fire it")
        end)
    end)

    it("sends a standing call on one click", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true } })
            addon.CallBoard:Refresh()

            local button = addon.CallBoard.standingButtons[1]
            button:GetScript("OnClick")(button)
            eq(#env.chat, 1, "sent immediately")
            truthy(env.chat[1].msg:find("MANA CHECK", 1, true), "the standing call text")
        end)
    end)

    it("hides itself for a raider and comes back with assist", function()
        scenario(opts, function(addon, env)
            addon.db.shown.callboard = true
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 0, isPlayer = true } })
            addon.CallBoard:Refresh()
            falsy(addon.CallBoard.frame:IsShown(), "hidden without assist")

            env.units.player.rank = 1
            addon.CallBoard:Refresh()
            truthy(addon.CallBoard.frame:IsShown(), "shown with assist")
        end)
    end)

    it("shows in echo mode even without assist, and says so", function()
        scenario(opts, function(addon, env)
            addon.db.shown.callboard = true
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 0, isPlayer = true } })
            addon.db.localEcho = true
            addon.CallBoard:Refresh()

            truthy(addon.CallBoard.frame:IsShown(), "visible for testing the flow")
            truthy(addon.CallBoard.frame.title:GetText():find("LOCAL ECHO", 1, true), "title states the mode")
        end)
    end)

    it("titles itself with what a click will actually do", function()
        scenario(opts, function(addon, env)
            addon.db.shown.callboard = true
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 0, isPlayer = true } })
            addon.db.localEcho = false
            addon.CallBoard:Refresh()
            truthy(addon.CallBoard.frame.title:GetText():find("no assist", 1, true), "warns about degraded channel")
        end)
    end)
end

-- Feed the classifier a sequence of world-state readings.
local function feedWorldState(addon, env, sequence, slots)
    for _, value in ipairs(sequence) do
        if slots then
            env.worldStateUI = { { slots.label or "Wave", value } }
        else
            env.worldStateUI = { { "Counter: " .. value } }
        end
        addon.Detect:OnWorldStateUpdate()
    end
end

local function suiteDetect(profile, opts)
    group("Detect [" .. profile .. "]")

    it("loads the right data module from the instance id", function()
        scenario(opts, function(addon, env)
            env.instance = { name = "The Battle for Mount Hyjal", mapID = 534 }
            addon.Detect:CheckZone()
            truthy(addon.State.instance, "instance set")
            eq(addon.State.instance.id, "hyjal", "hyjal loaded")

            env.instance = { name = "Orgrimmar", mapID = 1 }
            addon.Detect:CheckZone()
            isNil(addon.State.instance, "cleared on leaving")
        end)
    end)

    -- Tier 1: the counter climbs, so it is a wave number.
    it("classifies a climbing counter as the wave number and follows it", function()
        scenario(opts, function(addon, env)
            addon.State:StartTest("hyjal_winterchill")
            feedWorldState(addon, env, { 1, 2, 3 })

            eq(addon.Detect.waveMode, "WAVE_NUMBER", "tier 1 resolved")
            eq(addon.State:Current().id, "wave3", "followed the counter")

            feedWorldState(addon, env, { 6 })
            eq(addon.State:Current().id, "wave6", "jumped with the counter")
        end)
    end)

    -- Tier 2: the counter decays and resets, so it is enemies remaining and
    -- each upward jump means a new wave spawned.
    it("classifies a decaying counter as enemies remaining and counts resets", function()
        scenario(opts, function(addon, env)
            addon.State:StartTest("hyjal_anetheron")   -- RL sits on wave 1
            -- 12 -> 8 -> 3 (wave 1 dying), then 12 again (wave 2 spawned)
            feedWorldState(addon, env, { 12, 8, 3, 12 })

            eq(addon.Detect.waveMode, "ENEMIES_REMAINING", "tier 2 resolved")
            -- Seeded from the RL's current wave, so a reset means wave 2, not
            -- "one reset". Counting from zero would put the whole clear an
            -- entire wave behind.
            eq(addon.Detect.waveCount, 2, "counted on from the current wave")
            eq(addon.State:Current().id, "wave2", "state followed")

            feedWorldState(addon, env, { 9, 2, 14 })
            eq(addon.Detect.waveCount, 3, "second reset counted")
            eq(addon.State:Current().id, "wave3", "state followed the count")
        end)
    end)

    -- Tier 3: nothing readable at all.
    it("falls back to manual when the world state reads nothing", function()
        scenario(opts, function(addon, env)
            addon.State:StartTest("hyjal_winterchill")
            env.worldStateUI = {}
            addon.Detect:OnWorldStateUpdate()

            eq(addon.Detect.waveMode, "MANUAL", "tier 3")
            eq(addon.State:Current().id, "wave1", "state untouched, RL drives")
        end)
    end)

    it("stays uncommitted until it has enough behaviour to judge", function()
        scenario(opts, function(addon, env)
            addon.State:StartTest("hyjal_winterchill")
            feedWorldState(addon, env, { 1, 2 })
            isNil(addon.Detect.waveMode, "no verdict from two samples")

            feedWorldState(addon, env, { 3 })
            eq(addon.Detect.waveMode, "WAVE_NUMBER", "verdict on the third")
        end)
    end)

    it("ignores a constant number and picks the one that actually moves", function()
        scenario(opts, function(addon, env)
            addon.State:StartTest("hyjal_winterchill")
            -- Slot 1 is a fixed 25 (raid size, say); slot 2 is the real wave.
            for _, wave in ipairs({ 1, 2, 3, 4 }) do
                env.worldStateUI = { { "Players: 25" }, { "Wave " .. wave } }
                addon.Detect:OnWorldStateUpdate()
            end

            eq(addon.Detect.waveMode, "WAVE_NUMBER", "classified")
            eq(addon.Detect.waveSlot, 2, "picked the moving slot, not the first one")
            eq(addon.State:Current().id, "wave4", "followed the right number")
        end)
    end)

    it("seeds the reset count from where the RL already is", function()
        scenario(opts, function(addon, env)
            addon.State:StartTest("hyjal_kazrogal")
            addon.State:GoToStep(4, "local")          -- RL is already on wave 4
            feedWorldState(addon, env, { 10, 6, 2, 11 })

            eq(addon.Detect.waveMode, "ENEMIES_REMAINING", "tier 2")
            eq(addon.Detect.waveCount, 5, "counted on from wave 4, not from zero")
        end)
    end)

    it("does not drive state on a client that is only following", function()
        scenario(opts, function(addon, env)
            addon.State:StartTest("hyjal_winterchill")
            addon.State.testMode = false
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 0, isPlayer = true } })

            feedWorldState(addon, env, { 1, 2, 3, 5 })
            eq(addon.Detect.waveMode, "WAVE_NUMBER", "still classifies, for debug")
            eq(addon.State:Current().id, "wave1", "but did not move the state")
        end)
    end)

    it("surfaces the encounter a known NPC belongs to", function()
        scenario(opts, function(addon, env)
            env.instance = { name = "The Battle for Mount Hyjal", mapID = 534 }
            addon.Detect:CheckZone()
            addon.State:SetEncounter("hyjal_winterchill", "local")

            env.combatLog("SPELL_DAMAGE", "Creature-0-1-534-0-17842-1", "Azgalor",
                "Player-0-1", "Popperpig")
            eq(addon.State.encounterID, "hyjal_azgalor", "jumped to the right encounter")
        end)
    end)

    it("records an NPC it does not have on file instead of ignoring it", function()
        scenario(opts, function(addon, env)
            env.instance = { name = "The Battle for Mount Hyjal", mapID = 534 }
            addon.Detect:CheckZone()

            env.combatLog("SPELL_DAMAGE", "Creature-0-1-534-0-99999-1", "Unknown Horror",
                "Player-0-1", "Popperpig")

            eq(addon.Detect.seenNPCs[99999], "Unknown Horror", "harvested for /pprc scan")
            local report = table.concat(addon.Detect:ScanReport(), "\n")
            truthy(report:find("NOT IN Data/", 1, true), "flagged as a gap")
        end)
    end)

    it("does not re-fire state for the same NPC on every combat log line", function()
        scenario(opts, function(addon, env)
            env.instance = { name = "The Battle for Mount Hyjal", mapID = 534 }
            addon.Detect:CheckZone()

            local fires = 0
            addon:Listen("STATE_CHANGED", function() fires = fires + 1 end)

            for _ = 1, 50 do
                env.combatLog("SPELL_DAMAGE", "Creature-0-1-534-0-17767-1", "Rage Winterchill",
                    "Player-0-1", "Popperpig")
            end
            eq(fires, 1, "fifty combat log lines, one state change")
        end)
    end)

    it("advances a phase when boss health crosses the threshold", function()
        scenario(opts, function(addon, env)
            addon:RegisterInstance({
                id = "fixture", mapID = 9999, name = "Fixture", order = { "fx_boss" },
                encounters = { fx_boss = { name = "Fixture Boss", npcID = 4242, steps = {
                    { id = "p1", label = "Phase 1", advance = "manual" },
                    { id = "p2", label = "Phase 2", advance = "health_pct", healthPct = 65 },
                } } },
            })
            addon.State:StartTest("fx_boss")

            env.units.target = { name = "Fixture Boss", guid = "Creature-0-1-9999-0-4242-1", hp = 80, hpMax = 100 }
            addon.Detect:PollHealth()
            eq(addon.State:Current().id, "p1", "80% has not crossed 65%")

            env.units.target.hp = 60
            addon.Detect:PollHealth()
            eq(addon.State:Current().id, "p2", "crossed the threshold")
        end)
    end)

    it("leaves phases to the RL when there is no health source", function()
        scenario(opts, function(addon, env)
            addon:RegisterInstance({
                id = "fixture2", mapID = 9998, name = "Fixture", order = { "fx2" },
                encounters = { fx2 = { name = "Fixture Boss", npcID = 4243, steps = {
                    { id = "p1", label = "Phase 1", advance = "manual" },
                    { id = "p2", label = "Phase 2", advance = "health_pct", healthPct = 65 },
                } } },
            })
            addon.State:StartTest("fx2")

            -- Nothing targeted, no boss tokens: BossHealthPct returns nil.
            addon.Detect:PollHealth()
            eq(addon.State:Current().id, "p1", "degraded to manual rather than guessing")
        end)
    end)

    it("only polls health while the next step is gated on it", function()
        scenario(opts, function(addon)
            addon:RegisterInstance({
                id = "fixture3", mapID = 9997, name = "Fixture", order = { "fx3" },
                encounters = { fx3 = { name = "Fixture Boss", npcID = 4244, steps = {
                    { id = "p1", label = "Phase 1", advance = "manual" },
                    { id = "p2", label = "Phase 2", advance = "health_pct", healthPct = 65 },
                    { id = "p3", label = "Phase 3", advance = "manual" },
                } } },
            })
            addon.State:StartTest("fx3")
            truthy(addon.Detect.healthTicker, "polling while a health step is next")

            addon.State:GoToStep(2, "local")
            isNil(addon.Detect.healthTicker, "stopped once it is not")
        end)
    end)

    it("reads a wipe from the bodies on the floor", function()
        scenario(opts, function(addon, env)
            local members = {}
            for i = 1, 10 do
                members[i] = { name = "P" .. i, class = "MAGE", dead = i <= 8, isPlayer = i == 1 }
            end
            env.buildRaid(members)

            local wiped
            addon:Listen("COMBAT_END", function(w) wiped = w end)
            env.fire("PLAYER_REGEN_ENABLED")
            eq(wiped, true, "8 of 10 dead reads as a wipe")
        end)
    end)

    it("does not read a clean kill as a wipe", function()
        scenario(opts, function(addon, env)
            local members = {}
            for i = 1, 10 do
                members[i] = { name = "P" .. i, class = "MAGE", dead = i <= 2, isPlayer = i == 1 }
            end
            env.buildRaid(members)

            local wiped, wipeFired = nil, false
            addon:Listen("COMBAT_END", function(w) wiped = w end)
            addon:Listen("WIPE_DETECTED", function() wipeFired = true end)
            env.fire("PLAYER_REGEN_ENABLED")

            eq(wiped, false, "2 of 10 dead is a kill, not a wipe")
            falsy(wipeFired, "no wipe signal")
        end)
    end)

    it("dumps your own buffs by exact name, flagging the recognised ones", function()
        scenario(opts, function(addon, env)
            env.units.player.auras = {
                { name = "Flask of Relentless Assault", spellId = 28520 },
                { name = "Arcane Intellect",            spellId = 27126 },
            }
            local report = table.concat(addon.Detect:ScanReport(), "\n")

            truthy(report:find("Flask of Relentless Assault", 1, true), "exact name shown")
            truthy(report:find("28520", 1, true), "spell id shown")
            truthy(report:find("Arcane Intellect", 1, true), "unrecognised buffs shown too")
            -- The flask is in Data/Consumables.lua; the intellect buff is not.
            local flaskLine = report:match("(Flask of Relentless Assault[^\n]*)")
            truthy(flaskLine:find("recognised", 1, true), "known name flagged: " .. tostring(flaskLine))
        end)
    end)

    it("names the active tier for each chain", function()
        scenario(opts, function(addon, env)
            addon.State:StartTest("hyjal_winterchill")
            local report = table.concat(addon.Detect:TierReport(), "\n")
            truthy(report:find("not yet classified", 1, true), "honest before it knows")

            feedWorldState(addon, env, { 1, 2, 3 })
            report = table.concat(addon.Detect:TierReport(), "\n")
            truthy(report:find("tier 1", 1, true), "names tier 1 once resolved")
        end)
    end)

    it("resets its wave tracking when the instance changes", function()
        scenario(opts, function(addon, env)
            addon.State:StartTest("hyjal_winterchill")
            feedWorldState(addon, env, { 1, 2, 3 })
            eq(addon.Detect.waveMode, "WAVE_NUMBER", "classified")

            env.instance = { name = "Orgrimmar", mapID = 1 }
            addon.Detect:CheckZone()
            isNil(addon.Detect.waveMode, "classification cleared on leaving")
        end)
    end)
end

-- Relay whatever the addon just put on the wire back into it, but attributed
-- to somebody else. That exercises the real encode -> wire -> decode -> gate
-- -> apply path; it is a loopback rather than two live clients, which the
-- harness cannot host in one Lua state.
local function relay(addon, env, fromName, index)
    local sent = env.addonMessages[index or #env.addonMessages]
    if not sent then return false end
    env.fire("CHAT_MSG_ADDON", sent.prefix, sent.msg, sent.channel, fromName)
    return true
end

local function drainAddon(env, addon)
    for _ = 1, 60 do env.advance(0.1, addon) end
end

local function suiteCodec(profile, opts)
    group("Codec [" .. profile .. "]")

    it("round-trips strings, numbers, booleans and arrays", function()
        scenario(opts, function(addon)
            local Codec = addon.Codec
            local original = {
                e = "hyjal_winterchill", s = 6, ready = true, off = false,
                names = { "Vexmoor", "Aeliswyn", "Kethran" },
            }
            local decoded = Codec.Decode(Codec.Encode(original))

            eq(decoded.e, "hyjal_winterchill", "string")
            eq(decoded.s, 6, "number stays a number")
            eq(decoded.ready, true, "true")
            eq(decoded.off, false, "false, not nil")
            eq(#decoded.names, 3, "array length")
            eq(decoded.names[2], "Aeliswyn", "array contents")
        end)
    end)

    it("survives separators and realm names inside values", function()
        scenario(opts, function(addon)
            local Codec = addon.Codec
            local original = { note = "a~b=c,d:e%f", who = "Sollura-Golemagg" }
            local decoded = Codec.Decode(Codec.Encode(original))
            eq(decoded.note, "a~b=c,d:e%f", "every separator escaped and restored")
            eq(decoded.who, "Sollura-Golemagg", "realm-qualified name")
        end)
    end)

    it("encodes deterministically so duplicates can be collapsed", function()
        scenario(opts, function(addon)
            local a = addon.Codec.Encode({ z = 1, a = 2, m = 3 })
            local b = addon.Codec.Encode({ m = 3, a = 2, z = 1 })
            eq(a, b, "same table, same bytes regardless of pairs() order")
        end)
    end)

    it("sends a small payload as a single frame", function()
        scenario(opts, function(addon)
            local frames = addon.Codec.Frame("STATE", { e = "hyjal_winterchill", s = 6 })
            eq(#frames, 1, "one frame")
            truthy(#frames[1] <= 255, "inside the addon message cap")
        end)
    end)

    -- The plan says chunking is not needed. For a 25-name roster it is.
    it("chunks a 25-name assignment and reassembles it exactly", function()
        scenario(opts, function(addon)
            local names = {}
            for i = 1, 25 do names[i] = "Raiderlongname" .. i end
            local payload = { corner_a = names, corner_b = names }

            local frames = addon.Codec.Frame("ASSIGN", payload)
            truthy(#frames > 1, "actually needed more than one frame")
            for _, frame in ipairs(frames) do
                truthy(#frame <= 255, "each frame inside the cap")
            end

            local messageType, decoded
            for _, frame in ipairs(frames) do
                messageType, decoded = addon.Codec.Receive("Sollura", frame)
            end
            eq(messageType, "ASSIGN", "type preserved")
            eq(#decoded.corner_a, 25, "all names arrived")
            eq(decoded.corner_a[25], "Raiderlongname25", "last name intact")
        end)
    end)

    it("returns nothing until every chunk has arrived", function()
        scenario(opts, function(addon)
            local names = {}
            for i = 1, 25 do names[i] = "Raiderlongname" .. i end
            local frames = addon.Codec.Frame("ASSIGN", { corner_a = names, corner_b = names })

            local messageType = addon.Codec.Receive("Sollura", frames[1])
            isNil(messageType, "incomplete payload yields nothing")
            truthy(addon.Codec.PendingCount() > 0, "partial buffered")
        end)
    end)

    it("does not interleave two senders chunking at the same time", function()
        scenario(opts, function(addon)
            local a, b = {}, {}
            for i = 1, 25 do a[i] = "Alpha" .. i; b[i] = "Bravo" .. i end
            local framesA = addon.Codec.Frame("ASSIGN", { x = a, y = a })
            local framesB = addon.Codec.Frame("ASSIGN", { x = b, y = b })

            -- Interleave them the way two people broadcasting at once would.
            local decodedA, decodedB
            for i = 1, math.max(#framesA, #framesB) do
                if framesA[i] then
                    local _, d = addon.Codec.Receive("Sollura", framesA[i])
                    decodedA = d or decodedA
                end
                if framesB[i] then
                    local _, d = addon.Codec.Receive("Kethran", framesB[i])
                    decodedB = d or decodedB
                end
            end

            eq(decodedA.x[1], "Alpha1", "sender A's payload intact")
            eq(decodedB.x[1], "Bravo1", "sender B's payload intact")
        end)
    end)

    it("drops a stale partial rather than leaking it forever", function()
        scenario(opts, function(addon, env)
            local names = {}
            for i = 1, 25 do names[i] = "Raiderlongname" .. i end
            local frames = addon.Codec.Frame("ASSIGN", { x = names, y = names })
            addon.Codec.Receive("Sollura", frames[1])
            truthy(addon.Codec.PendingCount() > 0, "buffered")

            env.now = env.now + 120
            addon.Codec.PurgeStale()
            eq(addon.Codec.PendingCount(), 0, "purged")
        end)
    end)
end

local function suiteComm(profile, opts)
    group("Comm [" .. profile .. "]")

    local function raidWithLeader(env)
        env.buildRaid({
            { name = "Popperpig", class = "WARRIOR", rank = 0, isPlayer = true },
            { name = "Sollura",   class = "PALADIN", rank = 2 },
            { name = "Kethran",   class = "HUNTER",  rank = 0 },
        })
    end

    it("broadcasts a local state change and follows a remote one", function()
        scenario(opts, function(addon, env)
            env.buildRaid({
                { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true },
                { name = "Sollura",   class = "PALADIN", rank = 2 },
            })
            addon.State:SetEncounter("hyjal_winterchill", "local")
            addon.State:GoToStep(4, "local")
            drainAddon(env, addon)

            truthy(#env.addonMessages > 0, "something went on the wire")

            -- Come back as the other leader, and confirm we apply it.
            addon.State:GoToStep(1, "local")
            relay(addon, env, "Sollura", 2)
            eq(addon.State.stepIndex, 4, "followed the remote state")
        end)
    end)

    it("discards a forged payload from someone without rank", function()
        scenario(opts, function(addon, env)
            raidWithLeader(env)
            addon.State:SetEncounter("hyjal_winterchill", "remote")

            -- Build a legitimate-looking STATE frame and send it as Kethran,
            -- who holds no rank at all.
            local frame = addon.Codec.Frame("STATE", { e = "hyjal_azgalor", s = 9 })[1]
            env.fire("CHAT_MSG_ADDON", "PPRC", frame, "RAID", "Kethran")

            eq(addon.State.encounterID, "hyjal_winterchill", "state untouched")
            truthy(table.concat(addon.logBuffer, "\n"):find("discarded", 1, true), "and said why")
        end)
    end)

    it("accepts the same payload once that player has assist", function()
        scenario(opts, function(addon, env)
            raidWithLeader(env)
            addon.State:SetEncounter("hyjal_winterchill", "remote")

            env.raidRoster[3].rank = 1   -- Kethran is given assist
            local frame = addon.Codec.Frame("STATE", { e = "hyjal_azgalor", s = 9 })[1]
            env.fire("CHAT_MSG_ADDON", "PPRC", frame, "RAID", "Kethran")

            eq(addon.State.encounterID, "hyjal_azgalor", "now accepted")
        end)
    end)

    it("ignores its own broadcast coming back", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true } })
            addon.State:SetEncounter("hyjal_winterchill", "local")
            drainAddon(env, addon)

            local fires = 0
            addon:Listen("STATE_CHANGED", function() fires = fires + 1 end)
            relay(addon, env, "Popperpig")
            eq(fires, 0, "own message ignored, no ping-pong")
        end)
    end)

    it("does not rebroadcast a change it was just told about", function()
        scenario(opts, function(addon, env)
            env.buildRaid({
                { name = "Popperpig", class = "WARRIOR", rank = 1, isPlayer = true },
                { name = "Sollura",   class = "PALADIN", rank = 2 },
            })
            addon.State:SetEncounter("hyjal_winterchill", "remote")
            drainAddon(env, addon)
            local before = #env.addonMessages

            addon.State:GoToStep(5, "remote")
            drainAddon(env, addon)
            eq(#env.addonMessages, before, "a remote change put nothing on the wire")
        end)
    end)

    it("answers a state request, and only once for a burst of them", function()
        scenario(opts, function(addon, env)
            env.buildRaid({
                { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true },
                { name = "Sollura",   class = "PALADIN", rank = 0 },
            })
            addon.State:SetEncounter("hyjal_kazrogal", "local")
            drainAddon(env, addon)
            local before = #env.addonMessages

            local request = addon.Codec.Frame("REQ_STATE", {})[1]
            for _ = 1, 10 do
                env.fire("CHAT_MSG_ADDON", "PPRC", request, "RAID", "Sollura")
            end
            drainAddon(env, addon)

            local replies = #env.addonMessages - before
            truthy(replies >= 1, "answered")
            truthy(replies <= 2, "ten requests did not produce ten replies (got " .. replies .. ")")
        end)
    end)

    it("restores a reloaded client from the controller's reply", function()
        scenario(opts, function(addon, env)
            env.buildRaid({
                { name = "Popperpig", class = "WARRIOR", rank = 0, isPlayer = true },
                { name = "Sollura",   class = "PALADIN", rank = 2 },
            })
            -- Fresh client: nothing loaded, as after a /reload mid-fight.
            isNil(addon.State.encounterID, "starts blank")

            local reply = addon.Codec.Frame("STATE", { e = "hyjal_azgalor", s = 7 })[1]
            env.fire("CHAT_MSG_ADDON", "PPRC", reply, "RAID", "Sollura")

            eq(addon.State.encounterID, "hyjal_azgalor", "caught up")
            eq(addon.State.stepIndex, 7, "on the right step")
            truthy(addon.Comm:HasController(), "knows who is driving")
        end)
    end)

    it("reports no controller once the leader goes quiet", function()
        scenario(opts, function(addon, env)
            env.buildRaid({
                { name = "Popperpig", class = "WARRIOR", rank = 0, isPlayer = true },
                { name = "Sollura",   class = "PALADIN", rank = 2 },
            })
            local frame = addon.Codec.Frame("STATE", { e = "hyjal_azgalor", s = 2 })[1]
            env.fire("CHAT_MSG_ADDON", "PPRC", frame, "RAID", "Sollura")
            truthy(addon.Comm:HasController(), "live right after a broadcast")

            env.now = env.now + 300
            falsy(addon.Comm:HasController(), "gone quiet")
        end)
    end)

    it("applies pushed assignments only from someone with rank", function()
        scenario(opts, function(addon, env)
            raidWithLeader(env)

            local payload = { corner_a = { "Vexmoor" }, corner_b = { "Aeliswyn" } }
            local frame = addon.Codec.Frame("ASSIGN", payload)[1]

            env.fire("CHAT_MSG_ADDON", "PPRC", frame, "RAID", "Kethran")
            isNil(addon.db.assignments.corner_a, "rejected from a plain raider")

            env.fire("CHAT_MSG_ADDON", "PPRC", frame, "RAID", "Sollura")
            eq(addon.db.assignments.corner_a[1], "Vexmoor", "accepted from the leader")
        end)
    end)

    it("tallies versions for the sync report", function()
        scenario(opts, function(addon, env)
            raidWithLeader(env)
            addon.version = "v1.2.0"

            local old = addon.Codec.Frame("VERSION", { v = "v1.0.0" })[1]
            local same = addon.Codec.Frame("VERSION", { v = "v1.2.0" })[1]
            env.fire("CHAT_MSG_ADDON", "PPRC", old, "RAID", "Sollura")
            env.fire("CHAT_MSG_ADDON", "PPRC", same, "RAID", "Kethran")

            local report = addon.Comm:VersionReport()
            truthy(report:find("3/3", 1, true), "counts who is running it: " .. report)
            truthy(report:find("1 outdated", 1, true), "flags the old one")
        end)
    end)

    it("sends nothing at all in test mode", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true } })
            addon.State:StartTest("hyjal_winterchill")
            addon.State:Advance("local")
            drainAddon(env, addon)
            eq(#env.addonMessages, 0, "test mode never touches the raid")
        end)
    end)

    it("degrades to a working addon when the client has no addon messaging", function()
        _G.PopperpigRaidCallDB = nil
        _G.PopperpigRaidCall = nil
        local env = stubs.install({
            modern = opts.modern, worldState = opts.worldState,
            missingEvents = { CHAT_MSG_ADDON = true },
        })
        env.units.player = { name = "Popperpig", class = "WARRIOR", guid = "Player-0-1" }
        local addon = loadAddon(env)

        addon.State:StartTest("hyjal_winterchill")
        addon.State:Advance("local")
        eq(addon.State:Current().id, "wave2", "state machine still works with no comms")
        env.restore()
    end)
end

local function suiteRoster(profile, opts)
    group("Roster [" .. profile .. "]")

    local FLASK = { name = "Flask of Relentless Assault", spellId = 28520 }
    local FOOD  = { name = "Well Fed", spellId = 33257 }

    local function standardRaid(env)
        env.buildRaid({
            { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true, auras = { FLASK, FOOD } },
            { name = "Sollura",   class = "PALADIN", auras = { FLASK, FOOD }, inRange = false },
            { name = "Aeliswyn",  class = "MAGE",    auras = {} },
            { name = "Kethran",   class = "HUNTER",  auras = { FOOD } },
            { name = "Brannoc",   class = "ROGUE",   auras = { FLASK } },
            { name = "Vexmoor",   class = "WARLOCK", auras = { FOOD }, dead = true },
        })
    end

    it("counts alive, in range, flask and food from the game", function()
        scenario(opts, function(addon, env)
            standardRaid(env)
            local _, summary = addon.Roster:Scan()

            eq(summary.total, 6, "roster size")
            eq(summary.alive, 5, "one dead")
            eq(summary.inRange, 5, "one out of range")
            eq(summary.flask, 3, "three flasked")
            eq(summary.food, 4, "four fed")
        end)
    end)

    it("counts an elixir as consumed, since we cannot count how many", function()
        scenario(opts, function(addon, env)
            env.buildRaid({
                { name = "Popperpig", class = "WARRIOR", isPlayer = true,
                  auras = { { name = "Elixir of Major Agility", spellId = 1 } } },
            })
            local players, summary = addon.Roster:Scan()
            eq(players[1].flask, false, "no flask")
            eq(players[1].elixir, true, "but an elixir")
            eq(summary.flask, 1, "counted as consumed")
        end)
    end)

    -- The heart of the plan's honesty rule.
    it("reports unknown, not zero, when the client cannot read auras", function()
        _G.PopperpigRaidCallDB = nil
        _G.PopperpigRaidCall = nil
        local env = stubs.install({ modern = opts.modern, worldState = opts.worldState, noAuras = true })
        env.units.player = { name = "Popperpig", class = "WARRIOR", guid = "Player-0-1" }
        local addon = loadAddon(env)

        env.buildRaid({
            { name = "Popperpig", class = "WARRIOR", isPlayer = true },
            { name = "Sollura",   class = "PALADIN" },
        })
        local players, summary = addon.Roster:Scan()

        isNil(players[1].flask, "flask unreadable, not false")
        eq(summary.flask, 0, "nothing counted as having one")
        eq(summary.flaskUnknown, 2, "both counted as unknown")

        -- And nobody is accused of missing a flask on that basis.
        eq(#addon.Roster:Offenders(), 0, "no offenders invented from a gap in our reading")
        env.restore()
    end)

    it("lists offenders with only what is actually wrong", function()
        scenario(opts, function(addon, env)
            standardRaid(env)
            addon.Roster:Scan()

            local byName = {}
            for _, entry in ipairs(addon.Roster:Offenders()) do
                byName[entry.player.name] = table.concat(entry.issues, ",")
            end

            eq(byName["Aeliswyn"], "no flask,no food", "missing both")
            eq(byName["Kethran"], "no flask", "missing only a flask")
            eq(byName["Brannoc"], "no food", "missing only food")
            isNil(byName["Popperpig"], "fully buffed player is not an offender")
            truthy(byName["Sollura"]:find("out of range"), "range noted")
        end)
    end)

    it("summarises in one line with counts and no names", function()
        scenario(opts, function(addon, env)
            standardRaid(env)
            local line = addon.Roster:SummaryLine()

            truthy(line:find("3 missing flask", 1, true), "flask count: " .. line)
            truthy(line:find("2 missing food", 1, true), "food count")
            falsy(line:find("Aeliswyn", 1, true), "no names in the announcement")
            falsy(line:find("\n", 1, true), "one line")
        end)
    end)

    it("says so plainly when everyone is ready", function()
        scenario(opts, function(addon, env)
            env.buildRaid({
                { name = "Popperpig", class = "WARRIOR", isPlayer = true, auras = { FLASK, FOOD } },
                { name = "Sollura",   class = "PALADIN", auras = { FLASK, FOOD } },
            })
            truthy(addon.Roster:SummaryLine():find("all 2 ready", 1, true), "clean report")
        end)
    end)

    it("whispers only about things a raider can fix standing there", function()
        scenario(opts, function(addon, env)
            standardRaid(env)
            addon.Roster:Scan()
            addon.Roster:WhisperOffenders()
            drainAddon(env, addon)

            local whispered = {}
            for _, message in ipairs(env.chat) do
                if message.channel == "WHISPER" then whispered[message.target] = message.msg end
            end

            truthy(whispered["Aeliswyn"], "told about consumables")
            truthy(whispered["Kethran"], "told about a missing flask")
            isNil(whispered["Sollura"], "not whispered merely for being out of range")
            isNil(whispered["Vexmoor"], "not told they are dead, which they know")
        end)
    end)

    it("splits a wipe into alive, released and still a corpse", function()
        scenario(opts, function(addon, env)
            env.buildRaid({
                { name = "A", class = "WARRIOR", isPlayer = true },
                { name = "B", class = "MAGE",   dead = true, ghost = true },
                { name = "C", class = "PRIEST", dead = true, ghost = true },
                { name = "D", class = "ROGUE",  dead = true },
            })
            local status = addon.Roster:WipeScan()

            eq(status.total, 4, "everyone counted")
            eq(status.alive, 1, "one still up")
            eq(status.released, 2, "two ghosts running back")
            eq(status.corpse, 1, "one waiting on a res")
        end)
    end)
end

local function suiteReadiness(profile, opts)
    group("Readiness [" .. profile .. "]")

    local FLASK = { name = "Flask of Relentless Assault", spellId = 28520 }
    local FOOD  = { name = "Well Fed", spellId = 33257 }

    it("renders the summary tiles", function()
        scenario(opts, function(addon, env)
            env.buildRaid({
                { name = "Popperpig", class = "WARRIOR", isPlayer = true, auras = { FLASK, FOOD } },
                { name = "Sollura",   class = "PALADIN", auras = { FLASK } },
                { name = "Aeliswyn",  class = "MAGE",    auras = {} },
            })
            addon.Readiness:Show()

            eq(addon.Readiness.tiles.alive.value:GetText(), "3/3", "alive tile")
            eq(addon.Readiness.tiles.flask.value:GetText(), "2/3", "flask tile")
            eq(addon.Readiness.tiles.food.value:GetText(), "1/3", "food tile")
            truthy(addon.Readiness.readyCount:GetText():find("/ 3 READY", 1, true), "ready count")
        end)
    end)

    it("shows a question mark, not a red zero, when auras are unreadable", function()
        _G.PopperpigRaidCallDB = nil
        _G.PopperpigRaidCall = nil
        local env = stubs.install({ modern = opts.modern, worldState = opts.worldState, noAuras = true })
        env.units.player = { name = "Popperpig", class = "WARRIOR", guid = "Player-0-1" }
        local addon = loadAddon(env)

        env.buildRaid({ { name = "Popperpig", class = "WARRIOR", isPlayer = true } })
        addon.Readiness:Show()

        eq(addon.Readiness.tiles.flask.value:GetText(), "?", "unknown, not 0/1")
        truthy(addon.Readiness.footerNote:GetText():find("cannot read auras", 1, true), "and says why")
        env.restore()
    end)

    it("lists offenders and says when there are none", function()
        scenario(opts, function(addon, env)
            env.buildRaid({
                { name = "Popperpig", class = "WARRIOR", isPlayer = true, auras = { FLASK, FOOD } },
                { name = "Aeliswyn",  class = "MAGE",    auras = {} },
            })
            addon.Readiness:Show()
            truthy(addon.Readiness.list.rows[1].left:GetText():find("Aeliswyn", 1, true), "offender listed")

            env.units.raid2.auras = { FLASK, FOOD }
            addon.Readiness:Refresh()
            truthy(addon.Readiness.listHeading:GetText():find("everyone readable is ready", 1, true), "clean state")
        end)
    end)

    it("renders the manual checklist from encounter data and remembers ticks", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", isPlayer = true } })
            addon.State:StartTest("hyjal_archimonde")
            addon.Readiness:Show()

            local box = addon.Readiness.checkboxes[1]
            truthy(box:IsShown(), "checklist shown for Archimonde")
            truthy(box._key, "keyed to the encounter")

            box:GetScript("OnClick")(box)
            truthy(addon.db.checklist[box._key], "tick persisted")

            -- Rebuild from the db, as a /reload would.
            addon.Readiness:RefreshChecklist()
            truthy(addon.Readiness.checkboxes[1]:GetChecked(), "tick restored")
        end)
    end)

    it("hides the checklist on a step that has none", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", isPlayer = true } })
            addon.State:StartTest("hyjal_winterchill")
            addon.Readiness:Show()
            falsy(addon.Readiness.checkboxes[1]:IsShown(), "nothing to tick")
            truthy(addon.Readiness.checkHeading:GetText():find("no manual checks", 1, true), "says so")
        end)
    end)

    it("switches to wipe recovery when the raid goes down", function()
        scenario(opts, function(addon, env)
            local members = {}
            for i = 1, 10 do
                members[i] = { name = "P" .. i, class = "MAGE", dead = i <= 8, ghost = i <= 5, isPlayer = i == 1 }
            end
            env.buildRaid(members)

            env.fire("PLAYER_REGEN_ENABLED")
            truthy(addon.Readiness.wipeMode, "entered wipe mode")
            truthy(addon.Readiness.frame.title:GetText():find("WIPE RECOVERY", 1, true), "retitled")
            eq(addon.Readiness.tiles.alive.value:GetText(), "2/10", "alive count")
            eq(addon.Readiness.tiles.food.caption:GetText(), "RELEASED", "tiles repurposed")
        end)
    end)

    it("leaves wipe mode on the next pull", function()
        scenario(opts, function(addon, env)
            local members = {}
            for i = 1, 10 do members[i] = { name = "P" .. i, class = "MAGE", dead = i <= 8, isPlayer = i == 1 } end
            env.buildRaid(members)

            env.fire("PLAYER_REGEN_ENABLED")
            truthy(addon.Readiness.wipeMode, "in wipe mode")
            env.fire("PLAYER_REGEN_DISABLED")
            falsy(addon.Readiness.wipeMode, "back to normal on the pull")
        end)
    end)
end

-- A four-corner encounter, so M6 can be exercised before Black Temple data
-- lands in M7. Mirrors the Teron layout the plan uses as its worked example.
local function registerTeronFixture(addon)
    addon:RegisterInstance({
        id = "fixture_bt", mapID = 8888, name = "Fixture Temple", order = { "fx_teron" },
        encounters = { fx_teron = {
            name = "Teron Gorefiend", tanks = 1, npcID = 22871,
            steps = {
                { id = "trash", label = "Promenade", advance = "manual" },
                { id = "boss",  label = "Teron Gorefiend", advance = "manual", posmap = "teron",
                  call = "Marked? Run to YOUR corner at 10s.",
                  brief = {
                      { spell = "Shadow of Death", text = "Marks a player; after 55s they die and spawn four constructs." },
                      { spell = "Ghost action bar", text = "Slow the four, then burn them before the ghost expires." },
                  } },
            },
        } },
    })
end

local function suitePosMap(profile, opts)
    group("PosMap [" .. profile .. "]")

    it("maps raid target icon indices onto the icon sheet", function()
        scenario(opts, function(addon)
            local l, r, t, b = addon.PosMap:MarkCoords(1)   -- star, top-left
            eq(l, 0, "star left"); eq(t, 0, "star top"); eq(r, 0.25, "star right")

            l, r, t, b = addon.PosMap:MarkCoords(8)         -- skull, second row end
            eq(l, 0.75, "skull left"); eq(t, 0.25, "skull top"); eq(b, 0.5, "skull bottom")
        end)
    end)

    it("indexes every layout's slots by id", function()
        scenario(opts, function(addon)
            local teron = addon.PosMap:Layout("teron")
            truthy(teron, "layout present")
            eq(#teron.slots, 5, "five slots")
            eq(teron.slotsByID.ghost_l.where, "top of the stairs, LEFT side", "landmark, not a bare cardinal")
            eq(teron.slotsByID.ghost_l.mark, 1, "star on the left drop point")
        end)
    end)

    it("reports which positions are still empty", function()
        scenario(opts, function(addon)
            eq(#addon.PosMap:EmptySlots("teron", {}), 5, "all empty")
            eq(#addon.PosMap:EmptySlots("teron", { ghost_l = "Vexmoor", ghost_r = "Aeliswyn" }), 3, "two filled")
            eq(#addon.PosMap:EmptySlots("teron", {
                mt = "A", melee = "B", healers = "C", ghost_l = "D", ghost_r = "E" }), 0, "all filled")
        end)
    end)

    it("renders a layout and hides an unknown one instead of erroring", function()
        scenario(opts, function(addon)
            local map = addon.PosMap:Create(_G.UIParent, {})
            truthy(addon.PosMap:Render(map, "teron", {}), "known layout renders")
            eq(map.landmarks.top:GetText(), "TOP OF THE STAIRS", "landmark drawn")
            eq(map.bossLabel:GetText(), "TERON", "boss labelled")
            eq(map.slots[1].who:GetText(), "- empty -", "empty slot flagged")

            falsy(addon.PosMap:Render(map, "no_such_room", {}), "unknown layout refused")
            falsy(map:IsShown(), "and hidden")
        end)
    end)

    it("puts the diagram's icons on the assigned players", function()
        scenario(opts, function(addon, env)
            env.buildRaid({
                { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true },
                { name = "Vexmoor",   class = "WARLOCK" },
                { name = "Aeliswyn",  class = "MAGE" },
            })
            local applied, failed = addon.PosMap:ApplyMarks("teron",
                { ghost_l = "Vexmoor", ghost_r = "Aeliswyn" })

            eq(applied, 2, "both marked")
            eq(failed, 0, "no failures")
            eq(env.marks.raid2, 1, "Vexmoor got the star")
            eq(env.marks.raid3, 3, "Aeliswyn got the diamond")
        end)
    end)

    it("reports failure rather than pretending, when marking is refused", function()
        scenario(opts, function(addon, env)
            env.buildRaid({
                { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true },
                { name = "Vexmoor",   class = "WARLOCK" },
            })
            env.raidTargetsBlocked = true

            local applied, failed = addon.PosMap:ApplyMarks("teron", { ghost_l = "Vexmoor" })
            eq(applied, 0, "nothing applied")
            eq(failed, 1, "and it said so")
        end)
    end)

    it("counts someone who left the raid as a failure, not a mark", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true } })
            local applied, failed = addon.PosMap:ApplyMarks("teron", { ghost_l = "Ghostperson" })
            eq(applied, 0, "nobody to mark")
            eq(failed, 1, "reported")
        end)
    end)
end

local function suiteRosterUI(profile, opts)
    group("RosterUI [" .. profile .. "]")

    local function teronRaid(env)
        env.buildRaid({
            { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true, role = "TANK" },
            { name = "Vexmoor",   class = "WARLOCK", role = "DAMAGER" },
            { name = "Aeliswyn",  class = "MAGE",    role = "DAMAGER" },
            { name = "Kethran",   class = "HUNTER" },   -- role NONE
            { name = "Brannoc",   class = "ROGUE",   role = "DAMAGER" },
            { name = "Sorrelin",  class = "PRIEST",  role = "HEALER" },
        })
    end

    -- The plan's own M6 acceptance scenario.
    it("drags five raiders onto the Teron diagram and pushes", function()
        scenario(opts, function(addon, env)
            teronRaid(env)
            registerTeronFixture(addon)
            addon.State:StartTest("fx_teron")
            addon.State:GoToStep(2, "local")
            addon.State.testMode = false
            addon.RosterUI:Show()

            addon.RosterUI:Select("Vexmoor");  addon.RosterUI:OnSlotClick("ghost_l")
            addon.RosterUI:Select("Aeliswyn"); addon.RosterUI:OnSlotClick("ghost_r")
            addon.RosterUI:Select("Kethran");  addon.RosterUI:OnSlotClick("mt")
            addon.RosterUI:Select("Brannoc");  addon.RosterUI:OnSlotClick("melee")
            addon.RosterUI:Select("Sorrelin"); addon.RosterUI:OnSlotClick("healers")

            local assignments = addon.Roster:Assignments()
            eq(assignments.ghost_l, "Vexmoor", "left drop point")
            eq(assignments.melee, "Brannoc", "melee")
            eq(#addon.PosMap:EmptySlots("teron", assignments), 0, "no gaps")

            truthy(addon.RosterUI:Push(), "pushed with every slot filled")
            drainAddon(env, addon)
            truthy(#env.addonMessages > 0, "assignments went out")
        end)
    end)

    it("blocks a push while a position is empty, until it is confirmed", function()
        scenario(opts, function(addon, env)
            teronRaid(env)
            registerTeronFixture(addon)
            addon.State:StartTest("fx_teron")
            addon.State:GoToStep(2, "local")
            addon.State.testMode = false
            addon.RosterUI:Show()

            addon.RosterUI:Select("Vexmoor"); addon.RosterUI:OnSlotClick("ghost_l")

            falsy(addon.RosterUI:Push(), "first push refused")
            eq(addon.RosterUI.pushBtn._label:GetText(), "PUSH ANYWAY?", "asks for confirmation")
            truthy(addon.RosterUI.footerNote:GetText():find("4 positions still empty", 1, true), "says how many")

            truthy(addon.RosterUI:Push(), "second push goes through")
        end)
    end)

    it("moves a raider rather than cloning them into two positions", function()
        scenario(opts, function(addon, env)
            teronRaid(env)
            registerTeronFixture(addon)
            addon.State:StartTest("fx_teron")
            addon.State:GoToStep(2, "local")
            addon.RosterUI:Show()

            addon.RosterUI:Select("Vexmoor"); addon.RosterUI:OnSlotClick("ghost_l")
            addon.RosterUI:Select("Vexmoor"); addon.RosterUI:OnSlotClick("ghost_r")

            local assignments = addon.Roster:Assignments()
            isNil(assignments.ghost_l, "left the old spot")
            eq(assignments.ghost_r, "Vexmoor", "took the new one")
        end)
    end)

    it("clears a position when a slot is clicked with nobody selected", function()
        scenario(opts, function(addon, env)
            teronRaid(env)
            registerTeronFixture(addon)
            addon.State:StartTest("fx_teron")
            addon.State:GoToStep(2, "local")
            addon.RosterUI:Show()

            addon.RosterUI:Select("Vexmoor"); addon.RosterUI:OnSlotClick("ghost_l")
            eq(addon.Roster:Assignments().ghost_l, "Vexmoor", "assigned")

            addon.RosterUI:OnSlotClick("ghost_l")
            isNil(addon.Roster:Assignments().ghost_l, "cleared")
        end)
    end)

    it("shows an unset role as unset rather than filling it in from class", function()
        scenario(opts, function(addon, env)
            teronRaid(env)
            registerTeronFixture(addon)
            addon.State:StartTest("fx_teron")
            addon.RosterUI:Show()

            local rows = addon.RosterUI.list.rows
            local byName = {}
            for i = 1, 5 do byName[rows[i]._name] = rows[i].right:GetText() end

            truthy(byName["Popperpig"]:find("TANK", 1, true), "role shown when the game has one")
            truthy(byName["Kethran"]:find("unset", 1, true), "and left unset when it does not")
            falsy(byName["Kethran"]:find("DAMAGER", 1, true), "never inferred from class")
        end)
    end)

    it("refuses a push from someone without rank", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 0, isPlayer = true } })
            registerTeronFixture(addon)
            addon.State:StartTest("fx_teron")
            addon.State:GoToStep(2, "local")
            addon.State.testMode = false
            addon.RosterUI:Show()

            addon.RosterUI._confirmPush = true   -- past the empty-slot guard
            falsy(addon.RosterUI:Push(), "refused")
            truthy(table.concat(env.printed, "\n"):find("lead or assist", 1, true), "explained")
        end)
    end)

    it("says there is nothing to push when a step has neither diagram nor roles", function()
        scenario(opts, function(addon, env)
            teronRaid(env)
            registerTeronFixture(addon)
            addon.State:StartTest("fx_teron")   -- step 1 has no posmap
            addon.RosterUI:Show()

            falsy(addon.RosterUI:Push(), "refused")
            truthy(addon.RosterUI.footerNote:GetText():find("nothing to assign", 1, true), "and says why")
        end)
    end)
end

local function suiteBriefing(profile, opts)
    group("Briefing [" .. profile .. "]")

    it("renders mechanics and the words to say", function()
        scenario(opts, function(addon)
            registerTeronFixture(addon)
            addon.State:StartTest("fx_teron")
            addon.State:GoToStep(2, "local")
            addon.Briefing:Show()

            eq(addon.Briefing.spells[1].name:GetText(), "SHADOW OF DEATH", "first mechanic")
            truthy(addon.Briefing.spells[1].text:GetText():find("four constructs", 1, true), "its detail")
            truthy(addon.Briefing.sayText:GetText():find("YOUR corner", 1, true), "the literal call")
            truthy(addon.Briefing.frame.title:GetText():find("1 TANK", 1, true), "tank count in the header")
        end)
    end)

    it("dismisses itself on the pull", function()
        scenario(opts, function(addon, env)
            registerTeronFixture(addon)
            addon.State:StartTest("fx_teron")
            addon.State:GoToStep(2, "local")
            addon.Briefing:Show()
            truthy(addon.Briefing.frame:IsShown(), "open before the pull")

            env.fire("PLAYER_REGEN_DISABLED")
            falsy(addon.Briefing.frame:IsShown(), "gone when combat starts")
        end)
    end)

    it("lights only the raider's own position on their client", function()
        scenario(opts, function(addon, env)
            env.buildRaid({
                { name = "Popperpig", class = "WARRIOR", rank = 0, isPlayer = true },
                { name = "Vexmoor",   class = "WARLOCK" },
            })
            registerTeronFixture(addon)
            addon.State:Set("fx_teron", 2, "remote")
            addon.db.assignments = { ghost_l = "Vexmoor", ghost_r = "Popperpig" }
            addon.Briefing:Show()

            truthy(addon.Briefing.posHeading:GetText():find("YOURS IS LIT", 1, true), "raider view")
            -- ghost_r is ours (slot 5): full alpha. ghost_l is someone else's: dimmed.
            eq(addon.Briefing.map.slots[5].icon:GetAlpha(), 1, "own slot lit")
            eq(addon.Briefing.map.slots[4].icon:GetAlpha(), 0.25, "others dimmed")
        end)
    end)

    it("shows the full chart to whoever is driving", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true } })
            registerTeronFixture(addon)
            addon.State:Set("fx_teron", 2, "local")
            addon.Briefing:Show()

            eq(addon.Briefing.posHeading:GetText(), "POSITIONING", "no personal filter for the RL")
            eq(addon.Briefing.map.slots[1].icon:GetAlpha(), 1, "everything lit")
        end)
    end)

    it("opens when a raid leader pushes one", function()
        scenario(opts, function(addon, env)
            env.buildRaid({
                { name = "Popperpig", class = "WARRIOR", rank = 0, isPlayer = true },
                { name = "Sollura",   class = "PALADIN", rank = 2 },
            })
            registerTeronFixture(addon)

            local frame = addon.Codec.Frame("BRIEF", { e = "fx_teron", step = "boss" })[1]
            env.fire("CHAT_MSG_ADDON", "PPRC", frame, "RAID", "Sollura")

            truthy(addon.Briefing.frame:IsShown(), "opened for the raider")
            eq(addon.State.encounterID, "fx_teron", "and switched to the encounter")
        end)
    end)

    it("ignores a briefing pushed by someone without rank", function()
        scenario(opts, function(addon, env)
            env.buildRaid({
                { name = "Popperpig", class = "WARRIOR", rank = 0, isPlayer = true },
                { name = "Kethran",   class = "HUNTER",  rank = 0 },
            })
            registerTeronFixture(addon)

            local frame = addon.Codec.Frame("BRIEF", { e = "fx_teron", step = "boss" })[1]
            env.fire("CHAT_MSG_ADDON", "PPRC", frame, "RAID", "Kethran")
            falsy(addon.Briefing.frame:IsShown(), "not opened")
        end)
    end)

    it("stays usable on a step with no mechanic notes", function()
        scenario(opts, function(addon)
            addon.State:StartTest("hyjal_winterchill")   -- wave 1, no brief block
            addon.Briefing:Show()
            truthy(addon.Briefing.spells[1].text:GetText():find("No mechanic notes", 1, true), "says so")
            truthy(addon.Briefing.sayText:GetText():find("Ghouls only", 1, true), "still shows the call")
        end)
    end)
end

local function suiteBlackTemple(profile, opts)
    group("Black Temple [" .. profile .. "]")

    it("registers all nine encounters", function()
        scenario(opts, function(addon)
            local bt = addon.Instances.blacktemple
            truthy(bt, "instance registered")
            eq(bt.mapID, 564, "map id")
            eq(#bt.order, 9, "nine encounters")

            for _, encounterID in ipairs(bt.order) do
                local encounter = addon:GetEncounter(encounterID)
                truthy(encounter, encounterID .. " present")
                truthy(#encounter.steps > 0, encounterID .. " has steps")
            end
        end)
    end)

    it("keys every boss for combat-log surfacing", function()
        scenario(opts, function(addon)
            local bt = addon.Instances.blacktemple
            eq(bt.byNPC[22887].encounter, "bt_najentus", "Naj'entus")
            eq(bt.byNPC[22871].encounter, "bt_teron", "Teron")
            eq(bt.byNPC[22917].encounter, "bt_illidan", "Illidan")
            -- The council share one health pool but four bodies; all four key
            -- to the same encounter.
            for _, npcID in ipairs({ 22949, 22950, 22951, 22952 }) do
                eq(bt.byNPC[npcID].encounter, "bt_council", "council member " .. npcID)
            end
        end)
    end)

    it("keys the three Reliquary essences to their own phases", function()
        scenario(opts, function(addon)
            local bt = addon.Instances.blacktemple
            local suffering = bt.byNPC[23418]
            local desire    = bt.byNPC[23419]
            local anger     = bt.byNPC[23420]

            eq(suffering.encounter, "bt_reliquary", "suffering")
            eq(desire.encounter, "bt_reliquary", "desire")
            eq(anger.encounter, "bt_reliquary", "anger")
            truthy(desire.step ~= suffering.step, "each essence lands on its own step")
        end)
    end)

    -- Illidan's phases are NOT a linear health ladder. Only two transitions are
    -- health-gated; phases 3 and 4 alternate on a timer until 30%. An earlier
    -- version of this data gated demon form at 30%, which is where phase 5
    -- actually starts, so this test pins the real shape.
    it("health-gates only the two transitions that really are health-gated", function()
        scenario(opts, function(addon)
            local illidan = addon:GetEncounter("bt_illidan")

            local byID, gated = {}, {}
            for _, step in ipairs(illidan.steps) do
                byID[step.id] = step
                if step.advance == "health_pct" then gated[#gated + 1] = step.id end
            end

            eq(#gated, 2, "exactly two health-gated steps, got: " .. table.concat(gated, ","))
            eq(byID.phase2.healthPct, 65, "flames at 65%")
            eq(byID.phase5.healthPct, 30, "Maiev phase at 30%")

            -- The whole point: demon form is on a timer, not a health gate.
            eq(byID.phase4.advance, "manual", "demon form is not health-gated")
            isNil(byID.phase4.healthPct, "and carries no threshold at all")
            eq(byID.phase3.advance, "manual", "the landing phase is not health-gated either")
        end)
    end)

    it("advances into the flame phase when Illidan crosses 65%", function()
        scenario(opts, function(addon, env)
            addon.State:StartTest("bt_illidan")
            env.units.target = { name = "Illidan Stormrage", guid = "Creature-0-1-564-0-22917-1",
                hp = 60, hpMax = 100 }
            addon.Detect:PollHealth()
            eq(addon.State:Current().id, "phase2", "crossed 65% into phase 2")
        end)
    end)

    it("names the phase 5 enrage and Maiev's traps", function()
        scenario(opts, function(addon)
            local illidan = addon:GetEncounter("bt_illidan")
            local phase5
            for _, step in ipairs(illidan.steps) do
                if step.id == "phase5" then phase5 = step end
            end

            -- The two things that decide phase 5. The previous text said
            -- "Bloodlust and burn" and mentioned neither.
            truthy(phase5.call:lower():find("enrage", 1, true), "warns about the enrage")
            truthy(phase5.call:lower():find("trap", 1, true), "tells them to use the trap")

            local briefText = ""
            for _, entry in ipairs(phase5.brief or {}) do
                briefText = briefText .. " " .. (entry.spell or "") .. " " .. entry.text
            end
            truthy(briefText:find("Cage Trap", 1, true), "brief covers the trap")
            truthy(briefText:upper():find("REMOVES THE ENRAGE", 1, true),
                "and that the trap is what strips the enrage")
            truthy(briefText:find("timer rather than a health gate", 1, true),
                "brief explains demon form is on a timer")
        end)
    end)

    it("calls for capped fire resistance on the flame tanks", function()
        scenario(opts, function(addon)
            local illidan = addon:GetEncounter("bt_illidan")
            local checklist = table.concat(illidan.checklist, " ")
            truthy(checklist:find("CAPPED", 1, true), "capped, not 'where you have it': " .. checklist)
        end)
    end)

    it("puts the spine in the hands of whoever frees the impaled player", function()
        scenario(opts, function(addon)
            local najentus = addon:GetEncounter("bt_najentus")
            local boss
            for _, step in ipairs(najentus.steps) do
                if step.id == "boss" then boss = step end
            end

            -- The impaled player is stunned and cannot act. Telling them to
            -- click is telling the one person who can't.
            local briefText = ""
            for _, entry in ipairs(boss.brief or {}) do briefText = briefText .. " " .. entry.text end
            truthy(briefText:find("cannot free themselves", 1, true), "says the impaled player is helpless")
            truthy(briefText:find("KEEPS it", 1, true), "and that the rescuer keeps the spine")
            truthy(boss.call:lower():find("click the spine", 1, true), "call addresses the rescuer")
        end)
    end)

    it("cites cosmophile on every step without claiming live confirmation", function()
        scenario(opts, function(addon)
            local bt = addon.Instances.blacktemple
            eq(bt.sourced, bt.total, "every step cites a source")
            eq(bt.verified, 0, "and none claims live-client confirmation")

            for _, encounterID in ipairs(bt.order) do
                for _, step in ipairs(addon:GetEncounter(encounterID).steps) do
                    eq(step.source, "cosmophile", encounterID .. "/" .. step.id .. " source")
                end
            end
        end)
    end)

    -- Each of these pins an error cosmophile's guide caught. They exist so a
    -- later "tidy up" cannot quietly reintroduce any of them.

    it("names Hateful Strike and the most-health rule on Supremus", function()
        scenario(opts, function(addon)
            local text = ""
            for _, step in ipairs(addon:GetEncounter("bt_supremus").steps) do
                text = text .. " " .. step.call .. " " .. table.concat(step.warn, " ")
                for _, e in ipairs(step.brief or {}) do text = text .. " " .. (e.spell or "") .. " " .. e.text end
            end
            truthy(text:find("Hateful Strike", 1, true), "correct ability name")
            falsy(text:find("Hurtful", 1, true), "the wrong name is gone")
            truthy(text:upper():find("MOST HEALTH", 1, true), "the most-health rule, not just second on threat")
            truthy(text:find("40 yards", 1, true), "the charge distance")
            truthy(text:lower():find("threat drops", 1, true), "the phase-1 threat drop")
        end)
    end)

    it("gates the Naj'entus shield break on raid health", function()
        scenario(opts, function(addon)
            local boss
            for _, step in ipairs(addon:GetEncounter("bt_najentus").steps) do
                if step.id == "boss" then boss = step end
            end
            local briefText = ""
            for _, e in ipairs(boss.brief) do briefText = briefText .. " " .. (e.spell or "") .. " " .. e.text end

            truthy(briefText:find("Tidal Burst", 1, true), "names the burst")
            truthy(briefText:find("8,500", 1, true), "states the raid damage")
            truthy(briefText:find("8,501", 1, true), "and the health everyone needs")
            truthy(boss.call:find("8,500", 1, true), "the call carries the gate too")
            local checklist = table.concat(addon:GetEncounter("bt_najentus").checklist, " ")
            truthy(checklist:find("8,501", 1, true), "and it is on the pre-pull checklist")
        end)
    end)

    it("has Akama's add roles the right way round", function()
        scenario(opts, function(addon)
            local text = ""
            for _, step in ipairs(addon:GetEncounter("bt_akama").steps) do
                text = text .. " " .. step.call
                for _, e in ipairs(step.brief or {}) do text = text .. " " .. (e.spell or "") .. " " .. e.text end
            end
            -- Spiritbinders heal; Sorcerers cannot be tanked. I had these swapped.
            truthy(text:find("Spiritbinder", 1, true), "names the actual healer")
            truthy(text:upper():find("CANNOT BE TANKED", 1, true), "sorcerers cannot be tanked")
            falsy(text:find("Sorcerers heal", 1, true), "the old wrong claim is gone")
            truthy(text:find("60 seconds", 1, true), "the phase 2 kill window")
        end)
    end)

    it("treats Shear as a max-HP cut, not a tank swap", function()
        scenario(opts, function(addon)
            local illidan = addon:GetEncounter("bt_illidan")
            local phase1, brief
            for _, step in ipairs(illidan.steps) do
                if step.id == "phase1" then phase1 = step end
                if step.brief then brief = step.brief end
            end
            local briefText = ""
            for _, e in ipairs(brief) do briefText = briefText .. " " .. (e.spell or "") .. " " .. e.text end

            truthy(briefText:find("60%", 1, true), "the max-health reduction")
            truthy(briefText:upper():find("CANNOT MISS", 1, true), "that it cannot miss")
            truthy(briefText:find("Shield Block", 1, true), "the actual counter")
            falsy(phase1.call:lower():find("swap", 1, true), "no stale tank-swap instruction")
            -- Draw Soul's heal is why melee stay out of the front.
            truthy(briefText:find("100,000", 1, true), "Draw Soul's heal")
            truthy(briefText:find("Uncaged Wrath", 1, true), "the 25-yard wipe mechanic")
            truthy(briefText:find("25 yards", 1, true), "and its distance")
        end)
    end)

    it("exempts Shahraz tanks from shadow resistance", function()
        scenario(opts, function(addon)
            local shahraz = addon:GetEncounter("bt_shahraz")
            local checklist = table.concat(shahraz.checklist, " ")
            truthy(checklist:find("174", 1, true), "the raid minimum")
            truthy(checklist:upper():find("TANKS ARE EXEMPT", 1, true), "tanks do not wear resist gear")

            local text = ""
            for _, step in ipairs(shahraz.steps) do
                text = text .. " " .. step.call
                for _, e in ipairs(step.brief or {}) do text = text .. " " .. (e.spell or "") .. " " .. e.text end
            end
            truthy(text:find("IMMUNITY TO FATAL ATTRACTION", 1, true), "why three tanks stack")
            truthy(text:find("Prismatic Shield", 1, true), "correct ability name")
            falsy(text:find("Prismatic Aura", 1, true), "the wrong name is gone")
            truthy(text:find("Beams", 1, true), "the beams exist at all")
        end)
    end)

    it("names the mage tank on Zerevor", function()
        scenario(opts, function(addon)
            local council = addon:GetEncounter("bt_council")
            local text = table.concat(council.checklist, " ")
            for _, step in ipairs(council.steps) do
                text = text .. " " .. step.call
                for _, e in ipairs(step.brief or {}) do text = text .. " " .. (e.spell or "") .. " " .. e.text end
            end
            truthy(text:upper():find("MAGE", 1, true), "a mage tanks him")
            truthy(text:find("Zerevor", 1, true), "named")
            truthy(text:find("Dampen Magic", 1, true), "what they spellsteal")
            truthy(text:find("100,000", 1, true), "Circle of Healing's heal on all four")
        end)
    end)

    it("describes Insignificance as a snapshot, not a threat wipe", function()
        scenario(opts, function(addon)
            local text = ""
            for _, step in ipairs(addon:GetEncounter("bt_bloodboil").steps) do
                text = text .. " " .. step.call
                for _, e in ipairs(step.brief or {}) do text = text .. " " .. (e.spell or "") .. " " .. e.text end
            end
            truthy(text:upper():find("NOT A THREAT", 1, true), "explicitly not a reset")
            truthy(text:lower():find("snapshot", 1, true), "it is a snapshot")
            truthy(text:lower():find("furthest", 1, true), "Blood Boil hits the furthest players")
            truthy(text:find("7-10", 1, true), "the Acidic Wound swap window")
        end)
    end)

    it("says healing is impossible in Reliquary phase 1", function()
        scenario(opts, function(addon)
            local text = ""
            for _, step in ipairs(addon:GetEncounter("bt_reliquary").steps) do
                text = text .. " " .. step.call
                for _, e in ipairs(step.brief or {}) do text = text .. " " .. (e.spell or "") .. " " .. e.text end
            end
            truthy(text:lower():find("no threat table", 1, true) or text:lower():find("closest", 1, true),
                "no threat table, he hits the closest")
            truthy(text:lower():find("healers, dps", 1, true) or text:lower():find("healers dps", 1, true),
                "healers DPS instead")
            truthy(text:find("reflect", 1, true), "phase 2 reflects damage")
            truthy(text:lower():find("stance dance", 1, true), "the Soul Scream rage dump")
        end)
    end)

    it("carries spell ids, the first machine-checkable data in the repo", function()
        scenario(opts, function(addon)
            local withID, total = 0, 0
            for _, encounterID in ipairs(addon.Instances.blacktemple.order) do
                for _, step in ipairs(addon:GetEncounter(encounterID).steps) do
                    for _, e in ipairs(step.brief or {}) do
                        total = total + 1
                        if e.spellID then
                            withID = withID + 1
                            truthy(type(e.spellID) == "number" and e.spellID > 0,
                                encounterID .. " spellID for " .. tostring(e.spell))
                        end
                    end
                end
            end
            truthy(withID >= 40, "most brief entries carry a spell id (got " .. withID .. "/" .. total .. ")")
        end)
    end)

    it("carries manual checklists for the gear-check fights", function()
        scenario(opts, function(addon)
            local shahraz = addon:GetEncounter("bt_shahraz")
            truthy(shahraz.checklist, "Shahraz has one")
            truthy(table.concat(shahraz.checklist, " "):find("resistance", 1, true),
                "and it is about resist gear, which cannot be read from the API")

            local illidan = addon:GetEncounter("bt_illidan")
            truthy(illidan.checklist, "Illidan has one")
        end)
    end)

    it("walks every Black Temple encounter end to end", function()
        scenario(opts, function(addon)
            for _, encounterID in ipairs(addon.Instances.blacktemple.order) do
                truthy(addon.State:StartTest(encounterID), "started " .. encounterID)
                local total = addon.State:StepCount()
                for _ = 2, total do addon.State:Advance("local") end
                eq(addon.State.stepIndex, total, encounterID .. " walked to its last step")
                truthy(addon.State:Current().call, encounterID .. " last step has words to say")
            end
        end)
    end)
end

local function suiteOptions(profile, opts)
    group("Options [" .. profile .. "]")

    it("round-trips a profile string", function()
        scenario(opts, function(addon)
            addon.db.localEcho = true
            addon.db.hudScale = 1.25
            addon.db.assignments = { corner_a = "Vexmoor", corner_b = "Aeliswyn" }
            addon.db.checklist = { ["bt_teron:1"] = true }

            local exported = addon.Options:Export()
            truthy(exported:find("^PPRC1:"), "prefixed so it can be recognised")

            -- Wipe, then restore from the string.
            addon.db.localEcho = false
            addon.db.assignments = {}
            addon.db.checklist = {}

            local ok, message = addon.Options:Import(exported)
            truthy(ok, "imported: " .. tostring(message))
            eq(addon.db.localEcho, true, "setting restored")
            eq(addon.db.hudScale, 1.25, "scale restored")
            eq(addon.db.assignments.corner_a, "Vexmoor", "assignment restored")
            truthy(addon.db.checklist["bt_teron:1"], "checklist tick restored")
        end)
    end)

    it("does not export personal frame positions", function()
        scenario(opts, function(addon)
            addon.db.frames = { hud = { point = "TOPLEFT", x = 5, y = -5 } }
            falsy(addon.Options:Export():find("TOPLEFT", 1, true),
                "someone else's screen layout is not ours to push")
        end)
    end)

    it("refuses a string that is not one of ours", function()
        scenario(opts, function(addon)
            local ok, message = addon.Options:Import("just some text a raider pasted")
            falsy(ok, "refused")
            truthy(message:find("does not look like", 1, true), "and explained why")

            local ok2, message2 = addon.Options:Import("PPRC1:")
            falsy(ok2, "empty payload refused too")
            truthy(message2, "with a reason")
        end)
    end)

    it("leaves existing settings alone when the import fails", function()
        scenario(opts, function(addon)
            addon.db.assignments = { corner_a = "Vexmoor" }
            addon.Options:Import("garbage")
            eq(addon.db.assignments.corner_a, "Vexmoor", "nothing was clobbered")
        end)
    end)

    it("reflects live settings in its checkboxes", function()
        scenario(opts, function(addon)
            addon.db.localEcho = true
            addon.Options:Show()
            truthy(addon.Options.boxes.localEcho:GetChecked(), "checkbox follows the db")

            local box = addon.Options.boxes.localEcho
            box:GetScript("OnClick")(box)
            eq(addon.db.localEcho, false, "and toggling it writes back")
        end)
    end)
end

local function suiteJurdi(profile, opts)
    group("Hyjal / cheat sheet [" .. profile .. "]")

    local function waveSteps(addon)
        local out = {}
        for _, encounterID in ipairs(addon.Instances.hyjal.order) do
            for _, step in ipairs(addon:GetEncounter(encounterID).steps) do
                if step.wave then out[#out + 1] = step end
            end
        end
        return out
    end

    it("carries all 32 waves with a real composition and a cited source", function()
        scenario(opts, function(addon)
            local waves = waveSteps(addon)
            eq(#waves, 32, "wave count")

            for _, step in ipairs(waves) do
                local where = step.encounterID .. "/" .. step.id
                truthy(step.detail and #step.detail > 0, where .. " has a composition")
                -- Every composition names a count, which is the thing the old
                -- invented data could not do.
                truthy(step.detail:find("%d"), where .. " composition has counts: " .. tostring(step.detail))
                eq(step.source, "jurdi", where .. " cites its source")
                truthy(step.mobs and #step.mobs > 0, where .. " names its mobs")
            end
        end)
    end)

    it("names only mobs that exist in the reference", function()
        scenario(opts, function(addon)
            for _, step in ipairs(waveSteps(addon)) do
                for _, id in ipairs(step.mobs) do
                    truthy(addon.Mobs[id],
                        step.encounterID .. "/" .. step.id .. " names unknown mob '" .. id .. "'")
                end
            end
        end)
    end)

    -- Spot-checks straight off the sheet. If someone "tidies" these, the diff
    -- should fail rather than quietly drift back toward invention.
    it("matches the sheet on specific waves", function()
        scenario(opts, function(addon)
            local function detail(encounterID, waveID)
                for _, step in ipairs(addon:GetEncounter(encounterID).steps) do
                    if step.id == waveID then return step.detail end
                end
            end

            eq(detail("hyjal_winterchill", "wave1"), "10 Ghouls", "Winterchill 1")
            eq(detail("hyjal_winterchill", "wave6"), "6 Ghouls, 6 Abominations", "Winterchill 6")
            eq(detail("hyjal_kazrogal", "wave2"), "4 Ghouls, 10 Gargoyles", "Kaz'rogal 2")
            eq(detail("hyjal_kazrogal", "wave6"), "8 Gargoyles, 1 Frostwyrm", "Kaz'rogal 6")
            eq(detail("hyjal_azgalor", "wave4"), "8 Infernals, 6 Fel Hounds", "Azgalor 4")
            eq(detail("hyjal_azgalor", "wave1"), "6 Abominations, 6 Shadowy Necromancers", "Azgalor 1")
        end)
    end)

    it("includes the mob types the invented data missed entirely", function()
        scenario(opts, function(addon)
            local seen = {}
            for _, step in ipairs(waveSteps(addon)) do
                for _, id in ipairs(step.mobs) do seen[id] = true end
            end
            -- None of these appeared anywhere before the sheet arrived.
            truthy(seen.fel_hound, "Fel Hounds present")
            truthy(seen.felstalker, "Felstalkers present")
            truthy(seen.infernal, "Infernals present")
            truthy(seen.crypt_fiend, "Crypt Fiends present")
        end)
    end)

    it("carries the wave-specific callouts that are the point of the sheet", function()
        scenario(opts, function(addon)
            local function step(encounterID, waveID)
                for _, s in ipairs(addon:GetEncounter(encounterID).steps) do
                    if s.id == waveID then return s end
                end
            end

            -- Kaz'rogal 6: gargoyles spawn left, LoS at the tower, spread for the wyrm.
            local k6 = step("hyjal_kazrogal", "wave6")
            truthy(k6.call:find("LEFT", 1, true), "names the spawn side")
            truthy(k6.call:lower():find("tower", 1, true), "names the LoS point")

            -- Winterchill 6: peel Aboms off the raid for the poison.
            local w6 = step("hyjal_winterchill", "wave6")
            truthy(w6.call:lower():find("away from the raid", 1, true), "the abom peel")

            -- Azgalor 4: one infernal spawns far out.
            local a4 = step("hyjal_azgalor", "wave4")
            truthy(a4.call:lower():find("far out", 1, true), "the far spawn warning")
        end)
    end)

    it("keeps the per-mob kick and dispel flags usable", function()
        scenario(opts, function(addon)
            local necro = addon.Mobs.shadowy_necromancer
            eq(necro.priority, "high", "necros are a priority target")

            local byName = {}
            for _, a in ipairs(necro.abilities) do byName[a.name] = a end
            truthy(byName["Shadowbolt"].kick, "shadowbolt is kickable")
            truthy(byName["Unholy Frenzy"].dispel, "unholy frenzy is dispellable")

            truthy(addon.Mobs.banshee.abilities[1].dispel, "banshee curse is dispellable")
            eq(addon.Mobs.abomination.priority, "high", "aboms are a priority target")
        end)
    end)

    it("keeps the trash rules for both bases", function()
        scenario(opts, function(addon)
            local alliance = table.concat(addon.MobRules.alliance, " ")
            local horde = table.concat(addon.MobRules.horde, " ")

            truthy(alliance:find("2-3 Abominations", 1, true), "the abom cap")
            truthy(alliance:find("Mind Control", 1, true), "the necro combat-drop trick")
            truthy(horde:find("parallel", 1, true), "the horde spawn behaviour")
            truthy(horde:find("bug", 1, true), "the wave 1 spawn bug")
        end)
    end)

    -- The corrections the sheet forced, pinned so they cannot regress.
    it("keeps 20 yards on BOTH Frost Nova and Death and Decay", function()
        scenario(opts, function(addon)
            local brief
            for _, step in ipairs(addon:GetEncounter("hyjal_winterchill").steps) do
                if step.id == "boss" then brief = step.brief end
            end
            local byName = {}
            for _, entry in ipairs(brief) do byName[entry.spell] = entry.text end

            -- I moved this figure off Frost Nova in an earlier pass. Both are
            -- 20 yards; the sheet is explicit about it.
            truthy(byName["Frost Nova"]:find("20 yards", 1, true), "Frost Nova radius")
            truthy(byName["Death and Decay"]:find("20 yard", 1, true), "D&D radius")
        end)
    end)

    it("names Anetheron's Vampiric Aura and the 75% healing cut", function()
        scenario(opts, function(addon)
            local text = ""
            for _, step in ipairs(addon:GetEncounter("hyjal_anetheron").steps) do
                if step.id == "boss" then
                    text = step.call
                    for _, e in ipairs(step.brief) do text = text .. " " .. e.spell .. " " .. e.text end
                end
            end
            truthy(text:find("Vampiric Aura", 1, true), "the healing-debuff requirement")
            truthy(text:find("300%", 1, true), "how much he heals")
            truthy(text:find("75%", 1, true), "the healing reduction, not 'halves'")
            truthy(text:find("NOT TAUNTABLE", 1, true), "infernals cannot be taunted")
        end)
    end)

    it("keeps Kaz'rogal's tanks stacked for the split cleave", function()
        scenario(opts, function(addon)
            local step
            for _, s in ipairs(addon:GetEncounter("hyjal_kazrogal").steps) do
                if s.id == "boss" then step = s end
            end
            local text = step.call .. " " .. table.concat(step.warn, " ")
            for _, e in ipairs(step.brief) do text = text .. " " .. e.text end

            truthy(text:find("23,000", 1, true), "the split cleave damage")
            truthy(text:lower():find("stack", 1, true), "tanks stack")
            truthy(text:find("12 yards", 1, true), "the War Stomp radius")
            -- The old text told melee to stand behind him, which drops the
            -- three-tank soak entirely.
            falsy(step.call:lower():find("stay behind him", 1, true), "no stale melee-behind advice")
        end)
    end)

    it("warns that Azgalor's Rain of Fire DoT follows you out", function()
        scenario(opts, function(addon)
            local text = ""
            for _, s in ipairs(addon:GetEncounter("hyjal_azgalor").steps) do
                if s.id == "boss" then
                    text = s.call
                    for _, e in ipairs(s.brief) do text = text .. " " .. e.text end
                end
            end
            truthy(text:find("30 yards", 1, true), "the range that avoids it entirely")
            truthy(text:upper():find("KEEPS TICKING", 1, true), "the persistent DoT, named as the wipe cause")
            truthy(text:lower():find("soulstone", 1, true), "soulstone the doom targets")
        end)
    end)

    it("carries Archimonde's Soul Charge with its per-class effects", function()
        scenario(opts, function(addon)
            local text = ""
            for _, s in ipairs(addon:GetEncounter("hyjal_archimonde").steps) do
                if s.id == "fight" then
                    for _, e in ipairs(s.brief) do text = text .. " " .. e.spell .. " " .. e.text end
                end
            end
            truthy(text:find("Soul Charge", 1, true), "named")
            truthy(text:find("4500", 1, true), "the raid damage per death")
            truthy(text:find("silence", 1, true), "caster death effect")
            truthy(text:find("50% increased damage taken", 1, true), "physical death effect")
            truthy(text:find("2250 mana", 1, true), "hybrid death effect")

            local checklist = table.concat(addon:GetEncounter("hyjal_archimonde").checklist, " ")
            truthy(checklist:find("Tyrande", 1, true), "Tears come from Tyrande specifically")
        end)
    end)
end

local function suiteMobPanel(profile, opts)
    group("MobPanel [" .. profile .. "]")

    it("lists the pack for the current wave, priority first", function()
        scenario(opts, function(addon)
            addon.State:StartTest("hyjal_winterchill")
            addon.State:GoToStep(7, "local")   -- 4 Ghouls, 4 Necros, 4 Aboms
            addon.MobPanel:Show()

            local body = ""
            for _, line in ipairs(addon.MobPanel.lines) do body = body .. "\n" .. (line:GetText() or "") end

            truthy(body:find("4 Ghouls, 4 Shadowy Necromancers, 4 Abominations", 1, true), "composition shown")
            truthy(body:find("Shadowy Necromancer", 1, true), "necros listed")
            truthy(body:find("[kick]", 1, true), "kick flags rendered")

            -- High priority mobs sort above normal ones: that ordering is the
            -- kill order, so it has to be right.
            local necro = body:find("Shadowy Necromancer", 1, true)
            local ghoul = body:find("! Ghoul", 1, true) or body:find("  Ghoul", 1, true)
            truthy(necro < ghoul, "priority targets listed first")
        end)
    end)

    it("says so plainly on a step with no pack", function()
        scenario(opts, function(addon)
            addon.State:StartTest("hyjal_winterchill")
            addon.State:GoToStep(9, "local")   -- the boss
            addon.MobPanel:Show()
            eq(addon.MobPanel.lines[1]:GetText(), "No mob breakdown for this step.", "explained")
        end)
    end)

    it("prints the rules for the base you are on", function()
        scenario(opts, function(addon, env)
            addon.State:StartTest("hyjal_kazrogal")
            addon.MobPanel:PrintRules()
            local out = table.concat(env.printed, "\n")
            truthy(out:find("Horde base", 1, true), "picked the horde rules")
            truthy(out:find("parallel", 1, true), "and printed them")

            addon.State:StartTest("hyjal_winterchill")
            addon.MobPanel:PrintRules()
            out = table.concat(env.printed, "\n")
            truthy(out:find("Alliance base", 1, true), "picks alliance on that side")
        end)
    end)
end

local function suiteZones(profile, opts)
    group("PosMap zones [" .. profile .. "]")

    it("draws the Rain of Fire ring the sheet draws", function()
        scenario(opts, function(addon)
            local azgalor = addon.PosMap:Layout("azgalor")
            truthy(azgalor.zones, "azgalor has a zone")
            eq(azgalor.zones[1].label, "30 yd Rain of Fire", "labelled")

            local map = addon.PosMap:Create(_G.UIParent, {})
            addon.PosMap:Render(map, "azgalor", {})
            truthy(#map.zoneDots > 0, "ring rendered")
            truthy(map.zoneLabels[1]:GetText():find("30 yd", 1, true), "label rendered")
        end)
    end)

    it("hides the ring on a layout that has none", function()
        scenario(opts, function(addon)
            local map = addon.PosMap:Create(_G.UIParent, {})
            addon.PosMap:Render(map, "azgalor", {})
            addon.PosMap:Render(map, "winterchill", {})
            for _, dot in ipairs(map.zoneDots) do falsy(dot:IsShown(), "dots hidden") end
        end)
    end)

    it("puts all three tanks on one Kaz'rogal slot", function()
        scenario(opts, function(addon)
            local kazrogal = addon.PosMap:Layout("kazrogal")
            truthy(kazrogal.slotsByID.tanks, "a single stacked tank slot")
            truthy(kazrogal.slotsByID.tanks.where:lower():find("stacked", 1, true), "says stacked")
            truthy(kazrogal.zones[1].label:find("12 yd", 1, true), "stomp radius drawn")
        end)
    end)
end

local function suiteBTLayouts(profile, opts)
    group("BT layouts [" .. profile .. "]")

    -- The bug this catches is silent: a step naming a layout that does not
    -- exist renders an empty panel with no error, so the RL sees a blank
    -- diagram mid-pull and assumes the addon is broken. Three BT layouts were
    -- referenced and missing before the diagrams were traced.
    it("every posmap named anywhere resolves to a real layout", function()
        scenario(opts, function(addon)
            for instanceID, instance in pairs(addon.Instances) do
                for _, encounterID in ipairs(instance.order) do
                    local encounter = addon:GetEncounter(encounterID)
                    if encounter.posmap then
                        truthy(addon.PosMap:Layout(encounter.posmap),
                            encounterID .. " encounter posmap '" .. encounter.posmap .. "' exists")
                    end
                    for _, step in ipairs(encounter.steps) do
                        if step.posmap then
                            truthy(addon.PosMap:Layout(step.posmap),
                                encounterID .. "/" .. step.id .. " posmap '" .. step.posmap .. "' exists")
                        end
                    end
                end
            end
        end)
    end)

    it("every layout slot has coordinates inside the room", function()
        scenario(opts, function(addon)
            for key, layout in pairs(addon.Layouts) do
                for _, slot in ipairs(layout.slots or {}) do
                    truthy(slot.x > 0 and slot.x < 1 and slot.y > 0 and slot.y < 1,
                        key .. "/" .. slot.id .. " is on the map")
                    truthy(slot.where and slot.where ~= "",
                        key .. "/" .. slot.id .. " tells the raider where to stand")
                end
            end
        end)
    end)

    -- Illidan's five diagrams are five different rooms. Rendering the phase 1
    -- picture during the demon phase would put melee on top of a 15 yard aura.
    it("gives Illidan a layout per phase", function()
        scenario(opts, function(addon)
            local illidan = addon:GetEncounter("bt_illidan")
            local seen = {}
            for _, step in ipairs(illidan.steps) do seen[step.posmap] = true end
            for _, key in ipairs({ "illidan", "illidan_p2", "illidan_p3", "illidan_p4", "illidan_p5" }) do
                truthy(seen[key], key .. " is used by a step")
                truthy(addon.PosMap:Layout(key), key .. " exists")
            end
        end)
    end)

    it("keeps the warlock 20 yards clear in demon form", function()
        scenario(opts, function(addon)
            local p4 = addon.PosMap:Layout("illidan_p4")
            truthy(p4.slotsByID.warlock.where:find("20 yards", 1, true), "Shadow Blast splash respected")
            local aura
            for _, zone in ipairs(p4.zones) do
                if zone.label and zone.label:find("Aura of Dread", 1, true) then aura = zone end
            end
            truthy(aura, "Aura of Dread is drawn")
            truthy(p4.slotsByID.melee.where:upper():find("OFF HIM", 1, true), "melee are told to back off")
        end)
    end)

    -- Both of these replaced shapes I invented before the guide arrived.
    it("uses the guide's two Teron drop points, not four corners", function()
        scenario(opts, function(addon)
            local teron = addon.PosMap:Layout("teron")
            truthy(teron.slotsByID.ghost_l and teron.slotsByID.ghost_r, "two drop points")
            falsy(teron.slotsByID.corner_c, "the invented back-wall corners are gone")
            truthy(teron.slotsByID.ghost_l.where:lower():find("stairs", 1, true), "at the top of the stairs")
        end)
    end)

    it("stacks Shahraz rather than scattering her raid", function()
        scenario(opts, function(addon)
            local shahraz = addon.PosMap:Layout("shahraz")
            falsy(shahraz.slotsByID.spot_1, "the invented four scatter spots are gone")
            truthy(shahraz.slotsByID.tanks.label:lower():find("stacked", 1, true), "tanks stack for Saber Lash")
            -- Tanks are exempt from shadow resistance; a diagram that told them
            -- otherwise would undo the correction in the encounter data.
            truthy(shahraz.slotsByID.tanks.where:lower():find("not shadow resist", 1, true),
                "tanks are still told to skip shadow resistance")
            truthy(shahraz.slotsByID.ranged.where:lower():find("fish statue", 1, true), "ranged get their landmark")
        end)
    end)

    it("draws Gurtogg's soak line and the group either side of it", function()
        scenario(opts, function(addon)
            local gurtogg = addon.PosMap:Layout("bloodboil")
            truthy(gurtogg.lines and gurtogg.lines[1], "the line exists")
            eq(gurtogg.lines[1].label, "SOAK LINE", "labelled")

            -- Three waiting groups on the far side, one soak spot across it.
            truthy(gurtogg.slotsByID.group_1.x < gurtogg.lines[1].x1, "group 1 waits on the far side")
            truthy(gurtogg.slotsByID.group_2.x < gurtogg.lines[1].x1, "group 2 waits on the far side")
            truthy(gurtogg.slotsByID.group_3.x < gurtogg.lines[1].x1, "group 3 waits on the far side")
            truthy(gurtogg.slotsByID.soak.x > gurtogg.lines[1].x1, "the soak spot is over the line")

            local map = addon.PosMap:Create(_G.UIParent, {})
            addon.PosMap:Render(map, "bloodboil", {})
            truthy(#map.lineDots > 0, "line rendered")
            truthy(map.lineLabels[1]:GetText():find("SOAK", 1, true), "label rendered")
        end)
    end)

    it("hides the line on a layout that has none", function()
        scenario(opts, function(addon)
            local map = addon.PosMap:Create(_G.UIParent, {})
            addon.PosMap:Render(map, "bloodboil", {})
            addon.PosMap:Render(map, "najentus", {})
            for _, dot in ipairs(map.lineDots) do falsy(dot:IsShown(), "dots hidden") end
            for _, label in ipairs(map.lineLabels) do falsy(label:IsShown(), "labels hidden") end
        end)
    end)

    it("draws the Eye Blast as a line across phase 2", function()
        scenario(opts, function(addon)
            local p2 = addon.PosMap:Layout("illidan_p2")
            truthy(p2.lines and p2.lines[1].label == "EYE BLAST", "the trail is drawn")
            -- The three marked groups are what the guide asks the RL to name.
            truthy(p2.slotsByID.group_1 and p2.slotsByID.group_2 and p2.slotsByID.group_3,
                "three marked groups")
            truthy(p2.slotsByID.flame_w.where:lower():find("fire resist", 1, true),
                "flame tanks are reminded about fire resistance")
        end)
    end)

    it("puts Zerevor's mage tank away from everyone", function()
        scenario(opts, function(addon)
            local council = addon.PosMap:Layout("council")
            local mage = council.slotsByID.mage_tank
            truthy(mage, "the mage tank has a slot")
            truthy(mage.label:lower():find("mage", 1, true), "named as the mage tank")
            -- Arcane Explosion is 10 yards, so distance from the pile is the point.
            truthy(math.abs(mage.x - council.boss.x) > 0.4, "far from the cleave pile")
        end)
    end)

    it("marks the Reliquary spread and the closest-gets-hit band", function()
        scenario(opts, function(addon)
            local reliquary = addon.PosMap:Layout("reliquary")
            local labels = {}
            for _, zone in ipairs(reliquary.zones or {}) do labels[#labels + 1] = zone.label or "" end
            local joined = table.concat(labels, " | "):lower()
            truthy(joined:find("closest", 1, true), "the no-threat-table band is drawn")
            truthy(joined:find("spread", 1, true), "the ranged spread is drawn")
            truthy(reliquary.slotsByID.tank_in.where:lower():find("closest", 1, true),
                "the active tank is told to be closest")
        end)
    end)

    it("names the doorway tanks on Akama", function()
        scenario(opts, function(addon)
            local akama = addon.PosMap:Layout("akama")
            truthy(akama.slotsByID.left_tank.where:lower():find("door", 1, true), "left doorway")
            truthy(akama.slotsByID.right_tank.where:lower():find("door", 1, true), "right doorway")
            truthy(akama.slotsByID.left_tank.x < 0.25 and akama.slotsByID.right_tank.x > 0.75,
                "on opposite sides of the room")
        end)
    end)

    it("warns that healthy melee eat Supremus's Hateful Strike", function()
        scenario(opts, function(addon)
            local supremus = addon.PosMap:Layout("supremus")
            truthy(supremus.slotsByID.melee.where:lower():find("hateful strike", 1, true),
                "the melee slot carries the warning")
            truthy(supremus.slotsByID.kite, "the phase 2 kite lead has a slot")
        end)
    end)
end

local function suiteGuideTextures(profile, opts)
    group("Guide textures [" .. profile .. "]")

    it("names a texture for every layout", function()
        scenario(opts, function(addon)
            for key, layout in pairs(addon.Layouts) do
                truthy(layout.texture, key .. " has a guide texture")
                eq(layout.texture, key, key .. " texture matches its layout key")
            end
        end)
    end)

    it("starts on the drawn diagram, not the screenshot", function()
        scenario(opts, function(addon)
            -- The drawn view is the one carrying live assignment names, so it
            -- is the everyday default.
            falsy(addon.db.showGuide, "guide off by default")
            local map = addon.PosMap:Create(_G.UIParent, {})
            addon.PosMap:Render(map, "azgalor", {})
            falsy(map.guide:IsShown(), "screenshot hidden")
            truthy(map.slots[1]:IsShown(), "slots drawn")
        end)
    end)

    it("swaps to the screenshot and back, and remembers the choice", function()
        scenario(opts, function(addon)
            local map = addon.PosMap:Create(_G.UIParent, {})
            addon.PosMap:Render(map, "azgalor", {})

            addon.PosMap:ToggleGuide(map)
            truthy(map.guide:IsShown(), "screenshot shown")
            truthy(addon.db.showGuide, "choice persisted")
            eq(map.guideBtn._label:GetText(), "DIAGRAM", "button offers the way back")

            -- Our traced coordinates are an interpretation of these images, not
            -- pixel-registered to them, so drawing both at once would put two
            -- different pictures of the same room in one frame.
            for _, slot in ipairs(map.slots) do falsy(slot:IsShown(), "slots hidden") end
            falsy(map.boss:IsShown(), "boss marker hidden")
            for _, dot in ipairs(map.zoneDots) do falsy(dot:IsShown(), "rings hidden") end

            addon.PosMap:ToggleGuide(map)
            falsy(map.guide:IsShown(), "back to the diagram")
            truthy(map.slots[1]:IsShown(), "slots drawn again")
        end)
    end)

    it("says which view is on screen", function()
        scenario(opts, function(addon)
            local map = addon.PosMap:Create(_G.UIParent, {})
            addon.PosMap:Render(map, "azgalor", {})
            addon.PosMap:ToggleGuide(map)
            truthy(map.note:GetText():find("guide image", 1, true),
                "the note names the view, so a picture is not mistaken for the chart")
        end)
    end)

    it("falls back to the diagram when the texture will not load", function()
        scenario(opts, function(addon)
            local map = addon.PosMap:Create(_G.UIParent, {})
            -- A corrupt or absent TGA must not take the panel down mid-pull.
            map.guide.SetTexture = function() error("no such file") end
            addon.db.showGuide = true
            truthy(addon.PosMap:Render(map, "azgalor", {}), "still renders")
            falsy(map.guide:IsShown(), "screenshot abandoned")
            truthy(map.slots[1]:IsShown(), "diagram carried on")
        end)
    end)

    it("hides the button for a layout with no screenshot", function()
        scenario(opts, function(addon)
            addon.Layouts.fx_bare = { name = "Bare", slots = {}, slotsByID = {} }
            local map = addon.PosMap:Create(_G.UIParent, {})
            addon.PosMap:Render(map, "fx_bare", {})
            falsy(map.guideBtn:IsShown(), "no button without a texture")
        end)
    end)
end

local function suiteRoute(profile, opts)
    group("BT route [" .. profile .. "]")

    it("covers every boss that has trash before it", function()
        scenario(opts, function(addon)
            truthy(addon.Route, "route defined")
            for _, encounterID in ipairs(addon.RouteOrder) do
                local route = addon.Route[encounterID]
                truthy(route, encounterID .. " has a route")
                truthy(addon:GetEncounter(encounterID), encounterID .. " is a real encounter")
                truthy(#route.pulls > 0, encounterID .. " has pulls")
                for _, pull in ipairs(route.pulls) do
                    truthy(type(pull.n) == "number", encounterID .. " pull numbered")
                    truthy(pull.mobs and #pull.mobs > 0, encounterID .. " pull " .. pull.n .. " has mobs")
                end
            end
        end)
    end)

    it("keeps the skips, which are the part that goes wrong", function()
        scenario(opts, function(addon)
            -- Half the raid reading the guide and half not is exactly how a
            -- skipped pack gets pulled, so skips are data, not prose.
            local skips = 0
            for _, route in pairs(addon.Route) do
                for _, pull in ipairs(route.pulls) do
                    if pull.skip then skips = skips + 1 end
                end
            end
            truthy(skips > 0, "skippable pulls are marked")

            truthy(addon.Route.bt_najentus.note:find("RIGHT WALL", 1, true), "the Aqueous Lord skip")
            truthy(addon.Route.bt_supremus.note:lower():find("spiked wall", 1, true), "the Wyrmcaller skip")
        end)
    end)

    it("prints a route with its pull numbers and skips", function()
        scenario(opts, function(addon, env)
            addon.Commands:Run("route bt_najentus")
            local out = table.concat(env.printed, "\n")
            truthy(out:find("Naj'entus", 1, true), "names the boss")
            truthy(out:find("10 Aqueous Spawns", 1, true), "lists the messy pull")
            truthy(out:find("RIGHT WALL", 1, true), "carries the route note")

            addon.Commands:Run("route bt_council")
            out = table.concat(env.printed, "\n")
            truthy(out:find("SKIPPABLE", 1, true), "flags skippable packs")
        end)
    end)

    it("says so rather than erroring when there is no route", function()
        scenario(opts, function(addon, env)
            addon.Commands:Run("route hyjal_winterchill")
            truthy(table.concat(env.printed, "\n"):find("no route", 1, true), "explained")
        end)
    end)
end

local function suiteRoles(profile, opts)
    group("Roles [" .. profile .. "]")

    it("defines role templates only for real encounters", function()
        scenario(opts, function(addon)
            local count = 0
            for encounterID, groups in pairs(addon.Roles) do
                truthy(addon:GetEncounter(encounterID), encounterID .. " is a real encounter")
                truthy(#groups > 0, encounterID .. " has groups")
                for _, g in ipairs(groups) do
                    truthy(g.group and #g.group > 0, encounterID .. " group is named")
                    truthy(g.slots and #g.slots > 0, encounterID .. "/" .. tostring(g.group) .. " has slots")
                end
                count = count + 1
            end
            truthy(count >= 14, "both raids covered (got " .. count .. ")")
        end)
    end)

    it("flattens Illidan's template into unique keys", function()
        scenario(opts, function(addon)
            local slots = addon:RoleSlots("bt_illidan")
            truthy(slots, "template exists")

            local keys = {}
            for _, slot in ipairs(slots) do
                falsy(keys[slot.key], "duplicate key: " .. slot.key)
                keys[slot.key] = true
            end

            -- Flames of Azzinoth repeats "Heal" four times across two tanks;
            -- the labels stay readable while the keys stay distinct.
            local heals = 0
            for _, slot in ipairs(slots) do
                if slot.group == "Flames of Azzinoth" and slot.label == "Heal" then heals = heals + 1 end
            end
            eq(heals, 4, "two heals per flame, labels unchanged")
            truthy(#slots >= 15, "full template flattened")
        end)
    end)

    it("assigns through the same path as a map slot", function()
        scenario(opts, function(addon, env)
            env.buildRaid({
                { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true },
                { name = "Vexmoor",   class = "WARLOCK" },
            })
            addon.State:StartTest("bt_illidan")
            addon.RosterUI:Show()

            local slots = addon:RoleSlots("bt_illidan")
            local warlockSlot
            for _, slot in ipairs(slots) do
                if slot.label == "Warlock Tank" then warlockSlot = slot.key end
            end
            truthy(warlockSlot, "found the warlock tank slot")

            addon.RosterUI:Select("Vexmoor")
            addon.RosterUI:OnSlotClick(warlockSlot)
            eq(addon.Roster:Assignments()[warlockSlot], "Vexmoor", "assigned")
        end)
    end)

    it("reports empty slots for an encounter with roles but no diagram", function()
        scenario(opts, function(addon, env)
            env.buildRaid({ { name = "Popperpig", class = "WARRIOR", rank = 2, isPlayer = true } })
            -- Reliquary has a five-deep tank order and no map coordinates.
            addon.State:StartTest("bt_reliquary")
            addon.RosterUI:Show()

            local empty, haveSlots = addon.RosterUI:EmptySlots()
            truthy(haveSlots, "it has slots despite having no diagram")
            truthy(#empty > 0, "and reports them empty")

            -- And a push is still possible once confirmed, rather than refused
            -- outright for lack of a map.
            addon.State.testMode = false
            addon.RosterUI._confirmPush = true
            truthy(addon.RosterUI:Push(), "pushable")
        end)
    end)
end

local function suiteWeakAuras(profile, opts)
    group("WeakAuras [" .. profile .. "]")

    it("shows the encounter's aura alongside the general packs", function()
        scenario(opts, function(addon, env)
            addon.State:StartTest("bt_shahraz")
            addon.Commands:Run("wa")
            local out = table.concat(env.printed, "\n")

            truthy(out:find("Fatal Attraction", 1, true), "the encounter-specific aura")
            truthy(out:find("wago.io/7p-NQ6ZJu", 1, true), "with its link")
            truthy(out:find("Master T6", 1, true), "and the general packs")
        end)
    end)

    it("still shows the general packs where there is no specific one", function()
        scenario(opts, function(addon, env)
            addon.State:StartTest("bt_najentus")
            addon.Commands:Run("wa")
            local out = table.concat(env.printed, "\n")
            truthy(out:find("Master T6", 1, true), "general packs listed")
            truthy(out:find("no encounter-specific", 1, true), "and says there is nothing specific")
        end)
    end)
end

-- ===========================================================================
-- Run every suite under both client profiles
-- ===========================================================================

local PROFILES = {
    { name = "modern", opts = { modern = true,  worldState = "namespace" } },
    { name = "legacy", opts = { modern = false, worldState = "global" } },
}

io.write("\nPopperpig Raid Call test suite\n")
io.write(string.rep("-", 60), "\n")

for _, profile in ipairs(PROFILES) do
    suiteAdapter(profile.name, profile.opts)
    suiteCore(profile.name, profile.opts)
    suiteState(profile.name, profile.opts)
    suiteHUD(profile.name, profile.opts)
    suiteCodec(profile.name, profile.opts)
    suiteDetect(profile.name, profile.opts)
    suiteComm(profile.name, profile.opts)
    suiteRoster(profile.name, profile.opts)
    suiteReadiness(profile.name, profile.opts)
    suitePosMap(profile.name, profile.opts)
    suiteRosterUI(profile.name, profile.opts)
    suiteBriefing(profile.name, profile.opts)
    suiteJurdi(profile.name, profile.opts)
    suiteMobPanel(profile.name, profile.opts)
    suiteZones(profile.name, profile.opts)
    suiteBlackTemple(profile.name, profile.opts)
    suiteBTLayouts(profile.name, profile.opts)
    suiteGuideTextures(profile.name, profile.opts)
    suiteRoute(profile.name, profile.opts)
    suiteRoles(profile.name, profile.opts)
    suiteWeakAuras(profile.name, profile.opts)
    suiteOptions(profile.name, profile.opts)
    suiteRateLimit(profile.name, profile.opts)
    suiteCallBoard(profile.name, profile.opts)
    suiteCommands(profile.name, profile.opts)
end

io.write(string.rep("-", 60), "\n")
if failed > 0 then
    io.write("\nFailures:\n")
    for _, f in ipairs(failures) do io.write("  ", f, "\n") end
end
io.write(string.format("%d passed, %d failed\n\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
