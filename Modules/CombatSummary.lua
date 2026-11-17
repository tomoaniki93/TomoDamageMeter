local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Combat Summary Overlay (compact)
-- Small in-combat summary without Lua-side inspection of secret values.
-- Shows the same two core values as the damage meter row: DPS/HPS and total.
----------------------------------------------------------------------

local originalBuildBarTooltip = ns.BuildBarTooltip
local overlay
local activeOwner
local activeMeterType
local refreshElapsed = 0

local function IsSecret(value)
    return value ~= nil and issecretvalue and issecretvalue(value)
end

local function MakeFont(parent, size, r, g, b, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont(ns.GetFont(), size, "OUTLINE")
    fs:SetTextColor(r, g, b)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function EnsureOverlay()
    if overlay then return overlay end

    local frame = CreateFrame("Frame", "TomoDMCombatSummaryOverlay", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("TOOLTIP")
    frame:SetSize(250, 78)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.03, 0.03, 0.04, 0.97)
    frame:SetBackdropBorderColor(0.67, 0.07, 0.13, 0.92)

    local topAccent = frame:CreateTexture(nil, "ARTWORK")
    topAccent:SetTexture("Interface\\Buttons\\WHITE8X8")
    topAccent:SetVertexColor(0.85, 0.09, 0.16, 0.95)
    topAccent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    topAccent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    topAccent:SetHeight(2)

    local bottomAccent = frame:CreateTexture(nil, "ARTWORK")
    bottomAccent:SetTexture("Interface\\Buttons\\WHITE8X8")
    bottomAccent:SetVertexColor(0.85, 0.09, 0.16, 0.95)
    bottomAccent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    bottomAccent:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    bottomAccent:SetHeight(2)

    frame.title = MakeFont(frame, 12, 1, 1, 1, "LEFT")
    frame.title:SetPoint("TOPLEFT", 12, -11)
    frame.title:SetPoint("TOPRIGHT", -12, -11)
    frame.title:SetHeight(16)

    frame.subtitle = MakeFont(frame, 9, 0.71, 0.72, 0.77, "LEFT")
    frame.subtitle:SetPoint("TOPLEFT", 12, -28)
    frame.subtitle:SetPoint("TOPRIGHT", -12, -28)
    frame.subtitle:SetHeight(12)
    frame.subtitle:SetText(ns.L["COMBAT_SUMMARY_TITLE"] or "Combat summary")

    frame.rateLabel = MakeFont(frame, 9, 0.77, 0.78, 0.83, "LEFT")
    frame.rateLabel:SetPoint("TOPLEFT", 12, -49)
    frame.rateLabel:SetWidth(36)

    frame.rateValue = MakeFont(frame, 14, 1, 1, 1, "LEFT")
    frame.rateValue:SetPoint("LEFT", frame.rateLabel, "RIGHT", 4, 0)
    frame.rateValue:SetPoint("RIGHT", frame, "RIGHT", -98, 0)
    frame.rateValue:SetHeight(16)

    frame.totalValue = MakeFont(frame, 13, 0.84, 0.85, 0.90, "RIGHT")
    frame.totalValue:SetPoint("TOPRIGHT", -12, -49)
    frame.totalValue:SetWidth(88)
    frame.totalValue:SetHeight(16)

    frame:Hide()
    overlay = frame
    return frame
end

local function DisplayNumeric(fontString, value)
    if value == nil then
        fontString:SetText("—")
    else
        fontString:SetFormattedText("%.0f", value)
    end
end

local function DisplayParenthesized(fontString, value)
    if value == nil then
        fontString:SetText("")
    else
        fontString:SetFormattedText("(%.0f)", value)
    end
end

local function RefreshSummary()
    if not activeOwner or not overlay then return end

    local ed = activeOwner._elementData
    if not ed or ed.kind == "spell" then
        overlay:Hide()
        activeOwner = nil
        return
    end

    overlay.title:SetText(ed.name ~= nil and ed.name or "?")
    local classColor = ed.classFilename and RAID_CLASS_COLORS[ed.classFilename]
    if classColor then
        overlay.title:SetTextColor(classColor.r, classColor.g, classColor.b)
    else
        overlay.title:SetTextColor(1, 1, 1)
    end

    local DMT = Enum and Enum.DamageMeterType
    local isActions = ns.ACTIONS_TYPES and ns.ACTIONS_TYPES[activeMeterType]
    local healing = DMT and (
        activeMeterType == DMT.HealingDone
        or activeMeterType == DMT.Hps
        or activeMeterType == DMT.Absorbs
    )

    if isActions then
        overlay.rateLabel:Hide()
        overlay.rateValue:Hide()
        overlay.totalValue:ClearAllPoints()
        overlay.totalValue:SetPoint("TOPLEFT", 12, -49)
        overlay.totalValue:SetPoint("TOPRIGHT", -12, -49)
        overlay.totalValue:SetJustifyH("LEFT")
        DisplayNumeric(overlay.totalValue, ed.totalAmount)
    else
        overlay.rateLabel:Show()
        overlay.rateValue:Show()
        overlay.rateLabel:SetText(ns.L[healing and "HPS" or "DPS"] or (healing and "HPS" or "DPS"))
        overlay.totalValue:ClearAllPoints()
        overlay.totalValue:SetPoint("TOPRIGHT", -12, -49)
        overlay.totalValue:SetWidth(88)
        overlay.totalValue:SetJustifyH("RIGHT")
        DisplayNumeric(overlay.rateValue, ed.amountPerSecond)
        DisplayParenthesized(overlay.totalValue, ed.totalAmount)
    end
end

function ns.HideCombatSummaryOverlay()
    activeOwner = nil
    refreshElapsed = 0
    if overlay then overlay:Hide() end
end

local function ShowSummary(owner, meterType, sessionType)
    local frame = EnsureOverlay()
    activeOwner = owner
    activeMeterType = meterType
    frame._sessionType = sessionType
    refreshElapsed = 0
    frame:ClearAllPoints()
    frame:SetPoint("LEFT", owner, "RIGHT", 10, 0)
    RefreshSummary()
    frame:Show()
end

local function InstallOnUpdate()
    local frame = EnsureOverlay()
    frame:SetScript("OnUpdate", function(self, elapsed)
        refreshElapsed = refreshElapsed + elapsed
        if refreshElapsed < 0.35 then return end
        refreshElapsed = 0
        if not activeOwner or not activeOwner:IsMouseOver() then
            ns.HideCombatSummaryOverlay()
            return
        end
        RefreshSummary()
    end)
end

InstallOnUpdate()

ns.BuildBarTooltip = function(owner, ed, meterType, sessionType)
    local inCombat = InCombatLockdown()
    local restricted = IsSecret(ed.name) or IsSecret(ed.totalAmount)
        or IsSecret(ed.amountPerSecond)

    if (inCombat or restricted) and ns.db and ns.db.showCombatSummaryOverlay ~= false then
        GameTooltip:Hide()
        ShowSummary(owner, meterType, sessionType)
        return
    end

    ns.HideCombatSummaryOverlay()
    if originalBuildBarTooltip then
        return originalBuildBarTooltip(owner, ed, meterType, sessionType)
    end
end
