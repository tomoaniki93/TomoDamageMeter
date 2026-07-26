local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Reusable Settings Widget Factories
----------------------------------------------------------------------

ns.Widgets = {}

-- Slider widget
function ns.Widgets.CreateSlider(parent, label, min, max, step, getter, setter)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(50)

    local title = frame:CreateFontString(nil, "ARTWORK")
    title:SetFont(ns.GetFont(), 11, "OUTLINE")
    title:SetTextColor(0.75, 0.75, 0.78)
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(label)

    local valueText = frame:CreateFontString(nil, "ARTWORK")
    valueText:SetFont(ns.GetFont(), 11, "OUTLINE")
    valueText:SetTextColor(1.00, 1.00, 1.00)
    valueText:SetPoint("TOPRIGHT", 0, 0)

    local slider = CreateFrame("Slider", nil, frame, "MinimalSliderTemplate")
    slider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    slider:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    slider:SetHeight(16)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(getter())

    local fmtStr = step < 1 and "%.2f" or "%.0f"
    valueText:SetText(string.format(fmtStr, getter()))

    slider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val / step + 0.5) * step
        valueText:SetText(string.format(step < 1 and "%.2f" or "%.0f", val))
        setter(val)
    end)

    frame.slider = slider
    frame.Refresh = function()
        slider:SetValue(getter())
        valueText:SetText(string.format(step < 1 and "%.2f" or "%.0f", getter()))
    end

    return frame
end

-- Checkbox widget
function ns.Widgets.CreateCheckbox(parent, label, getter, setter)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(24)

    local btn = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    btn:SetSize(24, 24)
    btn:SetPoint("LEFT", 0, 0)

    local title = frame:CreateFontString(nil, "ARTWORK")
    title:SetFont(ns.GetFont(), 11, "OUTLINE")
    title:SetTextColor(0.75, 0.75, 0.78)
    title:SetPoint("LEFT", btn, "RIGHT", 4, 0)
    title:SetText(label)

    btn:SetChecked(getter())
    btn:SetScript("OnClick", function(self)
        setter(self:GetChecked())
    end)

    frame.Refresh = function()
        btn:SetChecked(getter())
    end

    return frame
end

-- Dropdown button (simple text cycling)
-- `options` accepts either a static array of { value, label [, fontPath] } or a
-- function returning one. Passing a function keeps the list live: option sets
-- that change after the panel is built (LibSharedMedia textures registered by
-- addons loading later, meter types gated by category toggles) no longer need a
-- panel rebuild to show up.
function ns.Widgets.CreateDropdown(parent, label, options, getter, setter)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(30)

    local function GetOptions()
        if type(options) == "function" then return options() or {} end
        return options
    end

    local title = frame:CreateFontString(nil, "ARTWORK")
    title:SetFont(ns.GetFont(), 11, "OUTLINE")
    title:SetTextColor(0.75, 0.75, 0.78)
    title:SetPoint("LEFT", 0, 0)
    title:SetText(label)

    local btn = CreateFrame("Button", nil, frame)
    btn:SetSize(120, 22)
    btn:SetPoint("RIGHT", frame, "RIGHT", 0, 0)

    local btnBG = btn:CreateTexture(nil, "BACKGROUND")
    btnBG:SetTexture(ns.FLAT)
    btnBG:SetVertexColor(0.05, 0.12, 0.26, 0.92)
    btnBG:SetAllPoints()

    local btnText = btn:CreateFontString(nil, "ARTWORK")
    btnText:SetFont(ns.GetFont(), 10, "OUTLINE")
    btnText:SetTextColor(1.00, 1.00, 1.00)
    btnText:SetPoint("CENTER")

    local function UpdateText()
        local current = getter()
        for _, opt in ipairs(GetOptions()) do
            if opt.value == current then
                btnText:SetText(opt.label)
                -- Apply font preview if option has a fontPath
                if opt.fontPath then
                    btnText:SetFont(opt.fontPath, 10, "OUTLINE")
                end
                return
            end
        end
        btnText:SetText(tostring(current))
    end
    UpdateText()

    btn:SetScript("OnClick", function()
        local opts = GetOptions()
        if #opts == 0 then return end
        local current = getter()
        local idx = 1
        for i, opt in ipairs(opts) do
            if opt.value == current then idx = i; break end
        end
        local nextIdx = (idx % #opts) + 1
        setter(opts[nextIdx].value)
        UpdateText()
    end)

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(ns.FLAT); hl:SetVertexColor(1, 1, 1, 0.08)
    hl:SetAllPoints()

    frame.Refresh = UpdateText
    return frame
end