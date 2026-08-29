-- Tests/stubs.lua
--
-- A headless stand-in for the parts of the WoW client this addon touches, so
-- the whole thing can be exercised under plain lua5.1 without the game.
--
-- The important feature is `profile`: the same suite runs twice, once with the
-- modern API surface present and once with it stripped, which is how the
-- degradation chains in the plan actually get tested rather than just written.
--
-- Not shipped to players -- .pkgmeta excludes Tests/ from the release zip.

local stubs = {}

-- ---------------------------------------------------------------------------
-- Widget stub
-- ---------------------------------------------------------------------------

local frameMethods = {}

local frameMeta = {
    __index = function(t, key)
        local m = frameMethods[key]
        if m then return m end
        -- Widget methods are CamelCase; data fields are not. Auto-stub the
        -- former as no-ops so UI code loads without enumerating all of the
        -- Blizzard widget API, and leave the latter nil so code that reads
        -- `plate.namePlateUnitToken` still sees a real absence.
        if type(key) == "string" and key:match("^%u") then
            local noop = function() end
            rawset(t, key, noop)
            return noop
        end
        return nil
    end,
}

function stubs.newFrame(env, frameType, name, parent)
    local f = setmetatable({
        _type     = frameType or "Frame",
        _name     = name,
        _parent   = parent,
        _scripts  = {},
        _events   = {},
        _shown    = true,
        _children = {},
        _text     = nil,
        _width    = 100,
        _height   = 20,
        _env      = env,
    }, frameMeta)

    env.frames[#env.frames + 1] = f
    if name then env.g[name] = f end
    return f
end

function frameMethods:SetScript(handler, fn) self._scripts[handler] = fn end
function frameMethods:GetScript(handler) return self._scripts[handler] end
function frameMethods:HasScript(handler) return true end

function frameMethods:RegisterEvent(event)
    if self._env.missingEvents[event] then
        error("Attempt to register unknown event '" .. tostring(event) .. "'", 2)
    end
    self._events[event] = true
end

function frameMethods:UnregisterEvent(event) self._events[event] = nil end
function frameMethods:IsEventRegistered(event) return self._events[event] == true end
function frameMethods:UnregisterAllEvents() self._events = {} end

function frameMethods:Show() self._shown = true end
function frameMethods:Hide() self._shown = false end
function frameMethods:SetShown(v) self._shown = v and true or false end
function frameMethods:IsShown() return self._shown end
function frameMethods:IsVisible() return self._shown end
function frameMethods:GetName() return self._name end
function frameMethods:GetParent() return self._parent end
function frameMethods:GetObjectType() return self._type end

function frameMethods:CreateTexture(name)
    return stubs.newFrame(self._env, "Texture", name, self)
end

function frameMethods:CreateFontString(name)
    return stubs.newFrame(self._env, "FontString", name, self)
end

function frameMethods:SetText(text) self._text = text end
function frameMethods:GetText() return self._text end
function frameMethods:SetWidth(w) self._width = w end
function frameMethods:SetHeight(h) self._height = h end
function frameMethods:SetSize(w, h) self._width, self._height = w, h end
function frameMethods:GetWidth() return self._width end
function frameMethods:GetHeight() return self._height end
function frameMethods:GetStringWidth() return #tostring(self._text or "") * 6 end

function frameMethods:SetPoint(point, rel, relPoint, x, y)
    self._points = self._points or {}
    self._points[#self._points + 1] = { point, rel, relPoint, x, y }
end

function frameMethods:ClearAllPoints() self._points = {} end

function frameMethods:GetPoint()
    local p = self._points and self._points[1]
    if not p then return nil end
    return p[1], p[2], p[3], p[4], p[5]
end

-- ---------------------------------------------------------------------------
-- Environment
-- ---------------------------------------------------------------------------

-- opts.modern       : C_Timer / C_ChatInfo / C_UnitAuras / C_WorldStateInfo present
-- opts.worldState   : "none" | "global" | "namespace"
-- opts.missingEvents: set of event names whose registration throws
function stubs.install(opts)
    opts = opts or {}
    local g = _G

    local env = {
        g             = g,
        frames        = {},
        missingEvents = opts.missingEvents or {},
        now           = 1000,
        timers        = {},
        chat          = {},        -- SendChatMessage calls
        addonMessages = {},        -- SendAddonMessage calls
        printed       = {},
        units         = {},        -- unit token -> unit fixture
        raidRoster    = {},        -- index -> { name, rank }
        worldStateUI  = {},        -- index -> { returns... }
        instance      = { name = "Unknown", mapID = nil },
        marks         = {},
        inCombat      = false,
        _saved        = {},
    }

    local function set(name, value)
        env._saved[name] = { g[name] }
        g[name] = value
    end
    env.set = set

    -- --- base ---------------------------------------------------------------
    set("CreateFrame", function(frameType, name, parent) return stubs.newFrame(env, frameType, name, parent) end)
    set("GetTime", function() return env.now end)
    set("date", os.date)
    set("GetRealmName", function() return "Testrealm" end)
    set("GetBuildInfo", function() return "2.5.6", "12345", "2026-08-27", 20506 end)
    set("InCombatLockdown", function() return env.inCombat end)
    set("Ambiguate", function(name) return (name:gsub("%-.*$", "")) end)
    set("DEFAULT_CHAT_FRAME", {
        AddMessage = function(_, msg) env.printed[#env.printed + 1] = msg end,
    })
    set("RAID_CLASS_COLORS", {
        WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, MAGE = { r = 0.41, g = 0.80, b = 0.94 },
        ROGUE   = { r = 1.00, g = 0.96, b = 0.41 }, PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
        WARLOCK = { r = 0.58, g = 0.51, b = 0.79 }, PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
        DRUID   = { r = 1.00, g = 0.49, b = 0.04 }, SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
        HUNTER  = { r = 0.67, g = 0.83, b = 0.45 },
    })
    set("SlashCmdList", {})
    set("InterfaceOptions_AddCategory", function() end)
    set("InterfaceOptionsFrame_OpenToCategory", function() end)
    set("UIParent", stubs.newFrame(env, "Frame", "UIParent"))
    set("StaticPopupDialogs", {})
    set("StaticPopup_Show", function() end)
    set("PlaySound", function() end)
    set("GameTooltip", stubs.newFrame(env, "GameTooltip", "GameTooltip"))

    -- --- units --------------------------------------------------------------
    local function unit(token) return env.units[token] end

    set("UnitExists", function(token) return unit(token) ~= nil end)
    set("UnitName", function(token) local u = unit(token); return u and u.name or nil end)
    set("UnitClass", function(token)
        local u = unit(token)
        if not u then return nil end
        return u.className or u.class, u.class
    end)
    set("UnitGUID", function(token) local u = unit(token); return u and u.guid or nil end)
    set("UnitHealth", function(token) local u = unit(token); return u and u.hp or 0 end)
    set("UnitHealthMax", function(token) local u = unit(token); return u and u.hpMax or 0 end)
    set("UnitIsDeadOrGhost", function(token) local u = unit(token); return u and u.dead or false end)
    set("UnitIsConnected", function(token) local u = unit(token); return u == nil or u.connected ~= false end)
    set("UnitInRange", function(token) local u = unit(token); return u == nil or u.inRange ~= false end)
    set("UnitIsUnit", function(a, b) return unit(a) and unit(b) and unit(a) == unit(b) or false end)
    set("UnitGroupRolesAssigned", function(token) local u = unit(token); return u and u.role or "NONE" end)
    set("UnitIsGroupLeader", function(token) local u = unit(token); return u and u.rank == 2 or false end)
    set("UnitIsGroupAssistant", function(token) local u = unit(token); return u and u.rank == 1 or false end)

    set("GetNumGroupMembers", function() return env.groupSize or 0 end)
    set("IsInRaid", function() return env.inRaid or false end)
    set("IsInGroup", function() return (env.groupSize or 0) > 0 end)
    set("GetRaidRosterInfo", function(i)
        local r = env.raidRoster[i]
        if not r then return nil end
        -- name, rank, subgroup, level, class, fileName, ...
        return r.name, r.rank, r.subgroup or 1, r.level or 70, r.className, r.class
    end)

    set("GetInstanceInfo", function()
        local inst = env.instance
        -- name, instanceType, difficultyID, difficultyName, maxPlayers,
        -- dynamicDifficulty, isDynamic, instanceMapID, instanceGroupSize
        return inst.name, "raid", 1, "Normal", 25, 0, false, inst.mapID, 25
    end)

    -- --- outbound -----------------------------------------------------------
    set("SendChatMessage", function(msg, channel, lang, target)
        env.chat[#env.chat + 1] = { msg = msg, channel = channel, target = target, at = env.now }
    end)
    set("SetRaidTarget", function(token, index)
        if env.raidTargetsBlocked then error("cannot set raid target") end
        env.marks[token] = index
    end)

    -- --- world state --------------------------------------------------------
    local wsMode = opts.worldState or "global"
    local function numWorldStateUI() return #env.worldStateUI end
    local function worldStateUIInfo(i)
        local entry = env.worldStateUI[i]
        if not entry then return nil end
        return entry[1], entry[2], entry[3], entry[4], entry[5], entry[6]
    end

    if wsMode == "namespace" then
        set("C_WorldStateInfo", { GetNumWorldStateUI = numWorldStateUI, GetWorldStateUIInfo = worldStateUIInfo })
        set("GetNumWorldStateUI", nil)
        set("GetWorldStateUIInfo", nil)
    elseif wsMode == "global" then
        set("C_WorldStateInfo", nil)
        set("GetNumWorldStateUI", numWorldStateUI)
        set("GetWorldStateUIInfo", worldStateUIInfo)
    else
        set("C_WorldStateInfo", nil)
        set("GetNumWorldStateUI", nil)
        set("GetWorldStateUIInfo", nil)
    end

    -- --- modern vs legacy surface ------------------------------------------
    if opts.modern then
        set("C_Timer", {
            After = function(delay, fn)
                env.timers[#env.timers + 1] = { at = env.now + delay, fn = fn }
            end,
            NewTicker = function(interval, fn)
                local t = { at = env.now + interval, interval = interval, fn = fn }
                t.Cancel = function(self) self.cancelled = true end
                env.timers[#env.timers + 1] = t
                return t
            end,
        })
        set("C_ChatInfo", {
            SendAddonMessage = function(prefix, msg, channel, target)
                env.addonMessages[#env.addonMessages + 1] =
                    { prefix = prefix, msg = msg, channel = channel, target = target }
            end,
            RegisterAddonMessagePrefix = function() return true end,
        })
        set("SendAddonMessage", nil)
        set("RegisterAddonMessagePrefix", nil)
        set("C_UnitAuras", {
            GetAuraDataByIndex = function(token, i)
                local u = unit(token)
                local aura = u and u.auras and u.auras[i]
                if not aura then return nil end
                return { name = aura.name, spellId = aura.spellId }
            end,
        })
        set("UnitAura", nil)
        set("C_NamePlate", { GetNamePlates = function() return env.namePlates or {} end })
    else
        set("C_Timer", nil)
        set("C_ChatInfo", nil)
        set("SendAddonMessage", function(prefix, msg, channel, target)
            env.addonMessages[#env.addonMessages + 1] =
                { prefix = prefix, msg = msg, channel = channel, target = target }
        end)
        set("RegisterAddonMessagePrefix", function() return true end)
        set("C_UnitAuras", nil)
        -- Legacy return order, rank included, to prove the scan does not
        -- depend on a fixed position.
        set("UnitAura", function(token, i)
            local u = unit(token)
            local aura = u and u.auras and u.auras[i]
            if not aura then return nil end
            return aura.name, "", "Interface\\Icons\\x", 1, "Magic", 3600, env.now + 3600, "player", false, false, aura.spellId
        end)
        set("C_NamePlate", nil)
    end

    -- --- helpers ------------------------------------------------------------

    function env.fire(event, ...)
        for i = 1, #env.frames do
            local f = env.frames[i]
            if f._events[event] then
                local handler = f._scripts.OnEvent
                if handler then handler(f, event, ...) end
            end
        end
    end

    -- Advance the clock and run anything that came due, including the OnUpdate
    -- fallback scheduler used when C_Timer is absent.
    function env.advance(seconds, addon)
        env.now = env.now + seconds
        for i = #env.timers, 1, -1 do
            local t = env.timers[i]
            if t.cancelled then
                table.remove(env.timers, i)
            elseif env.now >= t.at then
                if t.interval then t.at = env.now + t.interval else table.remove(env.timers, i) end
                t.fn()
            end
        end
        if addon and addon._PumpScheduler then addon:_PumpScheduler() end
    end

    -- Build a raid of `count` players and wire up units + roster together, so
    -- name-based rank lookups and unit-token lookups cannot drift apart.
    function env.buildRaid(members)
        env.inRaid = true
        env.groupSize = #members
        env.raidRoster = {}
        for i = 1, #members do
            local m = members[i]
            local token = "raid" .. i
            env.units[token] = {
                name = m.name, class = m.class, className = m.className or m.class,
                guid = m.guid or ("Player-0-000000" .. i),
                hp = m.hp or 100, hpMax = m.hpMax or 100,
                dead = m.dead or false, connected = m.connected, inRange = m.inRange,
                role = m.role or "NONE", rank = m.rank or 0, auras = m.auras or {},
            }
            env.raidRoster[i] = { name = m.name, rank = m.rank or 0, class = m.class, className = m.className or m.class }
            if m.isPlayer then env.units.player = env.units[token] end
        end
        env.units.player = env.units.player or env.units.raid1
    end

    function env.restore()
        for name, saved in pairs(env._saved) do g[name] = saved[1] end
    end

    stubs.env = env
    return env
end

return stubs
