-- Data/Positions.lua
--
-- Room layouts for the positioning diagrams. Pure geometry and labels; the
-- drawing lives in UI/PosMap.lua.
--
-- The technical plan called for nine campaign-guide SVGs converted to 512x512
-- TGA. Those source SVGs are not in this repository and there is no asset
-- pipeline here, so the diagrams are drawn from these tables at runtime
-- instead. That turns out better than the TGA route on three counts: it scales
-- with the frame instead of being locked to a power-of-two texture, a fix is a
-- coordinate edit rather than a re-export, and the markers use Blizzard's own
-- raid target icon textures -- which the plan required anyway, so that "skull,
-- corner A" matches the mark players actually see on screen.
--
-- COORDINATES
-- -----------
-- Normalised 0..1 within the room rectangle. x runs left to right, y runs
-- bottom to top, matching BOTTOMLEFT anchor maths.
--
-- `mark` is a raid target icon index:
--   1 star  2 circle  3 diamond  4 triangle  5 moon  6 square  7 cross  8 skull
--
-- `where` is the words the assigned raider actually reads -- cardinal plus a
-- landmark, because "north-east" alone is useless to someone who has not
-- checked their minimap.

local ADDON_NAME, PPRC = ...

PPRC.Layouts = {

    -- =====================================================================
    -- Mount Hyjal
    -- =====================================================================

    winterchill = {
        name = "Rage Winterchill",
        note = "Spread for Frost Nova. The killer is Nova into Death and Decay.",
        landmarks = {
            { side = "top",    label = "ALLIANCE BASE" },
            { side = "bottom", label = "SPAWN RAMP" },
            { side = "left",   label = "TENTS" },
            { side = "right",  label = "OPEN GROUND" },
        },
        boss  = { x = 0.5, y = 0.55, label = "WINTERCHILL" },
        slots = {
            { id = "mt",      x = 0.50, y = 0.72, mark = 8, label = "Main tank",  where = "north, facing him away" },
            { id = "melee",   x = 0.50, y = 0.38, mark = 6, label = "Melee",      where = "south, behind him" },
            { id = "rangedw", x = 0.20, y = 0.50, mark = 3, label = "Ranged west", where = "west, by the tents" },
            { id = "rangede", x = 0.80, y = 0.50, mark = 4, label = "Ranged east", where = "east, open ground" },
        },
    },

    anetheron = {
        name = "Anetheron",
        note = "Infernal kiters take theirs away from the raid. Never tank one in the stack.",
        landmarks = {
            { side = "top",    label = "ALLIANCE BASE" },
            { side = "bottom", label = "SPAWN RAMP" },
            { side = "left",   label = "KITE LANE WEST" },
            { side = "right",  label = "KITE LANE EAST" },
        },
        boss  = { x = 0.5, y = 0.55, label = "ANETHERON" },
        slots = {
            { id = "mt",     x = 0.50, y = 0.74, mark = 8, label = "Main tank",     where = "north, facing him away" },
            { id = "stack",  x = 0.50, y = 0.40, mark = 6, label = "Raid stack",    where = "south of him" },
            { id = "kite1",  x = 0.14, y = 0.62, mark = 1, label = "Infernal kiter 1", where = "west lane, run it out" },
            { id = "kite2",  x = 0.86, y = 0.62, mark = 2, label = "Infernal kiter 2", where = "east lane, run it out" },
        },
    },

    kazrogal = {
        name = "Kaz'rogal",
        note = "Mark explodes at zero mana and it chains. Spread properly or it cascades.",
        landmarks = {
            { side = "top",    label = "HORDE BASE" },
            { side = "bottom", label = "SPAWN RAMP" },
            { side = "left",   label = "WEST SPREAD" },
            { side = "right",  label = "EAST SPREAD" },
        },
        boss  = { x = 0.5, y = 0.58, label = "KAZ'ROGAL" },
        slots = {
            { id = "mt",     x = 0.50, y = 0.76, mark = 8, label = "Main tank",   where = "north, facing him away" },
            { id = "melee",  x = 0.50, y = 0.40, mark = 6, label = "Melee",       where = "behind him, still spread" },
            { id = "mana1",  x = 0.16, y = 0.44, mark = 3, label = "Mana users W", where = "far west, spread wide" },
            { id = "mana2",  x = 0.84, y = 0.44, mark = 4, label = "Mana users E", where = "far east, spread wide" },
        },
    },

    azgalor = {
        name = "Azgalor",
        note = "Doom targets run OUT before it lands so the Doomguard spawns clear.",
        landmarks = {
            { side = "top",    label = "HORDE BASE" },
            { side = "bottom", label = "SPAWN RAMP" },
            { side = "left",   label = "DOOM CORNER WEST" },
            { side = "right",  label = "DOOM CORNER EAST" },
        },
        boss  = { x = 0.5, y = 0.58, label = "AZGALOR" },
        slots = {
            { id = "mt",       x = 0.50, y = 0.76, mark = 8, label = "Main tank",     where = "north, facing him away" },
            { id = "doomwest", x = 0.14, y = 0.30, mark = 1, label = "Doom corner W", where = "south-west, die there" },
            { id = "doomeast", x = 0.86, y = 0.30, mark = 2, label = "Doom corner E", where = "south-east, die there" },
            { id = "banish",   x = 0.50, y = 0.30, mark = 5, label = "Doomguard duty", where = "south, banish or offtank" },
        },
    },

    archimonde = {
        name = "Archimonde",
        note = "Run FROM Doomfire, never through it and never toward the raid.",
        landmarks = {
            { side = "top",    label = "NORDRASSIL" },
            { side = "bottom", label = "OPEN GROUND" },
            { side = "left",   label = "WEST SPREAD" },
            { side = "right",  label = "EAST SPREAD" },
        },
        boss  = { x = 0.5, y = 0.60, label = "ARCHIMONDE" },
        slots = {
            { id = "mt",      x = 0.50, y = 0.78, mark = 8, label = "Main tank",   where = "north, under him" },
            { id = "tremor1", x = 0.25, y = 0.46, mark = 1, label = "Tremor west", where = "west cluster" },
            { id = "tremor2", x = 0.75, y = 0.46, mark = 2, label = "Tremor east", where = "east cluster" },
            { id = "tremor3", x = 0.50, y = 0.28, mark = 5, label = "Tremor south", where = "south cluster" },
        },
    },

    -- =====================================================================
    -- Black Temple
    --
    -- Teron is here because it is the fight where a briefing pays off most:
    -- four named people need four specific corners, and saying it out loud
    -- has never worked.
    -- =====================================================================

    teron = {
        name = "Teron Gorefiend",
        note = "Marked player runs to THEIR corner at 10 seconds, then slows the four constructs.",
        landmarks = {
            { side = "top",    label = "ENTRANCE / DOOR" },
            { side = "bottom", label = "BACK WALL" },
            { side = "left",   label = "LEFT PILLAR" },
            { side = "right",  label = "RIGHT PILLAR" },
        },
        boss  = { x = 0.5, y = 0.5, label = "TERON" },
        slots = {
            { id = "corner_a", x = 0.16, y = 0.82, mark = 8, label = "Corner A", where = "NW, by the door" },
            { id = "corner_b", x = 0.84, y = 0.82, mark = 7, label = "Corner B", where = "NE, by the door" },
            { id = "corner_c", x = 0.16, y = 0.18, mark = 6, label = "Corner C", where = "SW, back wall" },
            { id = "corner_d", x = 0.84, y = 0.18, mark = 5, label = "Corner D", where = "SE, back wall" },
        },
    },

    najentus = {
        name = "High Warlord Naj'entus",
        note = "Spines get clicked and thrown back at him to break the shield.",
        landmarks = {
            { side = "top",    label = "ENTRANCE" },
            { side = "bottom", label = "WATER" },
            { side = "left",   label = "WEST BANK" },
            { side = "right",  label = "EAST BANK" },
        },
        boss  = { x = 0.5, y = 0.55, label = "NAJ'ENTUS" },
        slots = {
            { id = "mt",     x = 0.50, y = 0.75, mark = 8, label = "Main tank", where = "north, facing him away" },
            { id = "spine",  x = 0.35, y = 0.40, mark = 1, label = "Spine duty", where = "close, watch for the spine" },
            { id = "ranged", x = 0.70, y = 0.35, mark = 4, label = "Ranged",     where = "east bank, spread" },
        },
    },

    supremus = {
        name = "Supremus",
        note = "Phase 2 he chases one player. Kite him a full lap, do not cut corners.",
        landmarks = {
            { side = "top",    label = "KITE LAP NORTH" },
            { side = "bottom", label = "KITE LAP SOUTH" },
            { side = "left",   label = "KITE LAP WEST" },
            { side = "right",  label = "KITE LAP EAST" },
        },
        boss  = { x = 0.5, y = 0.5, label = "SUPREMUS" },
        slots = {
            { id = "mt",    x = 0.50, y = 0.74, mark = 8, label = "Phase 1 tank", where = "north, face him away" },
            { id = "kite",  x = 0.22, y = 0.28, mark = 1, label = "Kite lead",    where = "start SW, run the lap" },
        },
    },

    shahraz = {
        name = "Mother Shahraz",
        note = "Fatal Attraction pulls three people together. Assigned spots keep them apart.",
        landmarks = {
            { side = "top",    label = "ENTRANCE" },
            { side = "bottom", label = "BACK OF ROOM" },
            { side = "left",   label = "WEST SPOTS" },
            { side = "right",  label = "EAST SPOTS" },
        },
        boss  = { x = 0.5, y = 0.62, label = "SHAHRAZ" },
        slots = {
            { id = "mt",     x = 0.50, y = 0.82, mark = 8, label = "Main tank", where = "north, under her" },
            { id = "spot_1", x = 0.14, y = 0.55, mark = 1, label = "Spot 1", where = "far west" },
            { id = "spot_2", x = 0.38, y = 0.28, mark = 2, label = "Spot 2", where = "south-west" },
            { id = "spot_3", x = 0.62, y = 0.28, mark = 3, label = "Spot 3", where = "south-east" },
            { id = "spot_4", x = 0.86, y = 0.55, mark = 4, label = "Spot 4", where = "far east" },
        },
    },

    illidan = {
        name = "Illidan Stormrage",
        note = "Flame tanks take one each and hold them apart. Do not let the flames meet.",
        landmarks = {
            { side = "top",    label = "TEMPLE SUMMIT" },
            { side = "bottom", label = "STAIRS" },
            { side = "left",   label = "WEST FLAME" },
            { side = "right",  label = "EAST FLAME" },
        },
        boss  = { x = 0.5, y = 0.55, label = "ILLIDAN" },
        slots = {
            { id = "mt",      x = 0.50, y = 0.78, mark = 8, label = "Main tank",   where = "north, centre" },
            { id = "flame_w", x = 0.14, y = 0.50, mark = 1, label = "Flame tank W", where = "far west, hold it there" },
            { id = "flame_e", x = 0.86, y = 0.50, mark = 2, label = "Flame tank E", where = "far east, hold it there" },
            { id = "warlock", x = 0.50, y = 0.26, mark = 5, label = "Warlock tank", where = "south, phase 4 demon" },
        },
    },
}

-- Index slots by id so a lookup does not walk the list every refresh.
for _, layout in pairs(PPRC.Layouts) do
    layout.slotsByID = {}
    for _, slot in ipairs(layout.slots or {}) do
        layout.slotsByID[slot.id] = slot
    end
end
