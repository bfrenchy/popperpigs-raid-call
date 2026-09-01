-- Core/StateMachine.lua
--
-- Where we are in the night, and what comes next.
--
-- An encounter is a flat ordered list of steps. Each step declares how it
-- advances, so this file has no encounter-specific branching anywhere in it --
-- adding a boss is a data edit, never a code edit.
--
-- Authoritative on the raid leader's client. Raiders' clients hold the same
-- structure but only ever have it written to them by Comm, which is why every
-- mutation carries a source: "local" changes get broadcast, "remote" ones must
-- not be echoed back or two clients will ping-pong forever.
--
-- Also holds the data registry, because it is the only consumer that needs the
-- indexes built. Data files load after this and register themselves into it.

local ADDON_NAME, PPRC = ...

-- ---------------------------------------------------------------------------
-- Data registry
-- ---------------------------------------------------------------------------

PPRC.Instances      = {}   -- instance id  -> definition
PPRC.InstancesByMap = {}   -- instance map -> definition
PPRC.Encounters     = {}   -- encounter id -> encounter (flat, for /pprc test)

-- Advance modes. Everything terminates in MANUAL, which always works.
PPRC.ADVANCE = {
    WORLDSTATE = "worldstate",   -- the game's own wave counter drives this
    NPC_ID     = "npc_id",       -- a known creature GUID was engaged
    HEALTH_PCT = "health_pct",   -- boss health crossed a threshold
    MANUAL     = "manual",       -- the RL clicks Next
}

-- Record an id as a detection key, or as ambiguous if something else already
-- claimed it for a different target. Two claims on the SAME target -- an
-- encounter's boss id and that encounter's own boss step -- are not a conflict.
local function claim(def, npcID, encounterID, stepIndex)
    def.knownNPC[npcID] = true

    if def.ambiguousNPC[npcID] then return end

    local existing = def.byNPC[npcID]
    if existing then
        local sameTarget = existing.encounter == encounterID
            and (existing.step == stepIndex or existing.step == nil or stepIndex == nil)
        if sameTarget then
            -- Prefer the more specific claim: a step beats a bare encounter.
            if existing.step == nil and stepIndex ~= nil then
                existing.step = stepIndex
            end
            return
        end
        def.ambiguousNPC[npcID] = true
        def.byNPC[npcID] = nil
        return
    end

    def.byNPC[npcID] = { encounter = encounterID, step = stepIndex }
end

function PPRC:RegisterInstance(def)
    if type(def) ~= "table" or not def.id then return end

    -- byNPC       ids that may MOVE state. Unique, and only from steps that
    --             actually advance on an npc id.
    -- knownNPC    every id named anywhere, so /pprc scan can tell "not in
    --             Data/" from "in Data/ but not a detection key".
    -- ambiguousNPC ids claimed by more than one target. These are the trap:
    --             Ghoul 17916 appears in 24 Hyjal waves, so a single-slot map
    --             silently resolved it to whichever registered last and the
    --             combat log threw the HUD to a different boss's wave. They
    --             are recorded and then never used to advance.
    def.byNPC = {}
    def.knownNPC = {}
    def.ambiguousNPC = {}
    def.unverified = 0
    def.sourced = 0
    def.verified = 0
    def.total = 0

    for _, encounterID in ipairs(def.order or {}) do
        local encounter = def.encounters and def.encounters[encounterID]
        if encounter then
            encounter.id         = encounterID
            encounter.instanceID = def.id
            encounter.waveIndex  = {}
            self.Encounters[encounterID] = encounter

            -- A boss NPC seen in the combat log should surface its encounter
            -- even if we are sitting on an earlier trash step.
            if encounter.npcID then
                claim(def, encounter.npcID, encounterID, nil)
            end

            for i, step in ipairs(encounter.steps or {}) do
                step.index       = i
                step.encounterID = encounterID

                def.total = def.total + 1
                -- Three states, not two. `verified` means the live client
                -- confirmed it. `source` means a cited document says so, which
                -- is weaker but far from a guess. A step with neither is the
                -- only kind the HUD flags.
                if step.verified == true then
                    def.verified = def.verified + 1
                elseif step.source then
                    def.sourced = def.sourced + 1
                else
                    def.unverified = def.unverified + 1
                end

                -- Every id gets recorded as known, for the scan report.
                if step.npcID then def.knownNPC[step.npcID] = true end
                for _, id in ipairs(step.npcIDs or {}) do def.knownNPC[id] = true end

                -- ONLY a step that actually advances on an npc id may be keyed
                -- by one. On a wave step, npcIDs is the pack composition for
                -- the mob panel -- it says what you are fighting, not where you
                -- are. Letting it drive state is what made the combat log
                -- shuffle the HUD between waves of different bosses.
                if step.advance == PPRC.ADVANCE.NPC_ID then
                    if step.npcID then claim(def, step.npcID, encounterID, i) end
                    for _, id in ipairs(step.npcIDs or {}) do
                        claim(def, id, encounterID, i)
                    end
                end

                if step.wave then encounter.waveIndex[step.wave] = i end
            end
        end
    end

    self.Instances[def.id] = def
    if def.mapID then self.InstancesByMap[def.mapID] = def end

    local keys, ambiguous = 0, 0
    for _ in pairs(def.byNPC) do keys = keys + 1 end
    for _ in pairs(def.ambiguousNPC) do ambiguous = ambiguous + 1 end
    def.npcKeyCount = keys
    def.npcAmbiguousCount = ambiguous

    self:Log("registered %s: %d steps (%d verified, %d sourced, %d unverified), %d npc keys, %d ambiguous",
        def.id, def.total, def.verified, def.sourced, def.unverified, keys, ambiguous)
end

function PPRC:GetEncounter(id) return self.Encounters[id] end

function PPRC:GetInstanceByMap(mapID) return self.InstancesByMap[mapID] end

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local State = PPRC:NewModule("State")
PPRC.State = State

State.encounterID = nil
State.stepIndex   = 0
State.testMode    = false
State.detectMode  = nil   -- set by Detect; shown in the HUD and /pprc debug

function State:Encounter()
    return self.encounterID and PPRC:GetEncounter(self.encounterID) or nil
end

function State:StepCount()
    local encounter = self:Encounter()
    return encounter and #encounter.steps or 0
end

function State:Current()
    local encounter = self:Encounter()
    if not encounter then return nil end
    return encounter.steps[self.stepIndex], self.stepIndex
end

function State:Next()
    local encounter = self:Encounter()
    if not encounter then return nil end
    return encounter.steps[self.stepIndex + 1]
end

function State:Snapshot()
    return {
        encounterID = self.encounterID,
        stepIndex   = self.stepIndex,
        step        = self:Current(),
        nextStep    = self:Next(),
        total       = self:StepCount(),
    }
end

-- The single mutation point. Everything else routes through here so there is
-- exactly one place that validates, logs and fires.
function State:Set(encounterID, stepIndex, source)
    source = source or "local"

    local encounter = encounterID and PPRC:GetEncounter(encounterID) or nil
    if encounterID and not encounter then
        PPRC:Log("ignored unknown encounter '%s'", tostring(encounterID))
        return false
    end

    if encounter then
        local count = #encounter.steps
        if count == 0 then return false end
        -- Clamp rather than refuse: a rewind past the start should sit on step
        -- one, not throw the RL back to no-encounter mid-pull.
        if stepIndex < 1 then stepIndex = 1 end
        if stepIndex > count then stepIndex = count end
    else
        stepIndex = 0
    end

    if self.encounterID == encounterID and self.stepIndex == stepIndex then
        return false   -- no-op; do not fire, do not rebroadcast
    end

    self.encounterID = encounterID
    self.stepIndex   = stepIndex

    local step = self:Current()
    PPRC:Log("state -> %s step %d/%d (%s) [%s]",
        tostring(encounterID), stepIndex, self:StepCount(),
        step and step.id or "-", source)

    PPRC:Fire("STATE_CHANGED", self:Snapshot(), source)
    return true
end

function State:SetEncounter(encounterID, source)
    return self:Set(encounterID, 1, source)
end

function State:GoToStep(index, source)
    if not self.encounterID then return false end
    return self:Set(self.encounterID, index, source)
end

function State:Advance(source)
    if not self.encounterID then return false end
    return self:Set(self.encounterID, self.stepIndex + 1, source)
end

function State:Back(source)
    if not self.encounterID then return false end
    return self:Set(self.encounterID, self.stepIndex - 1, source)
end

function State:Clear(source)
    return self:Set(nil, 0, source)
end

-- Wave numbers are per-encounter, not per-instance: Hyjal restarts its count
-- at each base, so wave 3 is only meaningful alongside "which boss are we on".
function State:GoToWave(wave, source)
    local encounter = self:Encounter()
    if not encounter then return false end

    local index = encounter.waveIndex[wave]
    if not index then
        PPRC:Log("wave %s has no step in %s", tostring(wave), self.encounterID)
        return false
    end
    return self:Set(self.encounterID, index, source)
end

-- Jump straight to whatever step a given NPC belongs to, across the whole
-- loaded instance. This is what makes Black Temple trash work with no RL
-- input: engage a pack and its card surfaces.
function State:GoToNPC(npcID, instanceDef, source)
    instanceDef = instanceDef or self.instance
    if not instanceDef or not npcID then return false end

    local hit = instanceDef.byNPC[npcID]
    if not hit then return false end

    if hit.step then return self:Set(hit.encounter, hit.step, source) end

    -- Encounter-level match with no specific step: land on the boss step if
    -- the encounter names one, otherwise leave the step alone.
    local encounter = PPRC:GetEncounter(hit.encounter)
    if not encounter then return false end
    for i, step in ipairs(encounter.steps) do
        if step.npcID == npcID then return self:Set(hit.encounter, i, source) end
    end
    return self:Set(hit.encounter, #encounter.steps, source)
end

function State:SetInstance(def)
    if self.instance == def then return end
    self.instance = def
    PPRC:Log("instance -> %s", def and def.id or "none")
    PPRC:Fire("INSTANCE_CHANGED", def)
end

-- /pprc test <encounterID>: drive the machine with no raid and no instance.
-- Covers roughly 80% of the logic including all of the UI.
function State:StartTest(encounterID)
    local encounter = PPRC:GetEncounter(encounterID)
    if not encounter then return false end

    self.testMode = true
    self:SetInstance(PPRC.Instances[encounter.instanceID])
    self:Set(encounterID, 1, "test")
    return true
end

function State:StopTest()
    self.testMode = false
    self:Clear("test")
end

-- May this client drive state for everyone, or only watch?
function State:IsController()
    if self.testMode then return true end
    if not PPRC.Adapter:InGroup() then return true end   -- solo: your own state
    return PPRC.Adapter:CanBroadcast()
end
