-- UI/Roster.lua
--
-- The assignment panel. Live roster on the left, room diagram on the right,
-- names dropped onto positions.
--
-- NO INFERENCE, and specifically NO AUTO-FILL BUTTON. Assigning "four ranged
-- DPS" would require knowing who is ranged, and the API stops at DAMAGER --
-- ranged versus melee does not exist in it. Class and the game's assigned role
-- are shown so the RL decides fast; they never decide for them.
--
-- An empty slot renders red and blocks PUSH TO RAID until it is filled or the
-- push is explicitly confirmed, because a briefing with a hole in it is worse
-- than no briefing.

local ADDON_NAME, PPRC = ...

local W          = PPRC.UI
local RosterUI   = PPRC:NewModule("RosterUI")
PPRC.RosterUI    = RosterUI

local PAD      = 12
local LIST_W   = 250
local MAP_W    = 430
local ROW_H    = 18
local MAX_ROWS = 16
local WIDTH    = PAD * 3 + LIST_W + MAP_W

function RosterUI:OnEnable()
    self:Build()

    PPRC:Listen("STATE_CHANGED",       function() if self.frame:IsShown() then self:Refresh() end end)
    PPRC:Listen("ASSIGNMENTS_CHANGED", function() if self.frame:IsShown() then self:Refresh() end end)
    PPRC:On("GROUP_ROSTER_UPDATE",     function() if self.frame:IsShown() then self:Refresh() end end)

    if PPRC.db.shown.roster then self:Show() end
end

function RosterUI:Build()
    local height = 34 + (MAX_ROWS * ROW_H) + 60
    local f = W.Panel({
        key = "roster", title = "ASSIGNMENTS", width = WIDTH, height = height,
        default = { point = "CENTER", x = 0, y = 0 },
    })
    self.frame = f

    self.headerRight = W.Text(f.titleBar, { color = "muted", font = "GameFontNormalSmall", justify = "RIGHT" })
    self.headerRight:SetPoint("RIGHT", f.titleBar, "RIGHT", -8, 0)

    -- --- roster list -------------------------------------------------------
    self.listHeading = W.Text(f, { color = "muted2", font = "GameFontNormalSmall",
        text = "LIVE ROSTER - click a name, then click a position" })
    self.listHeading:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -30)

    local listFrame = CreateFrame("Frame", nil, f)
    listFrame:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -46)
    listFrame:SetWidth(LIST_W)
    listFrame:SetHeight(MAX_ROWS * ROW_H)
    W.Fill(listFrame, "BACKGROUND", "panel2")
    W.Border(listFrame, "line")
    self.list = W.RowList(listFrame, { rowHeight = ROW_H, x = 6 })
    self.listFrame = listFrame

    self.roleNote = W.Text(f, { color = "gold", font = "GameFontNormalSmall", width = LIST_W,
        text = "Role is TANK / HEALER / DAMAGER only. Ranged versus melee does not exist in the API." })
    self.roleNote:SetPoint("TOPLEFT", listFrame, "BOTTOMLEFT", 0, -6)

    -- Role slots from Data/Roles.lua. Clicking one assigns the selected
    -- raider, exactly like clicking a position on the map -- same Assign call,
    -- same ASSIGN sync. A role just has no coordinate.
    self.roleHeading = W.Text(f, { color = "muted2", font = "GameFontNormalSmall", text = "ASSIGNMENTS" })
    self.roleHeading:SetPoint("TOPLEFT", f, "TOPLEFT", PAD * 2 + LIST_W, -30)

    self.roleRows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, f)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", PAD * 2 + LIST_W, -46 - (i - 1) * ROW_H)
        row:SetWidth(MAP_W)

        row.label = W.Text(row, { color = "muted", font = "GameFontNormalSmall" })
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.who = W.Text(row, { color = "danger", font = "GameFontNormalSmall", justify = "RIGHT" })
        row.who:SetPoint("RIGHT", row, "RIGHT", 0, 0)

        row:SetScript("OnClick", function(self_)
            if self_._slotKey then RosterUI:OnSlotClick(self_._slotKey) end
        end)
        row:Hide()
        self.roleRows[i] = row
    end

    -- --- map ---------------------------------------------------------------
    self.map = PPRC.PosMap:Create(f, {
        interactive = true,
        onSlotClick = function(slotID) self:OnSlotClick(slotID) end,
    })
    self.map:SetPoint("TOPLEFT", f, "TOPLEFT", PAD * 2 + LIST_W, -46)
    self.map:SetSize(MAP_W, MAX_ROWS * ROW_H)

    -- --- footer ------------------------------------------------------------
    self.pushBtn = W.Button(f, {
        text = "PUSH TO RAID", width = 120, fill = "feldim", color = "fel",
        tooltip = "Send these positions to everyone running the addon. Each raider sees only their own.",
        onClick = function() self:Push() end,
    })
    self.pushBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD)

    self.marksBtn = W.Button(f, {
        text = "SET RAID MARKS", width = 130,
        tooltip = "Put the diagram's icons on the assigned players.",
        onClick = function() self:ApplyMarks() end,
    })
    self.marksBtn:SetPoint("LEFT", self.pushBtn, "RIGHT", 6, 0)

    self.clearBtn = W.Button(f, {
        text = "CLEAR", width = 70,
        onClick = function()
            PPRC.db.assignments = {}
            self.selected = nil
            PPRC:Fire("ASSIGNMENTS_CHANGED", PPRC.db.assignments, "local")
        end,
    })
    self.clearBtn:SetPoint("LEFT", self.marksBtn, "RIGHT", 6, 0)

    self.footerNote = W.Text(f, { color = "muted2", font = "GameFontNormalSmall" })
    self.footerNote:SetPoint("LEFT", self.clearBtn, "RIGHT", 10, 0)
end

-- ---------------------------------------------------------------------------
-- Interaction
-- ---------------------------------------------------------------------------

function RosterUI:Select(name)
    self.selected = (self.selected == name) and nil or name
    self:Refresh()
end

function RosterUI:OnSlotClick(slotID)
    if not slotID then return end

    if self.selected then
        -- One person per slot, and one slot per person: placing someone who is
        -- already positioned moves them rather than cloning them.
        local assignments = PPRC.Roster:Assignments()
        for existingSlot, who in pairs(assignments) do
            if who == self.selected then assignments[existingSlot] = nil end
        end
        PPRC.Roster:Assign(slotID, self.selected)
        self.selected = nil
    else
        PPRC.Roster:Unassign(slotID)
    end
    self:Refresh()
end

function RosterUI:CurrentLayoutKey()
    local step = PPRC.State:Current()
    if step and step.posmap then return step.posmap end
    local encounter = PPRC.State:Encounter()
    return encounter and encounter.posmap or nil
end

-- What is unfilled right now, whether this encounter is driven by a diagram
-- or by a role template. Several Black Temple fights have roles but no map --
-- a Reliquary tank order is not a set of coordinates -- and those must still
-- be pushable.
function RosterUI:EmptySlots()
    local assignments = PPRC.Roster:Assignments()

    local roleSlots = PPRC.State.encounterID and PPRC:RoleSlots(PPRC.State.encounterID) or nil
    if roleSlots and #roleSlots > 0 then
        local empty = {}
        for _, slot in ipairs(roleSlots) do
            if not assignments[slot.key] then empty[#empty + 1] = slot.label end
        end
        return empty, true
    end

    local layoutKey = self:CurrentLayoutKey()
    if layoutKey then return PPRC.PosMap:EmptySlots(layoutKey, assignments), true end

    return {}, false
end

function RosterUI:Push()
    local assignments = PPRC.Roster:Assignments()
    local empty, haveSlots = self:EmptySlots()

    if not haveSlots then
        PPRC:Print("nothing to assign on this step - no diagram and no role template")
        return false
    end

    if #empty > 0 and not self._confirmPush then
        self._confirmPush = true
        self.pushBtn:SetLabel("PUSH ANYWAY?")
        self.footerNote:SetText(string.format("|cffc1544a%d position%s still empty|r",
            #empty, #empty == 1 and "" or "s"))
        PPRC:After(4, function()
            if self._confirmPush then
                self._confirmPush = false
                self.pushBtn:SetLabel("PUSH TO RAID")
                self:Refresh()
            end
        end)
        return false
    end

    self._confirmPush = false
    self.pushBtn:SetLabel("PUSH TO RAID")

    if not PPRC.Adapter:CanBroadcast() then
        PPRC:Print("|cffc1544ayou need lead or assist to push assignments|r")
        return false
    end

    PPRC.Comm:BroadcastAssignments(assignments)
    local step = PPRC.State:Current()
    PPRC.Comm:BroadcastBrief(PPRC.State.encounterID, step and step.id)
    PPRC:Print("pushed positions to the raid")
    return true
end

function RosterUI:ApplyMarks()
    local layoutKey = self:CurrentLayoutKey()
    if not layoutKey then return end

    local applied, failed = PPRC.PosMap:ApplyMarks(layoutKey, PPRC.Roster:Assignments())

    if failed > 0 then
        -- Spike S4's fallback: if the client will not let an addon set marks,
        -- say so and hand over something the RL can actually click.
        PPRC:Print("marked %d, |cffc1544afailed %d|r. If none worked, this client blocks addon marking - "
            .. "use a macro: /script SetRaidTarget(\"target\", 8)", applied, failed)
    else
        PPRC:Print("marked %d raider%s", applied, applied == 1 and "" or "s")
    end
end

-- ---------------------------------------------------------------------------
-- Render
-- ---------------------------------------------------------------------------

function RosterUI:Refresh()
    if not self.frame then return end

    local players = PPRC.Roster:Scan()
    local assignments = PPRC.Roster:Assignments()

    self.headerRight:SetText(string.format("%d in raid", #players))

    local assignedTo = {}
    for slotID, name in pairs(assignments) do assignedTo[name] = slotID end

    for i = 1, math.min(#players, MAX_ROWS) do
        local player = players[i]
        local row = self.list:Row(i)

        local marker = (self.selected == player.name) and "|cff8fe04b> |r" or ""
        row.left:SetText(marker .. W.ClassName(player.name, player.class))

        -- Role straight from the game. NONE is shown as unset rather than
        -- filled in from class, which would be a guess.
        local role = player.role
        if role == "NONE" or not role then
            role = "|cff6c7c6e- unset -|r"
        else
            role = "|cff8fe04b" .. role .. "|r"
        end

        local slotID = assignedTo[player.name]
        if slotID then
            local layout = PPRC.PosMap:Layout(self:CurrentLayoutKey())
            local slotDef = layout and layout.slotsByID[slotID]
            role = "|cff5fb0c9" .. (slotDef and slotDef.label or slotID) .. "|r"
        end

        row.right:SetText(role)
        row._name = player.name
        row:SetScript("OnClick", function(self_) RosterUI:Select(self_._name) end)
        row:RegisterForDrag("LeftButton")
        row:SetScript("OnDragStart", function(self_) RosterUI.selected = self_._name end)
        row:Show()
    end
    self.list:Hide(math.min(#players, MAX_ROWS) + 1)

    -- Role slots first: they exist for encounters with or without a diagram.
    local roleSlots = PPRC.State.encounterID and PPRC:RoleSlots(PPRC.State.encounterID) or nil
    local shownRoles = 0
    if roleSlots then
        local lastGroup
        for i = 1, math.min(#roleSlots, MAX_ROWS) do
            local slot = roleSlots[i]
            local row = self.roleRows[i]
            local prefix = (slot.group ~= lastGroup) and ("|cff8fe04b" .. slot.group .. "|r  ") or "  "
            lastGroup = slot.group
            row.label:SetText(prefix .. slot.label)
            local who = assignments[slot.key]
            row.who:SetText(who or "|cff6c7c6e- -|r")
            row._slotKey = slot.key
            row:Show()
            shownRoles = i
        end
    end
    for i = shownRoles + 1, MAX_ROWS do self.roleRows[i]:Hide() end
    self.roleHeading:SetText(shownRoles > 0 and "ASSIGNMENTS" or "|cff6c7c6eno role template for this encounter|r")

    local layoutKey = self:CurrentLayoutKey()
    -- The map and the role list share the same column, so only one shows.
    -- Roles win when they exist: they cover every encounter, and a diagram
    -- with no names on it says less than a filled-in assignment sheet.
    if layoutKey and shownRoles == 0 then
        PPRC.PosMap:Render(self.map, layoutKey, { assignments = assignments })
        local layout = PPRC.PosMap:Layout(layoutKey)
        self.frame.title:SetText("ASSIGNMENTS - " .. string.upper(layout.name or layoutKey))

    else
        self.map:Hide()
        local encounter = PPRC.State:Encounter()
        self.frame.title:SetText(encounter
            and ("ASSIGNMENTS - " .. string.upper(encounter.name))
            or "ASSIGNMENTS")
    end

    if not self._confirmPush then
        local empty, haveSlots = self:EmptySlots()
        if not haveSlots then
            self.footerNote:SetText("|cff6c7c6enothing to assign on this step|r")
        elseif #empty > 0 then
            self.footerNote:SetText(string.format("|cffcda23f%d slot%s empty|r",
                #empty, #empty == 1 and "" or "s"))
        else
            self.footerNote:SetText("|cff3fae6fall slots filled|r")
        end
    end

    if self.selected then
        self.listHeading:SetText("|cff8fe04b" .. self.selected .. "|r selected - click a position")
    else
        self.listHeading:SetText("LIVE ROSTER - click a name, then click a position")
    end
end

-- ---------------------------------------------------------------------------
-- Visibility
-- ---------------------------------------------------------------------------

function RosterUI:Show()
    if not self.frame then return end
    PPRC.db.shown.roster = true
    self.frame:Show()
    self:Refresh()
end

function RosterUI:Hide()
    if not self.frame then return end
    self.frame:Hide()
    PPRC.db.shown.roster = false
end

function RosterUI:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self:Hide() else self:Show() end
end
