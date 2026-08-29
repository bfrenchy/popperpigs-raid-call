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

function RosterUI:Push()
    local layoutKey = self:CurrentLayoutKey()
    if not layoutKey then
        PPRC:Print("no positioning diagram on this step - nothing to push")
        return false
    end

    local assignments = PPRC.Roster:Assignments()
    local empty = PPRC.PosMap:EmptySlots(layoutKey, assignments)

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

    local layoutKey = self:CurrentLayoutKey()
    if layoutKey then
        PPRC.PosMap:Render(self.map, layoutKey, { assignments = assignments })
        local layout = PPRC.PosMap:Layout(layoutKey)
        self.frame.title:SetText("ASSIGNMENTS - " .. string.upper(layout.name or layoutKey))

        if not self._confirmPush then
            local empty = PPRC.PosMap:EmptySlots(layoutKey, assignments)
            self.footerNote:SetText(#empty > 0
                and string.format("|cffcda23f%d position%s empty|r", #empty, #empty == 1 and "" or "s")
                or "|cff3fae6fall positions filled|r")
        end
    else
        self.map:Hide()
        self.frame.title:SetText("ASSIGNMENTS")
        self.footerNote:SetText("|cff6c7c6eno diagram for this step|r")
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
