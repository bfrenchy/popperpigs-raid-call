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

    -- How much of the loaded data is still unconfirmed against this client.
    local instance = PPRC.State.instance
    if instance then
        PPRC:Print("data: %s has %d steps, |cffcda23f%d unverified|r",
            instance.id, instance.total, instance.unverified)
    end

    PPRC:Print("debug logging %s", PPRC.debugEnabled and "|cff3fae6fon|r" or "|cffc1544aoff|r")
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
