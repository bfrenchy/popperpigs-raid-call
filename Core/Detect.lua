-- Core/Detect.lua
--
-- How the addon knows where you are in the night.
--
-- Four layers, each degrading into the next, and the last one is the raid
-- leader clicking Next -- which always works. No probe result can make this
-- addon non-functional; that is the design guarantee.
--
--   A  WHICH RAID      GetInstanceInfo -> load the right data module
--   B  WHICH WAVE      world state counter, self-classifying (spike S2)
--   C  WHICH BOSS      NPC id out of the combat log
--   D  WHICH PHASE     boss health thresholds (spike S3)
--
-- S2 and S3 resolve themselves at runtime rather than gating development.
-- Both branches are coded; `/pprc debug` names which tier actually went live,
-- and the dead branch can then be deleted with evidence rather than guessed at.
--
-- Detection only writes state on a client that is entitled to drive it. A
-- raider follows the raid leader through Comm; two clients both auto-advancing
-- from their own reading of the world is how they drift apart.

local ADDON_NAME, PPRC = ...

local Detect = PPRC:NewModule("Detect")
PPRC.Detect  = Detect

local HISTORY   = 8      -- samples kept per world-state slot
local MIN_HIST  = 3      -- the plan's "classify over 3+ updates"
local HEALTH_POLL = 0.5
local WIPE_RATIO  = 0.6  -- fraction of the group dead that reads as a wipe

Detect.waveMode   = nil  -- "WAVE_NUMBER" | "ENEMIES_REMAINING" | "MANUAL"
Detect.waveSlot   = nil  -- which world-state number turned out to be the wave
Detect.waveCount  = 0    -- tier 2 only: waves counted from counter resets
Detect.seenNPCs   = {}   -- npcID -> name, harvested for /pprc scan
Detect.lastNPC    = nil

local history = {}       -- slot index -> { values... }

-- ---------------------------------------------------------------------------
-- Enable
-- ---------------------------------------------------------------------------

function Detect:OnEnable()
    PPRC:On("PLAYER_ENTERING_WORLD",  function() self:CheckZone() end)
    PPRC:On("ZONE_CHANGED_NEW_AREA",  function() self:CheckZone() end)

    -- Layer B. If the event will not register there is nothing to listen to,
    -- and On() has already logged it.
    PPRC:On("UPDATE_WORLD_STATES", function() self:OnWorldStateUpdate() end)

    -- Layer C.
    PPRC:On("COMBAT_LOG_EVENT_UNFILTERED", function() self:OnCombatLog() end)

    -- Encounter boundary chain. ENCOUNTER_START where it exists, and
    -- PLAYER_REGEN_* underneath it, which is bedrock and cannot fully fail.
    PPRC:On("ENCOUNTER_START",       function(_, id, name) self:OnEncounterStart(id, name) end)
    PPRC:On("PLAYER_REGEN_DISABLED", function() self:OnCombatStart() end)
    PPRC:On("PLAYER_REGEN_ENABLED",  function() self:OnCombatEnd() end)

    PPRC:Listen("STATE_CHANGED", function(snapshot) self:OnStateChanged(snapshot) end)

    self:CheckZone()
end

-- ---------------------------------------------------------------------------
-- Layer A -- which raid
-- ---------------------------------------------------------------------------

function Detect:CheckZone()
    local mapID, name = PPRC.Adapter:InstanceMapID()
    local instance = mapID and PPRC:GetInstanceByMap(mapID) or nil

    if instance ~= PPRC.State.instance then
        self:ResetWaveTracking()
        PPRC.State:SetInstance(instance)

        if instance then
            PPRC:Print("|cff8fe04b%s|r loaded. %d steps, %d still unverified against this client.",
                instance.name, instance.total, instance.unverified)
        end
    end

    PPRC:Log("zone: mapID=%s name=%s module=%s",
        tostring(mapID), tostring(name), instance and instance.id or "none")
end

-- ---------------------------------------------------------------------------
-- Layer B -- which wave
--
-- The client already knows the wave: it is rendering it at the top of the
-- screen. We read it rather than infer it. What we do not know is which of the
-- numbers on screen is the wave, or whether the counter counts waves up or
-- enemies down -- so the classifier watches how each number BEHAVES instead of
-- assuming a label format. That also makes it locale-proof.
-- ---------------------------------------------------------------------------

function Detect:ResetWaveTracking()
    history = {}
    self.waveMode  = nil
    self.waveSlot  = nil
    self.waveCount = 0
end

function Detect:SetWaveMode(mode, slot)
    if self.waveMode == mode and self.waveSlot == slot then return end
    self.waveMode = mode
    self.waveSlot = slot
    PPRC.State.detectMode = mode
    PPRC:Log("wave detection resolved: |cff8fe04b%s|r%s",
        mode, slot and (" (world state number " .. slot .. ")") or "")
    PPRC:Fire("DETECT_MODE_CHANGED", mode, slot)
end

-- Classify one slot's history. Returns nil until there is enough to judge.
local function classify(values)
    if #values < MIN_HIST then return nil end

    local rising, falling = 0, 0
    for i = 2, #values do
        if values[i] > values[i - 1] then rising  = rising  + 1 end
        if values[i] < values[i - 1] then falling = falling + 1 end
    end

    if rising == 0 and falling == 0 then return nil end            -- constant
    if falling > rising then return "ENEMIES_REMAINING" end        -- decays with resets
    return "WAVE_NUMBER"                                           -- climbs
end

function Detect:OnWorldStateUpdate()
    local numbers = PPRC.Adapter:WorldStateNumbers()

    if #numbers == 0 then
        self:SetWaveMode("MANUAL", nil)
        return
    end

    -- Track every number independently. The plan's sketch classified only the
    -- first, but Hyjal may well render more than one, and picking [1] would be
    -- an arbitrary choice dressed up as a reading.
    for slot = 1, #numbers do
        local values = history[slot] or {}
        values[#values + 1] = numbers[slot]
        if #values > HISTORY then table.remove(values, 1) end
        history[slot] = values
    end

    if not self.waveMode or self.waveMode == "MANUAL" then
        -- Prefer a slot that behaves like a wave counter; fall back to one
        -- that behaves like an enemy count.
        local waveSlot, enemySlot
        for slot, values in pairs(history) do
            local kind = classify(values)
            if kind == "WAVE_NUMBER" and not waveSlot then waveSlot = slot end
            if kind == "ENEMIES_REMAINING" and not enemySlot then enemySlot = slot end
        end

        if waveSlot then
            self:SetWaveMode("WAVE_NUMBER", waveSlot)
        elseif enemySlot then
            self:SetWaveMode("ENEMIES_REMAINING", enemySlot)
            -- Seed from where the RL already is, so tier 2 does not restart
            -- the count at 1 when the addon is loaded mid-clear.
            local step = PPRC.State:Current()
            self.waveCount = (step and step.wave) or 0
        else
            return   -- not enough behaviour yet; stay uncommitted
        end
    end

    if not PPRC.State:IsController() then return end

    local values = history[self.waveSlot]
    if not values or #values == 0 then return end
    local current = values[#values]

    if self.waveMode == "WAVE_NUMBER" then
        PPRC.State:GoToWave(current, "detect")

    elseif self.waveMode == "ENEMIES_REMAINING" then
        local previous = values[#values - 1]
        if previous and current > previous then
            -- The count jumped up: a new wave spawned.
            self.waveCount = self.waveCount + 1
            PPRC.State:GoToWave(self.waveCount, "detect")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Layer C -- which boss, which trash pack
--
-- Creature-0-1234-534-0000-17767-0000AB -> 17767 -> Rage Winterchill
--
-- This is what makes Black Temple trash work with no RL input: engage a
-- Promenade Sentinel and its card surfaces, because that id appears nowhere
-- else in the instance.
-- ---------------------------------------------------------------------------

function Detect:OnCombatLog()
    local units = PPRC.Adapter:CombatLogUnits()
    if #units == 0 then return end

    local instance = PPRC.State.instance

    for i = 1, #units do
        local npcID, name = units[i].npcID, units[i].name

        -- Harvest for /pprc scan regardless of whether we know the id: an
        -- unknown id in Hyjal is exactly what needs recording.
        if name and not self.seenNPCs[npcID] then
            self.seenNPCs[npcID] = name
            PPRC:Log("saw NPC %d (%s)%s", npcID, name,
                (instance and instance.byNPC[npcID]) and "" or " |cffcda23f- not in Data/|r")
        end

        -- The combat log fires constantly. Only act when the id we are looking
        -- at actually changed, or this would re-set state hundreds of times a
        -- second for the same pack.
        if instance and npcID ~= self.lastNPC and instance.byNPC[npcID] then
            self.lastNPC = npcID
            if PPRC.State:IsController() then
                PPRC.State:GoToNPC(npcID, instance, "detect")
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Layer D -- which phase
--
-- Polled only while the NEXT step is actually gated on health. There is no
-- reason to ask the client for a boss's health on a trash wave, and the plan
-- is explicit that nameplates are never the primary source here.
-- ---------------------------------------------------------------------------

function Detect:OnStateChanged()
    local nextStep = PPRC.State:Next()
    local wanted = nextStep and nextStep.advance == PPRC.ADVANCE.HEALTH_PCT

    if wanted and not self.healthTicker then
        self.healthTicker = PPRC:Ticker(HEALTH_POLL, function() Detect:PollHealth() end)
        PPRC:Log("health polling on for '%s' at %s%%", nextStep.id, tostring(nextStep.healthPct))
    elseif not wanted and self.healthTicker then
        if self.healthTicker.Cancel then self.healthTicker:Cancel() end
        self.healthTicker = nil
    end
end

function Detect:PollHealth()
    if not PPRC.State:IsController() then return end

    local nextStep = PPRC.State:Next()
    if not nextStep or nextStep.advance ~= PPRC.ADVANCE.HEALTH_PCT then return end

    local encounter = PPRC.State:Encounter()
    local npcID = nextStep.npcID or (encounter and encounter.npcID)
    if not npcID then return end

    local pct = PPRC.Adapter:BossHealthPct(npcID)
    if not pct then return end   -- nil means no health source; RL clicks Next

    if pct <= (nextStep.healthPct or 0) then
        PPRC:Log("health %.1f%% crossed %s%% -> advancing to '%s'", pct, tostring(nextStep.healthPct), nextStep.id)
        PPRC.State:Advance("detect")
    end
end

-- ---------------------------------------------------------------------------
-- Encounter boundaries
-- ---------------------------------------------------------------------------

function Detect:OnEncounterStart(encounterID, encounterName)
    PPRC:Log("ENCOUNTER_START %s (%s)", tostring(encounterID), tostring(encounterName))
    self.sawEncounterEvent = true
end

function Detect:OnCombatStart()
    self.inCombat = true
    self.lastNPC = nil    -- a fresh pull should re-key off whatever we engage
    PPRC:Fire("COMBAT_START")
end

function Detect:OnCombatEnd()
    self.inCombat = false

    -- Wipe or clear? Count the bodies. Anything above the threshold means the
    -- next twenty minutes are recovery, which the readiness board switches to.
    local units = PPRC.Adapter:GroupUnits()
    local total, dead = 0, 0
    for i = 1, #units do
        if UnitExists(units[i]) then
            total = total + 1
            if UnitIsDeadOrGhost(units[i]) then dead = dead + 1 end
        end
    end

    local wiped = total > 0 and (dead / total) >= WIPE_RATIO
    PPRC:Log("combat ended: %d/%d dead%s", dead, total, wiped and " - reads as a wipe" or "")
    PPRC:Fire("COMBAT_END", wiped, dead, total)
    if wiped then PPRC:Fire("WIPE_DETECTED", dead, total) end
end

-- ---------------------------------------------------------------------------
-- Reporting
-- ---------------------------------------------------------------------------

function Detect:TierReport()
    local Cap = PPRC.Cap
    local lines = {}

    local waveTier
    if self.waveMode == "WAVE_NUMBER" then
        waveTier = "|cff3fae6ftier 1|r - reading the wave number directly"
    elseif self.waveMode == "ENEMIES_REMAINING" then
        waveTier = "|cff3fae6ftier 2|r - counting counter resets"
    elseif self.waveMode == "MANUAL" then
        waveTier = "|cffc1544atier 3|r - manual"
    else
        waveTier = "|cff6c7c6enot yet classified|r - needs " .. MIN_HIST .. " world state updates"
    end
    lines[#lines + 1] = "wave chain ......... " .. waveTier

    local bossTier
    if Cap.bossTokens == true then
        bossTier = "|cff3fae6fboss tokens|r"
    elseif Cap.bossTokens == false then
        bossTier = "|cffcda23ftarget/focus polling|r - no boss tokens on this client"
    else
        bossTier = "|cff6c7c6eunresolved|r - decides on the first encounter"
    end
    lines[#lines + 1] = "boss chain ......... " .. bossTier

    lines[#lines + 1] = "encounter chain .... " ..
        (Cap.encounterEvents and "|cff3fae6fENCOUNTER_START|r" or "|cffcda23fPLAYER_REGEN + combat log|r")

    local known, unknown = 0, 0
    local instance = PPRC.State.instance
    for npcID in pairs(self.seenNPCs) do
        if instance and instance.byNPC[npcID] then known = known + 1 else unknown = unknown + 1 end
    end
    lines[#lines + 1] = string.format("NPCs seen .......... %d known, |cffcda23f%d not in Data/|r", known, unknown)

    return lines
end

-- /pprc scan. Produces the paste that corrects Data/ after a raid night: the
-- raw world state returns and every NPC id seen that we do not have on file.
function Detect:ScanReport()
    local lines = { "--- Popperpig Raid Call scan ---" }

    for _, line in ipairs(PPRC.Adapter:WorldStateDump()) do lines[#lines + 1] = line end

    lines[#lines + 1] = string.format("wave mode: %s (slot %s), counted %d",
        tostring(self.waveMode), tostring(self.waveSlot), self.waveCount)

    local instance = PPRC.State.instance
    lines[#lines + 1] = "NPCs seen this session:"

    local ids = {}
    for npcID in pairs(self.seenNPCs) do ids[#ids + 1] = npcID end
    table.sort(ids)

    if #ids == 0 then
        lines[#lines + 1] = "  (none yet - engage something)"
    end
    for _, npcID in ipairs(ids) do
        local inData = instance and instance.byNPC[npcID]
        lines[#lines + 1] = string.format("  %-7d %-34s %s",
            npcID, self.seenNPCs[npcID] or "?", inData and "in Data/" or "<< NOT IN Data/")
    end

    return lines
end
