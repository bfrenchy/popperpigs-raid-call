-- Core/RateLimit.lua
--
-- Outbound throttle. Ships from the start rather than bolted on later, because
-- the failure mode it prevents is getting the raid leader disconnected mid-pull
-- for chat flooding -- and that is not something you want to discover live.
--
-- Two lanes with separate budgets:
--   chat   SendChatMessage / RAID_WARNING. The tight one. Blizzard's flood
--          protection is on the server and the exact ceiling is unpublished,
--          so 1 message per 1.5s is a deliberately conservative hard cap.
--   addon  SendAddonMessage. Also throttled server-side, but far more
--          forgiving, and sync traffic is small and bursty by nature.
--
-- Nothing is ever dropped silently. A queue that overflows says so, with a
-- count, in the RL's own chat frame. The plan's acceptance bar for this
-- milestone is ten rapid clicks producing neither a disconnect nor a silent
-- drop, and "silent" is the half that is easy to get wrong.

local ADDON_NAME, PPRC = ...

local RateLimit = PPRC:NewModule("RateLimit")
PPRC.RateLimit = RateLimit

local PUMP_INTERVAL = 0.1

RateLimit.lanes = {
    chat = {
        interval = 1.5,
        -- 16 deep, so the plan's "ten rapid clicks" bar clears with room to
        -- spare. Still bounded: an unbounded queue would keep firing calls
        -- into a fight that has already moved past them, which is worse than
        -- saying out loud that we could not keep up.
        maxQueue = 16,
        queue    = {},
        lastSent = 0,
        dropped  = 0,
    },
    addon = {
        interval = 0.2,
        maxQueue = 40,
        queue    = {},
        lastSent = 0,
        dropped  = 0,
    },
}

-- Overflow notices are themselves throttled: a stuck finger on the call board
-- should produce one explanation, not eight.
local NOTICE_INTERVAL = 5
local lastNotice = 0

local function notifyDropped(lane, laneName)
    local now = GetTime()
    if now - lastNotice < NOTICE_INTERVAL then return end
    lastNotice = now

    PPRC:Print("|cffc1544a%d %s message%s dropped|r - queued faster than the throttle allows.",
        lane.dropped, laneName, lane.dropped == 1 and "" or "s")
    lane.dropped = 0
end

function RateLimit:EnsurePump()
    if self.ticker then return end
    self.ticker = PPRC:Ticker(PUMP_INTERVAL, function() RateLimit:Pump() end)
end

function RateLimit:StopPump()
    if not self.ticker then return end
    if self.ticker.Cancel then self.ticker:Cancel() end
    self.ticker = nil
end

local function dispatch(lane, entry)
    lane.lastSent = GetTime()
    local ok, err = pcall(entry.fn)
    if not ok then PPRC:Log("|cffc1544asend failed|r: %s", tostring(err)) end
    return ok
end

-- key (optional) collapses an identical message that is already waiting, so a
-- double-click sends once rather than twice. Repeating a call deliberately
-- still works -- once the first has gone out, the queue no longer holds it.
function RateLimit:Queue(laneName, fn, key)
    local lane = self.lanes[laneName]
    if not lane or type(fn) ~= "function" then return false end

    local now = GetTime()

    -- Free lane: send immediately. A raid warning should not eat a tick of
    -- latency just because a queue exists.
    if #lane.queue == 0 and (now - lane.lastSent) >= lane.interval then
        return dispatch(lane, { fn = fn })
    end

    if key then
        for i = 1, #lane.queue do
            if lane.queue[i].key == key then
                PPRC:Log("collapsed duplicate queued message (%s)", tostring(key))
                return true
            end
        end
    end

    if #lane.queue >= lane.maxQueue then
        lane.dropped = lane.dropped + 1
        PPRC:Log("|cffc1544adropped|r a %s message: queue full (%d)", laneName, lane.maxQueue)
        notifyDropped(lane, laneName)
        return false
    end

    lane.queue[#lane.queue + 1] = { fn = fn, key = key }
    self:EnsurePump()
    return true
end

function RateLimit:Pump()
    local now = GetTime()
    local pending = 0

    for laneName, lane in pairs(self.lanes) do
        if #lane.queue > 0 then
            if (now - lane.lastSent) >= lane.interval then
                dispatch(lane, table.remove(lane.queue, 1))
            end
            pending = pending + #lane.queue
        end
        if lane.dropped > 0 then notifyDropped(lane, laneName) end
    end

    if pending == 0 then self:StopPump() end
end

function RateLimit:QueueDepth(laneName)
    local lane = self.lanes[laneName]
    return lane and #lane.queue or 0
end

-- Test seam and a genuine reset for /pprc reset.
function RateLimit:Flush()
    for _, lane in pairs(self.lanes) do
        lane.queue = {}
        lane.dropped = 0
        lane.lastSent = 0
    end
    self:StopPump()
    lastNotice = 0
end

-- ---------------------------------------------------------------------------
-- Outbound helpers
--
-- Everything that leaves this addon goes through one of these two. Nothing
-- calls SendChatMessage directly.
-- ---------------------------------------------------------------------------

-- Where should a call go? Lead or assist gets RAID_WARNING; a plain raider
-- degrades to /raid rather than failing; solo, or with local echo on, it
-- stays in your own chat frame and touches nobody.
function RateLimit:ChatChannel()
    if PPRC.db and PPRC.db.localEcho then return "ECHO" end
    if not PPRC.Adapter:InGroup() then return "ECHO" end
    if PPRC.Adapter:CanBroadcast() then return "RAID_WARNING" end
    return "RAID"
end

function RateLimit:SendCall(message, key)
    if type(message) ~= "string" or message == "" then return false end

    local channel = self:ChatChannel()

    if channel == "ECHO" then
        -- Local echo is immediate and unthrottled: it costs the server nothing
        -- and the whole point of the mode is testing the flow.
        PPRC:Print("|cffcda23f[echo]|r %s", message)
        return true
    end

    return self:Queue("chat", function()
        PPRC.Adapter:SendChat(message, channel)
    end, key or message)
end

function RateLimit:SendAddon(prefix, message, channel, target)
    return self:Queue("addon", function()
        PPRC.Adapter:SendAddon(prefix, message, channel, target)
    end)
end
