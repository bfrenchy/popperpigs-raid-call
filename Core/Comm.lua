-- Core/Comm.lua
--
-- Keeping 25 clients on the same step.
--
-- PERMISSION IS VERIFIED ON RECEIVE, NEVER TRUSTED FROM THE PAYLOAD.
--
-- That is the whole security model and it is one line of policy: a message
-- claiming to be from the raid leader means nothing, so we look up the
-- sender's actual rank in the raid roster and discard anything from someone
-- who does not hold lead or assist. A forged payload from a plain raider
-- cannot move anyone's state.
--
-- Rank is resolved by NAME through GetRaidRosterInfo. The technical plan uses
-- UnitIsGroupLeader(sender), but that family takes a unit token rather than a
-- player name, and an addon message only ever gives us a name.

local ADDON_NAME, PPRC = ...

local Comm = PPRC:NewModule("Comm")
PPRC.Comm  = Comm

local PREFIX = "PPRC"

-- A controller is considered live for this long after their last broadcast.
-- Long enough to survive a quiet trash pull, short enough that the sync dot
-- goes red reasonably soon after an RL logs out.
local CONTROLLER_TIMEOUT = 90

-- Storms are the failure mode here. 25 people zoning in at once must not
-- produce 25 state requests and 25 replies.
local REQUEST_THROTTLE = 5
local REPLY_THROTTLE   = 2

Comm.versions   = {}    -- player name -> version string
Comm.controller = nil   -- name of whoever last sent us valid state
Comm.lastSeen   = 0

local lastRequest = 0
local lastReply   = 0

-- ---------------------------------------------------------------------------
-- Enable
-- ---------------------------------------------------------------------------

function Comm:OnEnable()
    if not PPRC.Cap.addonMessage then
        PPRC:Log("|cffc1544ano addon messaging on this client|r - sync disabled, everything else still works")
        return
    end

    PPRC.Adapter:RegisterPrefix(PREFIX)

    self.available = PPRC:On("CHAT_MSG_ADDON", function(_, prefix, message, channel, sender)
        self:OnAddonMessage(prefix, message, channel, sender)
    end)

    -- Broadcast our own changes, but only the ones we originated. A "remote"
    -- change is one we were just told about; echoing it back is how two
    -- clients ping-pong forever.
    PPRC:Listen("STATE_CHANGED", function(snapshot, source)
        if source == "local" or source == "detect" then self:BroadcastState(snapshot) end
    end)

    PPRC:On("GROUP_ROSTER_UPDATE", function() self:RequestState() end)
    PPRC:On("PLAYER_ENTERING_WORLD", function() self:RequestState() end)
end

-- ---------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------

function Comm:Channel()
    if not PPRC.Adapter:InGroup() then return nil end
    return PPRC.Adapter:InRaid() and "RAID" or "PARTY"
end

function Comm:Send(messageType, payload)
    if PPRC.State.testMode then return false end   -- test mode never talks

    local channel = self:Channel()
    if not channel then return false end

    for _, frame in ipairs(PPRC.Codec.Frame(messageType, payload or {})) do
        PPRC.RateLimit:SendAddon(PREFIX, frame, channel)
    end
    return true
end

function Comm:BroadcastState(snapshot)
    if not PPRC.Adapter:CanBroadcast() then return false end
    return self:Send("STATE", {
        e = snapshot.encounterID or "",
        s = snapshot.stepIndex or 0,
    })
end

function Comm:BroadcastAssignments(assignments)
    if not PPRC.Adapter:CanBroadcast() then return false end
    return self:Send("ASSIGN", assignments or {})
end

function Comm:BroadcastBrief(encounterID, stepID)
    if not PPRC.Adapter:CanBroadcast() then return false end
    return self:Send("BRIEF", { e = encounterID or "", step = stepID or "" })
end

-- Asked on join and after a reload. Throttled, because a raid forming produces
-- a burst of roster updates and every one of them would otherwise ask again.
function Comm:RequestState()
    local now = GetTime()
    if now - lastRequest < REQUEST_THROTTLE then return false end
    lastRequest = now

    self:Send("VERSION", { v = PPRC.version })
    return self:Send("REQ_STATE", {})
end

-- ---------------------------------------------------------------------------
-- Receiving
-- ---------------------------------------------------------------------------

local function isSelf(sender)
    local me = UnitName("player")
    return me and PPRC.Adapter:StripRealm(sender) == PPRC.Adapter:StripRealm(me)
end

function Comm:OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= PREFIX or not sender then return end
    if isSelf(sender) then return end

    local messageType, payload = PPRC.Codec.Receive(sender, message)
    if not messageType then return end       -- still waiting on more chunks
    if not payload then return end

    local handler = self["Handle" .. messageType]
    if not handler then
        PPRC:Log("unknown message type %s from %s", messageType, sender)
        return
    end

    handler(self, sender, payload)
end

-- Lead or assist. Everything that can move another player's screen goes
-- through this, and it is checked here rather than at the send site because
-- the send site is on someone else's computer.
function Comm:SenderMayControl(sender)
    return PPRC.Adapter:RankOf(sender) >= 1
end

function Comm:HandleSTATE(sender, payload)
    if not self:SenderMayControl(sender) then
        PPRC:Log("|cffc1544adiscarded|r STATE from %s: not lead or assist", sender)
        return
    end

    -- If we are driving, we do not follow. Two people with assist both
    -- clicking would otherwise fight over the raid's screen.
    if PPRC.Adapter:CanBroadcast() and PPRC.Adapter:RankOf(sender) < 2 then
        PPRC:Log("ignored STATE from %s: we hold rank too", sender)
        return
    end

    self.controller = sender
    self.lastSeen = GetTime()

    local encounterID = payload.e
    if encounterID == "" then encounterID = nil end

    PPRC.State:Set(encounterID, payload.s or 0, "remote")
    PPRC:Fire("SYNC_CHANGED")
end

function Comm:HandleASSIGN(sender, payload)
    if not self:SenderMayControl(sender) then
        PPRC:Log("|cffc1544adiscarded|r ASSIGN from %s: not lead or assist", sender)
        return
    end

    PPRC.db.assignments = payload
    PPRC:Fire("ASSIGNMENTS_CHANGED", payload, sender)
end

function Comm:HandleBRIEF(sender, payload)
    if not self:SenderMayControl(sender) then
        PPRC:Log("|cffc1544adiscarded|r BRIEF from %s: not lead or assist", sender)
        return
    end
    PPRC:Fire("BRIEF_PUSHED", payload.e, payload.step, sender)
end

-- Anyone may ask; only a controller answers, and the answer is a broadcast, so
-- 24 simultaneous requests still cost one reply.
function Comm:HandleREQ_STATE(sender)
    if not PPRC.Adapter:CanBroadcast() then return end

    local now = GetTime()
    if now - lastReply < REPLY_THROTTLE then return end
    lastReply = now

    self:BroadcastState(PPRC.State:Snapshot())
    if PPRC.db.assignments and next(PPRC.db.assignments) then
        self:BroadcastAssignments(PPRC.db.assignments)
    end
end

function Comm:HandleVERSION(sender, payload)
    self.versions[PPRC.Adapter:StripRealm(sender)] = payload.v or "?"
    PPRC:Fire("VERSIONS_CHANGED")
end

-- ---------------------------------------------------------------------------
-- Status
-- ---------------------------------------------------------------------------

function Comm:HasController()
    if not self.controller then return false end
    return (GetTime() - self.lastSeen) < CONTROLLER_TIMEOUT
end

-- "18/25 running - 2 outdated"
function Comm:VersionReport()
    local groupSize = PPRC.Adapter:GroupSize()
    if groupSize == 0 then return "not in a group" end

    local mine = PPRC:VersionNumber()
    local running, outdated = 0, 0

    for _, version in pairs(self.versions) do
        running = running + 1
        if PPRC:VersionNumber(version) < mine then outdated = outdated + 1 end
    end

    running = running + 1   -- us

    local report = string.format("%d/%d running", running, groupSize)
    if outdated > 0 then report = report .. string.format(" - |cffcda23f%d outdated|r", outdated) end
    return report
end
