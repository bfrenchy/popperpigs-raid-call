-- UI/Readiness.lua
--
-- Replaces three rounds of "everyone check your flasks" with one glance.
--
-- The rule that shapes this whole panel: a green tick always means the game
-- confirmed it. Anything the API cannot read is an honest checkbox the RL
-- ticks, never an inferred tick and never a red cross. Resistance gear, spec
-- and consumables sitting in bags are all unreadable without inspection, so
-- they are checkboxes.
--
-- On a wipe the same panel switches to alive / released / in range / rebuffed,
-- because "is everyone back yet?" is the most repeated question of the night.

local ADDON_NAME, PPRC = ...

local W         = PPRC.UI
local Readiness = PPRC:NewModule("Readiness")
PPRC.Readiness  = Readiness

local PAD        = 12
local TILE_W     = 104
local TILE_H     = 52
local TILE_GAP   = 6
local ROW_H      = 17
local MAX_ROWS   = 8
local WIDTH      = PAD * 2 + 5 * TILE_W + 4 * TILE_GAP

function Readiness:OnEnable()
    self:Build()

    PPRC:Listen("STATE_CHANGED", function() if self.frame:IsShown() then self:Refresh() end end)
    PPRC:Listen("WIPE_DETECTED", function() self:EnterWipeMode() end)
    PPRC:Listen("COMBAT_START",  function() self.wipeMode = false end)

    if PPRC.db.shown.readiness then self:Show() end
end

-- ---------------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------------

local function tile(parent, index, caption)
    local t = CreateFrame("Frame", nil, parent)
    t:SetSize(TILE_W, TILE_H)
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + (index - 1) * (TILE_W + TILE_GAP), -34)
    W.Fill(t, "BACKGROUND", "panel2")
    W.Border(t, "line")

    t.value = W.Text(t, { text = "-", color = "muted", font = "GameFontNormalLarge", justify = "CENTER" })
    t.value:SetPoint("CENTER", t, "CENTER", 0, 8)

    t.caption = W.Text(t, { text = caption, color = "muted2", font = "GameFontNormalSmall", justify = "CENTER" })
    t.caption:SetPoint("BOTTOM", t, "BOTTOM", 0, 6)

    return t
end

function Readiness:Build()
    local height = 34 + TILE_H + 22 + (MAX_ROWS * ROW_H) + 30 + 34
    local f = W.Panel({
        key = "readiness", title = "READINESS - PRE-PULL CHECK",
        width = WIDTH, height = height,
        default = { point = "CENTER", x = 0, y = 120 },
    })
    self.frame = f

    self.readyCount = W.Text(f.titleBar, { color = "gold", font = "GameFontNormalSmall", justify = "RIGHT" })
    self.readyCount:SetPoint("RIGHT", f.titleBar, "RIGHT", -8, 0)

    self.tiles = {
        alive     = tile(f, 1, "ALIVE"),
        inRange   = tile(f, 2, "IN RANGE"),
        flask     = tile(f, 3, "FLASK / ELIXIR"),
        food      = tile(f, 4, "FOOD BUFF"),
        soulstone = tile(f, 5, "SOULSTONES OUT"),
    }

    local listTop = -(34 + TILE_H + 10)

    self.listHeading = W.Text(f, { color = "muted2", font = "GameFontNormalSmall",
        text = "NEEDS ATTENTION - click a name to whisper them" })
    self.listHeading:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, listTop)

    local listFrame = CreateFrame("Frame", nil, f)
    listFrame:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, listTop - 16)
    listFrame:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    listFrame:SetHeight(MAX_ROWS * ROW_H)
    self.list = W.RowList(listFrame, { rowHeight = ROW_H })

    -- Manual checklist: things the API genuinely cannot answer.
    self.checkHeading = W.Text(f, { color = "gold", font = "GameFontNormalSmall",
        text = "MANUAL - the game cannot report these, so they are checkboxes" })
    self.checkHeading:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, listTop - 22 - (MAX_ROWS * ROW_H))

    self.checkboxes = {}
    for i = 1, 4 do
        local box = W.Checkbox(f, {
            width = 240,
            onToggle = function(checked)
                local key = self.checkboxes[i]._key
                if key then PPRC.db.checklist[key] = checked or nil end
            end,
        })
        box:SetPoint("TOPLEFT", f, "TOPLEFT",
            PAD + ((i - 1) % 2) * 260,
            listTop - 38 - (MAX_ROWS * ROW_H) - math.floor((i - 1) / 2) * 18)
        box:Hide()
        self.checkboxes[i] = box
    end

    -- Footer
    self.whisperBtn = W.Button(f, {
        text = "WHISPER OFFENDERS", width = 150, fill = "feldim", color = "fel",
        tooltip = "Whisper everyone missing a flask or food. Throttled, so it cannot flood.",
        onClick = function() PPRC.Roster:WhisperOffenders() end,
    })
    self.whisperBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD)

    self.announceBtn = W.Button(f, {
        text = "ANNOUNCE SUMMARY", width = 150,
        tooltip = "Post one line to the raid. Never a wall of names.",
        onClick = function() PPRC.Roster:Announce() end,
    })
    self.announceBtn:SetPoint("LEFT", self.whisperBtn, "RIGHT", 6, 0)

    self.footerNote = W.Text(f, { color = "muted2", font = "GameFontNormalSmall" })
    self.footerNote:SetPoint("LEFT", self.announceBtn, "RIGHT", 10, 0)

    self.refreshBtn = W.Button(f, {
        text = "RESCAN", width = 70,
        onClick = function() self:Refresh() end,
    })
    self.refreshBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

-- have / total, plus how many could not be read at all. Unknowns never turn
-- the tile red -- that would be reporting a gap in our reading as a failure by
-- the raider.
local function setTile(t, have, total, unknown, invert)
    if total == 0 then
        t.value:SetText("-")
        W.Paint(t.value, "muted2")
        W.Recolor(t, "line")
        return
    end

    if unknown and unknown >= total then
        t.value:SetText("?")
        local c = PPRC.COLORS.muted2
        t.value:SetTextColor(c[1], c[2], c[3])
        W.Recolor(t, "line")
        return
    end

    t.value:SetText(string.format("%d/%d", have, total))

    local ratio = have / total
    local color
    if ratio >= 1 then color = "green"
    elseif ratio >= 0.85 then color = "gold"
    else color = "danger" end
    if invert and have == 0 then color = "muted2" end

    local c = PPRC.COLORS[color]
    t.value:SetTextColor(c[1], c[2], c[3])
    W.Recolor(t, color)
end

function Readiness:Refresh()
    if not self.frame then return end
    if self.wipeMode then return self:RefreshWipe() end

    self.frame.title:SetText("READINESS - PRE-PULL CHECK")

    local players, summary = PPRC.Roster:Scan()
    local ready, total = PPRC.Roster:ReadyCount()
    self.readyCount:SetText(string.format("%d / %d READY", ready, total))

    setTile(self.tiles.alive,     summary.alive,   summary.total, 0)
    setTile(self.tiles.inRange,   summary.inRange, summary.total, 0)
    setTile(self.tiles.flask,     summary.flask,   summary.total, summary.flaskUnknown)
    setTile(self.tiles.food,      summary.food,    summary.total, summary.foodUnknown)
    setTile(self.tiles.soulstone, summary.soulstone, math.max(summary.warlocks, summary.soulstone), 0, true)

    -- Offender list
    local offenders = PPRC.Roster:Offenders()
    for i = 1, math.min(#offenders, MAX_ROWS) do
        local entry = offenders[i]
        local row = self.list:Row(i)
        row.left:SetText(W.ClassName(entry.player.name, entry.player.class))
        row.right:SetText("|cffc1544a" .. table.concat(entry.issues, "  ") .. "|r")
        row._name = entry.player.name
        row:SetScript("OnClick", function(self_)
            PPRC.Roster:Whisper(self_._name, "Raid check: sort your consumables before the pull please.")
            PPRC:Print("whispered %s", self_._name)
        end)
        row:Show()
    end
    self.list:Hide(math.min(#offenders, MAX_ROWS) + 1)

    if #offenders == 0 then
        self.listHeading:SetText("|cff3fae6feveryone readable is ready|r")
    elseif #offenders > MAX_ROWS then
        self.listHeading:SetText(string.format(
            "NEEDS ATTENTION - click a name to whisper them  |cff6c7c6e(%d more not shown)|r",
            #offenders - MAX_ROWS))
    else
        self.listHeading:SetText("NEEDS ATTENTION - click a name to whisper them")
    end

    if summary.flaskUnknown >= summary.total and summary.total > 0 then
        self.footerNote:SetText("|cffcda23fthis client cannot read auras - consumable columns are blank, not zero|r")
    else
        self.footerNote:SetText("")
    end

    self:RefreshChecklist()
end

function Readiness:RefreshChecklist()
    local encounter = PPRC.State:Encounter()
    local items = encounter and encounter.checklist or nil

    PPRC.db.checklist = PPRC.db.checklist or {}

    for i, box in ipairs(self.checkboxes) do
        local item = items and items[i]
        if item then
            local key = (encounter.id or "?") .. ":" .. i
            box._key = key
            box:SetChecked(PPRC.db.checklist[key] and true or false)
            box:Show()
        else
            box._key = nil
            box:Hide()
        end
    end

    if items and #items > 0 then
        self.checkHeading:SetText("MANUAL - the game cannot report these, so they are checkboxes")
    else
        self.checkHeading:SetText("|cff6c7c6eno manual checks for this step|r")
    end
end

-- ---------------------------------------------------------------------------
-- Wipe recovery
-- ---------------------------------------------------------------------------

function Readiness:EnterWipeMode()
    self.wipeMode = true
    if PPRC.db.shown.readiness or PPRC.Adapter:CanBroadcast() then
        self.frame:Show()
    end
    self:RefreshWipe()
end

function Readiness:RefreshWipe()
    self.frame.title:SetText("WIPE RECOVERY - IS EVERYONE BACK?")

    local status = PPRC.Roster:WipeScan()
    self.readyCount:SetText(string.format("%d / %d BACK", status.alive, status.total))

    setTile(self.tiles.alive,     status.alive,    status.total, 0)
    setTile(self.tiles.inRange,   status.inRange,  status.total, 0)
    setTile(self.tiles.flask,     status.rebuffed, status.total, 0)
    setTile(self.tiles.food,      status.released, status.total, 0, true)
    setTile(self.tiles.soulstone, status.corpse,   status.total, 0, true)

    self.tiles.flask.caption:SetText("REBUFFED")
    self.tiles.food.caption:SetText("RELEASED")
    self.tiles.soulstone.caption:SetText("NOT RELEASED")

    local players = PPRC.Roster.players or {}
    local row = 0
    for i = 1, #players do
        local player = players[i]
        if player.dead and row < MAX_ROWS then
            row = row + 1
            local r = self.list:Row(row)
            r.left:SetText(W.ClassName(player.name, player.class))
            r.right:SetText("|cffc1544astill down|r")
            r._name = player.name
            r:Show()
        end
    end
    self.list:Hide(row + 1)
    self.listHeading:SetText(row > 0 and "STILL DOWN" or "|cff3fae6feveryone is up|r")

    self:RefreshChecklist()
end

function Readiness:ExitWipeMode()
    self.wipeMode = false
    self.tiles.flask.caption:SetText("FLASK / ELIXIR")
    self.tiles.food.caption:SetText("FOOD BUFF")
    self.tiles.soulstone.caption:SetText("SOULSTONES OUT")
    self:Refresh()
end

-- ---------------------------------------------------------------------------
-- Visibility
-- ---------------------------------------------------------------------------

function Readiness:Show()
    if not self.frame then return end
    PPRC.db.shown.readiness = true
    self.frame:Show()
    self:Refresh()
end

function Readiness:Hide()
    if not self.frame then return end
    self.frame:Hide()
    PPRC.db.shown.readiness = false
end

function Readiness:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self:Hide() else self:Show() end
end
