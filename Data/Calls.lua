-- Data/Calls.lua
--
-- The standing call board: the handful of things a raid leader says on every
-- fight, regardless of which one it is. Per-step calls live on the steps
-- themselves in Data/Hyjal.lua and Data/BlackTemple.lua.
--
-- Nothing here has a countdown attached. Anything counting down to an incoming
-- ability belongs to DBM, and duplicating it is the fastest way to get
-- uninstalled.

local ADDON_NAME, PPRC = ...

PPRC.StandingCalls = {
    { id = "mana",      label = "MANA CHECK", text = "MANA CHECK - healers report, drink now if you are under 80%" },
    { id = "spread",    label = "SPREAD",     text = "SPREAD OUT" },
    { id = "stack",     label = "STACK",      text = "STACK UP ON THE TANK" },
    { id = "decurse",   label = "DECURSE",    text = "DECURSE / DISPEL NOW" },
    { id = "bloodlust", label = "BLOODLUST",  text = "BLOODLUST / HEROISM NOW" },
    { id = "hold",      label = "HOLD DPS",   text = "HOLD DPS" },
    { id = "pull",      label = "PULLING",    text = "PULLING - get in position" },

    -- Destructive: calling a wipe that was not meant ends the attempt for 24
    -- other people. The UI requires a second click to confirm this one.
    { id = "wipe",      label = "WIPE",       text = "WIPE IT - run out, do not release until called",
      danger = true, confirm = true },
}

PPRC.StandingCallsByID = {}
for _, call in ipairs(PPRC.StandingCalls) do
    PPRC.StandingCallsByID[call.id] = call
end
