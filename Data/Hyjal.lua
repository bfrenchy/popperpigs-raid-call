-- Data/Hyjal.lua
--
-- The Battle for Mount Hyjal. 5 encounters, 32 waves.
--
-- SOURCE: Jurdi's Mount Hyjal Cheat Sheet (twitch.tv/jurdijd), supplied by the
-- raid leader this addon is built for. Wave compositions, boss ability numbers,
-- positioning and the tactical calls are his work, transcribed here.
--
-- Every wave step carries source = "jurdi". That is deliberately NOT the same
-- as verified: `verified` still means "confirmed against the live 2.5.6
-- client", and nothing here has been. A cited raid-tested document is a long
-- way better than the guesswork this file used to contain, but it is still not
-- the game telling us. The HUD flags a step only when it has neither.
--
-- NPC ids are the exception -- they are not in the cheat sheet and remain
-- unconfirmed. `/pprc scan` harvests the real ones during a clear.
--
-- Pure tables, zero logic. Mobs are named by id and defined once in
-- Data/Mobs.lua, so a wave lists what it contains and the mob panel does the
-- rest.

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

local SOURCE = "jurdi"

PPRC:RegisterInstance({
    id    = "hyjal",
    mapID = 534,
    name  = "The Battle for Mount Hyjal",
    credit = "Wave and boss data from Jurdi's Mount Hyjal Cheat Sheet (twitch.tv/jurdijd)",
    order = { "hyjal_winterchill", "hyjal_anetheron", "hyjal_kazrogal", "hyjal_azgalor", "hyjal_archimonde" },

    encounters = {

    -- =====================================================================
    -- Rage Winterchill -- Alliance base, waves 1-8
    -- =====================================================================
    hyjal_winterchill = {
        name  = "Rage Winterchill",
        base  = "Alliance Base",
        side  = "alliance",
        tanks = 1,
        npcID = 17767,
        waves = 8,
        steps = {
            {
                id = "wave1", wave = 1, label = "Wave 1", detail = "10 Ghouls",
                call = "Ghouls only. Hold the choke and AoE them down -- save cooldowns, this is the easy one.",
                advance = "worldstate", npcIDs = { GHOUL }, mobs = { "ghoul" },
                warn = { "HOLD THE CHOKE" }, source = SOURCE,
            },
            {
                id = "wave2", wave = 2, label = "Wave 2", detail = "10 Ghouls, 2 Crypt Fiends",
                call = "Two Crypt Fiends in with the ghouls. Watch for webs on the back line.",
                advance = "worldstate", npcIDs = { GHOUL, CRYPT_FIEND }, mobs = { "ghoul", "crypt_fiend" },
                warn = { "WEBS ON RANGED" }, source = SOURCE,
            },
            {
                id = "wave3", wave = 3, label = "Wave 3", detail = "6 Ghouls, 6 Crypt Fiends",
                call = "Even split. Nothing special -- kill them, break the webs.",
                advance = "worldstate", npcIDs = { GHOUL, CRYPT_FIEND }, mobs = { "ghoul", "crypt_fiend" },
                warn = { "BREAK THE WEBS" }, source = SOURCE,
            },
            {
                id = "wave4", wave = 4, label = "Wave 4", detail = "6 Ghouls, 4 Crypt Fiends, 2 Shadowy Necromancers",
                call = "First Necromancers. Only two, so they are manageable -- interrupt them and they do nothing.",
                advance = "worldstate", npcIDs = { GHOUL, CRYPT_FIEND, NECROMANCER },
                mobs = { "shadowy_necromancer", "ghoul", "crypt_fiend" },
                warn = { "INTERRUPT NECROS" }, source = SOURCE,
            },
            {
                id = "wave5", wave = 5, label = "Wave 5", detail = "2 Ghouls, 6 Crypt Fiends, 4 Shadowy Necromancers",
                call = "Four Necromancers -- that is the number where they start killing people. Full interrupt rotation, dispel Unholy Frenzy.",
                advance = "worldstate", npcIDs = { GHOUL, CRYPT_FIEND, NECROMANCER },
                mobs = { "shadowy_necromancer", "crypt_fiend", "ghoul" },
                warn = { "INTERRUPT ROTATION", "DISPEL FRENZY" }, source = SOURCE,
            },
            {
                id = "wave6", wave = 6, label = "Wave 6", detail = "6 Ghouls, 6 Abominations",
                call = "Six Abominations. No tank takes more than two, and drag about three away from the raid once threat is set so the poison is not ticking on everyone.",
                advance = "worldstate", npcIDs = { GHOUL, ABOMINATION }, mobs = { "abomination", "ghoul" },
                warn = { "FAP NOW", "MAX 2 PER TANK", "PEEL 3 ABOMS OUT" }, source = SOURCE,
            },
            {
                id = "wave7", wave = 7, label = "Wave 7", detail = "4 Ghouls, 4 Shadowy Necromancers, 4 Abominations",
                call = "Four Necros and four Aboms together. Necros die first, Aboms get stunned before they knock the tanks down.",
                advance = "worldstate", npcIDs = { GHOUL, NECROMANCER, ABOMINATION },
                mobs = { "shadowy_necromancer", "abomination", "ghoul" },
                warn = { "NECROS FIRST", "STUN THE ABOMS" }, source = SOURCE,
            },
            {
                id = "wave8", wave = 8, label = "Wave 8", detail = "6 Ghouls, 4 Crypt Fiends, 2 Abominations, 2 Shadowy Necromancers",
                call = "Last wave. Winterchill follows about a minute later -- do not chain-pull, get mana up.",
                advance = "worldstate", npcIDs = { GHOUL, CRYPT_FIEND, ABOMINATION, NECROMANCER },
                mobs = { "shadowy_necromancer", "abomination", "crypt_fiend", "ghoul" },
                warn = { "LAST WAVE", "MANA UP" }, source = SOURCE,
            },
            {
                id = "boss", label = "Rage Winterchill", detail = "Icebolt - Death and Decay - Frost Nova",
                call = "Hunter misdirect and drag him to the ballista. Spread for Death and Decay, dispel Frost Nova so nobody dies stuck in it, and lust once we are in position.",
                advance = "npc_id", npcID = 17767, posmap = "winterchill",
                warn = { "SPREAD FOR D&D", "DISPEL THE NOVA", "TRINKET ICEBOLT", "LUST" },
                source = SOURCE,
                brief = {
                    { spell = "Icebolt",         text = "4000-5000 instant frost damage plus 10k over 5 seconds, and the target is stunned for the duration. PvP trinket and any immunity (Divine Shield, Ice Block) breaks it." },
                    { spell = "Death and Decay", text = "A 20 yard patch dealing 15% of max health per second. Very hard to see -- treat it like the one in Botanica. A tank can stay in it if you heal them; nobody else should." },
                    { spell = "Frost Nova",      text = "2500-3000 frost damage and a 10 second root to anyone within 20 yards. Dispel it, or people die rooted inside Death and Decay. Priests should be ready to Mass Dispel the melee." },
                    { spell = "Frost Armor",     text = "Slows anyone attacking him physically by 25% attack speed and 50% movement." },
                    { spell = "Free Action Potion", text = "Removes Frost Nova and Frost Armor and prevents Icebolt outright. Likely worth more than a haste potion here." },
                    { spell = "Healer setup",    text = "Assign healers to the players near them so an Icebolt always has cover -- but do not leave the tank uncovered doing it." },
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
        side  = "alliance",
        tanks = 2,
        npcID = 17808,
        waves = 8,
        steps = {
            {
                id = "wave1", wave = 1, label = "Wave 1", detail = "10 Ghouls",
                call = "Ghouls only again. Same choke, easy start.",
                advance = "worldstate", npcIDs = { GHOUL }, mobs = { "ghoul" },
                warn = { "HOLD THE CHOKE" }, source = SOURCE,
            },
            {
                id = "wave2", wave = 2, label = "Wave 2", detail = "8 Ghouls, 4 Abominations",
                call = "Four Abominations -- two per tank, no more. Free Action Potions up.",
                advance = "worldstate", npcIDs = { GHOUL, ABOMINATION }, mobs = { "abomination", "ghoul" },
                warn = { "FAP NOW", "MAX 2 PER TANK" }, source = SOURCE,
            },
            {
                id = "wave3", wave = 3, label = "Wave 3", detail = "4 Ghouls, 4 Crypt Fiends, 4 Shadowy Necromancers",
                call = "Four Necromancers. Interrupt rotation on, do not let their casts land together.",
                advance = "worldstate", npcIDs = { GHOUL, CRYPT_FIEND, NECROMANCER },
                mobs = { "shadowy_necromancer", "crypt_fiend", "ghoul" },
                warn = { "INTERRUPT ROTATION" }, source = SOURCE,
            },
            {
                id = "wave4", wave = 4, label = "Wave 4", detail = "6 Crypt Fiends, 2 Banshees, 4 Shadowy Necromancers",
                call = "First Banshees. Decurse the Banshee Curse immediately -- 66% miss chance ends a wave fast. Necros still die first.",
                advance = "worldstate", npcIDs = { CRYPT_FIEND, BANSHEE, NECROMANCER },
                mobs = { "shadowy_necromancer", "banshee", "crypt_fiend" },
                warn = { "DECURSE", "NECROS FIRST" }, source = SOURCE,
            },
            {
                id = "wave5", wave = 5, label = "Wave 5", detail = "6 Ghouls, 4 Banshees, 2 Shadowy Necromancers",
                call = "Four Banshees. Kick the Wails, decurse fast, and swap to physical if one shells up.",
                advance = "worldstate", npcIDs = { GHOUL, BANSHEE, NECROMANCER },
                mobs = { "banshee", "shadowy_necromancer", "ghoul" },
                warn = { "DECURSE", "KICK THE WAIL" }, source = SOURCE,
            },
            {
                id = "wave6", wave = 6, label = "Wave 6", detail = "6 Ghouls, 2 Abominations, 4 Shadowy Necromancers",
                call = "Four Necros again. Silence them -- Arcane Bomb and Arcane Torrent are ideal.",
                advance = "worldstate", npcIDs = { GHOUL, ABOMINATION, NECROMANCER },
                mobs = { "shadowy_necromancer", "abomination", "ghoul" },
                warn = { "ARCANE BOMB", "INTERRUPT NECROS" }, source = SOURCE,
            },
            {
                id = "wave7", wave = 7, label = "Wave 7", detail = "2 Ghouls, 4 Crypt Fiends, 4 Banshees, 4 Abominations",
                call = "Heavy wave. Aboms split across tanks, melee onto Banshees once the Aboms are handled, decurse throughout.",
                advance = "worldstate", npcIDs = { GHOUL, CRYPT_FIEND, BANSHEE, ABOMINATION },
                mobs = { "abomination", "banshee", "crypt_fiend", "ghoul" },
                warn = { "MAX 2 PER TANK", "DECURSE", "MELEE ON BANSHEES" }, source = SOURCE,
            },
            {
                id = "wave8", wave = 8, label = "Wave 8", detail = "3 Ghouls, 3 Crypt Fiends, 2 Banshees, 2 Shadowy Necromancers, 4 Abominations",
                call = "Everything at once, then Anetheron. Drink before he lands -- healers to full.",
                advance = "worldstate", npcIDs = { GHOUL, CRYPT_FIEND, BANSHEE, NECROMANCER, ABOMINATION },
                mobs = { "abomination", "shadowy_necromancer", "banshee", "crypt_fiend", "ghoul" },
                warn = { "LAST WAVE", "DRINK NOW" }, source = SOURCE,
            },
            {
                id = "boss", label = "Anetheron", detail = "Carrion Swarm - Sleep - Summon Infernal",
                call = "Everyone spread evenly, healers especially -- Carrion Swarm cuts healing by 75%. Infernals are NOT tauntable, so the offtank picks them up at range and keeps them away from everyone.",
                advance = "npc_id", npcID = 17808, posmap = "anetheron",
                warn = { "SPREAD FOR SWARM", "DISPEL SLEEP", "INFERNAL - OFFTANK IT", "KEEP DEBUFFS UP" },
                source = SOURCE,
                brief = {
                    { spell = "Carrion Swarm",   text = "3000-6000 instant damage in a large frontal cone from a random target, and it reduces healing done by 75% for 15 seconds. Spread evenly so it never catches several healers at once." },
                    { spell = "Vampiric Aura",   text = "He heals for 300% of the melee damage he takes. Healing reduction debuffs -- Mortal Strike, Wound Poison -- must stay on him the whole fight or he outheals your DPS." },
                    { spell = "Summon Infernal", text = "Roughly every minute, a random player is stunned for 2 seconds and an Infernal drops on them for 3500 fire damage every 2 seconds. THEY ARE NOT TAUNTABLE." },
                    { spell = "Handling the Infernals", text = "Offtank stands away from the raid before one spawns. Targeted players move TOWARD the offtank but not on top of them, or they get stunned too. Paladin tanks are ideal -- Avenger's Shield and Exorcism pick them up at range. Fire resistance gear on that tank is worth it." },
                    { spell = "Sleep",           text = "Puts 2-3 players to sleep for ten seconds, untargetable and unable to act. Dispel it fast; a sleeping healer is how the fight is lost." },
                    { spell = "Consumables",     text = "He is a demon, so Elixir of Demonslaying is the best physical DPS elixir here." },
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
        side  = "horde",
        tanks = 3,
        npcID = 17888,
        waves = 8,
        steps = {
            {
                id = "wave1", wave = 1, label = "Wave 1", detail = "4 Ghouls, 2 Banshees, 4 Abominations, 2 Shadowy Necromancers",
                call = "Horde base now -- reposition to the Horde choke. Straight into a mixed wave: Aboms split, Necros interrupted, decurse.",
                advance = "worldstate", npcIDs = { GHOUL, BANSHEE, ABOMINATION, NECROMANCER },
                mobs = { "abomination", "shadowy_necromancer", "banshee", "ghoul" },
                warn = { "MOVE TO HORDE CHOKE", "MAX 2 PER TANK", "DECURSE" }, source = SOURCE,
            },
            {
                id = "wave2", wave = 2, label = "Wave 2", detail = "4 Ghouls, 10 Gargoyles",
                call = "Ten Gargoyles. Line of sight them behind the tents and buildings, ranged bring them down.",
                advance = "worldstate", npcIDs = { GHOUL, GARGOYLE }, mobs = { "gargoyle", "ghoul" },
                warn = { "LOS THE GARGOYLES", "RANGED ON GARGS" }, source = SOURCE,
            },
            {
                id = "wave3", wave = 3, label = "Wave 3", detail = "6 Ghouls, 6 Crypt Fiends, 2 Shadowy Necromancers",
                call = "Only two Necromancers -- easy wave. Break the webs and move on.",
                advance = "worldstate", npcIDs = { GHOUL, CRYPT_FIEND, NECROMANCER },
                mobs = { "shadowy_necromancer", "crypt_fiend", "ghoul" },
                warn = { "INTERRUPT NECROS" }, source = SOURCE,
            },
            {
                id = "wave4", wave = 4, label = "Wave 4", detail = "6 Crypt Fiends, 6 Gargoyles, 2 Shadowy Necromancers",
                call = "Gargoyles again -- LoS them in, ranged take them while melee handle the fiends.",
                advance = "worldstate", npcIDs = { CRYPT_FIEND, GARGOYLE, NECROMANCER },
                mobs = { "gargoyle", "shadowy_necromancer", "crypt_fiend" },
                warn = { "LOS THE GARGOYLES", "SPLIT TARGETS" }, source = SOURCE,
            },
            {
                id = "wave5", wave = 5, label = "Wave 5", detail = "4 Ghouls, 4 Abominations, 4 Shadowy Necromancers",
                call = "Four Aboms and four Necros. Sheep or fear the Necros if it is getting heavy -- they can be crowd controlled on this side.",
                advance = "worldstate", npcIDs = { GHOUL, ABOMINATION, NECROMANCER },
                mobs = { "abomination", "shadowy_necromancer", "ghoul" },
                warn = { "SHEEP THE NECROS", "MAX 2 PER TANK" }, source = SOURCE,
            },
            {
                id = "wave6", wave = 6, label = "Wave 6", detail = "8 Gargoyles, 1 Frostwyrm",
                call = "Gargoyles spawn LEFT, above the mountains. Use the Horde tower to line of sight them, then spread out for the Frostwyrm's breath.",
                advance = "worldstate", npcIDs = { GARGOYLE, FROST_WYRM }, mobs = { "gargoyle", "frost_wyrm" },
                warn = { "GARGS ON THE LEFT", "LOS AT THE TOWER", "SPREAD FOR BREATH" }, source = SOURCE,
            },
            {
                id = "wave7", wave = 7, label = "Wave 7", detail = "6 Ghouls, 4 Abominations, 1 Frostwyrm",
                call = "Ranged focus the Frostwyrm until it lands, melee hold the Aboms. Two per tank.",
                advance = "worldstate", npcIDs = { GHOUL, ABOMINATION, FROST_WYRM },
                mobs = { "abomination", "frost_wyrm", "ghoul" },
                warn = { "RANGED ON THE WYRM", "MAX 2 PER TANK" }, source = SOURCE,
            },
            {
                id = "wave8", wave = 8, label = "Wave 8", detail = "6 Ghouls, 2 Crypt Fiends, 2 Banshees, 2 Shadowy Necromancers, 4 Abominations",
                call = "Last wave. Everyone drink to full afterwards -- Kaz'rogal is decided by how much mana you bring to it.",
                advance = "worldstate", npcIDs = { GHOUL, CRYPT_FIEND, BANSHEE, NECROMANCER, ABOMINATION },
                mobs = { "abomination", "shadowy_necromancer", "banshee", "crypt_fiend", "ghoul" },
                warn = { "LAST WAVE", "DRINK TO FULL" }, source = SOURCE,
            },
            {
                -- The detonation triggers on INSUFFICIENT mana, not on being
                -- drained. Keeping mana high is what keeps you alive, and an
                -- earlier version of this file said the exact opposite.
                id = "boss", label = "Kaz'rogal", detail = "Mark of Kaz'rogal - Malevolent Cleave - War Stomp",
                call = "Mark drains your mana and you EXPLODE if it runs you dry -- keep mana up and pot through it. Tanks STACKED for the cleave, ranged past 12 yards for War Stomp. If you are about to bottom out, run out first.",
                advance = "npc_id", npcID = 17888, posmap = "kazrogal",
                warn = { "KEEP MANA UP", "POT / RUNE NOW", "RUN OUT IF LOW", "TANKS STACK" },
                source = SOURCE,
                brief = {
                    { spell = "Mark of Kaz'rogal", text = "Burns 3000 mana over 5 seconds -- 600 mana every second for 5 seconds. If it empties you, you explode for around 11k and damage everyone near you. High mana is what saves you -- do NOT dump mana before the pull." },
                    { spell = "Mark cadence",      text = "First cast about a minute in, then every 50 seconds, then 40, 30, 20, 10, and after that he spams it. Mana pressure compounds, so this is a race." },
                    { spell = "Staying above it",  text = "Mana Potions, Demonic Runes and Dark Runes on cooldown. Warlocks can sit in their own spot and life tap to never come close to empty. Divine Shield and similar immunities remove the debuff outright." },
                    { spell = "Class outs",        text = "Hunters swap to Aspect of the Viper while marked. Druids can shift to Cat Form and negate the drain entirely, since it has no mana to take." },
                    { spell = "Malevolent Cleave", text = "23,000 damage SPLIT between the targets it hits, which is why three tanks stack together to soak it. This is a requirement, not a preference -- do not wipe on the pull to bad tank positioning." },
                    { spell = "War Stomp",         text = "Stuns everyone within 12 yards for 5 seconds. All ranged stand further out than that." },
                    { spell = "Healing",           text = "He hits hard -- treat it like Magtheridon. Cleave does not reset his swing timer, so a tank can be two-shot if heals are slow." },
                    { spell = "If it goes wrong",  text = "If he is nearly dead and the raid is dying, Thrall and the Horde may finish him. Do not release until the fight is fully over." },
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
        side  = "horde",
        tanks = 2,
        npcID = 17842,
        waves = 8,
        steps = {
            {
                id = "wave1", wave = 1, label = "Wave 1", detail = "6 Abominations, 6 Shadowy Necromancers",
                call = "Straight into six Aboms and six Necros. Two Aboms per tank maximum, full interrupt rotation on the casters.",
                advance = "worldstate", npcIDs = { ABOMINATION, NECROMANCER },
                mobs = { "abomination", "shadowy_necromancer" },
                warn = { "MAX 2 PER TANK", "INTERRUPT ROTATION", "FAP NOW" }, source = SOURCE,
            },
            {
                id = "wave2", wave = 2, label = "Wave 2", detail = "5 Ghouls, 8 Gargoyles, 1 Frostwyrm",
                call = "Gargoyles and a Frostwyrm. LoS the gargoyles, ranged on the wyrm, spread for the breath.",
                advance = "worldstate", npcIDs = { GHOUL, GARGOYLE, FROST_WYRM },
                mobs = { "gargoyle", "frost_wyrm", "ghoul" },
                warn = { "LOS THE GARGOYLES", "SPREAD FOR BREATH" }, source = SOURCE,
            },
            {
                id = "wave3", wave = 3, label = "Wave 3", detail = "6 Ghouls, 8 Infernals",
                call = "Eight Infernals. These ones CAN be stunned -- stun them and burn them down. Do not stand in the immolation.",
                advance = "worldstate", npcIDs = { GHOUL, INFERNAL }, mobs = { "infernal", "ghoul" },
                warn = { "STUN THE INFERNALS", "OUT OF IMMOLATION" }, source = SOURCE,
            },
            {
                id = "wave4", wave = 4, label = "Wave 4", detail = "8 Infernals, 6 Fel Hounds",
                call = "Interrupt the Fel Hounds' Mana Burn or banish them. Watch for one Infernal that spawns far out, near the exit toward the Night Elf village.",
                advance = "worldstate", npcIDs = { INFERNAL }, mobs = { "infernal", "fel_hound" },
                warn = { "KICK MANA BURN", "STUN THE INFERNALS", "ONE SPAWNS FAR OUT" }, source = SOURCE,
            },
            {
                id = "wave5", wave = 5, label = "Wave 5", detail = "6 Felstalkers, 4 Abominations, 4 Shadowy Necromancers",
                call = "Arcane Bombs here -- they work on the Felstalkers and the Necromancers both.",
                advance = "worldstate", npcIDs = { ABOMINATION, NECROMANCER },
                mobs = { "felstalker", "abomination", "shadowy_necromancer" },
                warn = { "ARCANE BOMB", "MAX 2 PER TANK" }, source = SOURCE,
            },
            {
                id = "wave6", wave = 6, label = "Wave 6", detail = "6 Banshees, 6 Shadowy Necromancers",
                call = "All casters. Silence them immediately or they will nuke the tank down. Sheep and fear are on the table here.",
                advance = "worldstate", npcIDs = { BANSHEE, NECROMANCER },
                mobs = { "shadowy_necromancer", "banshee" },
                warn = { "SILENCE NOW", "SHEEP THE NECROS", "DECURSE" }, source = SOURCE,
            },
            {
                id = "wave7", wave = 7, label = "Wave 7", detail = "2 Ghouls, 2 Crypt Fiends, 2 Felstalkers, 8 Infernals",
                call = "Eight Infernals again. Stun them, rotate melee out of the immolation when they get low.",
                advance = "worldstate", npcIDs = { GHOUL, CRYPT_FIEND, INFERNAL },
                mobs = { "infernal", "felstalker", "crypt_fiend", "ghoul" },
                warn = { "STUN THE INFERNALS", "ROTATE OUT" }, source = SOURCE,
            },
            {
                id = "wave8", wave = 8, label = "Wave 8", detail = "4 Crypt Fiends, 2 Felstalkers, 4 Banshees, 2 Shadowy Necromancers, 4 Abominations",
                call = "Last wave of the night's trash. Full mana before Azgalor, and warlocks get soulstones out.",
                advance = "worldstate", npcIDs = { CRYPT_FIEND, BANSHEE, NECROMANCER, ABOMINATION },
                mobs = { "abomination", "banshee", "shadowy_necromancer", "felstalker", "crypt_fiend" },
                warn = { "LAST WAVE", "SOULSTONES OUT" }, source = SOURCE,
            },
            {
                id = "boss", label = "Azgalor", detail = "Doom - Rain of Fire - Howl of Azgalor",
                call = "Ranged stay OUTSIDE 30 yards and Rain of Fire cannot touch you. Doom targets run out and get soulstoned before they die. If the fire lands on melee, tank moves him.",
                advance = "npc_id", npcID = 17842, posmap = "azgalor",
                warn = { "DOOM - RUN OUT", "SOULSTONE THE DOOM", "MOVE OUT OF RAIN", "RANGED BACK OUT" },
                source = SOURCE,
                brief = {
                    { spell = "Doom",            text = "A 20 second debuff that kills the target when it expires and spawns a Doomguard. Run out before it lands, and soulstone them before they die." },
                    { spell = "Rain of Fire",    text = "10 seconds of fire for roughly 1700 every 2 seconds, only cast within 30 yards of him. IT LEAVES A DOT THAT KEEPS TICKING AFTER YOU LEAVE THE FIRE -- that is what causes the wipes. Ranged standing past 30 yards never get hit at all." },
                    { spell = "Doomguards",      text = "The offtank drags them into melee and helps DPS the boss. They have a War Stomp of their own." },
                    { spell = "Howl of Azgalor", text = "A 5 second raid silence. Shadow Resistance can resist it, so priests hand out their SR buff and healers wear their Mother Shahraz resist gear." },
                    { spell = "Cleave",          text = "Weapon damage plus 1700 and a knockback. Treat the tank healing like Magtheridon -- full mitigation and avoidance." },
                    { spell = "Raid setup",      text = "A sixth healer is worth it here to cover a bad silence-into-fire-tick. Save potions for health rather than damage on week one. Shadow Priests are the exception -- they have to be inside Rain of Fire range." },
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
        side  = "alliance",
        tanks = 1,
        npcID = 17968,
        waves = 0,
        -- The API cannot read any of these, so they are checkboxes rather than
        -- inferred ticks.
        checklist = {
            "EVERYONE has looted Tears of the Goddess from Tyrande",
            "Tears is on an action bar, not sitting in a bag",
            "Raid split into 4-5 spread groups",
            "Every group has a decurser and a shaman",
        },
        steps = {
            {
                id = "prep", label = "Pre-pull - Tears of the Goddess", detail = "Every single player loots Tears from Tyrande",
                call = "Not a suggestion: everyone loots Tears of the Goddess from Tyrande and puts it on a bar. If you get Air Burst without it, you die on landing.",
                advance = "manual", posmap = "archimonde",
                warn = { "TEARS FROM TYRANDE", "PUT IT ON YOUR BAR" }, source = SOURCE,
            },
            {
                id = "positioning", label = "Positioning", detail = "4-5 loose groups, decurser and shaman in each",
                call = "Split into four or five groups, loosely spread, each with a decurser and a shaman. Loose spacing is what keeps Air Burst from catching a whole group.",
                advance = "manual", posmap = "archimonde",
                warn = { "SPREAD IN GROUPS", "DECURSER PER GROUP" }, source = SOURCE,
            },
            {
                id = "fight", label = "Archimonde", detail = "Air Burst - Doomfire - Fear - Grip of the Legion",
                call = "Decursing is priority one, all fight. Tears right before you land from an Air Burst. Run FROM Doomfire, never through it. Fight ends at 10 percent.",
                advance = "npc_id", npcID = 17968, posmap = "archimonde",
                warn = { "DECURSE - PRIORITY ONE", "USE YOUR TEAR", "RUN FROM DOOMFIRE", "FEAR INCOMING" },
                source = SOURCE,
                brief = {
                    { spell = "Air Burst",       text = "Throws the target and anyone close to them into the air. Use Tears of the Goddess right before you land, not on the way up." },
                    { spell = "Doomfire Strike", text = "Summons a fire that paths randomly around the area. Standing in it applies a 45 second ticking burn. Run away from it, never through it and never toward the raid." },
                    { spell = "Grip of the Legion", text = "A curse dealing 2500 shadow damage every 2 seconds. Decursing is the number one job in this fight." },
                    { spell = "Fear",            text = "Fears the whole raid for 8 seconds. Tremor totems and fear wards on rotation." },
                    { spell = "Soul Charge -- why deaths cascade", text = "Every death hits the raid for 4500 and adds an effect based on the class that died. Priest, Mage or Warlock: fire damage plus a 6 second silence. Warrior, Rogue or Paladin: damage plus 50% increased damage taken. Druid, Shaman or Hunter: 2250 mana drained plus 4500 nature damage over 8 seconds." },
                    { spell = "Tanking",         text = "He does not crush but swings for around 10k. The tank will be moving all fight if the fire is bad -- reposition him if Doomfire closes in." },
                    { spell = "The end",         text = "The encounter ends at 10%, not at zero." },
                },
            },
        },
    },

    },
})
