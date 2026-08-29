-- Data/Hyjal.lua
--
-- The Battle for Mount Hyjal. 5 encounters, 32 waves.
--
-- Pure tables, zero logic. No NPC ID, spell name or wave composition appears
-- anywhere outside Data/, so when Blizzard shifts an ID in a patch -- which
-- 2.5.6 demonstrated they will -- the fix is a data edit that ships the same
-- night rather than a code change.
--
-- VERIFICATION
-- ------------
-- Every step carries `verified`. false means the composition or NPC ID was
-- authored from knowledge rather than read off the live 2.5.6 client, and has
-- not yet been confirmed in game. The HUD renders these normally -- they are
-- the RL's best available information -- but `/pprc debug` counts them and
-- `/pprc scan` harvests real values during a raid so they can be corrected
-- here. Flip the flag to true as each one is confirmed.
--
-- The `call` lines are authored raid-leading copy, not game data: they are the
-- literal words to say, and are not what `verified` is about.

local ADDON_NAME, PPRC = ...

-- Wave trash. IDs unconfirmed against 2.5.6; `/pprc scan` prints the real ones.
local GHOUL       = 17916
local ABOMINATION = 17886
local NECROMANCER = 17899
local BANSHEE     = 17905
local CRYPT_FIEND = 17897
local GARGOYLE    = 17906
local FROST_WYRM  = 17907
local INFERNAL    = 17908

PPRC:RegisterInstance({
    id    = "hyjal",
    mapID = 534,
    name  = "The Battle for Mount Hyjal",
    order = { "hyjal_winterchill", "hyjal_anetheron", "hyjal_kazrogal", "hyjal_azgalor", "hyjal_archimonde" },

    encounters = {

    -- =====================================================================
    -- Rage Winterchill -- Alliance base, waves 1-8
    -- =====================================================================
    hyjal_winterchill = {
        name  = "Rage Winterchill",
        base  = "Alliance Base",
        tanks = 1,
        npcID = 17767,
        waves = 8,
        steps = {
            {
                id = "wave1", wave = 1, label = "Wave 1", detail = "Ghouls",
                call = "Ghouls only. Tanks hold the choke, AoE them down, save cooldowns.",
                advance = "worldstate", npcIDs = { GHOUL },
                warn = { "HOLD THE CHOKE" }, verified = false,
            },
            {
                id = "wave2", wave = 2, label = "Wave 2", detail = "Ghouls + Necromancers",
                call = "Necros in the back are summoning skeletons -- kill the casters first, ghouls last.",
                advance = "worldstate", npcIDs = { GHOUL, NECROMANCER },
                warn = { "CASTERS FIRST", "INTERRUPT NECROS" }, verified = false,
            },
            {
                id = "wave3", wave = 3, label = "Wave 3", detail = "Ghouls + Abominations",
                call = "Abominations cleave -- tanks face them away from the raid. Melee behind.",
                advance = "worldstate", npcIDs = { GHOUL, ABOMINATION },
                warn = { "FACE ABOMS AWAY", "MELEE BEHIND" }, verified = false,
            },
            {
                id = "wave4", wave = 4, label = "Wave 4", detail = "Necromancers + Abominations + Banshees",
                call = "Banshees will possess -- decurse fast and do not stand alone. Casters die first.",
                advance = "worldstate", npcIDs = { NECROMANCER, ABOMINATION, BANSHEE },
                warn = { "DECURSE", "CASTERS FIRST" }, verified = false,
            },
            {
                id = "wave5", wave = 5, label = "Wave 5", detail = "Ghouls + Banshees",
                call = "Banshee wave. Dispellers on the tanks, everyone else burn the banshees.",
                advance = "worldstate", npcIDs = { GHOUL, BANSHEE },
                warn = { "DISPEL TANKS", "BURN BANSHEES" }, verified = false,
            },
            {
                id = "wave6", wave = 6, label = "Wave 6", detail = "Ghouls + Abominations",
                call = "Abominations up -- tanks pop Free Action Potion, OTs peel one or two off the MT.",
                advance = "worldstate", npcIDs = { GHOUL, ABOMINATION },
                warn = { "FAP NOW", "OT PEEL" }, verified = false,
            },
            {
                id = "wave7", wave = 7, label = "Wave 7", detail = "Necromancers + Banshees + Abominations",
                call = "Heaviest mixed wave so far. Interrupt rotation on necros, decurse the banshee curse.",
                advance = "worldstate", npcIDs = { NECROMANCER, BANSHEE, ABOMINATION },
                warn = { "INTERRUPT ROTATION", "DECURSE" }, verified = false,
            },
            {
                id = "wave8", wave = 8, label = "Wave 8", detail = "Full mixed wave -- everything at once",
                call = "Last wave. Everything at once, then Winterchill spawns immediately -- do not chain-pull, mana up.",
                advance = "worldstate", npcIDs = { GHOUL, ABOMINATION, NECROMANCER, BANSHEE },
                warn = { "LAST WAVE", "MANA UP AFTER" }, verified = false,
            },
            {
                id = "boss", label = "Rage Winterchill", detail = "Icebolt - Death and Decay - Frost Nova",
                call = "Trinket the Icebolt stun immediately. Move out of Death and Decay. Nova into D&D is what kills people.",
                advance = "npc_id", npcID = 17767, posmap = "winterchill",
                warn = { "TRINKET ICEBOLT", "MOVE OUT OF D&D", "SPREAD" },
                verified = false,
                brief = {
                    { spell = "Icebolt",        text = "4s stun on a random target plus heavy frost damage. Trinket or pot the moment it lands." },
                    { spell = "Death and Decay", text = "Ground effect, percentage of max HP per second. Move out immediately, do not heal through it." },
                    { spell = "Frost Nova",     text = "20 yard root, up to 10 seconds. The killer combo is Nova into D&D -- keep a trinket for it." },
                    { spell = "Frost Armor",    text = "Slows melee attack speed. Nothing to do, just expect slower threat." },
                },
            },
        },
    },

    -- =====================================================================
    -- Anetheron -- Alliance base, waves 1-8
    -- =====================================================================
    hyjal_anetheron = {
        name  = "Anetheron",
        base  = "Alliance Base",
        tanks = 1,
        npcID = 17808,
        waves = 8,
        steps = {
            {
                id = "wave1", wave = 1, label = "Wave 1", detail = "Ghouls + Necromancers",
                call = "Second base. Same opening -- casters first, hold the choke.",
                advance = "worldstate", npcIDs = { GHOUL, NECROMANCER },
                warn = { "CASTERS FIRST" }, verified = false,
            },
            {
                id = "wave2", wave = 2, label = "Wave 2", detail = "Ghouls + Crypt Fiends",
                call = "Crypt Fiends web -- ranged get rooted. Melee peel them off the back line.",
                advance = "worldstate", npcIDs = { GHOUL, CRYPT_FIEND },
                warn = { "WEBS ON RANGED", "MELEE PEEL" }, verified = false,
            },
            {
                id = "wave3", wave = 3, label = "Wave 3", detail = "Abominations + Necromancers",
                call = "Tanks face abominations away. Interrupts on the necros, do not let skeletons stack up.",
                advance = "worldstate", npcIDs = { ABOMINATION, NECROMANCER },
                warn = { "FACE ABOMS AWAY", "INTERRUPT NECROS" }, verified = false,
            },
            {
                id = "wave4", wave = 4, label = "Wave 4", detail = "Gargoyles + Ghouls",
                call = "Gargoyles are airborne -- ranged and hunters take them, melee stay on ghouls.",
                advance = "worldstate", npcIDs = { GARGOYLE, GHOUL },
                warn = { "RANGED ON GARGOYLES" }, verified = false,
            },
            {
                id = "wave5", wave = 5, label = "Wave 5", detail = "Banshees + Crypt Fiends",
                call = "Decurse the banshees, break webs. Nobody stands out of healer range.",
                advance = "worldstate", npcIDs = { BANSHEE, CRYPT_FIEND },
                warn = { "DECURSE", "STAY IN RANGE" }, verified = false,
            },
            {
                id = "wave6", wave = 6, label = "Wave 6", detail = "Frost Wyrms",
                call = "Frost Wyrm wave -- heavy frost breath. Tanks face them off the raid, healers watch the tank hard.",
                advance = "worldstate", npcIDs = { FROST_WYRM },
                warn = { "FACE WYRMS AWAY", "TANK HEALS UP" }, verified = false,
            },
            {
                id = "wave7", wave = 7, label = "Wave 7", detail = "Abominations + Gargoyles + Necromancers",
                call = "Split the raid: ranged on gargoyles, melee on abominations, interrupts on necros.",
                advance = "worldstate", npcIDs = { ABOMINATION, GARGOYLE, NECROMANCER },
                warn = { "SPLIT TARGETS", "INTERRUPT NECROS" }, verified = false,
            },
            {
                id = "wave8", wave = 8, label = "Wave 8", detail = "Full mixed wave + Frost Wyrms",
                call = "Last wave. Anetheron follows straight after -- drink before he lands, healers full mana.",
                advance = "worldstate", npcIDs = { GHOUL, ABOMINATION, BANSHEE, FROST_WYRM },
                warn = { "LAST WAVE", "DRINK NOW" }, verified = false,
            },
            {
                id = "boss", label = "Anetheron", detail = "Carrion Swarm - Sleep - Inferno",
                call = "Sleep is dispellable -- dispellers watch for it constantly. Infernals get picked up and kited, never tanked in the raid.",
                advance = "npc_id", npcID = 17808, posmap = "anetheron",
                warn = { "DISPEL SLEEP", "INFERNAL - KITE IT", "SPREAD FOR SWARM" },
                verified = false,
                brief = {
                    { spell = "Carrion Swarm", text = "Frontal cone, halves healing received. Stay out of the front, healers watch for the debuff." },
                    { spell = "Sleep",         text = "Random players sleep until damaged or dispelled. Dispel immediately -- a sleeping healer is how this fight is lost." },
                    { spell = "Inferno",       text = "Summons a Towering Infernal with an immolation aura. Assigned player kites it away from the raid; do not tank it in the stack." },
                    { spell = "Immolation",    text = "Passive raid damage aura from the infernals. This is why they get kited out." },
                },
            },
        },
    },

    -- =====================================================================
    -- Kaz'rogal -- Horde base, waves 1-8
    -- =====================================================================
    hyjal_kazrogal = {
        name  = "Kaz'rogal",
        base  = "Horde Base",
        tanks = 1,
        npcID = 17888,
        waves = 8,
        steps = {
            {
                id = "wave1", wave = 1, label = "Wave 1", detail = "Ghouls + Crypt Fiends",
                call = "Horde base now. Reposition to the Horde choke before the first wave lands.",
                advance = "worldstate", npcIDs = { GHOUL, CRYPT_FIEND },
                warn = { "MOVE TO HORDE CHOKE" }, verified = false,
            },
            {
                id = "wave2", wave = 2, label = "Wave 2", detail = "Abominations + Ghouls",
                call = "Abominations again -- face away, melee behind, OTs pick up strays.",
                advance = "worldstate", npcIDs = { ABOMINATION, GHOUL },
                warn = { "FACE ABOMS AWAY", "OT PEEL" }, verified = false,
            },
            {
                id = "wave3", wave = 3, label = "Wave 3", detail = "Necromancers + Banshees",
                call = "All casters. Interrupt rotation, decurse, and kill them before the skeletons pile up.",
                advance = "worldstate", npcIDs = { NECROMANCER, BANSHEE },
                warn = { "INTERRUPT ROTATION", "DECURSE" }, verified = false,
            },
            {
                id = "wave4", wave = 4, label = "Wave 4", detail = "Gargoyles + Crypt Fiends",
                call = "Ranged take gargoyles, melee break the webs. Do not let the back line get pinned.",
                advance = "worldstate", npcIDs = { GARGOYLE, CRYPT_FIEND },
                warn = { "RANGED ON GARGOYLES" }, verified = false,
            },
            {
                id = "wave5", wave = 5, label = "Wave 5", detail = "Abominations + Necromancers + Ghouls",
                call = "Big pull. Tanks establish first, then AoE -- do not open with AoE and rip threat.",
                advance = "worldstate", npcIDs = { ABOMINATION, NECROMANCER, GHOUL },
                warn = { "TANKS FIRST", "WAIT FOR THREAT" }, verified = false,
            },
            {
                id = "wave6", wave = 6, label = "Wave 6", detail = "Frost Wyrms + Banshees",
                call = "Frost Wyrms plus banshees. Face the wyrms off the raid and keep decursing.",
                advance = "worldstate", npcIDs = { FROST_WYRM, BANSHEE },
                warn = { "FACE WYRMS AWAY", "DECURSE" }, verified = false,
            },
            {
                id = "wave7", wave = 7, label = "Wave 7", detail = "Full mixed wave",
                call = "Everything. Hold the choke, do not chase runners into the base.",
                advance = "worldstate", npcIDs = { GHOUL, ABOMINATION, NECROMANCER, GARGOYLE },
                warn = { "HOLD THE CHOKE", "DO NOT CHASE" }, verified = false,
            },
            {
                id = "wave8", wave = 8, label = "Wave 8", detail = "Full mixed wave -- final",
                call = "Last wave before Kaz'rogal. Everyone drink -- this fight is decided by mana pools.",
                advance = "worldstate", npcIDs = { GHOUL, ABOMINATION, BANSHEE, FROST_WYRM },
                warn = { "LAST WAVE", "DRINK TO FULL" }, verified = false,
            },
            {
                id = "boss", label = "Kaz'rogal", detail = "Mark of Kaz'rogal - War Stomp - Cripple",
                call = "Mark drains mana and explodes when you hit zero. Mana users spend down BEFORE the pull and stay spread -- the explosion chains.",
                advance = "npc_id", npcID = 17888, posmap = "kazrogal",
                warn = { "SPEND YOUR MANA", "SPREAD - MARK EXPLODES", "STOMP INCOMING" },
                verified = false,
                brief = {
                    { spell = "Mark of Kaz'rogal", text = "Drains mana. At zero mana it explodes for heavy damage to everyone nearby. Spread out, and burn mana down deliberately before the pull." },
                    { spell = "War Stomp",         text = "Raid-wide stun. Nothing to avoid, but healers should expect a gap in healing right after it." },
                    { spell = "Cripple",           text = "Slows attack and movement on melee. Expect lower melee output; not dispellable by most." },
                    { spell = "Malevolent Cleave", text = "Heavy frontal cleave. Melee stay behind him at all times." },
                },
            },
        },
    },

    -- =====================================================================
    -- Azgalor -- Horde base, waves 1-8
    -- =====================================================================
    hyjal_azgalor = {
        name  = "Azgalor",
        base  = "Horde Base",
        tanks = 1,
        npcID = 17842,
        waves = 8,
        steps = {
            {
                id = "wave1", wave = 1, label = "Wave 1", detail = "Ghouls + Necromancers",
                call = "Final wave set. Same choke, casters first.",
                advance = "worldstate", npcIDs = { GHOUL, NECROMANCER },
                warn = { "CASTERS FIRST" }, verified = false,
            },
            {
                id = "wave2", wave = 2, label = "Wave 2", detail = "Abominations + Crypt Fiends",
                call = "Face abominations away, melee free the webbed ranged.",
                advance = "worldstate", npcIDs = { ABOMINATION, CRYPT_FIEND },
                warn = { "FACE ABOMS AWAY" }, verified = false,
            },
            {
                id = "wave3", wave = 3, label = "Wave 3", detail = "Banshees + Gargoyles",
                call = "Decurse on cooldown, ranged pull the gargoyles down.",
                advance = "worldstate", npcIDs = { BANSHEE, GARGOYLE },
                warn = { "DECURSE", "RANGED ON GARGOYLES" }, verified = false,
            },
            {
                id = "wave4", wave = 4, label = "Wave 4", detail = "Infernals",
                call = "Infernals -- immolation aura, so melee rotate out when low. Kite, do not stand in them.",
                advance = "worldstate", npcIDs = { INFERNAL },
                warn = { "IMMOLATION - ROTATE OUT" }, verified = false,
            },
            {
                id = "wave5", wave = 5, label = "Wave 5", detail = "Frost Wyrms + Abominations",
                call = "Wyrms face away, abominations face away. Nothing points at the raid.",
                advance = "worldstate", npcIDs = { FROST_WYRM, ABOMINATION },
                warn = { "EVERYTHING FACES AWAY" }, verified = false,
            },
            {
                id = "wave6", wave = 6, label = "Wave 6", detail = "Full mixed wave",
                call = "Hold the line. Healers rotate drinks between waves from here on.",
                advance = "worldstate", npcIDs = { GHOUL, NECROMANCER, BANSHEE, GARGOYLE },
                warn = { "ROTATE DRINKS" }, verified = false,
            },
            {
                id = "wave7", wave = 7, label = "Wave 7", detail = "Infernals + Frost Wyrms",
                call = "Heaviest wave of the instance. Cooldowns now -- do not save them for the boss.",
                advance = "worldstate", npcIDs = { INFERNAL, FROST_WYRM },
                warn = { "COOLDOWNS NOW" }, verified = false,
            },
            {
                id = "wave8", wave = 8, label = "Wave 8", detail = "Full mixed wave -- final",
                call = "Last wave of the night's trash. Full mana before Azgalor, and warlocks get soulstones out.",
                advance = "worldstate", npcIDs = { GHOUL, ABOMINATION, INFERNAL, FROST_WYRM },
                warn = { "LAST WAVE", "SOULSTONES OUT" }, verified = false,
            },
            {
                id = "boss", label = "Azgalor", detail = "Doom - Rain of Fire - Howl of Azgalor",
                call = "Doom is a death sentence with a timer -- if you get it, run out NOW and die away from the raid so the Doomguard spawns clear.",
                advance = "npc_id", npcID = 17842, posmap = "azgalor",
                warn = { "DOOM - RUN OUT", "MOVE OUT OF RAIN", "DOOMGUARD - BANISH" },
                verified = false,
                brief = {
                    { spell = "Doom",            text = "Kills the target after 20 seconds and spawns a Lesser Doomguard. Run out immediately so it spawns away from the raid." },
                    { spell = "Lesser Doomguard", text = "Spawns from Doom. Banish or offtank it -- never let it free-roam into the healers." },
                    { spell = "Rain of Fire",    text = "Ground fire on random spots. Move out, do not try to heal through it." },
                    { spell = "Howl of Azgalor", text = "Raid-wide silence. Healers pre-hot before it lands where you can." },
                },
            },
        },
    },

    -- =====================================================================
    -- Archimonde -- no waves, one long fight
    -- =====================================================================
    hyjal_archimonde = {
        name  = "Archimonde",
        base  = "Nordrassil",
        tanks = 1,
        npcID = 17968,
        waves = 0,
        -- The API cannot read any of these, so they are checkboxes rather than
        -- inferred ticks. A green tick in this addon always means the game
        -- confirmed it, and none of this can be confirmed without inspection.
        checklist = {
            "Everyone has looted Tears of the Goddess",
            "Tears is on an action bar, not in a bag",
            "Tremor totems / fear ward assigned per group",
            "Everyone spread to their starting spot",
        },
        steps = {
            {
                id = "prep", label = "Pre-pull -- Tears of the Goddess", detail = "Everyone loots Tears from the base NPC",
                call = "Everyone has a Tear of the Goddess and it is on your bars. If you get Air Burst, use it on the way down or you die on landing.",
                advance = "manual", posmap = "archimonde",
                warn = { "TEARS ON YOUR BARS", "CHECK YOUR SPACING" }, verified = false,
            },
            {
                id = "positioning", label = "Positioning", detail = "Spread wide, Doomfire needs room",
                call = "Spread out properly before we pull. Doomfire chases people and it will wipe us if we are stacked.",
                advance = "manual", posmap = "archimonde",
                warn = { "SPREAD WIDE" }, verified = false,
            },
            {
                id = "fight", label = "Archimonde", detail = "Fear - Air Burst - Doomfire - Grip of the Legion",
                call = "Tremor and fear ward up. Run FROM Doomfire, never through it. Anyone thrown by Air Burst uses their Tear.",
                advance = "npc_id", npcID = 17968, posmap = "archimonde",
                warn = { "FEAR INCOMING", "RUN FROM DOOMFIRE", "USE YOUR TEAR", "DECURSE GRIP" },
                verified = false,
                brief = {
                    { spell = "Fear",             text = "Raid-wide. Tremor totems and fear wards on rotation; this is what breaks positioning." },
                    { spell = "Air Burst",        text = "Throws players into the air. Use your Tear of the Goddess on the way down or the fall kills you." },
                    { spell = "Doomfire",         text = "A moving fire that chases players. Run away from it, never through it, and never toward the raid." },
                    { spell = "Grip of the Legion", text = "Magic debuff, heavy damage over time. Dispel promptly." },
                    { spell = "Finger of Death",  text = "Instantly kills anyone too far from him. Do not kite out of range." },
                },
            },
        },
    },

    },
})
