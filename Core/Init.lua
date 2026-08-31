-- Core/Init.lua
--
-- Namespace, event bus, signal bus, timers, saved-variable profiles and the
-- debug ring buffer. This is what would otherwise be AceAddon + AceEvent +
-- AceDB; writing it here costs ~250 lines and removes an unfetchable
-- dependency plus three libraries' worth of taint surface.
--
-- Loads first. Nothing above it in the .toc.

local ADDON_NAME, PPRC = ...

_G.PopperpigRaidCall = PPRC

PPRC.ADDON_NAME = ADDON_NAME

-- The packager substitutes this on release; in a working copy it stays literal.
local VERSION = "@project-version@"
PPRC.version = VERSION:match("^@") and "dev" or VERSION

-- Numeric form for the version handshake, so "outdated" is a comparison rather
-- than a string mismatch. dev always sorts highest so a developer is never
-- nagged by their own raid.
function PPRC:VersionNumber(v)
    v = v or self.version
    if v == "dev" then return math.huge end
    local major, minor, patch = v:match("^v?(%d+)%.(%d+)%.(%d+)")
    if not major then return 0 end
    return tonumber(major) * 10000 + tonumber(minor) * 100 + tonumber(patch)
end

-- ---------------------------------------------------------------------------
-- Palette. Matches the technical plan so the addon looks like its own document.
-- ---------------------------------------------------------------------------

PPRC.COLORS = {
    fel     = { 0.56, 0.88, 0.29 },  -- #8fe04b  primary
    feldim  = { 0.23, 0.33, 0.14 },  -- #3a5324  pressed / fill
    green   = { 0.25, 0.68, 0.44 },  -- #3fae6f  confirmed good
    gold    = { 0.80, 0.64, 0.25 },  -- #cda23f  needs attention / spoken call
    danger  = { 0.76, 0.33, 0.29 },  -- #c1544a  bad
    ice     = { 0.37, 0.69, 0.79 },  -- #5fb0c9  landmarks
    purple  = { 0.49, 0.36, 0.77 },  -- #7c5cc4  comms
    text    = { 0.91, 0.90, 0.85 },  -- #e9e6da
    muted   = { 0.58, 0.64, 0.58 },  -- #93a294
    muted2  = { 0.42, 0.49, 0.43 },  -- #6c7c6e
    panel   = { 0.07, 0.09, 0.07 },  -- #121713
    panel2  = { 0.09, 0.11, 0.09 },  -- #161d18
    line    = { 0.15, 0.20, 0.16 },  -- #26332a
}

local function hex(c) return string.format("%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255) end

PPRC.HEX = {}
for k, v in pairs(PPRC.COLORS) do PPRC.HEX[k] = hex(v) end

function PPRC:Colorize(key, text)
    local h = self.HEX[key] or self.HEX.text
    return "|cff" .. h .. tostring(text) .. "|r"
end

-- ---------------------------------------------------------------------------
-- Debug ring buffer
--
-- Bounded so a long raid night cannot grow it without limit. /pprc debug shows
-- it in a copyable frame: the plan asks testers to paste this rather than
-- describe symptoms, which only works if it is actually selectable text.
-- ---------------------------------------------------------------------------

local LOG_MAX = 200
PPRC.logBuffer = {}
PPRC.debugEnabled = false

function PPRC:Log(fmt, ...)
    local msg
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, fmt, ...)
        msg = ok and formatted or tostring(fmt)
    else
        msg = tostring(fmt)
    end

    local line = string.format("|cff6c7c6e%s|r %s", date("%H:%M:%S"), msg)

    local buf = self.logBuffer
    buf[#buf + 1] = line
    -- Ring: drop the oldest rather than letting the table grow all night.
    if #buf > LOG_MAX then table.remove(buf, 1) end

    if self.debugEnabled then self:Print(msg) end
    self:Fire("LOG_APPENDED", line)
end

function PPRC:Print(fmt, ...)
    local msg
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, fmt, ...)
        msg = ok and formatted or tostring(fmt)
    else
        msg = tostring(fmt)
    end
    local frame = _G.DEFAULT_CHAT_FRAME
    if frame and frame.AddMessage then
        frame:AddMessage("|cff8fe04bPPRC|r " .. msg)
    else
        print("PPRC " .. msg)
    end
end

-- ---------------------------------------------------------------------------
-- Signal bus (internal). Distinct from game events: these are our own
-- broadcasts, so the UI redraws on state change instead of polling OnUpdate.
-- ---------------------------------------------------------------------------

local signalHandlers = {}

function PPRC:Listen(signal, fn)
    if type(fn) ~= "function" then return end
    signalHandlers[signal] = signalHandlers[signal] or {}
    table.insert(signalHandlers[signal], fn)
end

function PPRC:Fire(signal, ...)
    local list = signalHandlers[signal]
    if not list then return end
    for i = 1, #list do
        -- pcall per listener: one broken panel must not stop the others from
        -- redrawing, and must never break the state transition that fired it.
        local ok, err = pcall(list[i], ...)
        if not ok and signal ~= "LOG_APPENDED" then
            -- Guard against LOG_APPENDED to avoid recursing through Log().
            self:Log("|cffc1544alistener error|r on %s: %s", signal, tostring(err))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Event bus
--
-- A missing event throws when registered rather than returning false, so every
-- registration goes through pcall. An event this client does not have becomes
-- a logged branch, never a Lua error window mid-pull.
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
PPRC.eventFrame = eventFrame

local eventHandlers = {}
local eventState = {}   -- event -> true (live) | false (unavailable on this client)

function PPRC:SafeRegister(frame, event)
    return (pcall(frame.RegisterEvent, frame, event)) and true or false
end

-- Returns true if the handler is live, false if this client lacks the event.
function PPRC:On(event, fn)
    if type(fn) ~= "function" then return false end

    if eventState[event] == nil then
        if self:SafeRegister(eventFrame, event) then
            eventState[event] = true
            eventHandlers[event] = {}
        else
            eventState[event] = false
            self:Log("event %s is not available on this client", event)
        end
    end

    if eventState[event] == false then return false end

    table.insert(eventHandlers[event], fn)
    return true
end

function PPRC:Off(event, fn)
    local list = eventHandlers[event]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == fn then table.remove(list, i) end
    end
    if #list == 0 and eventState[event] then
        pcall(eventFrame.UnregisterEvent, eventFrame, event)
        eventState[event] = nil
        eventHandlers[event] = nil
    end
end

function PPRC:HasEvent(event) return eventState[event] == true end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = eventHandlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then
            PPRC:Log("|cffc1544ahandler error|r on %s: %s", event, tostring(err))
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Timers
--
-- C_Timer is probable on 2.5.6 given the Midnight backport, but "probable" is
-- not "present", so there is a scheduler behind it. Both paths are exercised
-- by the test harness.
-- ---------------------------------------------------------------------------

local scheduled = {}
local schedulerFrame

local function ensureScheduler()
    if schedulerFrame then return end
    schedulerFrame = CreateFrame("Frame")
    schedulerFrame:SetScript("OnUpdate", function()
        if #scheduled == 0 then return end
        local now = GetTime()
        -- Reverse iteration so removal during the walk is safe.
        for i = #scheduled, 1, -1 do
            local entry = scheduled[i]
            if entry.cancelled then
                table.remove(scheduled, i)
            elseif now >= entry.at then
                if entry.interval then
                    entry.at = now + entry.interval
                else
                    table.remove(scheduled, i)
                end
                local ok, err = pcall(entry.fn)
                if not ok then PPRC:Log("|cffc1544atimer error|r: %s", tostring(err)) end
            end
        end
    end)
end

function PPRC:After(delay, fn)
    if type(fn) ~= "function" then return end
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(delay, fn)
        return
    end
    ensureScheduler()
    scheduled[#scheduled + 1] = { at = GetTime() + delay, fn = fn }
end

-- Returns a handle with :Cancel(), matching C_Timer.NewTicker's shape so
-- callers do not care which path they got.
function PPRC:Ticker(interval, fn)
    if type(fn) ~= "function" then return end
    if _G.C_Timer and _G.C_Timer.NewTicker then
        return _G.C_Timer.NewTicker(interval, fn)
    end
    ensureScheduler()
    local entry = { at = GetTime() + interval, interval = interval, fn = fn }
    scheduled[#scheduled + 1] = entry
    entry.Cancel = function(self_) self_.cancelled = true end
    return entry
end

-- Test seam: lets the harness drive the fallback scheduler without real time.
function PPRC:_PumpScheduler()
    if schedulerFrame and schedulerFrame.GetScript then
        local handler = schedulerFrame:GetScript("OnUpdate")
        if handler then handler(schedulerFrame, 0) end
    end
end

-- ---------------------------------------------------------------------------
-- Saved variables
--
-- Profile per character, because an alt tank and a main raid leader want
-- different frames on screen. Defaults are filled in without clobbering
-- anything the user already set, so adding a setting in a later version does
-- not reset their layout.
-- ---------------------------------------------------------------------------

PPRC.defaults = {
    -- Frame geometry, keyed by frame name. Populated by UI/Widgets.lua.
    frames      = {},
    locked      = false,

    -- Local echo prints calls to your own chat frame instead of the raid's.
    -- The plan requires the first live night to run this way.
    localEcho   = false,

    -- Panels the user has chosen to keep open between sessions.
    shown       = { hud = true, callboard = true, readiness = false, roster = false, mobs = false },

    -- Assignments persist by character name across weeks (plan §10).
    assignments = {},

    -- Manual checklist ticks for things the API cannot read (plan §9).
    checklist   = {},

    -- Guide screenshots off by default: the drawn diagram is the one that
    -- carries live assignment names, and that is the everyday view.
    showGuide   = false,

    minimap     = { hide = false, angle = 200 },
    hudScale    = 1.0,
    debug       = false,
}

local function fillDefaults(defaults, target)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            fillDefaults(v, target[k])
        elseif target[k] == nil then
            target[k] = v
        end
    end
    return target
end

PPRC.fillDefaults = fillDefaults

function PPRC:ProfileKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName and GetRealmName() or "Unknown"
    return name .. "-" .. realm
end

function PPRC:InitDB()
    _G.PopperpigRaidCallDB = _G.PopperpigRaidCallDB or {}
    local sv = _G.PopperpigRaidCallDB

    sv.profiles = sv.profiles or {}
    local key = self:ProfileKey()
    sv.profiles[key] = sv.profiles[key] or {}

    self.db = fillDefaults(self.defaults, sv.profiles[key])
    self.dbKey = key
    self.debugEnabled = self.db.debug and true or false

    self:Log("profile loaded: %s", key)
    return self.db
end

-- ---------------------------------------------------------------------------
-- Module registry
--
-- Modules register an :OnEnable() that runs once the DB exists. This keeps
-- load-order coupling to exactly one rule: Init first, Adapter second.
-- ---------------------------------------------------------------------------

PPRC.modules = {}

function PPRC:NewModule(name)
    local module = { moduleName = name }
    self.modules[name] = module
    self.modules[#self.modules + 1] = module
    return module
end

function PPRC:EnableModules()
    for i = 1, #self.modules do
        local module = self.modules[i]
        if module.OnEnable and not module._enabled then
            local ok, err = pcall(module.OnEnable, module)
            module._enabled = true
            if not ok then
                self:Log("|cffc1544amodule %s failed to enable|r: %s", module.moduleName, tostring(err))
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Boot
-- ---------------------------------------------------------------------------

PPRC:On("ADDON_LOADED", function(_, loaded)
    if loaded ~= ADDON_NAME then return end
    PPRC:InitDB()
    PPRC:EnableModules()
    PPRC:Fire("READY")
end)
