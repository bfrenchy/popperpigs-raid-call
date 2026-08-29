-- Core/Roster.lua
--
-- Who is here, what state they are in, and where they are standing.
--
-- Design principle, inherited straight from the plan: NO INFERENCE. Everything
-- reported here was read from the game or set by the raid leader. Class and
-- assigned role are shown to make the RL's decision fast; they never make it.
--
-- The tri-state from Core/Adapter.lua matters most in this file. A buff check
-- returns true, false, or nil, and nil means "this client cannot read auras" --
-- which has to render as unknown, not as a red cross. A green tick in this
-- addon always means the game confirmed it.

local ADDON_NAME, PPRC = ...

local Roster = PPRC:NewModule("Roster")
PPRC.Roster  = Roster

-- ---------------------------------------------------------------------------
-- Scanning
-- ---------------------------------------------------------------------------

-- Returns a list of players plus a summary. Counts are split three ways --
-- yes, no, and unknown -- so the UI never has to guess what a missing answer
-- meant.
function Roster:Scan()
    local A = PPRC.Adapter
    local C = PPRC.Consumables

    local units = A:GroupUnits()
    local players = {}

    local summary = {
        total = 0, alive = 0, online = 0, inRange = 0,
        flask = 0, flaskUnknown = 0,
        food  = 0, foodUnknown = 0,
        soulstone = 0,
        warlocks = 0,
    }

    for i = 1, #units do
        local unit = units[i]
        if UnitExists(unit) then
            local name = UnitName(unit)
            local _, class = UnitClass(unit)

            local flask   = A:UnitHasAura(unit, C.FLASKS)
            local elixir  = A:UnitHasAura(unit, C.ELIXIRS)
            local food    = A:UnitHasAura(unit, C.FOOD)
            local stone   = A:UnitHasAura(unit, C.SOULSTONE)

            -- Flask OR two elixirs is the accepted standard, and we cannot
            -- count elixirs, so any elixir counts as "consumed something".
            local consumed
            if flask == nil and elixir == nil then
                consumed = nil
            else
                consumed = (flask == true) or (elixir == true)
            end

            local player = {
                unit      = unit,
                name      = name,
                class     = class,
                role      = A:UnitRole(unit),
                online    = UnitIsConnected(unit) ~= false,
                dead      = UnitIsDeadOrGhost(unit) and true or false,
                inRange   = UnitInRange(unit) ~= false,
                flask     = flask,
                elixir    = elixir,
                consumed  = consumed,
                food      = food,
                soulstone = stone,
            }

            players[#players + 1] = player

            summary.total = summary.total + 1
            if not player.dead then summary.alive = summary.alive + 1 end
            if player.online then summary.online = summary.online + 1 end
            if player.inRange then summary.inRange = summary.inRange + 1 end

            if consumed == true then summary.flask = summary.flask + 1
            elseif consumed == nil then summary.flaskUnknown = summary.flaskUnknown + 1 end

            if food == true then summary.food = summary.food + 1
            elseif food == nil then summary.foodUnknown = summary.foodUnknown + 1 end

            if stone == true then summary.soulstone = summary.soulstone + 1 end
            if class == "WARLOCK" then summary.warlocks = summary.warlocks + 1 end
        end
    end

    self.players = players
    self.summary = summary
    return players, summary
end

-- Everyone with something the RL can act on. Deliberately not "everyone who
-- is not perfect": being out of range while running back is not an offence.
function Roster:Offenders()
    local players = self.players or select(1, self:Scan())
    local offenders = {}

    for i = 1, #players do
        local player = players[i]
        local issues = {}

        if player.consumed == false then issues[#issues + 1] = "no flask" end
        if player.food == false      then issues[#issues + 1] = "no food" end
        if not player.online         then issues[#issues + 1] = "offline" end
        if player.dead               then issues[#issues + 1] = "dead" end
        if not player.inRange        then issues[#issues + 1] = "out of range" end

        if #issues > 0 then
            offenders[#offenders + 1] = { player = player, issues = issues }
        end
    end

    return offenders
end

function Roster:ReadyCount()
    local players = self.players or select(1, self:Scan())
    local ready = 0
    for i = 1, #players do
        local p = players[i]
        if p.online and not p.dead and p.consumed ~= false and p.food ~= false then
            ready = ready + 1
        end
    end
    return ready, #players
end

-- ---------------------------------------------------------------------------
-- Wipe recovery
--
-- The most repeated question of the night -- "is everyone back yet?" -- as one
-- glance instead of a chat interrogation.
-- ---------------------------------------------------------------------------

function Roster:WipeScan()
    local players = select(1, self:Scan())
    local status = { total = #players, alive = 0, corpse = 0, released = 0, inRange = 0, rebuffed = 0 }

    for i = 1, #players do
        local player = players[i]
        if player.dead then
            -- A released player is a ghost; one who has not released is still
            -- a corpse waiting on a battle res or a run back.
            local isGhost = _G.UnitIsGhost and (pcall(_G.UnitIsGhost, player.unit)) and UnitIsGhost(player.unit)
            if isGhost then status.released = status.released + 1 else status.corpse = status.corpse + 1 end
        else
            status.alive = status.alive + 1
            if player.inRange then status.inRange = status.inRange + 1 end
            if player.consumed == true then status.rebuffed = status.rebuffed + 1 end
        end
    end

    return status
end

-- ---------------------------------------------------------------------------
-- Announcing
-- ---------------------------------------------------------------------------

-- One line. Never a 25-name wall of text -- that is the thing this replaces,
-- not the thing it does.
function Roster:SummaryLine()
    local _, summary = self:Scan()
    if summary.total == 0 then return "not in a group" end

    local missing = {}
    local noFlask = summary.total - summary.flask - summary.flaskUnknown
    local noFood  = summary.total - summary.food - summary.foodUnknown

    if noFlask > 0 then missing[#missing + 1] = noFlask .. " missing flask" end
    if noFood > 0  then missing[#missing + 1] = noFood .. " missing food" end
    if summary.alive < summary.total then
        missing[#missing + 1] = (summary.total - summary.alive) .. " dead"
    end
    if summary.online < summary.total then
        missing[#missing + 1] = (summary.total - summary.online) .. " offline"
    end

    if #missing == 0 then
        return string.format("Readiness: all %d ready", summary.total)
    end
    return "Readiness: " .. table.concat(missing, ", ")
end

function Roster:Announce()
    PPRC.RateLimit:SendCall(self:SummaryLine(), "readiness")
end

function Roster:Whisper(name, message)
    if not name then return end
    PPRC.RateLimit:Queue("chat", function()
        PPRC.Adapter:SendChat(message, "WHISPER", name)
    end, "whisper:" .. name)
end

function Roster:WhisperOffenders()
    local offenders = self:Offenders()
    local sent = 0

    for i = 1, #offenders do
        local entry = offenders[i]

        -- Only whisper about things they can fix standing there, and only to
        -- someone who can act on it. A corpse cannot drink a flask and an
        -- offline player will read it tomorrow; both are noise.
        local reachable = entry.player.online and not entry.player.dead

        local actionable = {}
        if reachable then
            for _, issue in ipairs(entry.issues) do
                if issue == "no flask" or issue == "no food" then actionable[#actionable + 1] = issue end
            end
        end

        if #actionable > 0 then
            self:Whisper(entry.player.name,
                "Raid check: " .. table.concat(actionable, " and ") .. ". Sort it before the pull please.")
            sent = sent + 1
        end
    end

    if sent == 0 then
        PPRC:Print("nobody to whisper - everyone readable is consumed up")
    else
        PPRC:Print("whispered %d raider%s", sent, sent == 1 and "" or "s")
    end
    return sent
end

-- ---------------------------------------------------------------------------
-- Assignments
--
-- Stored by character name so they survive across weeks, and pushed to the
-- raid by Comm. A raider is only ever shown their own.
-- ---------------------------------------------------------------------------

function Roster:Assignments()
    PPRC.db.assignments = PPRC.db.assignments or {}
    return PPRC.db.assignments
end

function Roster:Assign(slot, name)
    local assignments = self:Assignments()
    assignments[slot] = name
    PPRC:Fire("ASSIGNMENTS_CHANGED", assignments, "local")
end

function Roster:Unassign(slot)
    local assignments = self:Assignments()
    assignments[slot] = nil
    PPRC:Fire("ASSIGNMENTS_CHANGED", assignments, "local")
end

-- What this player, specifically, was told to do on this step.
function Roster:MyAssignment(step)
    if not step or not step.posmap then return nil end

    local me = UnitName("player")
    if not me then return nil end

    local layout = PPRC.PosMap and PPRC.PosMap:Layout(step.posmap)
    local assignments = self:Assignments()

    for slot, name in pairs(assignments) do
        if PPRC.Adapter:StripRealm(tostring(name)) == PPRC.Adapter:StripRealm(me) then
            local slotDef = layout and layout.slotsByID and layout.slotsByID[slot]
            if slotDef then
                return string.format("%s (%s)", slotDef.label or slot, slotDef.where or "")
            end
            return slot
        end
    end
    return nil
end
