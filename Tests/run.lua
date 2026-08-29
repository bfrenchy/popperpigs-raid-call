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

    it("indexes every step's NPC ids for combat-log lookup", function()
        scenario(opts, function(addon)
            local hyjal = addon.Instances.hyjal
            eq(hyjal.byNPC[17767].encounter, "hyjal_winterchill", "winterchill boss id")
            eq(hyjal.byNPC[17968].encounter, "hyjal_archimonde", "archimonde boss id")
            truthy(hyjal.byNPC[17916], "ghoul trash id indexed")
        end)
    end)

    it("counts unverified data so drift is visible", function()
        scenario(opts, function(addon)
            local hyjal = addon.Instances.hyjal
            truthy(hyjal.total > 0, "steps counted")
            -- Every Hyjal step ships unverified until confirmed against 2.5.6.
            eq(hyjal.unverified, hyjal.total, "all steps flagged unverified")
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
            eq(State:Current().detail, "Frost Wyrms", "correct data")

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
            eq(addon.HUD.nowDetail:GetText(), "Ghouls", "NOW detail")
            truthy(addon.HUD.nowCall:GetText():find("Ghouls only", 1, true), "spoken call rendered")
            truthy(addon.HUD.nextTitle:GetText():find("Wave 2", 1, true), "NEXT title")
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
            truthy(blob:find("unverified", 1, true), "unverified data count printed")
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
            eq(addon.CallBoard.stepButtons[2]._label:GetText(), "OT PEEL", "second step call")
            falsy(addon.CallBoard.stepButtons[3]:IsShown(), "unused buttons hidden")
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
