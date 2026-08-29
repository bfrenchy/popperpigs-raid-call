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
end

io.write(string.rep("-", 60), "\n")
if failed > 0 then
    io.write("\nFailures:\n")
    for _, f in ipairs(failures) do io.write("  ", f, "\n") end
end
io.write(string.format("%d passed, %d failed\n\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
