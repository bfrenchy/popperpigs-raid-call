-- UI/MobPanel.lua
--
-- What is actually in the pack you are looking at, and what to do about it.
--
-- The HUD is 320px and carries one line of detail. That is right for NOW/NEXT,
-- but it cannot hold four mobs' worth of abilities, kick targets and dispel
-- flags -- and on a Hyjal wave that is exactly the information a raid leader
-- wants within reach.
--
-- So the wave step names the mobs it contains and this panel renders them from
-- Data/Mobs.lua. High priority mobs sort first and render in fel green, because
-- "what do I kill first" is the question being asked.
--
-- Built entirely on the existing UI/Widgets.lua factories. No new widget code.

local ADDON_NAME, PPRC = ...

local W        = PPRC.UI
local MobPanel = PPRC:NewModule("MobPanel")
PPRC.MobPanel  = MobPanel

local PAD      = 10
local WIDTH    = 340
local LINE_H   = 13
local MAX_LINES = 26

function MobPanel:OnEnable()
    self:Build()
    PPRC:Listen("STATE_CHANGED", function() if self.frame:IsShown() then self:Refresh() end end)
    if PPRC.db.shown.mobs then self:Show() end
end

function MobPanel:Build()
    local f = W.Panel({
        key = "mobs", title = "PACK", width = WIDTH, height = PAD * 2 + 22 + MAX_LINES * LINE_H,
        default = { point = "LEFT", x = 40, y = 0 },
    })
    self.frame = f

    -- One flat list of pre-made lines, reused on every refresh. A wave change
    -- should not churn frames mid-pull.
    self.lines = {}
    for i = 1, MAX_LINES do
        local line = W.Text(f, { color = "muted", font = "GameFontNormalSmall", width = WIDTH - PAD * 2 })
        line:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(24 + (i - 1) * LINE_H))
        self.lines[i] = line
    end
end

local function put(self, index, text, color)
    if index > MAX_LINES then return index end
    local line = self.lines[index]
    line:SetText(text or "")
    local c = PPRC.COLORS[color or "muted"]
    line:SetTextColor(c[1], c[2], c[3])
    return index + 1
end

function MobPanel:Refresh()
    if not self.frame then return end

    local step = PPRC.State:Current()
    local i = 1

    if not step or not step.mobs or #step.mobs == 0 then
        self.frame.title:SetText("PACK")
        i = put(self, i, step and "No mob breakdown for this step." or "No step loaded.", "muted2")
        for n = i, MAX_LINES do self.lines[n]:SetText("") end
        return
    end

    self.frame.title:SetText("PACK - " .. string.upper(step.label or ""))

    -- Composition first: it is the one line that answers "how bad is this".
    i = put(self, i, step.detail or "", "text")
    i = put(self, i, "", nil)

    -- High priority first. That ordering IS the kill order.
    local ordered = {}
    for _, id in ipairs(step.mobs) do
        local mob = PPRC.Mobs[id]
        if mob then ordered[#ordered + 1] = { id = id, mob = mob } end
    end
    table.sort(ordered, function(a, b)
        local ap = a.mob.priority == "high" and 0 or 1
        local bp = b.mob.priority == "high" and 0 or 1
        if ap ~= bp then return ap < bp end
        return a.id < b.id
    end)

    for _, entry in ipairs(ordered) do
        local mob = entry.mob
        local high = mob.priority == "high"

        i = put(self, i, (high and "! " or "  ") .. mob.name, high and "fel" or "text")

        for _, ability in ipairs(mob.abilities or {}) do
            local flags = ""
            if ability.kick then flags = flags .. " |cff5fb0c9[kick]|r" end
            if ability.dispel then flags = flags .. " |cff7c5cc4[dispel]|r" end
            i = put(self, i, "    " .. ability.name .. " - " .. ability.text .. flags, "muted2")
        end

        if mob.note then i = put(self, i, "    " .. mob.note, high and "gold" or "muted") end
        i = put(self, i, "", nil)
    end

    for n = i, MAX_LINES do self.lines[n]:SetText("") end
end

-- The instance-wide rules, printed rather than panelled: they are read once at
-- the start of a night, not glanced at mid-wave.
function MobPanel:PrintRules()
    local encounter = PPRC.State:Encounter()
    local side = encounter and encounter.side or nil
    local rules = side and PPRC.MobRules[side] or nil

    if not rules then
        PPRC:Print("no trash rules for this step - zone in or /pprc test a Hyjal encounter")
        return
    end

    PPRC:Print("|cff8fe04b%s trash rules|r", side == "horde" and "Horde base" or "Alliance base")
    for _, rule in ipairs(rules) do PPRC:Print("  " .. rule) end
end

function MobPanel:Show()
    if not self.frame then return end
    PPRC.db.shown.mobs = true
    self.frame:Show()
    self:Refresh()
end

function MobPanel:Hide()
    if not self.frame then return end
    self.frame:Hide()
    PPRC.db.shown.mobs = false
end

function MobPanel:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self:Hide() else self:Show() end
end
