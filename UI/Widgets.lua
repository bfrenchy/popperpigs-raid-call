-- UI/Widgets.lua
--
-- Shared frame furniture. Everything here is a plain CreateFrame("Frame") or
-- ("Button") with texture-drawn borders: no secure templates, no inherited
-- Blizzard frames, so none of this can taint and none of it can break in
-- combat. That matters more than usual on a client whose 2.5.6 patch rewrote
-- the raid frame and nameplate code.
--
-- No BackdropTemplate dependency either -- borders are four thin textures,
-- which works the same on every build.

local ADDON_NAME, PPRC = ...

local W = {}
PPRC.UI = W

local WHITE = "Interface\\Buttons\\WHITE8X8"

local function resolve(color)
    if type(color) == "string" then return PPRC.COLORS[color] or PPRC.COLORS.text end
    return color or PPRC.COLORS.text
end

-- SetColorTexture is the modern call; older builds want a white file plus a
-- vertex colour. Same probe-and-branch habit as Core/Adapter.lua.
function W.Paint(texture, color, alpha)
    local c = resolve(color)
    if texture.SetColorTexture then
        texture:SetColorTexture(c[1], c[2], c[3], alpha or 1)
    else
        texture:SetTexture(WHITE)
        texture:SetVertexColor(c[1], c[2], c[3], alpha or 1)
    end
    return texture
end

function W.Fill(parent, layer, color, alpha)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints(parent)
    return W.Paint(t, color, alpha)
end

-- Four 1px edges. Returns the table so a caller can recolour later (the sync
-- dot and the empty-slot warning both do).
function W.Border(frame, color, thickness)
    thickness = thickness or 1
    local edges = {}
    local sides = {
        top    = { "TOPLEFT", 0, 0, "TOPRIGHT", 0, 0 },
        bottom = { "BOTTOMLEFT", 0, 0, "BOTTOMRIGHT", 0, 0 },
        left   = { "TOPLEFT", 0, 0, "BOTTOMLEFT", 0, 0 },
        right  = { "TOPRIGHT", 0, 0, "BOTTOMRIGHT", 0, 0 },
    }
    for name, s in pairs(sides) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetPoint(s[1], frame, s[1], s[2], s[3])
        t:SetPoint(s[4], frame, s[4], s[5], s[6])
        if name == "top" or name == "bottom" then t:SetHeight(thickness) else t:SetWidth(thickness) end
        W.Paint(t, color)
        edges[name] = t
    end
    frame._border = edges
    return edges
end

function W.Recolor(frame, color)
    if not frame._border then return end
    for _, t in pairs(frame._border) do W.Paint(t, color) end
end

function W.Text(parent, opts)
    opts = opts or {}
    local fs = parent:CreateFontString(nil, opts.layer or "OVERLAY", opts.font or "GameFontNormal")
    local c = resolve(opts.color or "text")
    fs:SetTextColor(c[1], c[2], c[3], opts.alpha or 1)
    fs:SetJustifyH(opts.justify or "LEFT")
    if opts.text then fs:SetText(opts.text) end
    if opts.width then fs:SetWidth(opts.width); fs:SetWordWrap(true) end
    if opts.point then fs:SetPoint(opts.point, parent, opts.relPoint or opts.point, opts.x or 0, opts.y or 0) end
    return fs
end

function W.Divider(parent, opts)
    opts = opts or {}
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    W.Paint(t, opts.color or "line")
    if opts.point then
        t:SetPoint("LEFT", parent, "TOPLEFT", opts.x or 0, opts.y or 0)
        t:SetPoint("RIGHT", parent, "TOPRIGHT", -(opts.x or 0), opts.y or 0)
    end
    return t
end

-- ---------------------------------------------------------------------------
-- Buttons
-- ---------------------------------------------------------------------------

function W.Button(parent, opts)
    opts = opts or {}
    local b = CreateFrame("Button", opts.name, parent)
    b:SetSize(opts.width or 90, opts.height or 22)

    b._bg = W.Fill(b, "BACKGROUND", opts.fill or "panel2", 1)
    W.Border(b, opts.border or "feldim")

    b._label = W.Text(b, {
        text = opts.text, color = opts.color or "text",
        font = opts.font or "GameFontNormalSmall", justify = "CENTER",
    })
    b._label:SetPoint("CENTER", b, "CENTER", 0, 0)

    b._normalFill = opts.fill or "panel2"
    b._hoverFill  = opts.hoverFill or "feldim"

    b:SetScript("OnEnter", function(self)
        if self._disabled then return end
        W.Paint(self._bg, self._hoverFill, 1)
        if opts.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(opts.tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        W.Paint(self._bg, self._normalFill, 1)
        if opts.tooltip then GameTooltip:Hide() end
    end)
    b:SetScript("OnClick", function(self, ...)
        if self._disabled then return end
        if opts.onClick then opts.onClick(self, ...) end
    end)

    function b:SetLabel(text) self._label:SetText(text) end

    function b:SetDisabled(disabled)
        self._disabled = disabled and true or false
        local c = resolve(disabled and "muted2" or (opts.color or "text"))
        self._label:SetTextColor(c[1], c[2], c[3])
        W.Recolor(self, disabled and "line" or (opts.border or "feldim"))
    end

    return b
end

function W.Checkbox(parent, opts)
    opts = opts or {}
    local b = CreateFrame("Button", opts.name, parent)
    b:SetSize(opts.width or 200, 18)

    local box = CreateFrame("Frame", nil, b)
    box:SetSize(12, 12)
    box:SetPoint("LEFT", b, "LEFT", 0, 0)
    W.Fill(box, "BACKGROUND", "panel2")
    W.Border(box, "muted2")

    local tick = box:CreateTexture(nil, "OVERLAY")
    tick:SetPoint("TOPLEFT", box, "TOPLEFT", 2, -2)
    tick:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2, 2)
    W.Paint(tick, "fel")
    tick:Hide()

    local label = W.Text(b, { text = opts.text, color = "muted", font = "GameFontNormalSmall" })
    label:SetPoint("LEFT", box, "RIGHT", 8, 0)

    b._checked = false
    function b:SetChecked(v)
        self._checked = v and true or false
        if self._checked then tick:Show() else tick:Hide() end
    end
    function b:GetChecked() return self._checked end

    b:SetScript("OnClick", function(self)
        self:SetChecked(not self._checked)
        if opts.onToggle then opts.onToggle(self._checked) end
    end)

    return b
end

-- ---------------------------------------------------------------------------
-- Panels
-- ---------------------------------------------------------------------------

-- Every panel is movable and remembers where it was put. The plan makes this
-- a hard rule: the RL owns their screen, we do not.
function W.MakeMovable(frame, key)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        if PPRC.db and PPRC.db.locked then return end
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if not PPRC.db then return end
        local point, _, relPoint, x, y = self:GetPoint()
        if not point then return end
        PPRC.db.frames[key] = { point = point, relPoint = relPoint, x = x, y = y }
    end)
end

function W.RestorePosition(frame, key, default)
    local saved = PPRC.db and PPRC.db.frames[key]
    frame:ClearAllPoints()
    if saved and saved.point then
        frame:SetPoint(saved.point, UIParent, saved.relPoint or saved.point, saved.x or 0, saved.y or 0)
    else
        default = default or {}
        frame:SetPoint(default.point or "CENTER", UIParent, default.point or "CENTER",
            default.x or 0, default.y or 0)
    end
end

-- opts: key (persistence + db.shown), title, width, height, default point
function W.Panel(opts)
    opts = opts or {}
    local f = CreateFrame("Frame", "PPRC_" .. (opts.key or "Panel"), UIParent)
    f:SetSize(opts.width or 300, opts.height or 160)
    f:SetFrameStrata(opts.strata or "MEDIUM")

    W.Fill(f, "BACKGROUND", "panel", opts.alpha or 0.94)
    W.Border(f, opts.border or "fel")

    -- Title bar
    local bar = CreateFrame("Frame", nil, f)
    bar:SetHeight(22)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    W.Fill(bar, "BACKGROUND", "feldim", 1)

    f.title = W.Text(bar, { text = opts.title or "", color = "fel", font = "GameFontNormalSmall" })
    f.title:SetPoint("LEFT", bar, "LEFT", 8, 0)

    f.titleBar = bar
    f.body = f

    W.MakeMovable(f, opts.key or "panel")
    W.RestorePosition(f, opts.key or "panel", opts.default)

    f:Hide()
    return f
end

-- ---------------------------------------------------------------------------
-- Class colours
--
-- Read from the client's own table so a class colour addon or a future patch
-- stays consistent with what the player already sees.
-- ---------------------------------------------------------------------------

local FALLBACK_CLASS_COLORS = {
    WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 },
    HUNTER  = { 0.67, 0.83, 0.45 }, ROGUE   = { 1.00, 0.96, 0.41 },
    PRIEST  = { 1.00, 1.00, 1.00 }, SHAMAN  = { 0.00, 0.44, 0.87 },
    MAGE    = { 0.41, 0.80, 0.94 }, WARLOCK = { 0.58, 0.51, 0.79 },
    DRUID   = { 1.00, 0.49, 0.04 },
}

function W.ClassColor(class)
    if not class then return PPRC.COLORS.text end
    local blizzard = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class]
    if blizzard then return { blizzard.r, blizzard.g, blizzard.b } end
    return FALLBACK_CLASS_COLORS[class] or PPRC.COLORS.text
end

function W.ClassHex(class)
    local c = W.ClassColor(class)
    return string.format("%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

function W.ClassName(name, class)
    return "|cff" .. W.ClassHex(class) .. tostring(name) .. "|r"
end

-- ---------------------------------------------------------------------------
-- Simple row list
--
-- Rows are created once and reused, so a 25-player refresh does not churn
-- frames every time someone's flask ticks over.
-- ---------------------------------------------------------------------------

function W.RowList(parent, opts)
    opts = opts or {}
    local list = { rows = {}, parent = parent, rowHeight = opts.rowHeight or 18 }

    function list:Row(i)
        local row = self.rows[i]
        if row then return row end

        row = CreateFrame("Button", nil, self.parent)
        row:SetHeight(self.rowHeight)
        row:SetPoint("LEFT", self.parent, "LEFT", opts.x or 0, 0)
        row:SetPoint("RIGHT", self.parent, "RIGHT", -(opts.x or 0), 0)
        row:SetPoint("TOP", self.parent, "TOP", 0, -((i - 1) * self.rowHeight) + (opts.y or 0))

        row.left  = W.Text(row, { color = "text", font = "GameFontNormalSmall" })
        row.left:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.right = W.Text(row, { color = "muted", font = "GameFontNormalSmall", justify = "RIGHT" })
        row.right:SetPoint("RIGHT", row, "RIGHT", 0, 0)

        self.rows[i] = row
        return row
    end

    function list:Hide(from)
        for i = from, #self.rows do self.rows[i]:Hide() end
    end

    return list
end
