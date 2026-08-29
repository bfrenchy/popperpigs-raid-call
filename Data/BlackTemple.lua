-- Data/BlackTemple.lua
--
-- Black Temple. 9 encounters, phase-driven rather than wave-driven, plus the
-- named trash packs worth calling.
--
-- Pure tables, zero logic, same as Data/Hyjal.lua.
--
-- VERIFICATION -- READ THIS BEFORE TRUSTING AN ID
-- -----------------------------------------------
-- Everything here is verified = false: authored from knowledge, not read off a
-- live 2.5.6 client.
--
-- Boss NPC ids are the more confident half. TRASH IDS ARE THE LEAST CONFIDENT
-- DATA IN THIS REPOSITORY, so packs where the id is genuinely unknown carry no
-- npcIDs at all rather than a plausible-looking guess. A wrong id surfaces the
-- wrong card, which is worse than no card: an empty npcIDs list simply means
-- that pack does not auto-surface and the RL clicks Next, which always works.
--
-- `/pprc scan` prints every NPC id seen with its creature name and flags the
-- ones missing from here. One clear night produces the paste that fixes this
-- file properly.

local ADDON_NAME, PPRC = ...

PPRC:RegisterInstance({
    id    = "blacktemple",
    mapID = 564,
    name  = "Black Temple",
    order = {
        "bt_najentus", "bt_supremus", "bt_akama", "bt_teron", "bt_bloodboil",
        "bt_reliquary", "bt_shahraz", "bt_council", "bt_illidan",
    },

    encounters = {

    -- =====================================================================
    bt_najentus = {
        name = "High Warlord Naj'entus",
        tanks = 1,
        npcID = 22887,
        posmap = "najentus",
        steps = {
            {
                id = "trash", label = "Approach trash", detail = "Naga packs before the bridge",
                call = "Single pull the naga, do not chain them. Casters get interrupted.",
                advance = "manual", warn = { "SINGLE PULL", "INTERRUPT CASTERS" }, verified = false,
            },
            {
                id = "boss", label = "High Warlord Naj'entus", detail = "Impaling Spine - Needle Spine - Tidal Shield",
                call = "When you get a spine, CLICK IT and throw it back at him. The shield does not break any other way.",
                advance = "npc_id", npcID = 22887, posmap = "najentus",
                warn = { "SPINE - CLICK IT", "THROW IT BACK", "SPREAD FOR NEEDLES" },
                verified = false,
                brief = {
                    { spell = "Impaling Spine",  text = "Impales a player and roots them. Someone clicks the spine on the ground to free them." },
                    { spell = "Tidal Shield",    text = "Absorbs all damage and ticks raid-wide. Only a thrown spine breaks it -- keep one ready." },
                    { spell = "Needle Spine",    text = "Hits several nearby players. Stay spread so it cannot chain through the stack." },
                },
            },
        },
    },

    -- =====================================================================
    bt_supremus = {
        name = "Supremus",
        tanks = 2,
        npcID = 22898,
        posmap = "supremus",
        steps = {
            {
                id = "phase1", label = "Phase 1 - tank and spank", detail = "Molten Punch - Hurtful Strike",
                call = "Offtank stays second on threat for Hurtful Strike. Move out of the volcanoes.",
                advance = "manual", npcID = 22898, posmap = "supremus",
                warn = { "OT STAY SECOND", "MOVE OUT OF FIRE" }, verified = false,
            },
            {
                id = "phase2", label = "Phase 2 - kite", detail = "He chases one player at reduced speed",
                call = "He is chasing someone. Run the full lap, do not cut corners, and nobody body-blocks the kiter.",
                advance = "manual", posmap = "supremus",
                warn = { "KITING - GIVE ROOM", "RUN THE LAP" }, verified = false,
            },
            {
                id = "alternate", label = "Alternating", detail = "Phases swap roughly every 60 seconds",
                call = "He alternates all fight. Tanks be ready to pick him back up the moment he stops chasing.",
                advance = "manual", posmap = "supremus",
                warn = { "SWAPPING - TANKS READY" }, verified = false,
                brief = {
                    { spell = "Hurtful Strike", text = "Hits the second-highest threat in melee. The offtank must hold that spot deliberately." },
                    { spell = "Molten Flame",   text = "Volcanoes erupt under players. Move, do not heal through them." },
                    { spell = "Volcanic Geyser", text = "Phase 2 ground effects follow the chased player. Everyone else stays clear of their path." },
                },
            },
        },
    },

    -- =====================================================================
    bt_akama = {
        name = "Shade of Akama",
        tanks = 1,
        npcID = 22841,
        steps = {
            {
                id = "channelers", label = "Shadowmoon Channelers", detail = "Kill the channelers to release the Shade",
                call = "Assigned groups on your own channeler. Do not let them re-channel -- interrupt everything.",
                advance = "manual", warn = { "YOUR CHANNELER", "INTERRUPT" }, verified = false,
            },
            {
                id = "adds", label = "Defenders and Sorcerers", detail = "Waves spawn from both sides",
                call = "Sorcerers heal the Shade -- they die first, every time.",
                advance = "manual", warn = { "SORCERERS FIRST", "WATCH BOTH SIDES" }, verified = false,
            },
            {
                id = "boss", label = "Shade of Akama", detail = "He walks to Akama and must be burned",
                call = "Shade is loose. Everything on the Shade now, he cannot be tanked -- just burn him.",
                advance = "npc_id", npcID = 22841,
                warn = { "ALL ON THE SHADE", "BURN IT" }, verified = false,
                brief = {
                    { spell = "Channelers", text = "Six Shadowmoon Channelers hold the Shade. Assigned groups kill them, interrupting on cooldown." },
                    { spell = "The Shade",  text = "Once free he walks toward Akama. He cannot be tanked or slowed; he is a pure damage race." },
                    { spell = "Add waves",  text = "Defenders and Sorcerers spawn throughout. Sorcerers heal him and are the priority kill." },
                },
            },
        },
    },

    -- =====================================================================
    bt_teron = {
        name = "Teron Gorefiend",
        tanks = 1,
        npcID = 22871,
        posmap = "teron",
        checklist = {
            "Ghost action bar practised by everyone",
            "Four corners assigned and pushed",
            "Constructs slow assignment agreed",
        },
        steps = {
            {
                id = "brief", label = "Pre-pull - corners", detail = "Four players, four corners",
                call = "Marked? Run to YOUR corner at 10 seconds. As a ghost: slow all four, then lance them down.",
                advance = "manual", posmap = "teron",
                warn = { "KNOW YOUR CORNER", "PRACTISE THE GHOST BAR" }, verified = false,
            },
            {
                id = "boss", label = "Teron Gorefiend", detail = "Shadow of Death - Constructs - Incinerate",
                call = "Shadow of Death is out. Get to your corner before it lands, slow the four constructs, then kill them.",
                advance = "npc_id", npcID = 22871, posmap = "teron",
                warn = { "SHADOW OF DEATH", "GO TO YOUR CORNER", "SLOW THE CONSTRUCTS", "DISPEL INCINERATE" },
                verified = false,
                brief = {
                    { spell = "Shadow of Death",  text = "Marks a player. After 55 seconds they die, become a ghost, and spawn four Shadowy Constructs." },
                    { spell = "Ghost action bar", text = "As a ghost you get four abilities. Slow and root all four constructs, then burn them down before the ghost expires." },
                    { spell = "Incinerate",       text = "Heavy fire damage on a random player. Dispel promptly." },
                    { spell = "Crushing Shadows", text = "Shadow damage amplifier. Dispel it or the next hit is far worse." },
                },
            },
        },
    },

    -- =====================================================================
    bt_bloodboil = {
        name = "Gurtogg Bloodboil",
        tanks = 2,
        npcID = 22948,
        steps = {
            {
                id = "boss", label = "Gurtogg Bloodboil", detail = "Bloodboil - Fel Rage - Acidic Wound",
                call = "Fel Rage target runs to the ranged spot and gets healed hard. Everyone else stays spread for Bloodboil.",
                advance = "npc_id", npcID = 22948,
                warn = { "FEL RAGE - RUN OUT", "HEALS ON FEL RAGE", "SPREAD FOR BLOODBOIL", "TANK SWAP" },
                verified = false,
                brief = {
                    { spell = "Bloodboil",    text = "Hits the players nearest him, stacking. The raid rotates so the same people do not eat every stack." },
                    { spell = "Fel Rage",     text = "Fixates one player, who takes enormous damage and must be healed through it. They run to the assigned spot." },
                    { spell = "Acidic Wound", text = "Tank debuff that stacks. Swap tanks before it becomes unhealable." },
                    { spell = "Eject",        text = "Throws the tank. Expect a threat gap right after." },
                },
            },
        },
    },

    -- =====================================================================
    bt_reliquary = {
        name = "Reliquary of Souls",
        tanks = 2,
        npcID = 23418,
        steps = {
            {
                id = "suffering", label = "Phase 1 - Essence of Suffering", detail = "Fixate - Frenzy - Soul Drain",
                call = "Suffering fixates and cannot be tanked. Assigned kiter runs it, everyone else DPS and stay away.",
                advance = "npc_id", npcID = 23418,
                warn = { "FIXATE - KITE IT", "DO NOT STAND NEAR" }, verified = false,
            },
            {
                id = "desire", label = "Phase 2 - Essence of Desire", detail = "Spirit Shock - Deaden - Rune Shield",
                call = "Desire reflects damage back as shadow. Healers watch yourselves -- Deaden halves your healing.",
                advance = "npc_id", npcID = 23419,
                warn = { "SHADOW REFLECT", "DEADEN ON HEALERS" }, verified = false,
            },
            {
                id = "anger", label = "Phase 3 - Essence of Anger", detail = "Spite - Seethe - Soul Scream",
                call = "Anger is the burn phase. Spite explodes on the target -- if you get it, run out before it detonates.",
                advance = "npc_id", npcID = 23420,
                warn = { "SPITE - RUN OUT", "BURN IT DOWN" }, verified = false,
                brief = {
                    { spell = "Essence of Suffering", text = "Fixates a random player and cannot be tanked. One assigned kiter runs it for the whole phase." },
                    { spell = "Essence of Desire",    text = "Reflects a share of damage taken back onto the raid as shadow. Deaden halves healing received." },
                    { spell = "Essence of Anger",     text = "Spite marks players and explodes. Run out of the raid before it lands." },
                    { spell = "Between phases",       text = "There is a gap between essences. Use it to drink -- it is the only mana break in the fight." },
                },
            },
        },
    },

    -- =====================================================================
    bt_shahraz = {
        name = "Mother Shahraz",
        tanks = 1,
        npcID = 22947,
        posmap = "shahraz",
        checklist = {
            "Shadow resistance gear equipped by everyone",
            "Fatal Attraction spots assigned and pushed",
            "Resistance aura / totem assigned",
        },
        steps = {
            {
                id = "prep", label = "Pre-pull - shadow resist", detail = "Everyone in resist gear",
                call = "Shadow resist gear ON. This is the fight it exists for -- check now, not after the wipe.",
                advance = "manual", posmap = "shahraz",
                warn = { "SHADOW RESIST ON", "CHECK YOUR SPOT" }, verified = false,
            },
            {
                id = "boss", label = "Mother Shahraz", detail = "Fatal Attraction - Prismatic Aura - Saber Lash",
                call = "Fatal Attraction pulls three of you together. Go to YOUR spot immediately and do not stop moving.",
                advance = "npc_id", npcID = 22947, posmap = "shahraz",
                warn = { "FATAL ATTRACTION - MOVE", "GO TO YOUR SPOT", "DISPEL THE DEBUFFS" },
                verified = false,
                brief = {
                    { spell = "Fatal Attraction", text = "Teleports three players together and damages them for as long as they are near each other. Everyone has an assigned spot to run to." },
                    { spell = "Prismatic Aura",   text = "Rotating resistance aura. This is why shadow resist gear matters and why the fight is a gear check." },
                    { spell = "Saber Lash",       text = "Split between players near the tank. This fight wants the tank taking it, not the raid." },
                    { spell = "Silencing Shriek", text = "Raid-wide silence. Healers pre-hot where you can." },
                },
            },
        },
    },

    -- =====================================================================
    bt_council = {
        name = "Illidari Council",
        tanks = 4,
        npcID = 22949,
        steps = {
            {
                id = "boss", label = "Illidari Council", detail = "Gathios - Zerevor - Malande - Veras",
                call = "Four bosses, one health pool. Kill order and interrupts as assigned -- Zerevor gets interrupted every single cast.",
                advance = "npc_id", npcIDs = { 22949, 22950, 22951, 22952 },
                warn = { "INTERRUPT ZEREVOR", "DISPEL MALANDE", "TANK GATHIOS AWAY", "VERAS VANISHED" },
                verified = false,
                brief = {
                    { spell = "Gathios the Shatterer",   text = "Paladin. Blessings and auras; tank him away from the others and dispel his blessing where you can." },
                    { spell = "High Nethermancer Zerevor", text = "Mage. Blizzard, Flamestrike, Arcane Explosion. Interrupt every cast -- this is the single most important job." },
                    { spell = "Lady Malande",            text = "Priest. Heals the council and drops Circle of Healing. Interrupt and dispel." },
                    { spell = "Veras Darkshadow",        text = "Rogue. Vanishes and poisons a player. Dispel the poison; the tank re-picks him up on reappear." },
                    { spell = "Shared health",           text = "They share one pool, so damage anywhere counts. Positioning and interrupts decide this, not DPS." },
                },
            },
        },
    },

    -- =====================================================================
    -- Illidan. The one encounter where health thresholds genuinely drive the
    -- phases, so the health_pct advance mode does real work here.
    -- =====================================================================
    bt_illidan = {
        name = "Illidan Stormrage",
        tanks = 3,
        npcID = 22917,
        posmap = "illidan",
        checklist = {
            "Flame tanks assigned and in position",
            "Warlock tank ready for phase 4",
            "Fire resistance where you have it",
        },
        steps = {
            {
                id = "phase1", label = "Phase 1 - melee", detail = "Shear - Draw Soul - Parasitic Shadowfiend",
                call = "Tank swap on Shear. Parasitic Shadowfiends spawn from players -- kill them fast, they spread.",
                advance = "npc_id", npcID = 22917, posmap = "illidan",
                warn = { "TANK SWAP - SHEAR", "KILL THE FIENDS", "MOVE OUT OF DRAW SOUL" },
                verified = false,
            },
            {
                id = "phase2", label = "Phase 2 - flight and flames", detail = "Flames of Azzinoth at 65%",
                call = "He is up. Flame tanks take one each and hold them APART. Everyone else spreads for Dark Barrage.",
                advance = "health_pct", healthPct = 65, npcID = 22917, posmap = "illidan",
                warn = { "FLAME TANKS GO", "KEEP THEM APART", "SPREAD FOR BARRAGE" },
                verified = false,
            },
            {
                id = "phase3", label = "Phase 3 - back down", detail = "Shadow Demons - Agonizing Flames",
                call = "He is landing. Shadow Demons fixate -- ranged kill them before they reach anyone.",
                advance = "manual", posmap = "illidan",
                warn = { "SHADOW DEMONS", "RANGED KILL THEM" },
                verified = false,
            },
            {
                id = "phase4", label = "Phase 4 - demon form", detail = "Demon Form at 30%",
                call = "Demon form. Warlock tank takes him, everyone runs OUT of the aura and waits it out.",
                advance = "health_pct", healthPct = 30, npcID = 22917, posmap = "illidan",
                warn = { "DEMON FORM", "WARLOCK TANK", "RUN OUT OF THE AURA" },
                verified = false,
            },
            {
                id = "phase5", label = "Phase 5 - the end", detail = "Enrage timer, burn it",
                call = "Last phase. Everything you have left, right now. Bloodlust and burn.",
                advance = "manual", posmap = "illidan",
                warn = { "BLOODLUST NOW", "BURN IT" },
                verified = false,
                brief = {
                    { spell = "Shear",                text = "Removes the tank's shield or hits enormously. Tanks swap on it." },
                    { spell = "Parasitic Shadowfiend", text = "Spawns from a player and infects others on contact. Kill them immediately." },
                    { spell = "Flames of Azzinoth",   text = "Two elementals at 65%. One tank each, held far apart -- if the flames meet, the raid dies." },
                    { spell = "Shadow Demons",        text = "Fixate and stun whoever they reach. Ranged kill them on sight." },
                    { spell = "Demon Form",           text = "At 30% he transforms. The warlock tank takes him and everyone else leaves the aura." },
                },
            },
        },
    },

    },
})

-- ---------------------------------------------------------------------------
-- Named trash packs
--
-- Only the packs whose NPC id is reasonably known are keyed. The rest are
-- deliberately absent rather than guessed at: an unkeyed pack means the RL
-- clicks Next, which always works, while a wrong id would surface the wrong
-- card mid-pull. `/pprc scan` closes the gap with real values.
-- ---------------------------------------------------------------------------

PPRC.TrashPacks = PPRC.TrashPacks or {}

PPRC.TrashPacks.blacktemple = {
    {
        id = "promenade", name = "Illidari Promenade",
        call = "Nightlords fear and Heartseekers shoot from range. Interrupt the Nightlords, LOS the rest.",
        npcIDs = { 22872, 22873 },
        warn = { "INTERRUPT NIGHTLORDS", "LOS PULL" },
        verified = false,
    },
    {
        id = "channelers", name = "Shadowmoon Channelers",
        call = "Channelers must be interrupted or they heal each other forever.",
        npcIDs = {},   -- id unknown; surfaces manually rather than wrongly
        warn = { "INTERRUPT ROTATION" },
        verified = false,
    },
    {
        id = "ashtongue", name = "Ashtongue packs",
        call = "Sever the healers first, then the casters. Melee interrupt on cooldown.",
        npcIDs = {},   -- id unknown
        warn = { "HEALERS FIRST" },
        verified = false,
    },
}
