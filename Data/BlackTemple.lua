-- Data/BlackTemple.lua
--
-- Black Temple. 9 encounters, phase-driven rather than wave-driven.
--
-- SOURCE: cosmophile's Black Temple guide, supplied by the raid leader this
-- addon is built for. Abilities, spell ids, phase timings, tank rules and the
-- tactical calls are transcribed from it. Spell ids are the guide's own.
--
-- Every step carries source = "cosmophile". As with Hyjal that is deliberately
-- NOT the same as verified: `verified` still means "confirmed against the live
-- 2.5.6 client", and nothing here has been. A raid-tested document beats the
-- guesswork this file used to hold, but it is not the game telling us.
--
-- NPC ids are the exception -- they are not in the guide and remain
-- unconfirmed. `/pprc scan` harvests the real ones during a clear.
--
-- The trash route lives in Data/BTTrash.lua.

local ADDON_NAME, PPRC = ...

local SOURCE = "cosmophile"

PPRC:RegisterInstance({
    id    = "blacktemple",
    mapID = 564,
    name  = "Black Temple",
    credit = "Boss and trash data from cosmophile's Black Temple guide",
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
        checklist = {
            "Spine buddy system agreed -- everyone has a partner",
            "Raid knows NOT to pop the shield until everyone is above 8,501 HP",
        },
        steps = {
            {
                id = "boss", label = "High Warlord Naj'entus", detail = "Impaling Spine - Tidal Shield - Tidal Burst",
                call = "Spread 6 yards. If your buddy gets impaled, click the spine and HOLD IT. Nobody pops the shield until everyone is above 8,500 health -- he only regens 1% a second, we have all the time we need.",
                advance = "npc_id", npcID = 22887, posmap = "najentus",
                warn = { "SPREAD 6 YARDS", "FREE THE IMPALED", "HOLD THE SPINE", "TOP EVERYONE UP", "POP IT NOW" },
                source = SOURCE,
                brief = {
                    { spell = "Needle Spine", spellID = 39835, text = "Frost damage to the target and anyone within 6 yards of them. Stay spread 6 yards and it only ever hits one person." },
                    { spell = "Impaling Spine", spellID = 39837, text = "Impales a player -- they cannot free themselves. Somebody else clicks the spine, and that person KEEPS it to break the shield. Run a buddy system so every raider knows who is pulling theirs." },
                    { spell = "Tidal Shield", spellID = 31256, text = "He becomes immune to all damage and regenerates 1% health per second. Only a thrown spine breaks it. Rogues can still build combo points through the shield." },
                    { spell = "Tidal Burst", spellID = 39878, text = "Breaking the shield deals 8,500 damage to the ENTIRE RAID. Everyone must be above 8,501 health before the spine goes in. This is the whole fight -- 1% a second is nothing, so take the time and top up." },
                    { spell = "Pacing", text = "Lust on the pull. There is an 8 minute enrage and you will not see it. Play clean." },
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
                id = "phase1", label = "Phase 1 - tank phase", detail = "60 seconds - Hateful Strike - Molten Flame",
                call = "Offtank in melee range, second or third on threat, and kept TOPPED OFF -- Hateful Strike hits whoever has the most health, so a full melee DPS eats it instead. Spread in the arc. At 55 seconds everyone spreads, melee included.",
                advance = "npc_id", npcID = 22898, posmap = "supremus",
                warn = { "OT TOPPED AND IN RANGE", "OUT OF THE BLUE FIRE", "SPREAD AT 55s" },
                source = SOURCE,
            },
            {
                id = "phase2", label = "Phase 2 - kite phase", detail = "60 seconds - Fixate - Volcanic Geyser",
                call = "He is chasing someone. Stay between 5 and 40 yards -- go past 40 and he charges you. Use the ramp to kite, but do not out-range the healers. Stop DPS just before he switches back, threat drops on the transition.",
                advance = "manual", posmap = "supremus",
                warn = { "KITING - GIVE ROOM", "STAY 5-40 YARDS", "AVOID THE GEYSERS", "STOP DPS BEFORE SWAP" },
                source = SOURCE,
            },
            {
                id = "alternate", label = "Phases alternate", detail = "60 seconds each, all fight",
                call = "He swaps every 60 seconds all fight. Tanks be ready to pick him back up the moment he stops chasing.",
                advance = "manual", posmap = "supremus",
                warn = { "SWAPPING - TANKS READY" },
                source = SOURCE,
                brief = {
                    { spell = "Hateful Strike", spellID = 41926, text = "Massive damage to whoever has the MOST HEALTH among the 2nd and 3rd highest threat players in melee range. Not simply second on threat -- keep the offtank topped or a healthy melee DPS takes it instead." },
                    { spell = "Molten Flame", spellID = 40265, text = "Blue fire, roughly 3,500 per tick, and it spreads. Do not touch it." },
                    { spell = "Molten Punch", spellID = 40126, text = "He punches the ground and spawns Molten Flame." },
                    { spell = "Fixate", text = "Phase 2. Chases one player for about 10 seconds. Stay between 5 and 40 yards of him -- beyond 40 yards he charges the target. The ramp is fair game for kiting; just do not leave your healers behind." },
                    { spell = "Volcanic Geyser", spellID = 42052, text = "Blue volcanoes erupting for roughly 4,500 fire damage per second within 15 yards. Avoid at all costs." },
                    { spell = "Phase timing", text = "Each phase lasts exactly 60 seconds. At 55 seconds into phase 1 everyone spreads, melee included. Threat drops when he returns to phase 1, so stop damage just before the transition." },
                },
            },
        },
    },

    -- =====================================================================
    bt_akama = {
        name = "Shade of Akama",
        tanks = 3,
        npcID = 22841,
        checklist = {
            "A tank on each doorway for the add spawns",
            "Interrupt and purge assignments on the Spiritbinders",
            "A trash add parked in the middle for Seed of Corruption",
        },
        steps = {
            {
                id = "channelers", label = "Phase 1 - the six Channelers", detail = "Kill all six to release the Shade",
                call = "Six Channelers around the Shade, all of them have to die. Tank on every doorway for the spawns -- Sorcerer, Elementalist and Rogue every 35 seconds, a Defender every minute.",
                advance = "manual",
                warn = { "TANKS ON THE DOORWAYS", "KILL THE CHANNELERS", "SEED IN THE MIDDLE" },
                source = SOURCE,
            },
            {
                id = "adds", label = "Add control", detail = "Spiritbinders heal - Sorcerers cannot be tanked",
                call = "Interrupt the Spiritbinders' Chain Heal and purge Spirit Mend. Sorcerers cannot be tanked, so just kill them. Casters and healers stay 5 yards off the Defenders or they get Shield Bashed.",
                advance = "manual",
                warn = { "INTERRUPT SPIRITBINDERS", "PURGE SPIRIT MEND", "KILL THE SORCERERS", "5 YARDS OFF DEFENDERS" },
                source = SOURCE,
            },
            {
                id = "boss", label = "Phase 2 - Shade of Akama", detail = "60 seconds to kill him",
                call = "Shade is loose. Tanks hold the adds, healers keep the tanks up, lust and burn. Sixty seconds or he kills Akama.",
                advance = "npc_id", npcID = 22841,
                warn = { "ALL ON THE SHADE", "60 SECOND TIMER", "TANKS HOLD ADDS" },
                source = SOURCE,
                brief = {
                    { spell = "Ashtongue Channeler", text = "Six of them surround the Shade casting Shade Soul Channel. All six must die before you can fight him. Park a trash add in the middle beforehand and Seed of Corruption does a lot of the work." },
                    { spell = "Ashtongue Sorcerer", text = "CANNOT be tanked. They run from the doorways and channel; just kill them." },
                    { spell = "Ashtongue Spiritbinder", spellID = 42025, text = "The actual healer. Chain Heal -- interrupt it. Spirit Mend -- purge it." },
                    { spell = "Ashtongue Defender", text = "Hardest hitting add. Debilitating Strike, Heroic Strike and Shield Bash. Casters and healers stay 5 yards away or the Shield Bash interrupts them." },
                    { spell = "Ashtongue Rogue", spellID = 41978, text = "Eviscerates the tank for moderate damage. Dispel Debilitating Poison if it bites." },
                    { spell = "Ashtongue Elementalist", text = "Lightning Bolt damage is negligible; let the healers handle it. Move out of the Rain of Fire." },
                    { spell = "Spawn timing", text = "A Sorcerer, an Elementalist and a Rogue every ~35 seconds; a Defender every 60. Every add here can be crowd controlled." },
                    { spell = "Phase 2 timer", text = "Once the Shade is free you have 60 seconds to kill him or he kills Akama and the attempt is over." },
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
            "Everyone's pet bar is active (Steam Tonk Controller for non-pet classes)",
            "Ghost construct rotation practised: 5, 4, 3, 3, 3, 3",
            "Back corner agreed for Shadow of Death targets",
        },
        steps = {
            {
                id = "brief", label = "Pre-pull - the ghost rotation", detail = "5, 4, 3, 3, 3, 3 - tab between the 3s",
                call = "Check your pet bar works NOW. If you get Shadow of Death, walk to the back corner. As a ghost the rotation is 5, 4, 3, 3, 3, 3 -- tab target between each 3, and use 5 and 4 whenever they are off cooldown.",
                advance = "manual", posmap = "teron",
                warn = { "CHECK YOUR PET BAR", "5 4 3 3 3 3", "BACK CORNER" },
                source = SOURCE,
            },
            {
                id = "boss", label = "Teron Gorefiend", detail = "Shadow of Death - Incinerate - Doom Blossoms",
                call = "Tank and spank, lust on the pull. Shadow of Death target walks to the back corner and kills their four constructs. Dispel Incinerate the moment it lands.",
                advance = "npc_id", npcID = 22871, posmap = "teron",
                warn = { "SHADOW OF DEATH", "GO TO YOUR CORNER", "DISPEL INCINERATE", "HELP THE OTHER GHOSTS" },
                source = SOURCE,
                brief = {
                    { spell = "Shadow of Death", spellID = 40251, text = "Kills the target after 55 seconds, turning them into a Vengeful Spirit and spawning 4 Shadowy Constructs. Walk to the back corner of the room before it lands." },
                    { spell = "The ghost rotation", text = "5, 4, 3, 3, 3, 3 -- tab target between each 3. Use 5 and 4 whenever they are off cooldown. Once your constructs are dead, use 1 on the boss, and help any other ghost still working." },
                    { spell = "Pet bar", text = "The ghost abilities appear on the pet bar, so it has to be enabled BEFORE the pull. Non-pet classes can use a Steam Tonk Controller to make sure theirs is set up." },
                    { spell = "Incinerate", spellID = 40239, text = "About 3,000 fire damage on hit plus a damage-over-time worth ~8,500 over 3 seconds. Dispel it immediately." },
                    { spell = "Crushing Shadows", spellID = 40243, text = "Five random players take extra shadow damage. Not a big deal." },
                    { spell = "Doom Blossoms", text = "Non-targetable things that spawn as the fight runs long and cast Shadow Bolt at random. Effectively a soft enrage -- he should be dead before they matter." },
                },
            },
        },
    },

    -- =====================================================================
    bt_bloodboil = {
        name = "Gurtogg Bloodboil",
        tanks = 3,
        npcID = 22948,
        posmap = "bloodboil",
        checklist = {
            "Raid split into 3 groups of 5 for the Blood Boil rotation",
            "Healers and melee kept OUT of the soak rotation where possible",
            "Paladin BoP rotation agreed for the Fel Rage target",
            "All DPS know to stay below ALL tanks on threat",
        },
        steps = {
            {
                id = "phase1", label = "Phase 1 - the soak rotation", detail = "60 seconds - Blood Boil on the 5 FURTHEST players",
                call = "Three groups of five, rotate every 10 seconds. The soak group crosses the line, eats a stack, then moves up and the next group drops back. Melee in two tight groups behind him. Everyone stays below ALL tanks on threat.",
                advance = "npc_id", npcID = 22948, posmap = "bloodboil",
                warn = { "ROTATE THE SOAK", "MELEE BEHIND HIM", "STAY BELOW THE TANKS", "TANK SWAP 7-10" },
                source = SOURCE,
            },
            {
                id = "phase2", label = "Phase 2 - Fel Rage", detail = "30 seconds - starts on the 5th Blood Boil stack",
                call = "Fifth stack is out -- SPREAD now and be ready for Fel Rage. If you get it, blow every defensive you have, but do NOT feign or Ice Block. Paladins run the BoP rotation, healers spam it. Lust once we are stable.",
                advance = "manual", posmap = "bloodboil",
                warn = { "SPREAD FOR FEL RAGE", "SPAM HEAL THE TARGET", "BOP ROTATION", "DO NOT FEIGN / BLOCK" },
                source = SOURCE,
            },
            {
                id = "cycle", label = "Back to phase 1", detail = "Threat is a SNAPSHOT, not a reset",
                call = "Five seconds left -- collapse back to phase 1 positions. This is NOT a threat wipe: he goes back to whoever was tanking him at the END of phase 1.",
                advance = "manual", posmap = "bloodboil",
                warn = { "COLLAPSE BACK", "NOT A THREAT WIPE" },
                source = SOURCE,
                brief = {
                    { spell = "Blood Boil", spellID = 42005, text = "600 damage per second for 24 seconds, and it stacks. Applied to the 5 FURTHEST players -- which is why the soak is a rotation of three groups of five, swapping every 10 seconds. Keep healers and melee out of it where you can." },
                    { spell = "Acidic Wound", spellID = 40481, text = "Nature damage plus 500 armor reduction on the tank, applied every 3 seconds, stacking to 60. Swap tanks around 7-10 stacks -- the active tank has to slow their threat to let the next one take over." },
                    { spell = "Bewildering Strike", spellID = 40491, text = "Disorients the active tank for 5 seconds and removes them from the threat table. This forces a swap on its own." },
                    { spell = "Fel-Acid Breath", spellID = 40508, text = "Hits a random melee player for ~3k plus 2,750 every 5 seconds. Split melee into two tight groups behind him so it never catches everyone." },
                    { spell = "Arcing Smash", spellID = 40457, text = "5,000 damage frontal cone on a 10 second cooldown. First tank faces him away from the raid and the other tanks." },
                    { spell = "Eject", spellID = 40986, text = "Void Reaver style knockback that also drops threat. It can be dodged and does not always force a swap." },
                    { spell = "Fel Rage", spellID = 40594, text = "Phase 2. The target gets +15k armor, +30k health, +100% healing received, +300% damage and doubles in size, and the boss focuses them. Spam heal, use every defensive -- but do NOT feign death or Ice Block, it drops the fixate." },
                    { spell = "Fel Geyser", spellID = 40593, text = "18 yard damage and knockback centred on the Fel Rage target. The whole raid spreads in phase 2." },
                    { spell = "Insignificance", spellID = 40618, text = "Sets threat generation to 0 during phase 2. THIS IS NOT A THREAT RESET -- it snapshots the table at the end of phase 1, and he returns to whoever was tanking him then." },
                    { spell = "Phase timing", text = "Phase 1 runs 60 seconds, phase 2 runs 30. Spread as the 5th Blood Boil stack goes out; collapse back with about 5 seconds left in phase 2." },
                },
            },
        },
    },

    -- =====================================================================
    bt_reliquary = {
        name = "Reliquary of Souls",
        tanks = 3,
        npcID = 23418,
        posmap = "reliquary",
        checklist = {
            "Phase 1 tank rotation agreed (DPS included if needed)",
            "BoP rotation for whoever is tanking Suffering",
            "Spirit Shock interrupt rotation with backups",
            "A mage on Rune Shield spellsteal",
        },
        steps = {
            {
                id = "suffering", label = "Phase 1 - Essence of Suffering", detail = "No threat table - NO healing is possible",
                call = "He hits whoever is CLOSEST, so tanks rotate in and out as they get low. Nobody can be healed this phase -- healers, DPS him. Priests shield whoever is tanking. Dispel Soul Drain instantly and burn every drop of mana; the intermission gives it all back.",
                advance = "npc_id", npcID = 23418,
                warn = { "CLOSEST GETS HIT", "ROTATE THE TANKING", "HEALERS DPS", "DISPEL SOUL DRAIN", "BOP INCOMING" },
                source = SOURCE,
            },
            {
                id = "desire", label = "Phase 2 - Essence of Desire", detail = "Your damage reflects back at you",
                call = "Damage reflects -- watch you do not kill yourself. Mages spellsteal the Rune Shield the moment it goes up. Interrupt rotation on Spirit Shock, it cannot be allowed to land. Warrior tank spell reflects Deaden.",
                advance = "npc_id", npcID = 23419,
                warn = { "SPELLSTEAL RUNE SHIELD", "INTERRUPT SPIRIT SHOCK", "REFLECT THE DEADEN", "WATCH THE REFLECT" },
                source = SOURCE,
            },
            {
                id = "anger", label = "Phase 3 - Essence of Anger", detail = "Offtank starts it, MT taunts, then everything",
                call = "Offtank pulls, MT taunts immediately and builds threat under the 200% buff, hunters misdirect. DPS holds a few seconds then everything goes in with lust. Healers on the Spite targets. Warrior MT stance dances before Soul Scream to dump rage.",
                advance = "npc_id", npcID = 23420,
                warn = { "OT PULLS - MT TAUNT", "HOLD DPS A MOMENT", "HEALS ON SPITE", "DUMP RAGE - SOUL SCREAM", "LUST" },
                source = SOURCE,
                brief = {
                    { spell = "Aura of Suffering", spellID = 41292, text = "Phase 1. Prevents ALL healing and health regeneration and reduces armor. Power Word: Shield still works, which is the only mitigation there is." },
                    { spell = "Fixate", spellID = 41294, text = "Phase 1 has no threat table -- he fixates the closest player. Run a tank rotation, moving in and out as health allows, and include DPS if you have to. Warriors can shield-tank it, rogues can evasion tank the enrage. Note BoP makes him swap targets." },
                    { spell = "Soul Drain", spellID = 41303, text = "Drains 2,625-3,375 health AND mana every 3 seconds. Dispel it immediately." },
                    { spell = "Enrage (P1)", spellID = 41305, text = "Enrages every 45 seconds for 15 seconds of increased damage. This is when a rogue's evasion earns its place." },
                    { spell = "Intermissions", text = "Between every phase there is an intermission that restores all health and mana. Do not hoard mana in phase 1 -- spend it." },
                    { spell = "Aura of Desire", spellID = 41350, text = "Phase 2. Healing done is doubled, but 50% of your damage reflects back onto you, and max mana drops 5% every 8 seconds -- after about 160 seconds everyone is at zero." },
                    { spell = "Spirit Shock", spellID = 41426, text = "1 second cast for massive damage that disorients the target for 5 seconds and drops them from the threat table. It must never land. Rotation with backups; rogues with PvP gloves can cover every cast." },
                    { spell = "Rune Shield", spellID = 41431, text = "Absorbs 50,000 damage, grants immunity to interrupts and doubles his attack speed. Mages spellsteal it immediately." },
                    { spell = "Deaden", text = "1 second cast that doubles the target's damage taken for 10 seconds. The warrior tank spell reflects it." },
                    { spell = "Aura of Anger", spellID = 41337, text = "Phase 3. Shadow damage every 3 seconds, starting at 100 and climbing 100 per tick. It is a hard soft-enrage -- this phase is a race." },
                    { spell = "Seethe", spellID = 41364, text = "Fires after a target swap: +100% attack speed on him and +200% threat generation for the raid for 10 seconds. That is why the offtank starts the pull and the MT taunts into it. Soothe removes the attack speed." },
                    { spell = "Soul Scream", spellID = 41545, text = "Frontal cone for ~3k shadow PLUS damage scaled to how much mana or rage you are holding. Warrior MT watches the timer and stance dances to dump rage right before it." },
                    { spell = "Spite", spellID = 41376, text = "Three random players go immune for 2 seconds, take 7,500 damage, then go immune for 2 more. Healers pre-empt it." },
                },
            },
        },
    },

    -- =====================================================================
    bt_shahraz = {
        name = "Mother Shahraz",
        tanks = 3,
        npcID = 22947,
        posmap = "shahraz",
        checklist = {
            "Raid at 174+ shadow resistance UNBUFFED (more makes it easy)",
            "TANKS ARE EXEMPT - they want HP and mitigation, not resist gear",
            "Fatal Attraction WeakAura installed (see /pprc wa)",
            "Tanks keeping Ironshield potions up",
        },
        steps = {
            {
                id = "prep", label = "Pre-pull - shadow resistance", detail = "174 unbuffed minimum, tanks exempt",
                call = "Shadow resist on, 174 unbuffed is the floor and more makes this easy. Tanks do NOT wear resist -- stamina and mitigation, she hits far too hard for anything else. All three tanks stack in front of her.",
                advance = "manual", posmap = "shahraz",
                warn = { "SHADOW RESIST ON", "TANKS: HP NOT RESIST", "ALL 3 TANKS STACK" },
                source = SOURCE,
            },
            {
                id = "boss", label = "Mother Shahraz", detail = "Fatal Attraction - Beams - Prismatic Shield",
                call = "Fatal Attraction takes three of you somewhere random and LINKS you -- run apart the instant you land or it bleeds the raid. Everyone else stacks tight for the beams and heals through them.",
                advance = "npc_id", npcID = 22947, posmap = "shahraz",
                warn = { "FATAL ATTRACTION - RUN APART", "STACK FOR BEAMS", "SILENCE - PRE-HOT" },
                source = SOURCE,
                brief = {
                    { spell = "Saber Lash", spellID = 40810, text = "Heavy damage split between up to 3 targets -- and it grants IMMUNITY TO FATAL ATTRACTION. That is precisely why all three tanks stack in front of her. Threat is not an issue here, so tanks stack avoidance and health." },
                    { spell = "Fatal Attraction", spellID = 41001, text = "Teleports 3 random players to a random spot and links them, dealing 3k shadow to everyone nearby until the links break. Run away from each other IMMEDIATELY -- there is a WeakAura for this, see /pprc wa." },
                    { spell = "Beams", spellID = 40827, text = "Every 30 seconds one of four beams hits a player and chains to up to 10 more. Sinful is heavy damage, Vile is a DoT, Sinister is damage plus knockback, Wicked drains mana. Nothing to dodge -- stack tightly and heal through them." },
                    { spell = "Prismatic Shield", spellID = 40879, text = "Every 15 seconds it cuts damage taken from one magic school by 25% and raises another by 25%. The pairs are Arcane/Nature, Fire/Frost and Holy/Shadow. It is a damage modifier, not a resistance aura." },
                    { spell = "Silencing Shriek", spellID = 40823, text = "Silences anyone hit for 10 seconds within 18 yards. Healers pre-hot where they can." },
                    { spell = "Tanking her", text = "She cannot crush, so a bear tank works well. Keep Ironshield potions up -- she hits very hard and threat is never the problem." },
                },
            },
        },
    },

    -- =====================================================================
    bt_council = {
        name = "Illidari Council",
        tanks = 4,
        npcID = 22949,
        posmap = "council",
        checklist = {
            "A MAGE assigned to tank Zerevor, with a dedicated healer",
            "Melee AND ranged interrupters on Malande's Circle of Healing",
            "Curse of Tongues kept up",
            "Offtank ready to re-pick Veras after every vanish",
        },
        steps = {
            {
                id = "boss", label = "Illidari Council", detail = "Gathios - Zerevor - Malande - Veras, one health pool",
                call = "Gathios is the focus target. A MAGE tanks Zerevor and spellsteals Dampen Magic. Interrupt Circle of Healing or she heals all four for 100k. Offtank grabs Veras after every vanish and drags him onto Gathios for the cleave. Keep Curse of Tongues up.",
                advance = "npc_id", npcIDs = { 22949, 22950, 22951, 22952 }, posmap = "council",
                warn = { "INTERRUPT CIRCLE OF HEALING", "MAGE TANK ZEREVOR", "VERAS VANISHED", "MOVE OUT OF CONSECRATION", "DISPEL THE STUN" },
                source = SOURCE,
                brief = {
                    { spell = "Gathios the Shatterer", text = "The DPS focus target. The MT moves him out of his own Consecration and melee move without waiting to be told. Spell reflect the Seal of Command judgement where you can, and dispel Hammer of Justice." },
                    { spell = "Consecration", spellID = 41541, text = "2,250 damage every 3 seconds for 20 seconds. Move out of it -- do not wait for the tank." },
                    { spell = "Judgement", spellID = 41467, text = "Under Seal of Command it hits for 7k and can be spell reflected. Under Seal of Blood it deals 11k over 9 seconds." },
                    { spell = "Hammer of Justice", spellID = 41468, text = "Stuns a random player for 6 seconds at 40 yards. It can be dispelled -- do it fast." },
                    { spell = "High Nethermancer Zerevor", spellID = 41478, text = "MUST BE TANKED BY A MAGE, who spellsteals Dampen Magic and needs a dedicated healer. He casts Arcane Explosion if anyone is inside 10 yards, so nobody else goes near him." },
                    { spell = "Arcane Bolt", spellID = 41483, text = "2 second cast for 15k, Zerevor's main attack. Interrupt it as often as possible -- a ranged interrupt rotation is worth setting up." },
                    { spell = "Blizzard / Flamestrike", spellID = 41482, text = "10 yard ground effects on random players, 6k and 5k+3k per tick respectively. Move immediately." },
                    { spell = "Lady Malande", spellID = 41455, text = "Circle of Healing is a 2.5 second cast that heals ALL FOUR bosses for 100,000, on a 20 second cooldown. It has to be interrupted every time." },
                    { spell = "Why she needs ranged interrupters", spellID = 41450, text = "Gathios casts Blessing of Protection, which makes a target immune to physical damage -- so melee interrupts stop working and the ranged rotation has to cover it. Note it cannot be cast on Gathios himself." },
                    { spell = "Veras Darkshadow", spellID = 41476, text = "Vanishes roughly every 30 seconds and reappears on a random player with Deadly Poison into Envenom -- 1k per second for 4 seconds, then 6k. Priests shield the target, and the offtank must re-pick him quickly, then drag him to Gathios for the cleave." },
                    { spell = "Shared health", text = "They share one health pool, so damage anywhere counts. Positioning, interrupts and the mage tank decide this fight, not raw DPS. Keep Curse of Tongues up throughout." },
                },
            },
        },
    },

    -- =====================================================================
    -- Illidan. Five phases; only two transitions are health-gated. P3 and P4
    -- alternate on a timer until 30%.
    -- =====================================================================
    bt_illidan = {
        name = "Illidan Stormrage",
        tanks = 4,
        npcID = 22917,
        posmap = "illidan",
        checklist = {
            "Flame tanks assigned, fire resistance CAPPED",
            "Warlock tank in SHADOW resistance gear for demon phase",
            "Ranged and healers split into 3 marked groups for phase 2",
            "Platform regions named so trap locations can be called in phase 5",
        },
        steps = {
            {
                id = "phase1", label = "Phase 1 - melee", detail = "Shear - Draw Soul - Flame Crash",
                call = "MT blocks Shear -- Shield Block or Holy Shield, it cannot miss. Melee stay OUT of the front, Draw Soul heals him 100k. Tank shifts him a little after every Flame Crash. Parasitic target runs out and we kill the adds on spawn.",
                advance = "npc_id", npcID = 22917, posmap = "illidan",
                warn = { "BLOCK THE SHEAR", "OUT OF THE FRONT", "MOVE AFTER FLAME CRASH", "PARASITIC - RUN OUT" },
                source = SOURCE,
            },
            {
                id = "phase2", label = "Phase 2 - Flames of Azzinoth", detail = "65% - two elementals, capped fire resist tanks",
                call = "Flame tanks take one each and kite them on the arcs -- never let a Flame breathe on the raid, and NEVER let one get 25 yards from its glaive or we wipe. Ranged and healers into your three marked groups. Dodge the blue Eye Blast as it is drawn.",
                advance = "health_pct", healthPct = 65, npcID = 22917, posmap = "illidan",
                warn = { "FLAME TANKS GO", "DODGE THE BLUE FIRE", "3 GROUPS - SPREAD OUT", "FOCUS ONE FLAME" },
                source = SOURCE,
            },
            {
                id = "phase3", label = "Phase 3 - he lands", detail = "Phase 1 abilities plus Agonizing Flames",
                call = "He is down. Same as phase one but everyone spreads 5 yards for Agonizing Flames. Pick a spot for the Parasitic targets to drop their adds. If we have the damage, lust here and skip demon form.",
                advance = "manual", posmap = "illidan",
                warn = { "SPREAD 5 YARDS", "DROP PARASITICS THERE", "LUST TO SKIP P4" },
                source = SOURCE,
            },
            {
                id = "phase4", label = "Phase 4 - demon form", detail = "One minute on a timer, not a health gate",
                call = "Demon form. Warlock tank takes him and stands 20 yards clear -- Shadow Blast splashes that far. Everyone else spreads 5 yards for Flame Burst and kills the Shadow Demons the second they appear.",
                advance = "manual", posmap = "illidan",
                warn = { "WARLOCK TANK 20 YARDS", "SPREAD 5 YARDS", "KILL SHADOW DEMONS" },
                source = SOURCE,
            },
            {
                id = "phase5", label = "Phase 5 - Maiev", detail = "30% - enrage 40 seconds in, then the traps",
                call = "Thirty percent. He enrages 40 seconds in, so save cooldowns for it. Everyone watch for Maiev's traps and call the region -- MT kites him into one, the enrage drops and he takes extra damage. Glaives are MT priority.",
                advance = "health_pct", healthPct = 30, npcID = 22917, posmap = "illidan",
                warn = { "ENRAGE INCOMING", "CALL THE TRAP", "KITE HIM TO IT", "COOLDOWNS NOW" },
                source = SOURCE,
                brief = {
                    { spell = "Shear", spellID = 41032, text = "1.5s cast that cuts the target's maximum health by 60% for 7 seconds. It can be dodged, blocked or parried but it CANNOT MISS -- warrior tanks save Shield Block for it, paladins use Holy Shield. This is not a tank swap mechanic." },
                    { spell = "Draw Soul", spellID = 40904, text = "Frontal cone, 1.5s cast, 5k damage -- and it HEALS ILLIDAN FOR 100,000. Only the main tank should ever be hit by it, which is why melee never stand in front." },
                    { spell = "Flame Crash", spellID = 40832, text = "Drops a 10 yard circle of fire on his current target for 5k per tick, lasting 2 minutes. The tank walks him a little after each one." },
                    { spell = "Parasitic Shadowfiend", spellID = 41917, text = "Marks a random player, who takes damage and spawns 2 adds after 10 seconds. Run out of the group first; kill the adds the moment they appear, and slow traps help." },
                    { spell = "Uncaged Wrath", spellID = 39868, text = "THE WIPE MECHANIC. If a Flame gets 25 yards from its glaive, or ANY player gets 25 yards from a Flame, it enrages and the raid dies. Proper kiting and positioning prevents it entirely." },
                    { spell = "Eye Blast", spellID = 40018, text = "Draws a trail of blue fire: 20k on impact, then 2k per second for a minute. Never be caught in it as it is being drawn. Tanks may walk through it AFTER it lands if they must -- tell your healers first." },
                    { spell = "Flame Blast", spellID = 40631, text = "Frontal cone for 9k within 15 yards, usually followed by Blaze. Flame tanks keep the elementals pointed away from everyone." },
                    { spell = "Blaze", spellID = 40609, text = "Large fire under the tank for 5k per second. Kite along the arcs so melee can still reach the elemental without standing in it." },
                    { spell = "Fireball / Dark Barrage", spellID = 40598, text = "Fireball hits a random target and anyone within 10 yards for 3-4k, which is why ranged and healers split into 3 marked groups. Dark Barrage (40585) puts 3k per second for 10 seconds on one player, every 40 seconds -- heavy heals, but do not drop a flame tank for it." },
                    { spell = "Agonizing Flames", spellID = 40932, text = "Phases 3 and 5. A 5 yard area around a random player for 5k plus a heavy damage-over-time. Everyone stays 5 yards apart." },
                    { spell = "Demon Form", spellID = 40506, text = "One minute long, on a timer rather than a health gate. His physical damage rises 500% and he gains Aura of Dread (41142) -- 15 yards, 1k shadow per second, raising shadow damage taken 30% per tick." },
                    { spell = "Shadow Blast", spellID = 41078, text = "8.7-11.2k to the highest threat AND everyone within 20 yards, every 2 seconds. That is why the warlock tank stands 20 yards from the raid. It is resistable, so the warlock wants shadow resistance gear." },
                    { spell = "Flame Burst / Shadow Demons", spellID = 41126, text = "Flame Burst hits the whole raid for 3.5k plus a 5 yard splash, so spread. Shadow Demons (41117) appear 40 seconds into demon form, fixate and stun a player, and kill them on contact -- kill the demons immediately." },
                    { spell = "Enrage (P5)", spellID = 40683, text = "40 seconds into phase 5 he gains 30% attack speed and 50% damage. Save cooldowns and potions for this window." },
                    { spell = "Cage Trap", spellID = 40761, text = "Maiev drops traps through phase 5. Kiting him into one stuns him, REMOVES THE ENRAGE and increases his damage taken. Name the regions of the platform beforehand so people can call where a trap landed." },
                },
            },
        },
    },

    },
})
