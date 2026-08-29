-- Data/Consumables.lua
--
-- Buff names the readiness board looks for. Matched by aura NAME, because that
-- is what UnitAura gives us and it does not shift between patches the way spell
-- ids can.
--
-- The critical one is "Well Fed": in TBC every food buff produces that single
-- aura regardless of which food it came from, so one entry covers the whole
-- category. Flasks and elixirs each have their own name and need listing.
--
-- If a name here is wrong the board shows a false negative -- someone with a
-- flask reads as missing one -- so `/pprc scan` dumps your own current buffs
-- with their exact names, ready to be pasted in and corrected.

local ADDON_NAME, PPRC = ...

local function set(list)
    local lookup = {}
    for _, name in ipairs(list) do lookup[name] = true end
    return lookup
end

PPRC.Consumables = {}

-- Flasks last through death, so a raider with one is set for the night.
PPRC.Consumables.FLASKS = set({
    "Flask of Fortification",
    "Flask of Mighty Restoration",
    "Flask of Relentless Assault",
    "Flask of Blinding Light",
    "Flask of Pure Death",
    "Flask of Chromatic Wonder",
    "Flask of Chromatic Resistance",
    "Flask of Supreme Power",
    "Flask of Distilled Wisdom",
    "Flask of the Titans",
})

-- Elixirs are the budget option: two of them roughly equal a flask, but they
-- are lost on death. Counted separately so the board can say "flask or elixir"
-- honestly rather than pretending they are the same thing.
PPRC.Consumables.ELIXIRS = set({
    -- Battle
    "Elixir of Major Agility",
    "Elixir of Major Strength",
    "Elixir of Major Firepower",
    "Elixir of Major Shadow Power",
    "Elixir of Major Frost Power",
    "Elixir of Mastery",
    "Elixir of Demonslaying",
    "Fel Strength Elixir",
    "Onslaught Elixir",
    "Adept's Elixir",
    -- Guardian
    "Elixir of Major Fortitude",
    "Elixir of Major Defense",
    "Elixir of Major Armor",
    "Elixir of Draenic Wisdom",
    "Elixir of Major Mageblood",
    "Elixir of Empowerment",
    "Elixir of Ironskin",
    "Earthen Elixir",
})

-- One aura for every food in the expansion.
PPRC.Consumables.FOOD = set({
    "Well Fed",
})

PPRC.Consumables.SOULSTONE = set({
    "Soulstone Resurrection",
})
