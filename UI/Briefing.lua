-- UI/Briefing.lua
--
-- The pre-pull briefing. Mechanics on the left, positioning on the right, and
-- the literal words to say in a highlighted block.
--
-- Centred and modal-feeling but NOT modal: a plain frame that never blocks
-- input and cannot taint, so it physically cannot break anything in combat.
-- It dismisses itself on the pull, because a briefing still on screen when the
-- boss lands is exactly the thing an RL does not need.
--
-- A raider sees their own slot highlighted and everyone else's dimmed. They
-- need to know where THEY go, not study a seating chart for 25 people.

local ADDON_NAME, PPRC = ...

local W        = PPRC.UI
local Briefing = PPRC:NewModule("Briefing")
PPRC.Briefing  = Briefing

local PAD       = 16
local WIDTH     = 760
local HEIGHT    = 420
local LEFT_W    = 340
local MAX_SPELLS = 5

function Briefing:OnEnable()
    self:Build()

    -- Auto-dismiss on the pull. This is the whole reason it is not modal.
    PPRC:Listen("COMBAT_START", function() self:Hide() end)

    -- Pushed by the raid leader.
    PPRC:Listen("BRIEF_PUSHED", function(encounterID, stepID, sender)
        self:ShowPushed(encounterID, stepID, sender)
    end)

    PPRC:Listen("ASSIGNMENTS_CHANGED", function()
        if self.frame:IsShown() then self:Refresh() end
    end)
end

function Briefing:Build()
    local f = W.Panel({
        key = "briefing", title = "PRE-PULL BRIEFING", width = WIDTH, height = HEIGHT,
        default = { point = "CENTER", x = 0, y = 40 }, strata = "DIALOG",
    })
    self.frame = f

    self.dismissHint = W.Text(f.titleBar, { color = "muted2", font = "GameFontNormalSmall", justify = "RIGHT",
        text = "closes on the pull" })
    self.dismissHint:SetPoint("RIGHT", f.titleBar, "RIGHT", -8, 0)

    -- --- mechanics ---------------------------------------------------------
    self.mechHeading = W.Text(f, { text = "MECHANICS", color = "muted2", font = "GameFontNormalSmall" })
    self.mechHeading:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -32)

    self.spells = {}
    for i = 1, MAX_SPELLS do
        local entry = {}
        entry.name = W.Text(f, { color = "fel", font = "GameFontNormalSmall" })
        entry.name:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -50 - (i - 1) * 54)

        entry.text = W.Text(f, { color = "muted", font = "GameFontNormalSmall", width = LEFT_W })
        entry.text:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -64 - (i - 1) * 54)

        self.spells[i] = entry
    end

    -- --- say this ----------------------------------------------------------
    local sayBox = CreateFrame("Frame", nil, f)
    sayBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD + 30)
    sayBox:SetWidth(LEFT_W)
    sayBox:SetHeight(64)
    W.Fill(sayBox, "BACKGROUND", "panel2")
    W.Border(sayBox, "gold")
    self.sayBox = sayBox

    self.sayLabel = W.Text(sayBox, { text = "SAY THIS:", color = "gold", font = "GameFontNormalSmall" })
    self.sayLabel:SetPoint("TOPLEFT", sayBox, "TOPLEFT", 8, -6)

    self.sayText = W.Text(sayBox, { color = "text", font = "GameFontNormalSmall", width = LEFT_W - 16 })
    self.sayText:SetPoint("TOPLEFT", sayBox, "TOPLEFT", 8, -22)

    -- --- positioning -------------------------------------------------------
    self.posHeading = W.Text(f, { color = "muted2", font = "GameFontNormalSmall",
        text = "POSITIONING" })
    self.posHeading:SetPoint("TOPLEFT", f, "TOPLEFT", PAD * 2 + LEFT_W, -32)

    self.map = PPRC.PosMap:Create(f, {})
    self.map:SetPoint("TOPLEFT", f, "TOPLEFT", PAD * 2 + LEFT_W, -50)
    self.map:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD + 30)

    -- --- footer ------------------------------------------------------------
    self.pushBtn = W.Button(f, {
        text = "PUSH TO RAID", width = 120, fill = "feldim", color = "fel",
        tooltip = "Show this briefing to everyone running the addon.",
        onClick = function() self:Push() end,
    })
    self.pushBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD)

    self.closeBtn = W.Button(f, {
        text = "CLOSE", width = 70,
        onClick = function() self:Hide() end,
    })
    self.closeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)

    self.footerNote = W.Text(f, { color = "muted2", font = "GameFontNormalSmall" })
    self.footerNote:SetPoint("LEFT", self.pushBtn, "RIGHT", 10, 0)

    f:Hide()
end

-- ---------------------------------------------------------------------------
-- Render
-- ---------------------------------------------------------------------------

function Briefing:Refresh()
    if not self.frame then return end

    local step = PPRC.State:Current()
    local encounter = PPRC.State:Encounter()

    if not step then
        self.frame.title:SetText("PRE-PULL BRIEFING")
        for _, entry in ipairs(self.spells) do
            entry.name:SetText(""); entry.text:SetText("")
        end
        self.sayText:SetText("")
        self.map:Hide()
        return
    end

    local tanks = encounter and encounter.tanks
    self.frame.title:SetText(string.format("PRE-PULL BRIEFING - %s%s",
        string.upper(step.label or encounter.name or ""),
        tanks and string.format("  -  %d TANK%s", tanks, tanks == 1 and "" or "S") or ""))

    local brief = step.brief or (encounter and encounter.brief) or {}
    for i, entry in ipairs(self.spells) do
        local item = brief[i]
        if item then
            entry.name:SetText(string.upper(item.spell or ""))
            entry.text:SetText(item.text or "")
        else
            entry.name:SetText("")
            entry.text:SetText("")
        end
    end

    if #brief == 0 then
        self.spells[1].name:SetText("")
        self.spells[1].text:SetText("|cff6c7c6eNo mechanic notes on this step. "
            .. "The call below is what to say.|r")
    end

    self.sayText:SetText(step.call or "")

    -- Positioning. On a raider's client, only their own slot is lit.
    local layoutKey = step.posmap or (encounter and encounter.posmap)
    if layoutKey then
        local mine = not PPRC.State:IsController() and UnitName("player") or nil
        PPRC.PosMap:Render(self.map, layoutKey, {
            assignments = PPRC.Roster:Assignments(),
            mine = mine,
        })
        self.posHeading:SetText(mine and "POSITIONING - YOURS IS LIT" or "POSITIONING")
    else
        self.map:Hide()
        self.posHeading:SetText("|cff6c7c6eno diagram for this step|r")
    end

    if PPRC.Adapter:CanBroadcast() or PPRC.State.testMode then
        self.pushBtn:SetDisabled(false)
        self.footerNote:SetText("Each raider sees only their own position.")
    else
        self.pushBtn:SetDisabled(true)
        self.footerNote:SetText("|cff6c7c6elead or assist required to push|r")
    end
end

function Briefing:Push()
    if not PPRC.Adapter:CanBroadcast() then
        PPRC:Print("|cffc1544ayou need lead or assist to push a briefing|r")
        return false
    end
    local step = PPRC.State:Current()
    PPRC.Comm:BroadcastAssignments(PPRC.Roster:Assignments())
    PPRC.Comm:BroadcastBrief(PPRC.State.encounterID, step and step.id)
    PPRC:Print("pushed the briefing to the raid")
    return true
end

-- Somebody with rank pushed a briefing at us.
function Briefing:ShowPushed(encounterID, stepID, sender)
    if encounterID and encounterID ~= "" and encounterID ~= PPRC.State.encounterID then
        PPRC.State:Set(encounterID, PPRC.State.stepIndex, "remote")
    end
    PPRC:Log("briefing pushed by %s", tostring(sender))
    self:Show()
end

-- ---------------------------------------------------------------------------
-- Visibility
-- ---------------------------------------------------------------------------

function Briefing:Show()
    if not self.frame then return end
    self.frame:Show()
    self:Refresh()
end

function Briefing:Hide()
    if not self.frame then return end
    self.frame:Hide()
end

function Briefing:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self:Hide() else self:Show() end
end
