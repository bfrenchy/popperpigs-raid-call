-- Data/WeakAuras.lua
--
-- WeakAura links from cosmophile's guide.
--
-- Deliberately just links. This addon does not install, parse or manage
-- WeakAuras -- that is another addon's job and the scope rule says stay out of
-- it. What it does is put the right link in front of the raid leader at the
-- moment it matters, which is the pull where the aura would have helped.

local ADDON_NAME, PPRC = ...

PPRC.WeakAuras = {
    general = {
        { name = "Master T6 WeakAura Pack",   url = "https://wago.io/Y5J7NdyVH" },
        { name = "Raidframe Debuff Outline",  url = "https://wago.io/SwSK_MhT1" },
    },

    encounters = {
        bt_shahraz = {
            { name = "Fatal Attraction helper", url = "https://wago.io/7p-NQ6ZJu",
              note = "Shows who you are linked to so you can run the right way." },
        },
    },
}
