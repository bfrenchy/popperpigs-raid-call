-- Data/Mobs.lua
--
-- Trash mob reference for Mount Hyjal.
--
-- SOURCE: Jurdi's Mount Hyjal Cheat Sheet (twitch.tv/jurdijd), supplied by the
-- raid leader this addon is built for. Ability numbers, kill priorities and
-- handling notes are his; they are a raid-tested document rather than a guide
-- summary, which is why the wave data keyed to this file carries
-- source = "jurdi" instead of being flagged unverified.
--
-- Wave steps in Data/Hyjal.lua name the mobs they contain by the ids here, and
-- UI/MobPanel.lua renders whatever the current step names. So a mob's abilities
-- are written once and surface on every wave that includes it.
--
-- `priority` drives the panel's ordering and colour: "high" means kill or
-- control this before anything else in the pack.

local ADDON_NAME, PPRC = ...

PPRC.Mobs = {

    ghoul = {
        name = "Ghoul", priority = "normal",
        note = "Just kill them. You will not notice their abilities.",
        abilities = {
            { name = "Enrage",      text = "150% melee attack speed and 20% larger." },
            { name = "Cannibalize", text = "Eats corpses at low health to regenerate." },
        },
    },

    crypt_fiend = {
        name = "Crypt Fiend", priority = "normal",
        note = "Just kill them. Web is the only thing you will feel.",
        abilities = {
            { name = "Web",           text = "Roots players for 10 seconds." },
            { name = "Crypt Scarabs", text = "Summons three scarabs for ten seconds if it is not near a tank." },
        },
    },

    shadowy_necromancer = {
        name = "Shadowy Necromancer", priority = "high",
        note = "High priority. Interrupt and dispel everything they do. Only truly dangerous once four or more are casting.",
        abilities = {
            { name = "Shadowbolt",    text = "2435-2975 shadow damage on a 2 second cast.", kick = true },
            { name = "Cripple",       text = "Slows movement and attack speed by 50%.", kick = true, dispel = true },
            { name = "Raise Dead",    text = "Summons non-elite skeletons." },
            { name = "Unholy Frenzy", text = "100% attack speed for 20s plus 250 nature damage per second.", dispel = true },
        },
    },

    abomination = {
        name = "Abomination", priority = "high",
        note = "High priority. Tanks use Free Action Potions, stun them before they stun you, and never hold more than two on one tank.",
        abilities = {
            { name = "Knockdown",     text = "Instant 4000 damage and a 2 second stun on the threat target." },
            { name = "Disease Cloud", text = "700 nature damage every 3 seconds to anyone within 3 yards." },
        },
    },

    banshee = {
        name = "Banshee", priority = "high",
        note = "Melee focus these once Abominations and Necromancers are dead. Decurse friendly targets immediately.",
        abilities = {
            { name = "Banshee Curse",    text = "66% melee and ranged hit reduction for 5 minutes. Decurse ASAP.", dispel = true },
            { name = "Banshee Wail",     text = "2500-3000 shadow damage.", kick = true },
            { name = "Anti-Magic Shell", text = "Absorbs 200,000 magic damage for 30 seconds. Swap to physical." },
        },
    },

    gargoyle = {
        name = "Gargoyle", priority = "normal",
        note = "Line of sight them using the tents and buildings around the area.",
        abilities = {
            { name = "Gargoyle Strike", text = "800-1000 nature damage bolt." },
        },
    },

    frost_wyrm = {
        name = "Frost Wyrm", priority = "normal",
        note = "Ranged focus it until it lands. Its model is bigger than it looks -- melee can reach it well before it touches down.",
        abilities = {
            { name = "Frost Breath", text = "2500-3500 AoE frost bolt volley. Spread for it." },
        },
    },

    infernal = {
        name = "Infernal", priority = "high",
        note = "Stun them and nuke them down. They can be stunned, unlike the ones Anetheron summons.",
        abilities = {
            { name = "Flame Buffet", text = "Increases fire damage taken by 50 for 1 minute, and it stacks." },
            { name = "Immolation",   text = "400-500 fire damage every 2 seconds to anyone within 15 yards." },
        },
    },

    fel_hound = {
        name = "Fel Hound", priority = "high",
        note = "Interrupt Mana Burn, or banish them if the pack is getting away from you.",
        abilities = {
            { name = "Mana Burn", text = "Drains mana and health.", kick = true },
        },
    },

    felstalker = {
        name = "Felstalker", priority = "high",
        note = "Arcane Bombs and Arcane Torrent work well here. Banish is an option too.",
        abilities = {
            { name = "Mana Burn", text = "Drains mana and health.", kick = true },
        },
    },
}

-- General rules that hold across every wave, rather than on any one step.
PPRC.MobRules = {
    alliance = {
        "Never let a tank hold more than 2-3 Abominations.",
        "Do not let Necromancers land their casts in sync on one target -- that is what kills people.",
        "Shadowy Necromancers are only really dangerous once there are 4 or more.",
        "Arcane Bombs and Blood Elf Arcane Torrent are great for silencing Necromancers.",
        "Hyjal is an outdoor raid, so combat is not zone-wide. Mind Control the last Necromancer to drop combat WITHOUT triggering the next wave, then rez, buff and drink.",
        "If a pack is going badly, drag it to the centre of the Alliance camp and let the NPCs help.",
    },
    horde = {
        "Trash often spawns in two parallel lines, so half the pack will break line of sight and aggro the Horde grunts. That is fine -- it takes damage off your tanks.",
        "Necromancers can be sheeped and feared on this side, which is a big help on wave 6.",
        "The Frostwyrm's model is larger than it appears; melee can hit it while it is still well above the ground.",
        "Infernals can be stunned. One on wave 4 spawns a long way out, near the exit toward the Night Elf village.",
        "Arcane Bombs and Arcane Torrent work on Fel Hounds too, or banish them if they become a hassle.",
        "Kaz'rogal wave 1 can bug and simply not spawn. If that happens, swap to Black Temple rather than lose the raid night to it.",
    },
}
