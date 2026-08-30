-- Data/BTTrash.lua
--
-- The Black Temple trash route.
--
-- SOURCE: the Raid Path sheet of cosmophile's Black Temple guide. Pull order,
-- compositions, handling notes and the skips are his.
--
-- This replaces three near-empty packs that used to sit in BlackTemple.lua,
-- two of which deliberately carried no NPC ids because I could not stand
-- behind them. A real route is worth more than any of that: it is the part of
-- the night nothing else owns, which is the whole thesis of this addon.
--
-- Pull numbers are the guide's own, so a call of "pull 6" matches what the RL
-- is reading. `skip` marks a pack the route avoids rather than kills -- those
-- are listed on purpose, because "which pack are we NOT pulling" is exactly
-- the thing that goes wrong when half the raid has read the guide and half
-- has not.
--
-- Note the guide's own caveat: some skips may not be permitted by Warcraft
-- Logs. Treat the skips as the route's intent, not a ruling.

local ADDON_NAME, PPRC = ...

PPRC.Route = {

    bt_najentus = {
        boss = "High Warlord Naj'entus",
        note = "Hug the RIGHT WALL to skip the first Aqueous Lord pack, then take the small door to the right of the big entrance.",
        pulls = {
            { n = 1, mobs = "2 Aqueous Spawns", note = "Two more path on the other side but can be ignored. Interrupt or stun Sludge Nova." },
            { n = 2, mobs = "2 Wranglers, 1 Leviathan", note = "Point the Wranglers away from the raid and spread for Lightning Prod. MT takes the Leviathan facing away -- it frenzies, so be ready for big heals." },
            { n = 3, mobs = "2 Aqueous Spawns", note = "Two more path on the other side; pull and kill them when you can." },
            { n = 4, mobs = "1 Aqueous Lord, 2 Sea-Callers", note = "Face everything away. Sea-Callers die first. If the Lord summons spawns, focus them or they heal him." },
            { n = 5, mobs = "Wranglers and a Leviathan", note = "Pull into the entrance of the room -- Wranglers left, Leviathan right. Careful not to pull extra." },
            { n = 6, mobs = "2 Soothsayers, 2 Generals, 1 Harpooner, 1 Dragon Turtle", note = "Soothsayers first. Generals hit rapidly, so watch their tank. Keep Hunter's Mark dispelled. The Harpooner points the turtle at random targets." },
            { n = 7, mobs = "2 Aqueous Spawns" },
            { n = 8, mobs = "2 Aqueous Lords", note = "One tank each, both faced away. Kill the small Spawns as they appear." },
            { n = 9, mobs = "10 Aqueous Spawns", note = "The messy one. Line of sight around the wall, paladin tank picks them up. Stuns and interrupts ready -- poison totems and Blood Elf silence shine here." },
        },
    },

    bt_supremus = {
        boss = "Supremus",
        note = "After the Taskmaster pack, hug the spiked wall on your right to skip the Wyrmcallers and Sky Stalkers. Pulls 2-4 can be done in any order.",
        pulls = {
            { n = 1, mobs = "1 Taskmaster, 6 Workers", note = "Face the Taskmaster away and AoE the rest." },
            { n = 2, mobs = "2 Wyrmcallers" },
            { n = 3, mobs = "Fearbringer", note = "Face away from the raid. War stomps and casts Rain of Fire." },
            { n = 4, mobs = "1 Taskmaster, 6 Workers", note = "You can take the patrolling Wyrmcallers here too." },
            { n = 5, mobs = "Skystalkers and Wyrmcallers", note = "Pull any Skystalkers patrolling the area. Line of sight or run away to bring the Sky Stalkers down.", skip = true },
        },
    },

    bt_akama = {
        boss = "Shade of Akama",
        pulls = {
            { n = 1, mobs = "1 Mystic, 1 Primalist, 1 Battlelord", note = "Always face Battlelords away. Mystics die first." },
            { n = 2, mobs = "2 Stalkers", note = "Stealthed. Tank and spank." },
            { n = 3, mobs = "1 Nightlord, 1 Boneslicer, 1 Defiler" },
            { n = 4, mobs = "1 Feral Spirit, 1 Primalist, 1 Stormcaller, 1 Storm Fury, 1 Mystic, 2 Battlelords, 1 Stalker", note = "The Feral Spirit has a huge aggro radius. Pull this back and fight at the bottom of the stairs. Battlelords face away." },
            { n = 5, mobs = "2 Centurions, 2 Defilers, 1 Boneslicer, 1 Heartseeker", note = "Face Centurions away. Banish the Boneslicers to avoid gouge." },
            { n = 6, mobs = "2 Primalists", note = "Pull back to avoid aggroing the patrolling Feral Spirit packs." },
            { n = 7, mobs = "1 Feral Spirit, 1 Battlelord, 1 Primalist, 1 Mystic", note = "Pull back to avoid the other wolf pack, though some groups take both." },
            { n = 8, mobs = "2 Stormcallers, 1 Battlelord, 1 Mystic" },
            { n = 9, mobs = "2 Battlelords, 1 Stormcaller, 1 Mystic" },
        },
    },

    bt_teron = {
        boss = "Teron Gorefiend",
        pulls = {
            { n = 1, mobs = "2 Champions, 2 Reavers", note = "Champions throw spinning axes. Dodge them." },
            { n = 2, mobs = "2 Houndmasters", note = "They dismount and two wolves appear." },
            { n = 3, mobs = "1 Champion, 2 Blood Mages, 2 War Hounds", note = "Blood Mages siphon life in a frontal cone -- face away and kill them first. Peek around the corner and fight on the stairs." },
            { n = 4, mobs = "1 Champion, 2 Reavers, 2 Grunts, 2 War Hounds", note = "If skipping the pack on the left, watch your proximity here." },
            { n = 5, mobs = "1 Weaponmaster, 7 Soldiers", note = "Focus the Weaponmaster, AoE the rest." },
            { n = 6, mobs = "Grunts along the left wall", note = "Run the left wall picking up grunts and carry them to the far side. There is a grunt stuck in a bed -- stack on it and kill it." },
            { n = 7, mobs = "2 Blood Mages, 2 Deathshapers, 1 Flayer", note = "Blood Mages, then Deathshapers, then the Flayer. The Flayer briefly fixates someone -- run, and melee stay out." },
            { n = 8, mobs = "2 Hands of Gorefiend", note = "Prepare for the boss before pulling these. Rage users can pool rage on them." },
        },
    },

    bt_bloodboil = {
        boss = "Gurtogg Bloodboil",
        pulls = {
            { n = 1, mobs = "2 Shield Disciples, 2 Blade Fury, 2 Blood Prophets, 2 Mutant War Hounds", note = "Blade Furies can be disarmed. Drop a slowing trap between the pack and the raid -- they drop aggro. Pull back to avoid the patrolling Behemoth." },
            { n = 2, mobs = "1 Behemoth", note = "Meteor or war stomp. Stay stacked for the meteor, spread for the stomp -- stacking with Free Action Potions gives you both." },
            { n = 3, mobs = "1 Combatant, 1 Brawler, 11 Spectators", note = "Tank the big ones facing away, AoE the small ones. Easy pack." },
            { n = 4, mobs = "2 Shield Disciples, 2 Blade Fury, 2 Blood Prophets" },
        },
    },

    bt_reliquary = {
        boss = "Reliquary of Souls",
        note = "THE GAUNTLET. Get fully buffed before you start it.",
        pulls = {
            { n = 1, mobs = "Gauntlet", note = "Hug the right wall and let the tank hold aggro. AoE everything down at the top of the ramp, then move down the ramp when you are ready to start the boss." },
        },
    },

    bt_shahraz = {
        boss = "Mother Shahraz",
        note = "Lots of patrolling mobs, so this order is only a suggestion -- pull in whatever order the pathing gives you. In general: AoE the big packs, and cleave the succubi without hitting Torment while her reflective shield is up.",
        pulls = {
            { n = 1, mobs = "Patrolling Steward", note = "If it is on the far-north side of the room you may be able to avoid it entirely.", skip = true },
            { n = 2, mobs = "1 Torment, 1 Delight", note = "They share 50% of damage taken. Cleave and focus Torment, swapping to Delight when Torment's reflective shield goes up -- or kill her before she can apply it." },
            { n = 3, mobs = "Patrolling mob", note = "If it is on the far-right of the room you may be able to avoid it entirely.", skip = true },
            { n = 4, mobs = "Dementia", note = "Splits into two whirlwinding mobs at low health. Plant your feet and kill them." },
            { n = 5, mobs = "Woe", note = "Puts a shadow damage debuff on someone. Negligible -- just kill it." },
        },
    },

    bt_council = {
        boss = "Illidari Council",
        note = "Most of this can be skipped by hugging the right wall.",
        pulls = {
            { n = 1, mobs = "1 Sentinel", note = "Can be skipped by avoiding its path.", skip = true },
            { n = 2, mobs = "2 Battle Lords, 2 Battle-Mages, 1 Assassin, 1 Archon", note = "Can be skipped by hugging the right wall -- watch for the Sentinel. If you fight it: Archons, then Mages, then Lords, then Assassins. Mages can be polymorphed." },
            { n = 3, mobs = "Stairs pack", note = "Can be skipped by hugging the right side, or bring it down the stairs.", skip = true },
            { n = 4, mobs = "Sentinels", note = "Their L5 Beam will one-shot most players. Power Word: Shield or Blessing of Protection on the targets immediately." },
        },
    },
}

-- Route order matches the instance's own encounter order, so "next pull"
-- always means the same thing to the addon and to the raid leader.
PPRC.RouteOrder = {
    "bt_najentus", "bt_supremus", "bt_akama", "bt_teron",
    "bt_bloodboil", "bt_reliquary", "bt_shahraz", "bt_council",
}
