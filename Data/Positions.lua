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
-- The Black Temple layouts are traced the same way from the diagrams in
-- cosmophile's Black Temple guide. Two of them replace shapes I had invented:
-- Teron had four corners where the guide draws two drop points at the top of
-- the stairs, and Shahraz had four scatter spots where the guide has two named
-- stacks. The guide wins.
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
-- `lines` draw a labelled straight line, for the rooms that are divided rather
-- than circled: Gurtogg's soak line and Illidan's Eye Blast trail.
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
        texture = "winterchill",
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
        texture = "anetheron",
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
        texture = "kazrogal",
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
        texture = "azgalor",
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
        texture = "archimonde",
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
    -- Traced from the positioning diagrams in cosmophile's Black Temple guide,
    -- the same document the encounter data comes from. Where the guide draws a
    -- zone or a line, it is drawn here too: the ranged spread at Reliquary,
    -- Gurtogg's soak line, Illidan's Eye Blast and Aura of Dread. A picture of
    -- "inside or outside" explains those fights faster than a sentence does.
    --
    -- Illidan gets a layout per phase, because his five diagrams are five
    -- different rooms -- P2 is a kiting pattern, P4 is a 20 yard exclusion
    -- zone, and calling either from the P1 picture would be wrong.
    -- =====================================================================

    najentus = {
        name = "High Warlord Naj'entus",
        texture = "najentus",
        note = "Spread 6 yards for Needle Spine. Buddy system: somebody else clicks your spine, and that raider holds it.",
        landmarks = {
            { side = "top",    label = "HIS PLATFORM" },
            { side = "bottom", label = "DOWN THE RAMP" },
            { side = "left",   label = "WEST BANK" },
            { side = "right",  label = "EAST BANK" },
        },
        boss  = { x = 0.50, y = 0.78, label = "NAJ'ENTUS" },
        slots = {
            { id = "mt",       x = 0.50, y = 0.86, mark = 8, label = "Main tank",   where = "on him, back to his platform" },
            { id = "melee",    x = 0.49, y = 0.70, mark = 6, label = "Melee",       where = "under him, still 6 yards apart" },
            { id = "healers_w",x = 0.38, y = 0.60, mark = 1, label = "Healers W",   where = "west, spread from each other" },
            { id = "healers_e",x = 0.60, y = 0.60, mark = 2, label = "Healers E",   where = "east, spread from each other" },
            { id = "ranged_w", x = 0.36, y = 0.44, mark = 4, label = "Ranged W",    where = "west, down the ramp" },
            { id = "ranged_e", x = 0.62, y = 0.44, mark = 5, label = "Ranged E",    where = "east, down the ramp" },
        },
    },

    supremus = {
        name = "Supremus",
        texture = "supremus",
        note = "Phase 1 he is tanked at the top of the room. Phase 2 he chases one player -- run the lap, do not cut corners, and stop DPS before he turns back.",
        landmarks = {
            { side = "top",    label = "BACK WALL" },
            { side = "bottom", label = "OPEN GROUND - KITE LAP" },
            { side = "left",   label = "WEST SPIKES" },
            { side = "right",  label = "EAST SPIKES" },
        },
        boss  = { x = 0.50, y = 0.82, label = "SUPREMUS" },
        slots = {
            { id = "mt",      x = 0.47, y = 0.88, mark = 8, label = "Main tank",     where = "on him, top of the room" },
            { id = "ot",      x = 0.54, y = 0.88, mark = 7, label = "Offtank",       where = "beside the MT, stay TOPPED for Hateful Strike" },
            { id = "melee",   x = 0.50, y = 0.76, mark = 6, label = "Melee",         where = "on him -- healthy DPS in melee eat Hateful Strike" },
            { id = "healers", x = 0.60, y = 0.70, mark = 2, label = "Healers",       where = "east, behind the melee" },
            { id = "ranged",  x = 0.40, y = 0.70, mark = 4, label = "Ranged",        where = "west, behind the melee" },
            { id = "kite",    x = 0.28, y = 0.22, mark = 1, label = "Phase 2 kite",  where = "start south-west and run the full lap" },
        },
    },

    akama = {
        name = "Shade of Akama",
        texture = "akama",
        note = "A tank on each doorway. Sorcerers CANNOT be tanked -- burn them. Frost Traps and Earthbind at the side doors so the add tanks can kite.",
        landmarks = {
            { side = "top",    label = "CHANNELER PLATFORM" },
            { side = "bottom", label = "ENTRANCE" },
            { side = "left",   label = "LEFT DOOR" },
            { side = "right",  label = "RIGHT DOOR" },
        },
        boss  = { x = 0.52, y = 0.90, label = "THE SHADE" },
        slots = {
            { id = "dps",        x = 0.52, y = 0.82, mark = 8, label = "DPS pack",        where = "move together on the casters, park an add in the middle for Seed" },
            { id = "left_tank",  x = 0.16, y = 0.55, mark = 1, label = "Left add tank",   where = "left door, kite through the trap" },
            { id = "right_tank", x = 0.84, y = 0.55, mark = 2, label = "Right add tank",  where = "right door, kite through the trap" },
            { id = "left_heal",  x = 0.31, y = 0.70, mark = 4, label = "Left tank healer",where = "inside the left tank, keep him up" },
            { id = "right_heal", x = 0.69, y = 0.70, mark = 5, label = "Right tank healer", where = "inside the right tank, keep him up" },
            { id = "akama",      x = 0.52, y = 0.52, mark = 7, label = "Phase 2 burn",     where = "he walks down here -- lust and burn, 60 seconds" },
        },
    },

    -- The guide draws two drop points at the top of the stairs, not four
    -- corners. Ghosts run to whichever is theirs; the constructs spawn there.
    teron = {
        name = "Teron Gorefiend",
        texture = "teron",
        note = "Shadow of Death targets run UP THE STAIRS to their spot before they die. Constructs spawn where the body drops -- keep them off the raid.",
        landmarks = {
            { side = "top",    label = "TOP OF THE STAIRS" },
            { side = "bottom", label = "BACK OF THE PLATFORM" },
            { side = "left",   label = "LEFT BRAZIER" },
            { side = "right",  label = "RIGHT BRAZIER" },
        },
        boss  = { x = 0.50, y = 0.44, label = "TERON" },
        zones = {
            { cx = 0.34, cy = 0.86, r = 0.07, color = "purple" },
            { cx = 0.66, cy = 0.86, r = 0.07, color = "purple" },
        },
        slots = {
            { id = "mt",      x = 0.56, y = 0.40, mark = 8, label = "Main tank",       where = "on him, centre of the platform" },
            { id = "melee",   x = 0.44, y = 0.34, mark = 6, label = "Melee",           where = "on him, watch for your Shadow of Death" },
            { id = "healers", x = 0.52, y = 0.16, mark = 2, label = "Healers",         where = "back of the platform" },
            { id = "ghost_l", x = 0.34, y = 0.86, mark = 1, label = "Ghost spot LEFT", where = "top of the stairs, LEFT side" },
            { id = "ghost_r", x = 0.66, y = 0.86, mark = 3, label = "Ghost spot RIGHT",where = "top of the stairs, RIGHT side" },
        },
    },

    -- The one fight in the instance whose diagram is a line rather than a
    -- circle: three groups of five on one side of it, one crossing to soak.
    bloodboil = {
        name = "Gurtogg Bloodboil",
        texture = "bloodboil",
        note = "Blood Boil hits the 5 FURTHEST players. Three groups of five; one crosses the line to soak, then moves up and the next group falls back.",
        landmarks = {
            { side = "top",    label = "NORTH WALL" },
            { side = "bottom", label = "SOUTH WALL" },
            { side = "left",   label = "FAR SIDE - GROUPS WAIT" },
            { side = "right",  label = "GURTOGG" },
        },
        boss  = { x = 0.78, y = 0.55, label = "GURTOGG" },
        -- The red line from the diagram. Crossing it is the whole rotation.
        lines = {
            { x1 = 0.55, y1 = 0.12, x2 = 0.55, y2 = 0.90, label = "SOAK LINE", color = "danger" },
        },
        slots = {
            { id = "mt",      x = 0.72, y = 0.60, mark = 8, label = "Main tank",  where = "on him -- swap at 7-10 Acidic Wound stacks" },
            { id = "ot",      x = 0.72, y = 0.50, mark = 7, label = "Offtank",    where = "beside the MT, ready for the swap" },
            { id = "melee",   x = 0.66, y = 0.55, mark = 6, label = "Melee",      where = "on him, inside the line" },
            { id = "group_1", x = 0.42, y = 0.66, mark = 1, label = "Group 1",    where = "far side, cross to soak when called" },
            { id = "group_2", x = 0.42, y = 0.44, mark = 5, label = "Group 2",    where = "far side, you are next across" },
            { id = "group_3", x = 0.28, y = 0.55, mark = 3, label = "Group 3",    where = "furthest back, third in the rotation" },
            { id = "soak",    x = 0.62, y = 0.55, mark = 2, label = "Soak spot",  where = "over the line -- take the Boil, then move back up" },
        },
    },

    -- Phase 1 has no threat table: he hits whoever is closest, so the tanks
    -- take turns stepping in. The red ring is that "closest" band.
    reliquary = {
        name = "Reliquary of Souls",
        texture = "reliquary",
        note = "Phase 1 has NO threat table and healing is impossible -- the active tank simply stands closest and the others step back. Phase 2 reflects damage.",
        landmarks = {
            { side = "top",    label = "THE RELIQUARY" },
            { side = "bottom", label = "ENTRANCE" },
            { side = "left",   label = "RANGED SPREAD" },
            { side = "right",  label = "OPEN FLOOR" },
        },
        boss  = { x = 0.52, y = 0.72, label = "ESSENCE" },
        zones = {
            { cx = 0.52, cy = 0.72, r = 0.12, label = "CLOSEST GETS HIT", color = "danger" },
            { cx = 0.36, cy = 0.38, r = 0.17, label = "Ranged spread",    color = "purple" },
        },
        slots = {
            { id = "tank_in",  x = 0.52, y = 0.62, mark = 8, label = "Active tank",   where = "step in and be the closest -- rotate out on the call" },
            { id = "tank_out", x = 0.64, y = 0.56, mark = 7, label = "Next tank",     where = "just outside, ready to step in" },
            { id = "melee",    x = 0.62, y = 0.68, mark = 6, label = "Melee",         where = "on him, behind the active tank" },
            { id = "ranged",   x = 0.36, y = 0.38, mark = 4, label = "Ranged",        where = "west, spread -- P1 healers DPS here" },
            { id = "healers",  x = 0.24, y = 0.24, mark = 2, label = "Healers",       where = "south-west, spread from the ranged" },
        },
    },

    -- Two stacks, not four scatter spots: Saber Lash makes the stacked tanks
    -- immune to Fatal Attraction, which is why the stack exists at all.
    shahraz = {
        name = "Mother Shahraz",
        texture = "shahraz",
        note = "Melee under the statue's hand, ranged and healers under the fish statue. Tanks stack for Saber Lash -- they do NOT need shadow resistance.",
        landmarks = {
            { side = "top",    label = "FISH STATUE" },
            { side = "bottom", label = "THE WATERFALL" },
            { side = "left",   label = "ENTRANCE" },
            { side = "right",  label = "HER WALL" },
        },
        boss  = { x = 0.82, y = 0.36, label = "SHAHRAZ" },
        slots = {
            { id = "tanks",   x = 0.87, y = 0.28, mark = 8, label = "3 tanks STACKED", where = "on her, split Saber Lash -- HP and mitigation, not shadow resist" },
            { id = "melee",   x = 0.74, y = 0.30, mark = 6, label = "Melee",           where = "directly under the statue's hand or knee" },
            { id = "ranged",  x = 0.62, y = 0.48, mark = 4, label = "Ranged",          where = "directly under the fish statue" },
            { id = "healers", x = 0.56, y = 0.56, mark = 2, label = "Healers",         where = "with the ranged, under the fish statue" },
        },
    },

    -- Zerevor goes to the far corner with his mage. Everything else gets piled
    -- together so it can be cleaved.
    council = {
        name = "Illidari Council",
        texture = "council",
        note = "Zerevor is tanked by a MAGE in the far corner -- Arcane Explosion hits anything in melee range. Gathios, Malande and Veras get piled together for cleave.",
        landmarks = {
            { side = "top",    label = "THEIR DAIS" },
            { side = "bottom", label = "ENTRANCE" },
            { side = "left",   label = "MAGE CORNER" },
            { side = "right",  label = "CLEAVE PILE" },
        },
        boss  = { x = 0.74, y = 0.34, label = "CLEAVE PILE" },
        zones = {
            { cx = 0.38, cy = 0.32, r = 0.17, label = "Raid spreads", color = "green" },
        },
        slots = {
            { id = "mage_tank", x = 0.20, y = 0.84, mark = 5, label = "Mage tank - Zerevor", where = "far corner, Spellsteal Dampen Magic and keep him there" },
            { id = "mage_heal", x = 0.29, y = 0.76, mark = 3, label = "Zerevor healer",      where = "with the mage, out of Arcane Explosion range" },
            { id = "gathios",   x = 0.74, y = 0.40, mark = 8, label = "Gathios tank",        where = "cleave pile - walk him out of Consecration, Spell Reflect the Judgement" },
            { id = "malande",   x = 0.66, y = 0.28, mark = 4, label = "Malande tank",        where = "kited into the pile -- interrupters on Circle of Healing" },
            { id = "veras",     x = 0.82, y = 0.28, mark = 7, label = "Veras offtank",       where = "pick him up after every vanish and drag him back to the pile" },
            { id = "raid",      x = 0.38, y = 0.32, mark = 6, label = "Raid spread",         where = "centre, move the instant Blizzard or Flamestrike lands on you" },
        },
    },

    -- ---------------------------------------------------------------------
    -- Illidan, one layout per phase.
    -- ---------------------------------------------------------------------

    illidan = {
        name = "Illidan - phase 1",
        texture = "illidan",
        note = "Melee stay out of the front: Draw Soul heals him 100k. Tank walks him a little after every Flame Crash. Parasite target runs to the north pocket.",
        landmarks = {
            { side = "top",    label = "NORTH POCKET" },
            { side = "bottom", label = "STAIRS" },
            { side = "left",   label = "WEST" },
            { side = "right",  label = "EAST" },
        },
        boss  = { x = 0.51, y = 0.55, label = "ILLIDAN" },
        zones = {
            { cx = 0.51, cy = 0.71, r = 0.07, label = "Parasite drop", color = "ice" },
            { cx = 0.41, cy = 0.47, r = 0.06, label = "Flame Crash",   color = "danger" },
        },
        slots = {
            { id = "mt",       x = 0.50, y = 0.42, mark = 8, label = "Main tank",    where = "under him -- Shield Block or Holy Shield the Shear" },
            { id = "melee",    x = 0.59, y = 0.45, mark = 6, label = "Melee",        where = "behind him, NEVER in the front cone" },
            { id = "raid",     x = 0.31, y = 0.62, mark = 4, label = "Raid stacks",  where = "west of him, clear of the Flame Crash" },
            { id = "parasite", x = 0.51, y = 0.71, mark = 1, label = "Parasite drop",where = "north pocket -- a hunter trap here helps" },
        },
    },

    illidan_p2 = {
        name = "Illidan - phase 2, Flames of Azzinoth",
        texture = "illidan_p2",
        note = "Kite the Flames on the arcs and keep them pointed away. NEVER let a Flame get 25 yards from its glaive. Dodge the Eye Blast as it is being drawn.",
        landmarks = {
            { side = "top",    label = "NORTH" },
            { side = "bottom", label = "SOUTH" },
            { side = "left",   label = "WEST ARC" },
            { side = "right",  label = "EAST ARC" },
        },
        boss  = { x = 0.50, y = 0.60, label = "THE GLAIVES" },
        -- The blue streak on the diagram. It is drawn before it lands, which
        -- is the only window anyone has to move.
        lines = {
            { x1 = 0.70, y1 = 0.74, x2 = 0.46, y2 = 0.42, label = "EYE BLAST", color = "ice" },
        },
        slots = {
            { id = "flame_w",  x = 0.34, y = 0.60, mark = 8, label = "Flame tank WEST", where = "kite it on the west arc, capped fire resist" },
            { id = "flame_e",  x = 0.66, y = 0.74, mark = 7, label = "Flame tank EAST", where = "kite it on the east arc, capped fire resist" },
            { id = "melee",    x = 0.50, y = 0.52, mark = 6, label = "Melee",           where = "on the focused Flame, out of the Blaze" },
            { id = "group_1",  x = 0.56, y = 0.62, mark = 1, label = "Star group",      where = "share the space and move when the Eye Blast is drawn" },
            { id = "group_2",  x = 0.47, y = 0.75, mark = 2, label = "Circle group",    where = "north, away from the melee group" },
            { id = "group_3",  x = 0.42, y = 0.50, mark = 3, label = "Diamond group",   where = "south-west, away from the melee group" },
        },
    },

    illidan_p3 = {
        name = "Illidan - phase 3",
        texture = "illidan_p3",
        note = "Largely a repeat of phase 1, but everyone spreads 5 yards for Agonizing Flames. Parasites go to a named drop point -- pre-trap them.",
        landmarks = {
            { side = "top",    label = "NORTH DROP" },
            { side = "bottom", label = "STAIRS" },
            { side = "left",   label = "WEST DROP" },
            { side = "right",  label = "EAST DROP" },
        },
        boss  = { x = 0.51, y = 0.55, label = "ILLIDAN" },
        zones = {
            { cx = 0.51, cy = 0.66, r = 0.13, label = "Raid spreads 5 yd", color = "green" },
            { cx = 0.41, cy = 0.47, r = 0.06, label = "Flame Crash",       color = "danger" },
        },
        slots = {
            { id = "mt",     x = 0.50, y = 0.42, mark = 8, label = "Main tank",       where = "under him, same as phase 1" },
            { id = "melee",  x = 0.59, y = 0.45, mark = 6, label = "Melee",           where = "behind him, 5 yards from each other" },
            { id = "drop_n", x = 0.51, y = 0.86, mark = 1, label = "Parasite drop N", where = "north, pre-trapped" },
            { id = "drop_w", x = 0.29, y = 0.73, mark = 2, label = "Parasite drop W", where = "west, pre-trapped" },
            { id = "drop_e", x = 0.73, y = 0.73, mark = 3, label = "Parasite drop E", where = "east, pre-trapped" },
        },
    },

    illidan_p4 = {
        name = "Illidan - phase 4, demon form",
        texture = "illidan_p4",
        note = "Warlock tank takes him 20 yards clear -- Shadow Blast splashes that far. Melee back off: Aura of Dread is 15 yards. Focus the Shadow Demons instantly.",
        landmarks = {
            { side = "top",    label = "HE LIFTS OFF HERE" },
            { side = "bottom", label = "RAID SPREADS SOUTH" },
            { side = "left",   label = "WEST" },
            { side = "right",  label = "WARLOCK CORNER" },
        },
        boss  = { x = 0.50, y = 0.84, label = "ILLIDAN - DEMON" },
        zones = {
            { cx = 0.50, cy = 0.84, r = 0.11, label = "Aura of Dread 15 yd", color = "danger" },
            { cx = 0.48, cy = 0.34, r = 0.18, label = "Raid spreads 5 yd",   color = "green" },
        },
        slots = {
            { id = "warlock", x = 0.75, y = 0.62, mark = 8, label = "Warlock tank", where = "20 yards clear of everyone, shadow resistance gear" },
            { id = "wl_heal", x = 0.80, y = 0.50, mark = 7, label = "Warlock healer", where = "with the warlock, nobody else in Shadow Blast range" },
            { id = "melee",   x = 0.34, y = 0.54, mark = 6, label = "Melee",        where = "OFF him -- Aura of Dread is 15 yards" },
            { id = "raid",    x = 0.48, y = 0.34, mark = 4, label = "Raid spread",  where = "south, 5 yards apart for Flame Burst" },
        },
    },

    illidan_p5 = {
        name = "Illidan - phase 5, Maiev",
        texture = "illidan_p5",
        note = "Repeat of phase 3 until the enrage 40 seconds in. Call the region when a trap lands; the MT kites him into it and the enrage drops.",
        landmarks = {
            { side = "top",    label = "NORTH" },
            { side = "bottom", label = "STAIRS" },
            { side = "left",   label = "WEST" },
            { side = "right",  label = "EAST - MAIEV" },
        },
        boss  = { x = 0.51, y = 0.55, label = "ILLIDAN" },
        zones = {
            { cx = 0.51, cy = 0.66, r = 0.13, label = "Raid spreads 5 yd", color = "green" },
            { cx = 0.41, cy = 0.47, r = 0.06, label = "Flame Crash",       color = "danger" },
        },
        slots = {
            { id = "mt",     x = 0.50, y = 0.42, mark = 8, label = "Main tank",     where = "kite him into a trap, glaives are your priority" },
            { id = "melee",  x = 0.59, y = 0.45, mark = 6, label = "Melee",         where = "behind him, 5 yards apart" },
            { id = "traps",  x = 0.75, y = 0.48, mark = 1, label = "Trap watcher",  where = "call the region the moment a trap lands" },
            { id = "drop_n", x = 0.51, y = 0.86, mark = 2, label = "Parasite drop", where = "north, same as phase 3" },
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
