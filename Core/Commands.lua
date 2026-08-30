-- Core/Commands.lua
--
-- The /pprc router. Loads last, because it wires every module above it.
--
-- Commands are added here as their milestones land; anything not yet built
-- reports that plainly rather than failing silently.

local ADDON_NAME, PPRC = ...

local Commands = PPRC:NewModule("Commands")
PPRC.Commands = Commands

local handlers = {}
local order    = {}

local function register(name, usage, description, fn)
    handlers[name] = fn
    order[#order + 1] = { name = name, usage = usage, description = description }
end

-- ---------------------------------------------------------------------------
-- Help
-- ---------------------------------------------------------------------------

register("help", "/pprc help", "This list.", function()
    PPRC:Print("|cff8fe04bPopperpig Raid Call|r %s", PPRC.version)
    for _, entry in ipairs(order) do
        PPRC:Print("  |cffcda23f%s|r  %s", entry.usage, entry.description)
    end
end)

-- ---------------------------------------------------------------------------
-- Panels
-- ---------------------------------------------------------------------------

register("show", "/pprc show", "Show the HUD.", function()
    if PPRC.HUD then PPRC.HUD:Show() end
end)

register("hide", "/pprc hide", "Hide the HUD.", function()
    if PPRC.HUD then PPRC.HUD:Hide() end
end)

register("board", "/pprc board", "Show or hide the call board.", function()
    if PPRC.CallBoard then PPRC.CallBoard:Toggle() end
end)

register("echo", "/pprc echo", "Local echo: calls print to your own chat frame and go nowhere near the raid.", function()
    PPRC.db.localEcho = not PPRC.db.localEcho
    PPRC:Print("local echo %s%s",
        PPRC.db.localEcho and "|cff3fae6fon|r" or "|cffc1544aoff|r",
        PPRC.db.localEcho and " - nothing will be sent to the raid" or "")
    if PPRC.CallBoard then PPRC.CallBoard:Refresh() end
end)

register("say", "/pprc say <text>", "Send one line through the throttle, as a raid warning if you have assist.", function(args)
    local text = table.concat(args, " ")
    if text == "" then
        PPRC:Print("usage: /pprc say <text>")
        return
    end
    PPRC.RateLimit:SendCall(text)
end)

register("route", "/pprc route", "Print the trash route for the boss you are heading to.", function(args)
    local encounterID = args[1] or PPRC.State.encounterID
    local route = encounterID and PPRC.Route[encounterID] or nil

    if not route then
        PPRC:Print("no route for %s - try /pprc route <encounter>, or zone in",
            tostring(encounterID or "the current step"))
        return
    end

    PPRC:Print("|cff8fe04bRoute to %s|r", route.boss)
    if route.note then PPRC:Print("  |cffcda23f%s|r", route.note) end
    for _, pull in ipairs(route.pulls) do
        -- Skips are called out rather than hidden: "which pack are we NOT
        -- pulling" is what goes wrong when half the raid read the guide.
        PPRC:Print("  |cff6c7c6e%d.|r %s%s", pull.n, pull.mobs,
            pull.skip and "  |cff5fb0c9[SKIPPABLE]|r" or "")
        if pull.note then PPRC:Print("      |cff93a294%s|r", pull.note) end
    end
end)

register("wa", "/pprc wa", "WeakAura links for this encounter, plus the general packs.", function()
    local encounterID = PPRC.State.encounterID
    local specific = encounterID and PPRC.WeakAuras.encounters[encounterID] or nil

    if specific then
        local encounter = PPRC:GetEncounter(encounterID)
        PPRC:Print("|cff8fe04bFor %s|r", encounter and encounter.name or encounterID)
        for _, wa in ipairs(specific) do
            PPRC:Print("  %s  |cff5fb0c9%s|r", wa.name, wa.url)
            if wa.note then PPRC:Print("      |cff93a294%s|r", wa.note) end
        end
    end

    PPRC:Print("|cff8fe04bGeneral|r")
    for _, wa in ipairs(PPRC.WeakAuras.general) do
        PPRC:Print("  %s  |cff5fb0c9%s|r", wa.name, wa.url)
    end
    if not specific then
        PPRC:Print("|cff6c7c6eno encounter-specific auras for this step|r")
    end
end)

register("mobs", "/pprc mobs", "Show or hide the pack breakdown for the current wave.", function()
    if PPRC.MobPanel then PPRC.MobPanel:Toggle() end
end)

register("rules", "/pprc rules", "Print the trash rules for the base you are on.", function()
    if PPRC.MobPanel then PPRC.MobPanel:PrintRules() end
end)

register("ready", "/pprc ready", "Show or hide the readiness board.", function()
    if PPRC.Readiness then PPRC.Readiness:Toggle() end
end)

register("check", "/pprc check", "Announce one readiness summary line to the raid.", function()
    if PPRC.Roster then PPRC:Print(PPRC.Roster:SummaryLine()) end
end)

register("assign", "/pprc assign", "Show or hide the assignment panel.", function()
    if PPRC.RosterUI then PPRC.RosterUI:Toggle() end
end)

register("brief", "/pprc brief", "Show or hide the pre-pull briefing for the current step.", function()
    if PPRC.Briefing then PPRC.Briefing:Toggle() end
end)

register("config", "/pprc config", "Open the settings panel.", function()
    if PPRC.Options then PPRC.Options:Toggle() end
end)

register("lock", "/pprc lock", "Lock or unlock frame dragging.", function()
    PPRC.db.locked = not PPRC.db.locked
    PPRC:Print("frames are now %s", PPRC.db.locked and "|cffc1544alocked|r" or "|cff3fae6funlocked|r")
end)

register("reset", "/pprc reset", "Move every frame back to its default position.", function()
    PPRC.db.frames = {}
    PPRC:Print("frame positions reset - /reload to apply")
end)

-- ---------------------------------------------------------------------------
-- Driving the state machine
-- ---------------------------------------------------------------------------

register("test", "/pprc test <encounter>", "Walk an encounter solo, with no raid and no instance.", function(args)
    local encounterID = args[1]

    if not encounterID then
        PPRC:Print("known encounters:")
        for instanceID, instance in pairs(PPRC.Instances) do
            local ids = {}
            for _, id in ipairs(instance.order) do ids[#ids + 1] = id end
            PPRC:Print("  |cff6c7c6e%s|r  %s", instanceID, table.concat(ids, ", "))
        end
        return
    end

    if not PPRC:GetEncounter(encounterID) then
        PPRC:Print("|cffc1544ano such encounter|r '%s' - try /pprc test with no argument", encounterID)
        return
    end

    PPRC.State:StartTest(encounterID)
    if PPRC.HUD then PPRC.HUD:Show() end
    PPRC:Print("test mode: %s. Comms are off; nothing is sent to the raid.", encounterID)
end)

register("stop", "/pprc stop", "Leave test mode.", function()
    PPRC.State:StopTest()
    PPRC:Print("test mode off")
end)

register("next", "/pprc next", "Advance one step.", function()
    if not PPRC.State:Advance("local") then PPRC:Print("already on the last step") end
end)

register("back", "/pprc back", "Step back one.", function()
    if not PPRC.State:Back("local") then PPRC:Print("already on the first step") end
end)

-- ---------------------------------------------------------------------------
-- Diagnostics
-- ---------------------------------------------------------------------------

register("debug", "/pprc debug", "Toggle debug logging and print the capability table.", function()
    PPRC.debugEnabled = not PPRC.debugEnabled
    PPRC.db.debug = PPRC.debugEnabled

    for _, line in ipairs(PPRC.Adapter:CapabilityReport()) do PPRC:Print(line) end

    -- Which detection tier actually went active. The plan leans on this: S2 and
    -- S3 answer themselves the first night anyone zones in with debug on.
    if PPRC.Detect then
        for _, line in ipairs(PPRC.Detect:TierReport()) do PPRC:Print(line) end
    end

    -- Provenance of the loaded data, three ways: confirmed against this
    -- client, backed by a cited source, or backed by nothing.
    local instance = PPRC.State.instance
    if instance then
        PPRC:Print("data: %s has %d steps - |cff3fae6f%d verified|r, |cff5fb0c9%d sourced|r, |cffcda23f%d unbacked|r",
            instance.id, instance.total, instance.verified, instance.sourced, instance.unverified)
        if instance.credit then PPRC:Print("  |cff6c7c6e%s|r", instance.credit) end
    end

    PPRC:Print("debug logging %s", PPRC.debugEnabled and "|cff3fae6fon|r" or "|cffc1544aoff|r")
end)

register("sync", "/pprc sync", "Who is running the addon, and who is out of date.", function()
    if not PPRC.Comm then
        PPRC:Print("sync is not loaded")
        return
    end
    PPRC:Print("sync: %s", PPRC.Comm:VersionReport())
    if PPRC.Comm:HasController() then
        PPRC:Print("following |cff8fe04b%s|r", PPRC.Comm.controller)
    elseif PPRC.Adapter:CanBroadcast() then
        PPRC:Print("you are driving")
    else
        PPRC:Print("|cffc1544ano one is broadcasting|r - nobody with assist is running it")
    end
    PPRC.Comm:RequestState()
end)

register("scan", "/pprc scan", "Dump live world state and every NPC id seen, for correcting Data/.", function()
    if not PPRC.Detect then
        PPRC:Print("detection is not loaded")
        return
    end
    for _, line in ipairs(PPRC.Detect:ScanReport()) do PPRC:Print(line) end
    PPRC:Print("|cff6c7c6eAnything marked NOT IN Data/ is a gap. Paste this into SPIKES.md against the build number.|r")
end)

register("log", "/pprc log", "Print the recent debug log.", function()
    if #PPRC.logBuffer == 0 then
        PPRC:Print("log is empty")
        return
    end
    for _, line in ipairs(PPRC.logBuffer) do PPRC:Print(line) end
end)

-- ---------------------------------------------------------------------------
-- Dispatch
-- ---------------------------------------------------------------------------

function Commands:Run(input)
    input = input or ""

    local args = {}
    for word in input:gmatch("%S+") do args[#args + 1] = word end

    local command = table.remove(args, 1)
    if not command then
        if PPRC.HUD then PPRC.HUD:Toggle() end
        return
    end

    local handler = handlers[command:lower()]
    if not handler then
        PPRC:Print("|cffc1544aunknown command|r '%s' - try /pprc help", command)
        return
    end

    local ok, err = pcall(handler, args)
    if not ok then
        PPRC:Print("|cffc1544acommand failed|r: %s", tostring(err))
        PPRC:Log("command '%s' failed: %s", command, tostring(err))
    end
end

Commands.handlers = handlers

function Commands:OnEnable()
    _G.SLASH_POPPERPIGRAIDCALL1 = "/pprc"
    _G.SLASH_POPPERPIGRAIDCALL2 = "/popperpig"
    _G.SlashCmdList["POPPERPIGRAIDCALL"] = function(input) Commands:Run(input) end
end
