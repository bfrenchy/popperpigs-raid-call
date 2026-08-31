-- Core/Codec.lua
--
-- Wire format for addon messages. This is what AceSerializer plus LibDeflate
-- would have done, minus two libraries we cannot fetch and do not need: the
-- payloads here are a handful of short fields, and compressing 60 bytes costs
-- more than it saves.
--
-- Format is deliberately human-readable, because the first thing anyone does
-- when sync misbehaves is print the raw message:
--
--   e=hyjal_winterchill~s=#6
--
--   key=value pairs joined by ~
--   #  number      #6
--   !  boolean     !1 / !0
--   @  array       @Vexmoor,Aeliswyn
--   everything else is a string
--   ~ = , % inside a value are percent-escaped
--
-- CHUNKING
-- --------
-- The technical plan says payloads sit under the 255-byte cap so chunking is
-- not needed. That holds for STATE, which is two fields. It does not hold for
-- ASSIGN: 25 names at roughly 12 bytes each is ~300 bytes before any framing.
-- So chunking exists, and every message carries the same envelope whether it
-- needs it or not -- one format is easier to trust than two.
--
--   <type>:<id>:<seq>/<total>:<data>

local ADDON_NAME, PPRC = ...

local Codec = {}
PPRC.Codec = Codec

-- SendAddonMessage caps the body at 255. Leave room for the envelope and for
-- any framing the client adds on its own.
Codec.CHUNK_SIZE = 200
Codec.REASSEMBLY_TIMEOUT = 60

-- ---------------------------------------------------------------------------
-- Escaping
-- ---------------------------------------------------------------------------

local function escape(value)
    return (tostring(value):gsub("[%%~=,:]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function unescape(value)
    return (value:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

-- ---------------------------------------------------------------------------
-- Encode / decode
-- ---------------------------------------------------------------------------

function Codec.Encode(tbl)
    if type(tbl) ~= "table" then return "" end

    local parts = {}
    for key, value in pairs(tbl) do
        local encoded

        if type(value) == "table" then
            local items = {}
            for i = 1, #value do items[i] = escape(value[i]) end
            encoded = "@" .. table.concat(items, ",")
        elseif type(value) == "boolean" then
            encoded = value and "!1" or "!0"
        elseif type(value) == "number" then
            encoded = "#" .. tostring(value)
        else
            encoded = escape(value)
        end

        parts[#parts + 1] = escape(key) .. "=" .. encoded
    end

    -- Sorted so the same table always produces the same bytes. That makes the
    -- rate limiter's duplicate collapsing work and makes tests deterministic.
    table.sort(parts)
    return table.concat(parts, "~")
end

function Codec.Decode(text)
    if type(text) ~= "string" then return nil end

    local result = {}
    for pair in text:gmatch("[^~]+") do
        local key, value = pair:match("^([^=]*)=(.*)$")
        if key then
            key = unescape(key)
            local marker = value:sub(1, 1)

            if marker == "#" then
                result[key] = tonumber(value:sub(2))
            elseif marker == "!" then
                result[key] = value:sub(2) == "1"
            elseif marker == "@" then
                local items = {}
                local body = value:sub(2)
                if body ~= "" then
                    for item in body:gmatch("[^,]+") do items[#items + 1] = unescape(item) end
                end
                result[key] = items
            else
                result[key] = unescape(value)
            end
        end
    end
    return result
end

-- ---------------------------------------------------------------------------
-- Framing
-- ---------------------------------------------------------------------------

local nextID = 0

function Codec.Frame(messageType, payload)
    local data = Codec.Encode(payload)

    nextID = (nextID + 1) % 1000
    local id = nextID

    local frames = {}
    local total = math.max(1, math.ceil(#data / Codec.CHUNK_SIZE))

    for seq = 1, total do
        local slice = data:sub((seq - 1) * Codec.CHUNK_SIZE + 1, seq * Codec.CHUNK_SIZE)
        frames[seq] = string.format("%s:%d:%d/%d:%s", messageType, id, seq, total, slice)
    end

    return frames
end

-- ---------------------------------------------------------------------------
-- Reassembly
--
-- Buffers are per sender AND per message id, so two people broadcasting at
-- once cannot interleave into each other's payload. Stale partials are dropped
-- rather than kept forever: a client that disconnects mid-send should not leak.
-- ---------------------------------------------------------------------------

local buffers = {}

function Codec.Receive(sender, raw)
    local messageType, id, seq, total, data =
        raw:match("^([%u_]+):(%d+):(%d+)/(%d+):(.*)$")

    if not messageType then return nil end
    seq, total = tonumber(seq), tonumber(total)

    if total == 1 then
        return messageType, Codec.Decode(data)
    end

    local key = sender .. "\0" .. messageType .. "\0" .. id
    local buffer = buffers[key]

    if not buffer or (GetTime() - buffer.at) > Codec.REASSEMBLY_TIMEOUT then
        buffer = { parts = {}, count = 0, total = total, at = GetTime() }
        buffers[key] = buffer
    end

    if not buffer.parts[seq] then
        buffer.parts[seq] = data
        buffer.count = buffer.count + 1
    end

    if buffer.count < buffer.total then return nil end

    buffers[key] = nil
    return messageType, Codec.Decode(table.concat(buffer.parts))
end

function Codec.PurgeStale()
    local now = GetTime()
    for key, buffer in pairs(buffers) do
        if (now - buffer.at) > Codec.REASSEMBLY_TIMEOUT then buffers[key] = nil end
    end
end

function Codec.PendingCount()
    local n = 0
    for _ in pairs(buffers) do n = n + 1 end
    return n
end

-- Test seam.
function Codec._Reset()
    buffers = {}
    nextID = 0
end
