-- UI/Options.lua
--
-- A plain settings panel, registered into the game's own interface options.
-- No AceConfig -- it is one screen of checkboxes and it does not justify a
-- config library, let alone one that cannot be fetched here.
--
-- Also holds the profile export string, so a raid leader can hand their
-- assignments and settings to someone else instead of everyone rebuilding the
-- same corner layout from scratch every week.

local ADDON_NAME, PPRC = ...

local W       = PPRC.UI
local Options = PPRC:NewModule("Options")
PPRC.Options  = Options

local EXPORT_PREFIX = "PPRC1:"

-- ---------------------------------------------------------------------------
-- Export / import
--
-- Reuses Core/Codec.lua rather than inventing a second text format. Only flat
-- values and the assignment map travel: frame positions are personal, and
-- pushing someone else's screen layout onto them would be rude.
-- ---------------------------------------------------------------------------

function Options:Export()
    local db = PPRC.db
    local payload = {
        v         = PPRC.version,
        localEcho = db.localEcho and true or false,
        locked    = db.locked and true or false,
        hudScale  = db.hudScale or 1,
    }

    -- Assignments are slot -> name, already flat.
    for slot, name in pairs(db.assignments or {}) do
        payload["a_" .. slot] = tostring(name)
    end
    for key, value in pairs(db.checklist or {}) do
        if value then payload["c_" .. key] = true end
    end

    return EXPORT_PREFIX .. PPRC.Codec.Encode(payload)
end

function Options:Import(text)
    if type(text) ~= "string" then return false, "nothing to import" end

    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
        return false, "that does not look like a Popperpig Raid Call profile string"
    end

    local payload = PPRC.Codec.Decode(text:sub(#EXPORT_PREFIX + 1))
    if not payload or not next(payload) then return false, "could not read that string" end

    local db = PPRC.db
    if payload.localEcho ~= nil then db.localEcho = payload.localEcho end
    if payload.locked ~= nil then db.locked = payload.locked end
    if type(payload.hudScale) == "number" then db.hudScale = payload.hudScale end

    local assignments, checklist = {}, {}
    local assigned = 0
    for key, value in pairs(payload) do
        local slot = key:match("^a_(.+)$")
        if slot then assignments[slot] = value; assigned = assigned + 1 end
        local check = key:match("^c_(.+)$")
        if check then checklist[check] = true end
    end

    db.assignments = assignments
    db.checklist   = checklist

    PPRC:Fire("ASSIGNMENTS_CHANGED", assignments, "import")
    self:Refresh()

    return true, string.format("imported %d assignment%s", assigned, assigned == 1 and "" or "s")
end

-- ---------------------------------------------------------------------------
-- Panel
-- ---------------------------------------------------------------------------

function Options:OnEnable()
    self:Build()
    self:Register()
end

function Options:Build()
    local f = W.Panel({
        key = "options", title = "POPPERPIG RAID CALL - SETTINGS",
        width = 460, height = 340,
        default = { point = "CENTER", x = 0, y = 0 },
    })
    self.frame = f

    self.versionText = W.Text(f, { color = "muted2", font = "GameFontNormalSmall" })
    self.versionText:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -32)
    self.versionText:SetText("version " .. PPRC.version)

    local y = -54
    local function checkbox(label, get, set, tooltip)
        local box = W.Checkbox(f, {
            text = label, width = 420,
            onToggle = function(checked) set(checked); PPRC:Fire("OPTIONS_CHANGED") end,
        })
        box:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
        box:SetChecked(get())
        box._get = get
        y = y - 24
        return box
    end

    self.boxes = {}

    self.boxes.localEcho = checkbox("Local echo - calls print to your chat frame only",
        function() return PPRC.db.localEcho end,
        function(v)
            PPRC.db.localEcho = v
            if PPRC.CallBoard then PPRC.CallBoard:Refresh() end
        end)

    self.boxes.locked = checkbox("Lock frames in place",
        function() return PPRC.db.locked end,
        function(v) PPRC.db.locked = v end)

    self.boxes.debug = checkbox("Debug logging",
        function() return PPRC.debugEnabled end,
        function(v) PPRC.debugEnabled = v; PPRC.db.debug = v end)

    self.boxes.hud = checkbox("Show the HUD",
        function() return PPRC.db.shown.hud end,
        function(v) if PPRC.HUD then if v then PPRC.HUD:Show() else PPRC.HUD:Hide() end end end)

    self.boxes.callboard = checkbox("Show the call board",
        function() return PPRC.db.shown.callboard end,
        function(v) if PPRC.CallBoard then if v then PPRC.CallBoard:Show() else PPRC.CallBoard:Hide() end end end)

    -- --- profile string ----------------------------------------------------
    self.exportHeading = W.Text(f, { color = "gold", font = "GameFontNormalSmall",
        text = "PROFILE STRING - assignments and settings, not your frame positions" })
    self.exportHeading:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y - 10)

    local box = CreateFrame("EditBox", nil, f)
    box:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y - 28)
    box:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    box:SetHeight(40)
    box:SetAutoFocus(false)
    box:SetMultiLine(true)
    box:SetMaxLetters(0)
    box:SetFontObject("GameFontHighlightSmall")
    W.Fill(box, "BACKGROUND", "panel2")
    W.Border(box, "line")
    box:SetScript("OnEscapePressed", function(self_) self_:ClearFocus() end)
    self.editBox = box

    self.exportBtn = W.Button(f, {
        text = "EXPORT", width = 90, fill = "feldim", color = "fel",
        tooltip = "Put your profile string in the box, ready to copy.",
        onClick = function()
            self.editBox:SetText(self:Export())
            self.editBox:HighlightText()
            self.editBox:SetFocus()
            PPRC:Print("profile string ready - copy it out of the box")
        end,
    })
    self.exportBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 14)

    self.importBtn = W.Button(f, {
        text = "IMPORT", width = 90,
        tooltip = "Paste a profile string into the box first, then click this.",
        onClick = function()
            local ok, message = self:Import(self.editBox:GetText())
            PPRC:Print(ok and ("|cff3fae6f" .. message .. "|r") or ("|cffc1544a" .. message .. "|r"))
        end,
    })
    self.importBtn:SetPoint("LEFT", self.exportBtn, "RIGHT", 6, 0)

    self.resetBtn = W.Button(f, {
        text = "RESET FRAMES", width = 110,
        onClick = function()
            PPRC.db.frames = {}
            PPRC:Print("frame positions reset - /reload to apply")
        end,
    })
    self.resetBtn:SetPoint("LEFT", self.importBtn, "RIGHT", 6, 0)

    self.closeBtn = W.Button(f, {
        text = "CLOSE", width = 70,
        onClick = function() self:Hide() end,
    })
    self.closeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)
end

-- Also hang it off the game's own options list, so someone looking for it in
-- the obvious place finds it there.
function Options:Register()
    if type(_G.InterfaceOptions_AddCategory) ~= "function" then return end

    local panel = CreateFrame("Frame", "PPRC_BlizzOptions")
    panel.name = "Popperpig Raid Call"

    local title = W.Text(panel, { text = "Popperpig Raid Call", color = "fel", font = "GameFontNormalLarge" })
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)

    local hint = W.Text(panel, { color = "muted", font = "GameFontNormalSmall", width = 500,
        text = "Settings live in the addon's own panel, so they can be reached mid-raid without opening this menu.\n\nType /pprc config, or /pprc help for everything else." })
    hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -48)

    local open = W.Button(panel, {
        text = "OPEN SETTINGS", width = 130, fill = "feldim", color = "fel",
        onClick = function() Options:Show() end,
    })
    open:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -110)

    pcall(_G.InterfaceOptions_AddCategory, panel)
    self.blizzPanel = panel
end

function Options:Refresh()
    if not self.frame then return end
    for _, box in pairs(self.boxes or {}) do
        if box._get then box:SetChecked(box._get()) end
    end
end

function Options:Show()
    if not self.frame then return end
    self.frame:Show()
    self:Refresh()
end

function Options:Hide()
    if not self.frame then return end
    self.frame:Hide()
end

function Options:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self:Hide() else self:Show() end
end
