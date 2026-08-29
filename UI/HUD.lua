-- UI/HUD.lua
--
-- NOW / NEXT.
--
-- The NEXT panel is the point of the whole addon: it lets the raid leader call
-- a mechanic BEFORE it lands instead of reacting after it does. Everything
-- rendered here comes from Data/ -- no string in this file describes a fight.
--
-- Three states, per the plan:
--   RL / assist  full controls, drives the raid
--   raider       compact read-only strip, plus your own assignment
--   solo / test  local echo, no comms
--
-- Deliberately anchored right of centre by default: the plan reserves the
-- top-middle band for DBM and BigWigs, and drawing there is the fastest way to
-- get uninstalled.

local ADDON_NAME, PPRC = ...

local W   = PPRC.UI
local HUD = PPRC:NewModule("HUD")
PPRC.HUD  = HUD

local PAD = 10

function HUD:OnEnable()
    self:Build()

    PPRC:Listen("STATE_CHANGED",    function() self:Refresh() end)
    PPRC:Listen("INSTANCE_CHANGED", function() self:Refresh() end)
    PPRC:Listen("SYNC_CHANGED",     function() self:Refresh() end)
    PPRC:Listen("ASSIGNMENTS_CHANGED", function() self:Refresh() end)

    -- Rank can change mid-night (someone hands over lead), and that flips the
    -- HUD between controller and raider layout.
    PPRC:On("GROUP_ROSTER_UPDATE", function() self:Refresh() end)
    PPRC:On("PARTY_LEADER_CHANGED", function() self:Refresh() end)
    PPRC:On("PLAYER_ENTERING_WORLD", function() self:Refresh() end)

    if PPRC.db.shown.hud then self:Show() end
    self:Refresh()
end

function HUD:Build()
    local f = W.Panel({
        key = "hud", title = "PPRC", width = 320, height = 180,
        default = { point = "RIGHT", x = -40, y = 80 },
    })
    self.frame = f

    -- Sync dot: gold when you are driving, green when following an RL in sync,
    -- red when nobody is broadcasting.
    local dot = f.titleBar:CreateTexture(nil, "OVERLAY")
    dot:SetSize(8, 8)
    dot:SetPoint("RIGHT", f.titleBar, "RIGHT", -8, 0)
    W.Paint(dot, "muted2")
    self.dot = dot

    -- NOW ------------------------------------------------------------------
    self.nowLabel = W.Text(f, { text = "NOW", color = "muted2", font = "GameFontNormalSmall" })
    self.nowLabel:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -30)

    self.nowTitle = W.Text(f, { color = "text", font = "GameFontNormalLarge", width = 320 - PAD * 2 })
    self.nowTitle:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -46)

    self.nowDetail = W.Text(f, { color = "muted", font = "GameFontNormalSmall", width = 320 - PAD * 2 })
    self.nowDetail:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -68)

    -- Steps whose data has not been confirmed against a live client say so
    -- here, not just in /pprc debug. A raid leader reading a wave composition
    -- off the HUD mid-pull deserves to know whether it is a confirmed fact or
    -- our best guess, and the honest answer is currently "guess" for most of
    -- Data/. Sits on the title bar so it costs no body space.
    self.unverifiedTag = W.Text(f.titleBar, { color = "gold", font = "GameFontNormalSmall", justify = "RIGHT" })
    self.unverifiedTag:SetPoint("RIGHT", f.titleBar, "RIGHT", -20, 0)

    -- The literal words to say, in the plan's gold. Read aloud verbatim.
    self.nowCall = W.Text(f, { color = "gold", font = "GameFontNormalSmall", width = 320 - PAD * 2 })
    self.nowCall:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -84)

    self.divider = W.Divider(f, { point = true, x = PAD, y = -112 })

    -- NEXT -----------------------------------------------------------------
    self.nextLabel = W.Text(f, { text = "NEXT", color = "muted2", font = "GameFontNormalSmall" })
    self.nextLabel:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -118)

    self.nextTitle = W.Text(f, { color = "muted", font = "GameFontNormal", width = 320 - PAD * 2 })
    self.nextTitle:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -134)

    -- Raider-only line: your own assignment, and nothing about anyone else's.
    self.youLine = W.Text(f, { color = "ice", font = "GameFontNormalSmall", width = 320 - PAD * 2 })
    self.youLine:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -156)

    -- Controls -------------------------------------------------------------
    local row = CreateFrame("Frame", nil, f)
    row:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD)
    row:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)
    row:SetHeight(22)
    self.controls = row

    self.advanceBtn = W.Button(row, {
        text = "ADVANCE", width = 116, fill = "feldim", color = "fel",
        tooltip = "Advance to the next step. Also bound to /pprc next.",
        onClick = function() PPRC.State:Advance("local") end,
    })
    self.advanceBtn:SetPoint("LEFT", row, "LEFT", 0, 0)

    self.backBtn = W.Button(row, {
        text = "BACK", width = 52,
        tooltip = "Step back. Use after a wipe or a re-clear.",
        onClick = function() PPRC.State:Back("local") end,
    })
    self.backBtn:SetPoint("LEFT", self.advanceBtn, "RIGHT", 4, 0)

    self.briefBtn = W.Button(row, {
        text = "BRIEF", width = 52,
        tooltip = "Open the pre-pull briefing for this step.",
        onClick = function() if PPRC.Briefing then PPRC.Briefing:Toggle() end end,
    })
    self.briefBtn:SetPoint("LEFT", self.backBtn, "RIGHT", 4, 0)

    self.readyBtn = W.Button(row, {
        text = "READY?", width = 62,
        tooltip = "Open the readiness board.",
        onClick = function() if PPRC.Readiness then PPRC.Readiness:Toggle() end end,
    })
    self.readyBtn:SetPoint("LEFT", self.briefBtn, "RIGHT", 4, 0)
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

local function headerFor(state)
    local encounter = state:Encounter()
    if not encounter then return "PPRC" end
    local instance = PPRC.Instances[encounter.instanceID]
    local instanceName = instance and instance.name or ""
    -- Short form: the title bar is 320px, not a paragraph.
    instanceName = instanceName:gsub("^The Battle for ", ""):gsub("^The ", "")
    return string.format("PPRC - %s: %s", instanceName:upper(), encounter.name:upper())
end

function HUD:Refresh()
    if not self.frame then return end

    local State = PPRC.State
    local controller = State:IsController()
    local step, index = State:Current()
    local nextStep = State:Next()

    self.frame.title:SetText(headerFor(State))

    -- Sync dot ---------------------------------------------------------------
    if State.testMode then
        W.Paint(self.dot, "gold")
    elseif not PPRC.Adapter:InGroup() then
        W.Paint(self.dot, "muted2")
    elseif controller then
        W.Paint(self.dot, "gold")
    elseif PPRC.Comm and PPRC.Comm:HasController() then
        W.Paint(self.dot, "green")
    else
        W.Paint(self.dot, "danger")
    end

    -- Body -------------------------------------------------------------------
    -- verified == false means the composition or ids on this step were
    -- authored rather than read off a live client. nil means the step never
    -- made a factual claim worth flagging.
    self.unverifiedTag:SetText((step and step.verified == false) and "unverified" or "")

    if not step then
        self.nowTitle:SetText("No encounter loaded")
        self.nowDetail:SetText(PPRC.Adapter:InGroup() and "Zone into Hyjal or Black Temple."
            or "Try /pprc test hyjal_winterchill")
        self.nowCall:SetText("")
        self.nextTitle:SetText("")
        self.youLine:SetText("")
    else
        self.nowTitle:SetText(step.label or step.id or "")
        self.nowDetail:SetText(step.detail or "")
        self.nowCall:SetText(step.call and ('"' .. step.call .. '"') or "")

        if nextStep then
            local detail = nextStep.detail and (" - " .. nextStep.detail) or ""
            self.nextTitle:SetText((nextStep.label or nextStep.id or "") .. detail)
        else
            self.nextTitle:SetText("|cff6c7c6e- last step -|r")
        end

        local mine = PPRC.Roster and PPRC.Roster:MyAssignment(step)
        self.youLine:SetText(mine and ("YOU: " .. mine) or "")
    end

    -- Controls ---------------------------------------------------------------
    if controller then
        self.controls:Show()
        local total = State:StepCount()
        if step and total > 0 then
            self.advanceBtn:SetLabel(string.format("ADVANCE (%d/%d)", index, total))
        else
            self.advanceBtn:SetLabel("ADVANCE")
        end
        self.advanceBtn:SetDisabled(not step or index >= total)
        self.backBtn:SetDisabled(not step or index <= 1)
        self.briefBtn:SetDisabled(not (step and step.brief) and not (step and step.posmap))
        self.frame:SetHeight(180)
    else
        -- Raider: read-only strip. No buttons, because there is nothing here
        -- they are allowed to drive.
        self.controls:Hide()
        self.frame:SetHeight(150)
    end
end

-- ---------------------------------------------------------------------------
-- Visibility
-- ---------------------------------------------------------------------------

function HUD:Show()
    if not self.frame then return end
    self.frame:Show()
    PPRC.db.shown.hud = true
    self:Refresh()
end

function HUD:Hide()
    if not self.frame then return end
    self.frame:Hide()
    PPRC.db.shown.hud = false
end

function HUD:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self:Hide() else self:Show() end
end
