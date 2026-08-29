-- Core/Adapter.lua
--
-- THE ONLY FILE THAT TOUCHES BLIZZARD APIs DIRECTLY.
--
-- 2.5.6 backported Midnight-era nameplate and raid-frame code into the TBC
-- Anniversary client and broke a lot of addons on release. That already
-- happened once mid-phase, so the whole point of this file is that a 2.5.7
-- doing it again is a one-file fix.
--
-- Three rules, applied throughout:
--   1. Probe with pcall, so a missing API is a branch and not an error.
--   2. Read return values by TYPE AND CONTENT, never by fixed position, so a
--      changed signature does not silently shift what we parse.
--   3. Every chain terminates in manual control, which always works.
--
-- Capability values are deliberately tri-state:
--   true  = confirmed present
--   false = confirmed absent
--   nil   = not yet known
-- Callers must distinguish "the game says no" from "we cannot tell", because
-- the readiness board is required to show unknowns as unknown rather than as
-- a red cross. Never presenting a guess as data is a hard rule here.

local ADDON_NAME, PPRC = ...

local A   = {}
local Cap = {}
PPRC.Adapter, PPRC.Cap = A, Cap

-- ---------------------------------------------------------------------------
-- Existence probes
-- ---------------------------------------------------------------------------

local probe = CreateFrame("Frame")

-- Registering an event this client does not have throws. There is no
-- "DoesEventExist", so the probe registers, unregisters, and reports whether
-- the attempt survived.
local function CanRegister(event)
    local ok = pcall(probe.RegisterEvent, probe, event)
    if ok then pcall(probe.UnregisterEvent, probe, event) end
    return ok and true or false
end
A.CanRegister = CanRegister

local function isFunc(f) return type(f) == "function" end

-- --- World state -----------------------------------------------------------
-- Prefer the Midnight namespace (plausible after the 2.5.6 backport), fall
-- back to the documented TBC global. Black Morass uses this same counter, so
-- the global path is the likely winner.
do
    local ws = _G.C_WorldStateInfo
    Cap.wsCount = (ws and ws.GetNumWorldStateUI) or _G.GetNumWorldStateUI
    Cap.wsInfo  = (ws and ws.GetWorldStateUIInfo) or _G.GetWorldStateUIInfo
    Cap.worldState = isFunc(Cap.wsCount) and isFunc(Cap.wsInfo)
    if ws and isFunc(ws.GetWorldStateUIInfo) then
        Cap.worldStateSource = "C_WorldStateInfo"
    elseif Cap.worldState then
        Cap.worldStateSource = "global"
    else
        Cap.worldStateSource = "none"
    end
end

-- --- Events ----------------------------------------------------------------
Cap.encounterEvents = CanRegister("ENCOUNTER_START")
Cap.nameplates      = CanRegister("NAME_PLATE_UNIT_ADDED")
Cap.combatLog       = CanRegister("COMBAT_LOG_EVENT_UNFILTERED")
Cap.worldStateEvent = CanRegister("UPDATE_WORLD_STATES")

-- Unknowable out of combat: an empty boss1 slot is indistinguishable from a
-- client that has no boss tokens at all. Resolved lazily in GetBossUnit.
Cap.bossTokens = nil

-- --- Addon messaging (spike S5) --------------------------------------------
do
    local ci = _G.C_ChatInfo
    Cap.sendAddon      = (ci and ci.SendAddonMessage) or _G.SendAddonMessage
    Cap.registerPrefix = (ci and ci.RegisterAddonMessagePrefix) or _G.RegisterAddonMessagePrefix
    Cap.addonMessage   = isFunc(Cap.sendAddon)
    if ci and isFunc(ci.SendAddonMessage) then
        Cap.addonMessageSource = "C_ChatInfo"
    elseif Cap.addonMessage then
        Cap.addonMessageSource = "global"
    else
        Cap.addonMessageSource = "none"
    end
end

-- --- Auras -----------------------------------------------------------------
do
    local ua = _G.C_UnitAuras
    Cap.auraModern = (ua and isFunc(ua.GetAuraDataByIndex)) and true or false
    Cap.auraLegacy = isFunc(_G.UnitAura)
    Cap.auras      = Cap.auraModern or Cap.auraLegacy
    Cap.auraSource = Cap.auraModern and "C_UnitAuras" or (Cap.auraLegacy and "UnitAura" or "none")
end

-- --- Misc ------------------------------------------------------------------
Cap.roles       = isFunc(_G.UnitGroupRolesAssigned)
Cap.raidTargets = isFunc(_G.SetRaidTarget)
Cap.timers      = (_G.C_Timer and isFunc(_G.C_Timer.After)) and true or false
Cap.instance    = isFunc(_G.GetInstanceInfo)
Cap.rangeCheck  = isFunc(_G.UnitInRange)

-- ---------------------------------------------------------------------------
-- World state reading
--
-- The TBC 2.1 signature put uiType first, shifting every later return. Rather
-- than index a fixed position -- which breaks if Blizzard shifts it again --
-- collect every return and keep the digits out of any string that has them.
-- Label text is localized; digits are digits, so this is locale-independent.
-- ---------------------------------------------------------------------------

function A:WorldStateNumbers()
    local found = {}
    if not Cap.worldState then return found end

    local ok, n = pcall(Cap.wsCount)
    if not ok or type(n) ~= "number" then return found end

    for i = 1, n do
        local okInfo, r1, r2, r3, r4, r5, r6, r7, r8 = pcall(Cap.wsInfo, i)
        if okInfo then
            local returns = { r1, r2, r3, r4, r5, r6, r7, r8 }
            for j = 1, #returns do
                local v = returns[j]
                if type(v) == "string" and v:find("%d") then
                    for num in v:gmatch("%d+") do
                        found[#found + 1] = tonumber(num)
                    end
                end
            end
        end
    end
    return found
end

-- Raw dump for /pprc scan: the RL pastes this so real values can be recorded
-- in SPIKES.md against a build number.
function A:WorldStateDump()
    local lines = {}
    if not Cap.worldState then
        lines[1] = "world state API unavailable (" .. tostring(Cap.worldStateSource) .. ")"
        return lines
    end
    local ok, n = pcall(Cap.wsCount)
    if not ok or type(n) ~= "number" then
        lines[1] = "GetNumWorldStateUI failed"
        return lines
    end
    lines[1] = string.format("GetNumWorldStateUI() = %d  [%s]", n, Cap.worldStateSource)
    for i = 1, n do
        local returns = { pcall(Cap.wsInfo, i) }
        table.remove(returns, 1)  -- drop the pcall status
        local parts = {}
        for j = 1, #returns do
            parts[#parts + 1] = string.format("[%d]=%s(%s)", j, tostring(returns[j]), type(returns[j]))
        end
        lines[#lines + 1] = string.format("  ui %d: %s", i, table.concat(parts, " "))
    end
    return lines
end

-- ---------------------------------------------------------------------------
-- GUID -> NPC ID
--
-- Creature-0-1234-534-0000-17767-0000AB  ->  17767
--
-- Widened from ^Creature to ^%a+ so Vehicle- and Pet- GUIDs parse with the
-- same call. Deliberately no fallback for the pre-4.0 hex GUID format: this
-- client uses the string form, and half-remembering a bit layout would put a
-- guess where the plan requires a fact. A wrong NPC ID is worse than nil,
-- because nil degrades to manual and a wrong ID surfaces the wrong card.
-- ---------------------------------------------------------------------------

function A:NPCID(guid)
    if type(guid) ~= "string" then return nil end
    local id = guid:match("^%a+%-0%-%d+%-%d+%-%d+%-(%d+)")
    return id and tonumber(id) or nil
end

-- ---------------------------------------------------------------------------
-- Boss units (spike S3)
--
-- Ordered by reliability. bossTokens caches itself the first time it can be
-- decided, which is only possible during a real encounter.
-- ---------------------------------------------------------------------------

function A:GetBossUnit(npcID)
    if not npcID then return nil end

    -- 1. boss1-boss5, if this client has them at all.
    if Cap.bossTokens ~= false then
        for i = 1, 5 do
            local unit = "boss" .. i
            if UnitExists(unit) then
                Cap.bossTokens = true
                if self:NPCID(UnitGUID(unit)) == npcID then return unit, "boss" end
            end
        end
        -- In combat with no boss unit resolving at all: this client does not
        -- have them. Out of combat the same observation proves nothing.
        if Cap.bossTokens == nil and InCombatLockdown and InCombatLockdown() then
            Cap.bossTokens = false
            PPRC:Log("boss tokens absent on this client - phase steps fall back")
        end
    end

    -- 2. Whatever anyone currently has targeted. In practice the MT has the
    --    boss, so this covers most of what tier 1 would have.
    local units = { "target", "focus", "targettarget" }
    for i = 1, #units do
        local unit = units[i]
        if UnitExists(unit) and self:NPCID(UnitGUID(unit)) == npcID then
            return unit, "target"
        end
    end

    -- 3. Nameplates. FALLBACK ONLY -- 2.5.6 rewrote this system, so it is
    --    never primary and is skipped entirely if the event would not register.
    if Cap.nameplates and _G.C_NamePlate and _G.C_NamePlate.GetNamePlates then
        local ok, plates = pcall(_G.C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            for i = 1, #plates do
                local unit = plates[i] and plates[i].namePlateUnitToken
                if unit and self:NPCID(UnitGUID(unit)) == npcID then
                    return unit, "nameplate"
                end
            end
        end
    end

    return nil  -- caller falls back to manual phase advance
end

-- nil means "no health source, use manual" -- never 100, never 0.
function A:BossHealthPct(npcID)
    local unit = self:GetBossUnit(npcID)
    if not unit then return nil end
    local maxHP = UnitHealthMax(unit)
    if type(maxHP) ~= "number" or maxHP <= 0 then return nil end
    return UnitHealth(unit) / maxHP * 100
end

-- ---------------------------------------------------------------------------
-- Group and roster
-- ---------------------------------------------------------------------------

function A:GroupSize()
    if isFunc(_G.GetNumGroupMembers) then return GetNumGroupMembers() or 0 end
    return 0
end

function A:InRaid()
    return isFunc(_G.IsInRaid) and IsInRaid() and true or false
end

function A:InGroup()
    return isFunc(_G.IsInGroup) and IsInGroup() and true or false
end

-- Unit tokens for everyone in the group, including the player.
function A:GroupUnits()
    local units = {}
    local n = self:GroupSize()

    if self:InRaid() then
        for i = 1, n do units[#units + 1] = "raid" .. i end
    elseif n > 0 then
        units[#units + 1] = "player"
        for i = 1, n - 1 do units[#units + 1] = "party" .. i end
    else
        units[#units + 1] = "player"
    end
    return units
end

-- TANK / HEALER / DAMAGER / NONE. Never inferred from class -- the plan is
-- explicit that where the game does not provide a fact, we show nothing.
function A:UnitRole(unit)
    if not Cap.roles then return "NONE" end
    local ok, role = pcall(_G.UnitGroupRolesAssigned, unit)
    if not ok or type(role) ~= "string" then return "NONE" end
    return role
end

function A:StripRealm(name)
    if type(name) ~= "string" then return name end
    return (name:gsub("%-.*$", ""))
end

-- Rank by NAME, which is what an incoming addon message gives us.
--
-- The technical plan verifies senders with UnitIsGroupLeader(sender), but that
-- family takes a unit token, not a player name -- passing a name gets an
-- unreliable answer. GetRaidRosterInfo returns rank keyed by name, which is
-- the path that actually holds. Returns 2 = leader, 1 = assist, 0 = neither.
function A:RankOf(name)
    if type(name) ~= "string" then return 0 end
    local target = self:StripRealm(name)

    if self:InRaid() and isFunc(_G.GetRaidRosterInfo) then
        for i = 1, self:GroupSize() do
            local ok, rosterName, rank = pcall(_G.GetRaidRosterInfo, i)
            if ok and rosterName and self:StripRealm(rosterName) == target then
                return tonumber(rank) or 0
            end
        end
        return 0
    end

    -- Party: only the leader has rank, and there are no assists.
    if self:InGroup() then
        local units = self:GroupUnits()
        for i = 1, #units do
            local unitName = UnitName(units[i])
            if unitName and self:StripRealm(unitName) == target then
                local ok, isLeader = pcall(_G.UnitIsGroupLeader, units[i])
                return (ok and isLeader) and 2 or 0
            end
        end
    end

    return 0
end

-- May this client broadcast? Lead or assist only.
function A:CanBroadcast()
    if not self:InGroup() then return false end
    local ok, leader = pcall(_G.UnitIsGroupLeader, "player")
    if ok and leader then return true end
    local okA, assist = pcall(_G.UnitIsGroupAssistant, "player")
    return (okA and assist) and true or false
end

-- ---------------------------------------------------------------------------
-- Auras
--
-- Same signature-agnostic trick as world state: 2.5.x moved the rank return
-- around historically, so rather than trust position, scan every return for a
-- string or spell id we recognise. A flask name will not collide with a
-- debuff type ("Magic") or a caster unit token.
--
-- Returns:
--   true, matched  -- found
--   false          -- scanned, not present
--   nil            -- cannot read auras at all; caller must show "unknown"
-- ---------------------------------------------------------------------------

local MAX_AURA_SLOTS = 40

function A:UnitHasAura(unit, lookup)
    if not Cap.auras then return nil end
    if not unit or not UnitExists(unit) then return nil end

    for i = 1, MAX_AURA_SLOTS do
        local returns

        if Cap.auraModern then
            local ok, data = pcall(_G.C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
            if not ok or type(data) ~= "table" then break end
            returns = { data.name, data.spellId }
        else
            local packed = { pcall(_G.UnitAura, unit, i, "HELPFUL") }
            if not packed[1] or packed[2] == nil then break end
            table.remove(packed, 1)  -- drop the pcall status
            returns = packed
        end

        for j = 1, #returns do
            local v = returns[j]
            if (type(v) == "string" or type(v) == "number") and lookup[v] then
                return true, v
            end
        end
    end

    return false
end

-- ---------------------------------------------------------------------------
-- Instance identity
-- ---------------------------------------------------------------------------

function A:InstanceMapID()
    if not Cap.instance then return nil, nil end
    local packed = { pcall(_G.GetInstanceInfo) }
    if not packed[1] then return nil, nil end
    table.remove(packed, 1)

    local name = type(packed[1]) == "string" and packed[1] or nil
    local mapID = packed[8]

    -- Position 8 is instanceMapID in the documented signature. If a patch
    -- shifts it we return nil rather than a plausible-looking wrong number:
    -- nil loads no data module and the RL drives manually, which is the
    -- correct degradation. Guessing would load the wrong raid's cards.
    if type(mapID) ~= "number" then
        PPRC:Log("GetInstanceInfo signature unexpected - instance id unread")
        return nil, name
    end
    return mapID, name
end

-- ---------------------------------------------------------------------------
-- Outbound actions
-- ---------------------------------------------------------------------------

-- Spike S4. Returns ok plus a reason, so the UI can offer a click-to-run macro
-- instead of a button that silently does nothing.
function A:SetMark(unit, index)
    if not Cap.raidTargets then return false, "SetRaidTarget unavailable" end
    local ok, err = pcall(_G.SetRaidTarget, unit, index)
    if not ok then
        Cap.raidTargetsBlocked = true
        PPRC:Log("SetRaidTarget refused: %s", tostring(err))
        return false, tostring(err)
    end
    Cap.raidTargetsBlocked = false
    return true
end

function A:SendAddon(prefix, message, channel, target)
    if not Cap.addonMessage then return false end
    local ok = pcall(Cap.sendAddon, prefix, message, channel, target)
    return ok
end

function A:RegisterPrefix(prefix)
    if not isFunc(Cap.registerPrefix) then return false end
    return (pcall(Cap.registerPrefix, prefix)) and true or false
end

function A:SendChat(message, channel, target)
    if not isFunc(_G.SendChatMessage) then return false end
    return (pcall(_G.SendChatMessage, message, channel, nil, target)) and true or false
end

-- ---------------------------------------------------------------------------
-- Capability report for /pprc debug
--
-- The plan requires this to name which tier went active for each chain, so
-- S2/S3 answer themselves the first night someone zones into Hyjal.
-- ---------------------------------------------------------------------------

local function yesno(v)
    if v == nil then return "|cff6c7c6eunknown|r" end
    return v and "|cff3fae6fyes|r" or "|cffc1544ano|r"
end

function A:CapabilityReport()
    local lines = {
        string.format("Popperpig Raid Call %s  |  client %s",
            PPRC.version, (GetBuildInfo and select(1, GetBuildInfo())) or "?"),
        string.format("world state ........ %s  [%s]", yesno(Cap.worldState), Cap.worldStateSource),
        string.format("UPDATE_WORLD_STATES  %s", yesno(Cap.worldStateEvent)),
        string.format("combat log ......... %s", yesno(Cap.combatLog)),
        string.format("ENCOUNTER_START .... %s", yesno(Cap.encounterEvents)),
        string.format("nameplates ......... %s  (fallback only)", yesno(Cap.nameplates)),
        string.format("boss tokens ........ %s  (resolves in combat)", yesno(Cap.bossTokens)),
        string.format("addon messages ..... %s  [%s]", yesno(Cap.addonMessage), Cap.addonMessageSource),
        string.format("auras .............. %s  [%s]", yesno(Cap.auras), Cap.auraSource),
        string.format("roles .............. %s", yesno(Cap.roles)),
        string.format("raid target icons .. %s", yesno(Cap.raidTargets)),
        string.format("range check ........ %s", yesno(Cap.rangeCheck)),
        string.format("C_Timer ............ %s", yesno(Cap.timers)),
    }
    return lines
end
