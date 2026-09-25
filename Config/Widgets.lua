local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Reusable Settings Widget Factories
----------------------------------------------------------------------

ns.Widgets = {}

-- CreateSlider / CreateCheckbox live in Config/WidgetsV3.lua. The originals
-- that stood here were overwritten by it at load time and never ran.

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