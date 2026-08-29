-- UI/PosMap.lua
--
-- The positioning diagram, drawn from Data/Positions.lua rather than loaded
-- from a texture.
--
-- Markers use Blizzard's own raid target icon art, so "skull, corner A" on the
-- diagram is literally the mark players see over each other's heads. That was
-- a requirement in the plan and it is the reason this reads as instructions
-- rather than as decoration.
--
-- One map widget serves the roster panel and the briefing overlay. The briefing
-- passes `mine` so a raider's own slot is highlighted and everyone else's is
-- dimmed -- they should see where THEY go, not study a seating chart.

local ADDON_NAME, PPRC = ...

local W      = PPRC.UI
local PosMap = PPRC:NewModule("PosMap")
PPRC.PosMap  = PosMap

local ICON_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local INSET        = 34    -- room for the landmark labels around the room
local MARK_SIZE    = 18

-- The icon sheet is a 4x4 grid; indices run 1..8 across the first two rows.
function PosMap:MarkCoords(index)
    if not index or index < 1 or index > 8 then return 0, 1, 0, 1 end
    local col = (index - 1) % 4
    local row = math.floor((index - 1) / 4)
    return col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25
end

function PosMap:Layout(key)
    return key and PPRC.Layouts[key] or nil
end

-- ---------------------------------------------------------------------------
-- Build
--
-- The widget is created once per host frame and then updated in place, so
-- flipping between steps does not churn frames mid-pull.
-- ---------------------------------------------------------------------------

function PosMap:Create(parent, opts)
    opts = opts or {}

    local map = CreateFrame("Frame", nil, parent)
    W.Fill(map, "BACKGROUND", "panel2")
    W.Border(map, "line")

    -- The room rectangle, inset to leave space for landmark labels.
    local room = CreateFrame("Frame", nil, map)
    room:SetPoint("TOPLEFT", map, "TOPLEFT", INSET, -INSET)
    room:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", -INSET, INSET)
    W.Border(room, "muted2")
    map.room = room

    map.landmarks = {}
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
        local text = W.Text(map, { color = "ice", font = "GameFontNormalSmall", justify = "CENTER" })
        if side == "top" then
            text:SetPoint("BOTTOM", room, "TOP", 0, 4)
        elseif side == "bottom" then
            text:SetPoint("TOP", room, "BOTTOM", 0, -4)
        elseif side == "left" then
            text:SetPoint("RIGHT", room, "LEFT", -4, 0)
        else
            text:SetPoint("LEFT", room, "RIGHT", 4, 0)
        end
        map.landmarks[side] = text
    end

    -- Compass, so "north-east" means something without checking the minimap.
    map.compass = W.Text(map, { text = "N", color = "gold", font = "GameFontNormalSmall" })
    map.compass:SetPoint("TOPRIGHT", map, "TOPRIGHT", -8, -6)

    -- Boss marker
    map.boss = CreateFrame("Frame", nil, room)
    map.boss:SetSize(16, 16)
    W.Fill(map.boss, "ARTWORK", "fel")
    map.bossLabel = W.Text(room, { color = "text", font = "GameFontNormalSmall", justify = "CENTER" })

    map.slots = {}
    map.note  = W.Text(map, { color = "muted", font = "GameFontNormalSmall", justify = "CENTER" })
    map.note:SetPoint("BOTTOMLEFT", map, "BOTTOMLEFT", 6, 4)
    map.note:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", -6, 4)

    map._onSlotClick = opts.onSlotClick
    map._interactive = opts.interactive and true or false

    return map
end

-- Place a child at normalised room coordinates. y is bottom-up.
local function anchor(child, room, x, y)
    child:ClearAllPoints()
    child:SetPoint("CENTER", room, "BOTTOMLEFT",
        x * (room:GetWidth() or 300), y * (room:GetHeight() or 200))
end

function PosMap:SlotWidget(map, index)
    local slot = map.slots[index]
    if slot then return slot end

    local room = map.room

    slot = CreateFrame("Button", nil, room)
    slot:SetSize(MARK_SIZE, MARK_SIZE)

    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetAllPoints(slot)
    slot.icon:SetTexture(ICON_TEXTURE)

    slot.label = W.Text(room, { color = "muted2", font = "GameFontNormalSmall", justify = "CENTER" })
    slot.label:SetPoint("TOP", slot, "BOTTOM", 0, -2)

    slot.who = W.Text(room, { color = "danger", font = "GameFontNormalSmall", justify = "CENTER" })
    slot.who:SetPoint("TOP", slot.label, "BOTTOM", 0, -1)

    slot:SetScript("OnClick", function(self_)
        if map._onSlotClick then map._onSlotClick(self_._slotID) end
    end)

    -- Drag target, for the RL who would rather drag a name than click twice.
    slot:RegisterForDrag("LeftButton")
    slot:SetScript("OnReceiveDrag", function(self_)
        if map._onSlotClick then map._onSlotClick(self_._slotID) end
    end)

    map.slots[index] = slot
    return slot
end

-- ---------------------------------------------------------------------------
-- Render
--
-- opts.assignments  slot id -> player name
-- opts.mine         highlight only this player's slot (briefing, raider view)
-- ---------------------------------------------------------------------------

function PosMap:Render(map, layoutKey, opts)
    opts = opts or {}
    local layout = self:Layout(layoutKey)

    if not layout then
        map:Hide()
        return false
    end
    map:Show()

    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
        map.landmarks[side]:SetText("")
    end
    for _, landmark in ipairs(layout.landmarks or {}) do
        local text = map.landmarks[landmark.side]
        if text then text:SetText(landmark.label) end
    end

    map.note:SetText(layout.note or "")

    local room = map.room
    if layout.boss then
        anchor(map.boss, room, layout.boss.x, layout.boss.y)
        map.boss:Show()
        map.bossLabel:SetText(layout.boss.label or "")
        map.bossLabel:ClearAllPoints()
        map.bossLabel:SetPoint("TOP", map.boss, "BOTTOM", 0, -2)
    else
        map.boss:Hide()
        map.bossLabel:SetText("")
    end

    local assignments = opts.assignments or {}
    local me = opts.mine and PPRC.Adapter:StripRealm(opts.mine) or nil

    for i, slotDef in ipairs(layout.slots or {}) do
        local slot = self:SlotWidget(map, i)
        slot._slotID = slotDef.id

        anchor(slot, room, slotDef.x, slotDef.y)
        local left, right, top, bottom = self:MarkCoords(slotDef.mark)
        slot.icon:SetTexCoord(left, right, top, bottom)

        slot.label:SetText(slotDef.label or slotDef.id)

        local who = assignments[slotDef.id]
        if who then
            slot.who:SetText(who)
            local c = PPRC.COLORS.text
            slot.who:SetTextColor(c[1], c[2], c[3])
        else
            -- Empty renders red on purpose: it is the thing blocking a push.
            slot.who:SetText("- empty -")
            local c = PPRC.COLORS.danger
            slot.who:SetTextColor(c[1], c[2], c[3])
        end

        -- A raider is shown their own slot, not a seating chart.
        if me then
            local isMine = who and PPRC.Adapter:StripRealm(tostring(who)) == me
            slot.icon:SetAlpha(isMine and 1 or 0.25)
            slot.label:SetAlpha(isMine and 1 or 0.25)
            slot.who:SetAlpha(isMine and 1 or 0.25)
        else
            slot.icon:SetAlpha(1)
            slot.label:SetAlpha(1)
            slot.who:SetAlpha(1)
        end

        slot:Show()
    end

    for i = #(layout.slots or {}) + 1, #map.slots do
        map.slots[i]:Hide()
        map.slots[i].label:SetText("")
        map.slots[i].who:SetText("")
    end

    map._layoutKey = layoutKey
    return true
end

-- Which slots have nobody in them. PUSH TO RAID is blocked on this.
function PosMap:EmptySlots(layoutKey, assignments)
    local layout = self:Layout(layoutKey)
    if not layout then return {} end

    local empty = {}
    for _, slotDef in ipairs(layout.slots or {}) do
        if not (assignments or {})[slotDef.id] then empty[#empty + 1] = slotDef.id end
    end
    return empty
end

-- Apply raid target icons to the assigned players, so the marks on screen
-- match the diagram. Reports what it could not do rather than failing quietly.
function PosMap:ApplyMarks(layoutKey, assignments)
    local layout = self:Layout(layoutKey)
    if not layout then return 0, 0 end

    local applied, failed = 0, 0

    for _, slotDef in ipairs(layout.slots or {}) do
        local name = (assignments or {})[slotDef.id]
        if name and slotDef.mark then
            local unit = self:UnitForName(name)
            if unit then
                local ok = PPRC.Adapter:SetMark(unit, slotDef.mark)
                if ok then applied = applied + 1 else failed = failed + 1 end
            else
                failed = failed + 1
            end
        end
    end

    return applied, failed
end

function PosMap:UnitForName(name)
    local target = PPRC.Adapter:StripRealm(tostring(name))
    local units = PPRC.Adapter:GroupUnits()
    for i = 1, #units do
        local unitName = UnitName(units[i])
        if unitName and PPRC.Adapter:StripRealm(unitName) == target then return units[i] end
    end
    return nil
end
