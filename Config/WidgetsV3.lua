local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Settings Widgets V3 / 2.7.3
--
-- Visual replacement for the stock-looking checkbox and slider factories.
-- ConfigUIV2 is loaded after this file, so every checkbox/slider it creates
-- automatically receives the TDM Red treatment without touching page logic.
----------------------------------------------------------------------

if not ns.Widgets then return end

local RED       = { 0.88, 0.08, 0.18 }
local RED_HOVER = { 1.00, 0.13, 0.24 }
local SURFACE   = { 0.045, 0.045, 0.055, 0.98 }
local BORDER    = { 0.22, 0.22, 0.25, 0.92 }
local TEXT      = { 0.78, 0.78, 0.82 }
local WHITE     = { 1.00, 1.00, 1.00 }
local TRACK     = { 0.11, 0.11, 0.13, 0.95 }

local function SetBackdrop(frame, bg, border)
    frame:SetBackdrop({
        bgFile = ns.FLAT,
        edgeFile = ns.FLAT,
        edgeSize = 1,
    })
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

local function SetFont(fs, size, color)
    fs:SetFont(ns.GetFont(), size, "OUTLINE")
    color = color or TEXT
    fs:SetTextColor(color[1], color[2], color[3])
    return fs
end

----------------------------------------------------------------------
-- Modern checkbox
----------------------------------------------------------------------

function ns.Widgets.CreateCheckbox(parent, label, getter, setter)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(24)

    -- Full-row hit target: the label is clickable too.
    local btn = CreateFrame("CheckButton", nil, frame)
    btn:SetAllPoints()
    btn:RegisterForClicks("LeftButtonUp")

    local box = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    box:SetSize(18, 18)
    box:SetPoint("LEFT", 0, 0)
    SetBackdrop(box, SURFACE, BORDER)

    local inner = box:CreateTexture(nil, "BACKGROUND", nil, 1)
    inner:SetTexture(ns.FLAT)
    inner:SetPoint("TOPLEFT", 2, -2)
    inner:SetPoint("BOTTOMRIGHT", -2, 2)
    inner:SetVertexColor(RED[1], RED[2], RED[3], 0.14)

    local check = box:CreateTexture(nil, "ARTWORK", nil, 2)
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetSize(21, 21)
    check:SetPoint("CENTER", 0, 0)
    check:SetVertexColor(1, 1, 1, 1)
    check:Hide()

    local title = SetFont(btn:CreateFontString(nil, "ARTWORK"), 11, TEXT)
    title:SetPoint("LEFT", box, "RIGHT", 8, 0)
    title:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText(label)

    local function Paint(checked, hover)
        checked = checked and true or false
        check:SetShown(checked)
        if checked then
            box:SetBackdropColor(RED[1] * 0.34, RED[2] * 0.34, RED[3] * 0.34, 0.98)
            box:SetBackdropBorderColor(RED[1], RED[2], RED[3], 1)
            inner:SetVertexColor(RED[1], RED[2], RED[3], 0.62)
            title:SetTextColor(WHITE[1], WHITE[2], WHITE[3])
        elseif hover then
            box:SetBackdropColor(0.075, 0.045, 0.052, 0.98)
            box:SetBackdropBorderColor(RED_HOVER[1], RED_HOVER[2], RED_HOVER[3], 0.82)
            inner:SetVertexColor(RED[1], RED[2], RED[3], 0.22)
            title:SetTextColor(0.92, 0.92, 0.94)
        else
            SetBackdrop(box, SURFACE, BORDER)
            inner:SetVertexColor(RED[1], RED[2], RED[3], 0.14)
            title:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
        end
    end

    btn:SetChecked(getter() and true or false)
    Paint(btn:GetChecked(), false)

    btn:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        setter(checked)
        Paint(checked, true)
    end)
    btn:SetScript("OnEnter", function(self)
        Paint(self:GetChecked(), true)
    end)
    btn:SetScript("OnLeave", function(self)
        Paint(self:GetChecked(), false)
    end)

    frame.Refresh = function()
        local checked = getter() and true or false
        btn:SetChecked(checked)
        Paint(checked, false)
    end

    frame.button = btn
    frame.box = box
    return frame
end

----------------------------------------------------------------------
-- Modern slider
----------------------------------------------------------------------

function ns.Widgets.CreateSlider(parent, label, minValue, maxValue, step, getter, setter)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(50)

    local valueBox = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    valueBox:SetSize(50, 19)
    valueBox:SetPoint("TOPRIGHT", 0, 1)
    SetBackdrop(valueBox, { 0.055, 0.055, 0.067, 0.98 }, BORDER)

    local title = SetFont(frame:CreateFontString(nil, "ARTWORK"), 11, TEXT)
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetPoint("RIGHT", valueBox, "LEFT", -8, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText(label)

    local valueText = SetFont(valueBox:CreateFontString(nil, "ARTWORK"), 10, WHITE)
    valueText:SetPoint("CENTER", 0, 0)

    local slider = CreateFrame("Slider", nil, frame)
    slider:SetOrientation("HORIZONTAL")
    slider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    slider:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(ns.FLAT)
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetHeight(4)
    track:SetVertexColor(TRACK[1], TRACK[2], TRACK[3], TRACK[4])

    local fill = slider:CreateTexture(nil, "BORDER")
    fill:SetTexture(ns.FLAT)
    fill:SetPoint("LEFT", slider, "LEFT", 0, 0)
    fill:SetHeight(4)
    fill:SetVertexColor(RED[1], RED[2], RED[3], 0.92)

    slider:SetThumbTexture(ns.FLAT)
    local thumb = slider:GetThumbTexture()
    thumb:SetSize(10, 14)
    thumb:SetVertexColor(RED[1], RED[2], RED[3], 1)

    local glow = slider:CreateTexture(nil, "ARTWORK")
    glow:SetTexture(ns.FLAT)
    glow:SetSize(14, 18)
    glow:SetPoint("CENTER", thumb, "CENTER", 0, 0)
    glow:SetVertexColor(RED[1], RED[2], RED[3], 0.10)

    local fmtStr = step < 1 and "%.2f" or "%.0f"
    local initializing = false

    local function Normalize(value)
        value = tonumber(value) or minValue
        value = math.max(minValue, math.min(maxValue, value))
        return math.floor(value / step + 0.5) * step
    end

    local function UpdateVisual(value)
        value = Normalize(value)
        valueText:SetText(string.format(fmtStr, value))
        local range = math.max(0.000001, maxValue - minValue)
        local ratio = (value - minValue) / range
        local width = math.max(1, (slider:GetWidth() or 1) * ratio)
        fill:SetWidth(width)
        fill:SetShown(ratio > 0.001)
    end

    local function SetCurrent(value)
        initializing = true
        slider:SetValue(Normalize(value))
        initializing = false
        UpdateVisual(value)
    end

    slider:SetScript("OnValueChanged", function(_, value)
        value = Normalize(value)
        UpdateVisual(value)
        if initializing then return end
        setter(value)
    end)
    slider:SetScript("OnEnter", function()
        track:SetVertexColor(0.18, 0.18, 0.21, 1)
        thumb:SetVertexColor(RED_HOVER[1], RED_HOVER[2], RED_HOVER[3], 1)
        valueBox:SetBackdropBorderColor(RED[1], RED[2], RED[3], 0.84)
    end)
    slider:SetScript("OnLeave", function()
        track:SetVertexColor(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
        thumb:SetVertexColor(RED[1], RED[2], RED[3], 1)
        valueBox:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], BORDER[4])
    end)
    slider:HookScript("OnSizeChanged", function()
        UpdateVisual(slider:GetValue())
    end)

    SetCurrent(getter())

    frame.Refresh = function()
        SetCurrent(getter())
    end

    frame.slider = slider
    frame.valueText = valueText
    return frame
end
