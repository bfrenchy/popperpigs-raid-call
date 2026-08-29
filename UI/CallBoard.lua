-- UI/CallBoard.lua
--
-- One click, one sentence, out to the raid.
--
-- Two sections. The top row is what THIS step needs, pulled from the step's
-- own `warn` list in Data/. The grid below is the standing set -- the handful
-- of things a raid leader says on every fight.
--
-- Nothing here counts down to anything. That is DBM's job and the plan is
-- explicit about not touching it.
--
-- Every send goes through Core/RateLimit.lua. Nothing in this file calls
-- SendChatMessage.

local ADDON_NAME, PPRC = ...

local W         = PPRC.UI
local CallBoard = PPRC:NewModule("CallBoard")
PPRC.CallBoard  = CallBoard

local PAD          = 10
local BTN_W        = 102
local BTN_H        = 20
local GAP          = 4
local COLS         = 3
local STEP_ROWS    = 2
local CONFIRM_TIME = 3

function CallBoard:OnEnable()
    self:Build()

    PPRC:Listen("STATE_CHANGED", function() self:Refresh() end)
    PPRC:On("GROUP_ROSTER_UPDATE", function() self:Refresh() end)
    PPRC:On("PARTY_LEADER_CHANGED", function() self:Refresh() end)

    if PPRC.db.shown.callboard then self:Show() end
    self:Refresh()
end

-- Grid position for the i-th button in a section.
local function place(button, parent, i, topOffset)
    local col = (i - 1) % COLS
    local row = math.floor((i - 1) / COLS)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT",
        PAD + col * (BTN_W + GAP),
        -(topOffset + row * (BTN_H + GAP)))
end

function CallBoard:Build()
    local width = PAD * 2 + COLS * BTN_W + (COLS - 1) * GAP
    local standingRows = math.ceil(#PPRC.StandingCalls / COLS)
    local height = 30                                    -- title + step heading
        + STEP_ROWS * (BTN_H + GAP)                      -- step-specific row(s)
        + 18                                             -- divider + heading
        + standingRows * (BTN_H + GAP)
        + PAD

    local f = W.Panel({
        key = "callboard", title = "CALL BOARD", width = width, height = height,
        default = { point = "BOTTOMRIGHT", x = -40, y = 220 },
    })
    self.frame = f

    self.stepHeading = W.Text(f, { text = "THIS STEP", color = "muted2", font = "GameFontNormalSmall" })
    self.stepHeading:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -26)

    -- Step buttons are pooled: a wave change should not churn frames.
    self.stepButtons = {}
    for i = 1, STEP_ROWS * COLS do
        local button = W.Button(f, {
            width = BTN_W, height = BTN_H, text = "",
            onClick = function(btn) self:Send(btn._callText, btn._callText) end,
        })
        place(button, f, i, 40)
        button:Hide()
        self.stepButtons[i] = button
    end

    local dividerY = -(40 + STEP_ROWS * (BTN_H + GAP) + 2)
    W.Divider(f, { point = true, x = PAD, y = dividerY })

    self.standingHeading = W.Text(f, { text = "ALWAYS", color = "muted2", font = "GameFontNormalSmall" })
    self.standingHeading:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, dividerY - 6)

    self.standingButtons = {}
    local standingTop = -dividerY + 18
    for i, call in ipairs(PPRC.StandingCalls) do
        local button = W.Button(f, {
            width = BTN_W, height = BTN_H, text = call.label,
            color  = call.danger and "danger" or "text",
            border = call.danger and "danger" or "feldim",
            fill   = call.danger and "panel2" or "panel2",
            onClick = function(btn) self:StandingClick(btn, call) end,
        })
        place(button, f, i, standingTop)
        button._call = call
        self.standingButtons[i] = button
    end
end

-- ---------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------

function CallBoard:Send(text, key)
    if not text or text == "" then return end
    PPRC.RateLimit:SendCall(text, key)
end

-- A misclicked wipe call ends the attempt for 24 other people, so the ones
-- flagged `confirm` want a second click. The button says so rather than
-- silently doing nothing.
function CallBoard:StandingClick(button, call)
    if not call.confirm then
        self:Send(call.text, call.id)
        return
    end

    if button._armed then
        button._armed = false
        button:SetLabel(call.label)
        self:Send(call.text, call.id)
        return
    end

    button._armed = true
    button:SetLabel("CONFIRM?")
    PPRC:After(CONFIRM_TIME, function()
        if button._armed then
            button._armed = false
            button:SetLabel(call.label)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

function CallBoard:Refresh()
    if not self.frame then return end

    -- Losing assist mid-night has to take the board away, not leave dead
    -- buttons on screen. Visibility is re-derived on every refresh; only the
    -- user's own show/hide choice is stored.
    if self:ShouldShow() then self.frame:Show() else self.frame:Hide() end

    local channel = PPRC.RateLimit:ChatChannel()

    -- Title states what will actually happen when a button is pressed. An RL
    -- who lost assist should find that out from the board, not from silence.
    if channel == "ECHO" then
        self.frame.title:SetText("CALL BOARD - LOCAL ECHO")
    elseif channel == "RAID_WARNING" then
        self.frame.title:SetText("CALL BOARD - RAID WARNING")
    else
        self.frame.title:SetText("CALL BOARD - /RAID (no assist)")
    end

    local step = PPRC.State:Current()
    local warns = step and step.warn or nil

    for i, button in ipairs(self.stepButtons) do
        local text = warns and warns[i]
        if text then
            button._callText = text
            button:SetLabel(text)
            button:Show()
        else
            button._callText = nil
            button:Hide()
        end
    end

    if warns and #warns > 0 then
        self.stepHeading:SetText("THIS STEP - " .. (step.label or ""))
    else
        self.stepHeading:SetText("|cff6c7c6eno step-specific calls|r")
    end
end

-- ---------------------------------------------------------------------------
-- Visibility
--
-- Hidden entirely for someone who cannot broadcast: a board of buttons that
-- would only ever talk to /raid is clutter, not a feature. Local echo mode
-- overrides that, because the whole point of echo is trying the flow out.
-- ---------------------------------------------------------------------------

function CallBoard:ShouldShow()
    if not PPRC.db.shown.callboard then return false end
    if PPRC.db.localEcho then return true end
    if PPRC.State.testMode then return true end
    if not PPRC.Adapter:InGroup() then return true end
    return PPRC.Adapter:CanBroadcast()
end

function CallBoard:Show()
    if not self.frame then return end
    PPRC.db.shown.callboard = true
    self:Refresh()
    if not self.frame:IsShown() then
        PPRC:Print("call board stays hidden: you need lead or assist, or turn on /pprc echo")
    end
end

function CallBoard:Hide()
    if not self.frame then return end
    self.frame:Hide()
    PPRC.db.shown.callboard = false
end

function CallBoard:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self:Hide() else self:Show() end
end
