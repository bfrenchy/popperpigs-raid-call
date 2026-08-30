-- Data/Roles.lua
--
-- Per-boss assignment templates.
--
-- SOURCE: the Assignments sheet of cosmophile's Black Temple guide.
--
-- This is a different concern from Data/Positions.lua. A position is where you
-- stand; a role is what you are responsible for, and plenty of roles have no
-- meaningful coordinate at all -- "Heal 2 on the Second Flame" is not a spot on
-- a map. Trying to make one table serve both would put thirteen markers on
-- Illidan's diagram and make it unreadable.
--
-- Slots are ordered within a group, and the group order is the order the raid
-- leader fills them in. UI/Roster.lua renders these and writes through
-- PPRC.Roster:Assign, so they ride the existing ASSIGN sync message with no
-- new comms.

local ADDON_NAME, PPRC = ...

PPRC.Roles = {

    -- === Mount Hyjal =====================================================
    -- Not in cosmophile's sheet; these mirror the positional slots already in
    -- Data/Positions.lua so the panel is useful in both raids.
    hyjal_winterchill = {
        { group = "Tanks",   slots = { "Main Tank" } },
        { group = "Healers", slots = { "Heal 1", "Heal 2" } },
    },
    hyjal_anetheron = {
        { group = "Tanks",   slots = { "Main Tank", "Infernal Offtank" } },
        { group = "Healers", slots = { "Heal 1", "Heal 2" } },
    },
    hyjal_kazrogal = {
        { group = "Tanks",   slots = { "Tank 1", "Tank 2", "Tank 3" } },
        { group = "Healers", slots = { "Heal 1", "Heal 2" } },
    },
    hyjal_azgalor = {
        { group = "Tanks",   slots = { "Main Tank", "Doomguard Offtank" } },
        { group = "Healers", slots = { "Heal 1", "Heal 2" } },
    },
    hyjal_archimonde = {
        { group = "Tanks",     slots = { "Main Tank" } },
        { group = "Decursers", slots = { "Group 1", "Group 2", "Group 3", "Group 4", "Group 5" } },
    },

    -- === Black Temple ====================================================
    bt_najentus = {
        { group = "Tanks", slots = { "Main Tank" } },
    },

    bt_supremus = {
        { group = "Main Tank", slots = { "MT", "Heal 1", "Heal 2" } },
        { group = "Off Tank",  slots = { "OT", "Heal 1", "Heal 2" } },
    },

    bt_akama = {
        { group = "Left Team",  slots = { "Tank", "Hunter", "Heal 1", "Heal 2" } },
        { group = "Right Team", slots = { "Tank", "Hunter", "Heal 1", "Heal 2" } },
    },

    bt_teron = {
        { group = "Main Tank", slots = { "MT", "Heal 1", "Heal 2" } },
        { group = "Ghost groups", slots = { "Group 1", "Group 2", "Group 3" } },
        -- The guide's tip: park the BoP order next to the tanks who need them.
        { group = "BoP order", slots = { "Pally 1", "Pally 2", "Pally 3" } },
    },

    bt_bloodboil = {
        { group = "Main Tank",     slots = { "MT", "Heal 1", "Heal 2" } },
        { group = "Soak rotation", slots = { "Group 1", "Group 2", "Group 3" } },
    },

    bt_reliquary = {
        { group = "Phase 1 tank order", slots = { "Tank 1", "Tank 2", "Tank 3", "Tank 4", "Tank 5" } },
        { group = "Interrupt order",    slots = { "Interrupt 1", "Backup 1", "Interrupt 2", "Backup 2" } },
        { group = "Spell Steal",        slots = { "Mage 1", "Mage 2" } },
        { group = "Phase 3 opener",     slots = { "OT (starts pull)", "MT" } },
    },

    bt_shahraz = {
        { group = "Tanks", slots = { "MT", "OT 1", "OT 2" } },
    },

    bt_council = {
        { group = "Gathios",  slots = { "MT" } },
        { group = "Veras",    slots = { "Tank" } },
        { group = "Zerevor",  slots = { "Mage Tank" } },
        { group = "Malande",  slots = { "Tank", "Melee Interrupt", "Ranged Interrupt" } },
    },

    bt_illidan = {
        { group = "Main Tank",          slots = { "MT", "Heal 1", "Heal 2" } },
        { group = "Flames of Azzinoth", slots = { "First Flame Tank", "Heal", "Heal",
                                                  "Second Flame Tank", "Heal", "Heal" } },
        { group = "Ranged groups",      slots = { "Ranged Group 1", "Ranged Group 2", "Ranged Group 3" } },
        { group = "Demon phase",        slots = { "Warlock Tank", "Heal 1", "Heal 2" } },
    },
}

-- Flat, stable slot keys for the assignment store, so a name assigned to
-- "Illidan / Flames of Azzinoth / Second Flame Tank" round-trips through the
-- ASSIGN message as one string.
function PPRC:RoleSlots(encounterID)
    local groups = self.Roles[encounterID]
    if not groups then return nil end

    local flat = {}
    for _, group in ipairs(groups) do
        local seen = {}
        for _, slot in ipairs(group.slots) do
            -- A group may legitimately repeat a label ("Heal", "Heal"), so
            -- disambiguate on the way into the key rather than renaming the
            -- label the raid leader reads.
            seen[slot] = (seen[slot] or 0) + 1
            local suffix = seen[slot] > 1 and ("#" .. seen[slot]) or ""
            flat[#flat + 1] = {
                key   = encounterID .. "|" .. group.group .. "|" .. slot .. suffix,
                group = group.group,
                label = slot,
            }
        end
    end
    return flat
end
