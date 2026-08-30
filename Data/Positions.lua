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
-- The Mount Hyjal layouts below are traced from the positioning screenshots in
-- Jurdi's Mount Hyjal Cheat Sheet (twitch.tv/jurdijd) -- the same document the
-- wave data comes from. Slot placement, the landmarks and the numbered calls
-- are his; a raid that has actually used these beats anything I would invent.
--
-- COORDINATES
-- -----------
-- Normalised 0..1 within the room rectangle. x runs left to right, y runs
-- bottom to top, matching BOTTOMLEFT anchor maths.
--
-- `zones` draw a labelled radius ring -- the Azgalor sheet literally draws the
-- 30 yard Rain of Fire circle with the ranged standing outside it, and that
-- picture explains the fight faster than any sentence.
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
        note = "Hunter misdirect and drag him to the ballista. Spread wide -- Death and Decay is nearly invisible.",
        landmarks = {
            { side = "top",    label = "JAINA - NORTH" },
            { side = "bottom", label = "ALLIANCE BASE" },
            { side = "left",   label = "OPEN GROUND" },
            { side = "right",  label = "THE BALLISTA" },
        },
        boss  = { x = 0.58, y = 0.55, label = "WINTERCHILL" },
        slots = {
            { id = "mt",      x = 0.58, y = 0.70, mark = 8, label = "Main tank",  where = "on him, by the ballista" },
            { id = "melee",   x = 0.50, y = 0.44, mark = 6, label = "Melee",      where = "behind him, still spread" },
            { id = "healer1", x = 0.24, y = 0.68, mark = 1, label = "Healers W",  where = "west, cover the west ranged" },
            { id = "healer2", x = 0.82, y = 0.34, mark = 2, label = "Healers E",  where = "east, cover the east ranged" },
            { id = "ranged",  x = 0.34, y = 0.28, mark = 4, label = "Ranged",     where = "south-west, wide of the pack" },
        },
    },

    anetheron = {
        name = "Anetheron",
        note = "Infernals are NOT tauntable. Offtank stands clear and picks them up at range; targeted players run toward them, not onto them.",
        landmarks = {
            { side = "top",    label = "INFERNAL CORNER" },
            { side = "bottom", label = "ALLIANCE BASE" },
            { side = "left",   label = "OPEN GROUND" },
            { side = "right",  label = "THE BALLISTA" },
        },
        boss  = { x = 0.55, y = 0.52, label = "ANETHERON" },
        slots = {
            { id = "mt",       x = 0.55, y = 0.68, mark = 8, label = "Main tank",      where = "on him, by the ballista" },
            { id = "infernal", x = 0.80, y = 0.86, mark = 7, label = "Infernal tank",  where = "far NE, clear of everyone" },
            { id = "melee",    x = 0.47, y = 0.40, mark = 6, label = "Melee",          where = "behind him" },
            { id = "healer1",  x = 0.24, y = 0.66, mark = 1, label = "Healers W",      where = "west, spread from each other" },
            { id = "healer2",  x = 0.78, y = 0.30, mark = 2, label = "Healers E",      where = "east, spread from each other" },
            { id = "ranged",   x = 0.34, y = 0.26, mark = 4, label = "Ranged",         where = "south-west, wide" },
        },
    },

    kazrogal = {
        name = "Kaz'rogal",
        note = "Tanks STACKED to split Malevolent Cleave. Every ranged past 12 yards or War Stomp catches them.",
        landmarks = {
            { side = "top",    label = "THRALL - HORDE ARMY" },
            { side = "bottom", label = "HORDE BASE" },
            { side = "left",   label = "RANGED - WEST" },
            { side = "right",  label = "HEALERS - EAST" },
        },
        boss  = { x = 0.50, y = 0.34, label = "KAZ'ROGAL" },
        -- The stun radius, drawn. Ranged inside this ring get stunned.
        zones = {
            { cx = 0.50, cy = 0.34, r = 0.20, label = "12 yd War Stomp", color = "danger" },
        },
        slots = {
            { id = "tanks",   x = 0.56, y = 0.30, mark = 8, label = "ALL 3 TANKS", where = "stacked on him, split the cleave" },
            { id = "melee",   x = 0.40, y = 0.36, mark = 6, label = "Melee",       where = "on him, inside the stomp" },
            { id = "healers", x = 0.78, y = 0.56, mark = 2, label = "Healers",     where = "east, outside 12 yards" },
            { id = "ranged",  x = 0.24, y = 0.52, mark = 4, label = "Ranged",      where = "west, outside 12 yards" },
            { id = "locks",   x = 0.30, y = 0.74, mark = 5, label = "Warlocks",    where = "own spot, life tap to stay topped" },
        },
    },

    azgalor = {
        name = "Azgalor",
        note = "Ranged outside 30 yards never get touched by Rain of Fire. The DoT keeps ticking after you leave the fire -- that is what wipes raids.",
        landmarks = {
            { side = "top",    label = "THRALL - HORDE ARMY" },
            { side = "bottom", label = "HORDE BASE" },
            { side = "left",   label = "OPEN GROUND" },
            { side = "right",  label = "RANGED - OUTSIDE" },
        },
        boss  = { x = 0.50, y = 0.46, label = "AZGALOR" },
        -- The sheet draws this circle explicitly. It is the whole fight.
        zones = {
            { cx = 0.50, cy = 0.46, r = 0.30, label = "30 yd Rain of Fire", color = "danger" },
        },
        slots = {
            { id = "mt",      x = 0.58, y = 0.42, mark = 8, label = "Main tank",  where = "on him, centre" },
            { id = "melee",   x = 0.42, y = 0.44, mark = 6, label = "Melee",      where = "on him, inside the ring" },
            { id = "offtank", x = 0.36, y = 0.30, mark = 7, label = "Doomguards", where = "drag them into melee" },
            { id = "healers", x = 0.76, y = 0.82, mark = 2, label = "Healers",    where = "north-east, OUTSIDE the ring" },
            { id = "ranged",  x = 0.20, y = 0.80, mark = 4, label = "Ranged",     where = "north-west, OUTSIDE the ring" },
            { id = "doom",    x = 0.14, y = 0.24, mark = 1, label = "Doom run-out", where = "south-west, die clear of everyone" },
        },
    },

    archimonde = {
        name = "Archimonde",
        note = "MT in the middle. Four or five loose groups around him, each with a decurser and a shaman. Fight ends at 10%.",
        landmarks = {
            { side = "top",    label = "NORDRASSIL" },
            { side = "bottom", label = "OPEN GROUND" },
            { side = "left",   label = "SPREAD WEST" },
            { side = "right",  label = "SPREAD EAST" },
        },
        boss  = { x = 0.50, y = 0.52, label = "ARCHIMONDE" },
        slots = {
            { id = "mt",     x = 0.50, y = 0.52, mark = 8, label = "Main tank", where = "dead centre, all heals on you" },
            { id = "group1", x = 0.22, y = 0.72, mark = 1, label = "Group 1",   where = "north-west, decurser + shaman" },
            { id = "group2", x = 0.74, y = 0.78, mark = 2, label = "Group 2",   where = "north-east, decurser + shaman" },
            { id = "group3", x = 0.80, y = 0.40, mark = 3, label = "Group 3",   where = "east, decurser + shaman" },
            { id = "group4", x = 0.40, y = 0.22, mark = 4, label = "Group 4",   where = "south, decurser + shaman" },
            { id = "group5", x = 0.16, y = 0.40, mark = 5, label = "Group 5",   where = "west, decurser + shaman" },
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
