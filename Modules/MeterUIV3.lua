local ADDON_NAME, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Meter UI V3 / Patch 12A
--
-- Structural replacement for the main meter window. The validated legacy
-- DamageMeter.lua stays untouched and loaded; this module is loaded afterwards
-- and replaces ns.CreateMeterWindow before ADDON_LOADED creates any windows.
--
-- Data remains C_DamageMeter-only. No CLEU, no permanent OnUpdate, no polling
-- ticker is introduced here. Core/Database.lua remains the owner of refresh
-- cadence and secret-value-safe event timing.
----------------------------------------------------------------------

local TEX_ROOT = "Interface\\AddOns\\TomoDamageMeter\\Assets\\Textures\\"
local TEX_LOGO = TEX_ROOT .. "TDM_Icon_64"
local TEX_HEADER = TEX_ROOT .. "TDM_HeaderSheen_256x32"
local TEX_ROW = TEX_ROOT .. "TDM_RowSheen_256x32"
local TEX_GLOW = TEX_ROOT .. "TDM_FrameGlow_128"

local MIN_WIDTH = 300
local MIN_HEIGHT = 150
local HEADER_H = 48
local HEADER_PAD = 7
local BUTTON_SIZE = 20
local BUTTON_GAP = 1
local RANK_W = 27
local ICON_GAP = 4
local ROW_PAD_Y = 2
local SPELL_INDENT = 18

local windowCounter = 0

local function Safe(v)
    return v ~= nil and not issecretvalue(v)
end

local function Clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function SurfaceColor(alpha)
    local h = ns.HEADER_BG or { 0.055, 0.055, 0.065, 1 }
    return h[1], h[2], h[3], alpha or h[4] or 1
end

local function AccentColor(alpha)
    local a = ns.ACCENT or { 0.96, 0.035, 0.085, 1 }
    return a[1] or 0.96, a[2] or 0.035, a[3] or 0.085, alpha or a[4] or 1
end

local function TextColor(role)
    local map = {
        primary = ns.TEXT_PRIMARY,
        secondary = ns.TEXT_SECONDARY,
        muted = ns.TEXT_MUTED,
        label = ns.TEXT_LABEL,
    }
    local c = map[role] or ns.TEXT_PRIMARY or { 1, 1, 1 }
    return c[1] or 1, c[2] or 1, c[3] or 1
end

local function MakeFont(parent, size, role, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.GetFont(), size, "OUTLINE")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.55)
    local r, g, b = TextColor(role)
    fs:SetTextColor(r, g, b)
    return fs
end

local function SetFontRole(fs, role)
    if not fs then return end
    local r, g, b = TextColor(role)
    fs:SetTextColor(r, g, b)
end

local function SetBackdrop(frame, r, g, b, a, br, bg, bb, ba)
    frame:SetBackdrop({
        bgFile = ns.FLAT,
        edgeFile = ns.FLAT,
        edgeSize = 1,
    })
    frame:SetBackdropColor(r, g, b, a)
    frame:SetBackdropBorderColor(br, bg, bb, ba)
end

local function RowHeight()
    return math.max(22, (ns.GetBarHeight and ns.GetBarHeight() or 21) + 5)
end

local function SpellRowHeight()
    return math.max(18, RowHeight() - 5)
end

local function ShowTip(owner, text)
    if not text then return end
    GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
    GameTooltip:SetText(text, 1, 1, 1)
    GameTooltip:Show()
end

local function HideTip()
    GameTooltip:Hide()
end

local function ApplyRankStyle(button, rank)
    if not button.rankFS or not button.rankBG then return end
    button.rankFS:SetText(rank and tostring(rank) or "")
    button.rankBG:SetShown(rank ~= nil)
    button.rankFS:SetShown(rank ~= nil)
    if not rank then return end

    if rank == 1 then
        button.rankBG:SetVertexColor(0.78, 0.025, 0.055, 0.96)
        button.rankFS:SetTextColor(1, 1, 1)
    elseif rank == 2 then
        button.rankBG:SetVertexColor(0.42, 0.43, 0.47, 0.90)
        button.rankFS:SetTextColor(1, 1, 1)
    elseif rank == 3 then
        button.rankBG:SetVertexColor(0.43, 0.22, 0.10, 0.92)
        button.rankFS:SetTextColor(1.00, 0.80, 0.62)
    else
        button.rankBG:SetVertexColor(0.07, 0.07, 0.085, 0.94)
        local r, g, b = TextColor("secondary")
        button.rankFS:SetTextColor(r, g, b)
    end
end

function ns.CreateMeterWindow(cfg)
    windowCounter = windowCounter + 1

    local state = {
        cfg = cfg,
        meterType = cfg.meterType,
        sessionType = cfg.sessionType,
        dataGeneration = 0,
        elements = {},
        expandedGUID = nil,
    }

    local initialWidth = math.max(MIN_WIDTH, tonumber(cfg.width) or MIN_WIDTH)
    local initialHeight = math.max(MIN_HEIGHT, tonumber(cfg.height) or 250)

    ------------------------------------------------------------------
    -- Main frame
    ------------------------------------------------------------------
    local window = CreateFrame("Frame", "TomoDamageMeterFrame" .. windowCounter, UIParent, "BackdropTemplate")
    window:SetSize(initialWidth, initialHeight)
    window:SetPoint(cfg.point or "CENTER", UIParent, cfg.relPoint or "CENTER", cfg.x or 0, cfg.y or 0)
    window:SetMovable(true)
    window:SetResizable(true)
    window:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, 720, 620)
    window:SetClampedToScreen(true)
    window:SetFrameStrata("MEDIUM")
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window._tdmMeterUIV3 = true

    local bgAlpha = ns.db and ns.db.bgAlpha or (ns.BG and ns.BG[4]) or 0.90
    local br, bg, bb = unpack(ns.BORDER_COLOR or { 0.28, 0.28, 0.31 })
    SetBackdrop(window, ns.BG[1], ns.BG[2], ns.BG[3], bgAlpha, br, bg, bb, 0.92)

    local glow = window:CreateTexture(nil, "BACKGROUND", nil, -8)
    glow:SetTexture(TEX_GLOW)
    glow:SetPoint("TOPLEFT", window, "TOPLEFT", -7, 7)
    glow:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 7, -7)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.22)

    local topAccent = window:CreateTexture(nil, "OVERLAY", nil, 7)
    topAccent:SetTexture(ns.FLAT)
    topAccent:SetHeight(2)
    topAccent:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    topAccent:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)

    local hotCap = window:CreateTexture(nil, "OVERLAY", nil, 8)
    hotCap:SetTexture(ns.FLAT)
    hotCap:SetSize(54, 1)
    hotCap:SetPoint("TOPLEFT", window, "TOPLEFT", 8, -1)
    hotCap:SetVertexColor(1, 1, 1, 0.62)

    local watermark = window:CreateTexture(nil, "BACKGROUND", nil, -5)
    watermark:SetTexture(TEX_LOGO)
    watermark:SetSize(70, 70)
    watermark:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 10, 9)
    watermark:SetAlpha(0.025)

    ------------------------------------------------------------------
    -- Drag / snap / clamp
    ------------------------------------------------------------------
    local function SavePosition()
        if cfg.snap then
            cfg.meterType = state.meterType
            cfg.sessionType = state.sessionType
            cfg.width = window:GetWidth()
            cfg.height = window:GetHeight()
            return
        end
        local left = window:GetLeft()
        local top = window:GetTop()
        if left and top then
            cfg.point = "TOPLEFT"
            cfg.relPoint = "BOTTOMLEFT"
            cfg.x = left
            cfg.y = top
        end
        cfg.width = window:GetWidth()
        cfg.height = window:GetHeight()
        cfg.meterType = state.meterType
        cfg.sessionType = state.sessionType
    end

    window:SetScript("OnDragStart", function(self)
        if cfg.locked then return end
        if ns.SnapDetachFrame then ns.SnapDetachFrame(self) end
        self:StartMoving()
    end)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if ns.SnapTryFrame and ns.SnapTryFrame(self) then return end
        SavePosition()
    end)

    C_Timer.After(0, function()
        local left = window:GetLeft()
        local top = window:GetTop()
        if not left or not top then return end
        local w, h = window:GetWidth(), window:GetHeight()
        local sw, sh = GetScreenWidth(), GetScreenHeight()
        left = math.max(0, math.min(left, sw - w))
        top = math.max(h, math.min(top, sh))
        window:ClearAllPoints()
        window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end)

    ------------------------------------------------------------------
    -- Header: real product-style composition
    ------------------------------------------------------------------
    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT", window, "TOPLEFT", 1, -2)
    header:SetPoint("TOPRIGHT", window, "TOPRIGHT", -1, -2)
    header:SetHeight(HEADER_H - 2)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() window:GetScript("OnDragStart")(window) end)
    header:SetScript("OnDragStop", function() window:GetScript("OnDragStop")(window) end)

    local headerBG = header:CreateTexture(nil, "BACKGROUND")
    headerBG:SetTexture(ns.FLAT)
    headerBG:SetAllPoints()
    local hr, hg, hb, ha = SurfaceColor(0.98)
    headerBG:SetVertexColor(hr, hg, hb, ha)

    local headerSheen = header:CreateTexture(nil, "ARTWORK", nil, 0)
    headerSheen:SetTexture(TEX_HEADER)
    headerSheen:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    headerSheen:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
    headerSheen:SetHeight(HEADER_H - 2)
    headerSheen:SetBlendMode("ADD")
    headerSheen:SetAlpha(0.30)

    local headerSep = window:CreateTexture(nil, "OVERLAY")
    headerSep:SetTexture(ns.FLAT)
    headerSep:SetHeight(1)
    headerSep:SetPoint("TOPLEFT", window, "TOPLEFT", 1, -HEADER_H)
    headerSep:SetPoint("TOPRIGHT", window, "TOPRIGHT", -1, -HEADER_H)

    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(TEX_LOGO)
    logo:SetSize(30, 30)
    logo:SetPoint("LEFT", header, "LEFT", HEADER_PAD, 0)

    local catBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
    catBtn:SetSize(50, 14)
    catBtn:SetPoint("TOPLEFT", logo, "TOPRIGHT", 5, -5)
    catBtn:RegisterForClicks("LeftButtonUp")
    SetBackdrop(catBtn, 0.10, 0.015, 0.025, 0.88, 0.35, 0.04, 0.07, 0.65)

    local catText = MakeFont(catBtn, 8, "secondary", "CENTER")
    catText:SetPoint("CENTER", 0, 0)

    local typeBtn = CreateFrame("Button", nil, header)
    typeBtn:SetPoint("TOPLEFT", catBtn, "BOTTOMLEFT", 0, -1)
    typeBtn:SetHeight(21)
    typeBtn:SetWidth(105)
    typeBtn:RegisterForClicks("LeftButtonUp")

    local typeText = MakeFont(typeBtn, 12, "primary", "LEFT")
    typeText:SetPoint("LEFT", 0, 0)
    typeText:SetPoint("RIGHT", typeBtn, "RIGHT", 0, 0)

    local sessionBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
    sessionBtn:SetSize(70, 16)
    sessionBtn:SetPoint("LEFT", catBtn, "RIGHT", 4, 0)
    sessionBtn:RegisterForClicks("LeftButtonUp")
    SetBackdrop(sessionBtn, 0.025, 0.025, 0.03, 0.82, 0.20, 0.20, 0.23, 0.70)

    local sessionText = MakeFont(sessionBtn, 7, "secondary", "CENTER")
    sessionText:SetPoint("CENTER", 0, 0)

    local timerFS = MakeFont(header, 9, "secondary", "RIGHT")
    timerFS:SetPoint("LEFT", sessionBtn, "RIGHT", 5, 0)
    timerFS:SetWidth(42)

    local actionButtons = {}
    local function MakeHeaderAction(texPath, tooltip)
        local btn = CreateFrame("Button", nil, header, "BackdropTemplate")
        btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        SetBackdrop(btn, 0.025, 0.025, 0.032, 0.90, 0.18, 0.18, 0.21, 0.82)
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(texPath)
        icon:SetSize(11, 11)
        icon:SetPoint("CENTER")
        local mr, mg, mb = TextColor("muted")
        icon:SetVertexColor(mr, mg, mb)
        btn._icon = icon
        btn._tooltip = tooltip
        btn:SetScript("OnEnter", function(self)
            local ar, ag, ab = AccentColor(1)
            self:SetBackdropColor(ar * 0.16, ag * 0.16, ab * 0.16, 0.98)
            self:SetBackdropBorderColor(ar, ag, ab, 0.88)
            self._icon:SetVertexColor(1, 1, 1)
            ShowTip(self, self._tooltip)
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.025, 0.025, 0.032, 0.90)
            self:SetBackdropBorderColor(0.18, 0.18, 0.21, 0.82)
            local r, g, b = TextColor("muted")
            self._icon:SetVertexColor(r, g, b)
            HideTip()
        end)
        actionButtons[#actionButtons + 1] = btn
        return btn
    end

    local resetBtn = MakeHeaderAction(ns.TEX_RESET, L["TIP_RESET"])
    local reportBtn = MakeHeaderAction(ns.TEX_REPORT, L["TIP_REPORT"])
    local lockBtn = MakeHeaderAction(ns.TEX_LOCK, L["TIP_LOCK"])
    local detailsBtn = MakeHeaderAction(ns.TEX_DETAILS, L["TIP_DETAILS"])
    local targetBtn = MakeHeaderAction(ns.TEX_TARGET, L["TIP_TARGET"])
    local gearBtn = MakeHeaderAction(ns.TEX_GEAR, L["TIP_SETTINGS"])

    local ordered = { resetBtn, reportBtn, lockBtn, detailsBtn, targetBtn, gearBtn }
    for i, btn in ipairs(ordered) do
        if i == 1 then
            btn:SetPoint("RIGHT", header, "RIGHT", -HEADER_PAD, 0)
        else
            btn:SetPoint("RIGHT", ordered[i - 1], "LEFT", -BUTTON_GAP, 0)
        end
    end

    local function UpdateLockIcon()
        if cfg.locked then
            lockBtn._icon:SetTexture(ns.TEX_LOCK)
            local ar, ag, ab = AccentColor(1)
            lockBtn._icon:SetVertexColor(ar, ag, ab)
        else
            lockBtn._icon:SetTexture(ns.TEX_LOCK_OPEN)
            local r, g, b = TextColor("muted")
            lockBtn._icon:SetVertexColor(r, g, b)
        end
    end

    resetBtn:SetScript("OnClick", function()
        C_DamageMeter.ResetAllCombatSessions()
    end)
    reportBtn:SetScript("OnClick", function()
        local snap = ns.SnapshotReportData(state.meterType, state.sessionType, state.elements)
        if not snap then
            print((L["ADDON_PREFIX"] or "TDM: ") .. (L["REPORT_NO_DATA"] or "No data."))
            return
        end
        ns.SendReport(snap, ns.db.reportChannel or "AUTO", ns.db.reportLines or 5)
    end)
    lockBtn:SetScript("OnClick", function()
        cfg.locked = not cfg.locked
        UpdateLockIcon()
    end)
    detailsBtn:SetScript("OnClick", function()
        if ns.ShowSpellBreakdown then
            ns.ShowSpellBreakdown(nil, nil, state.meterType, state.sessionType, nil)
        end
    end)
    targetBtn:SetScript("OnClick", function()
        if ns.ShowTargetBreakdown then ns.ShowTargetBreakdown(state.sessionType) end
    end)
    gearBtn:SetScript("OnClick", function()
        if InCombatLockdown() then
            print((L["ADDON_PREFIX"] or "TDM: ") .. (L["COMBAT_SETTINGS_UNAVAILABLE"] or "Settings unavailable in combat."))
            return
        end
        if ns.ToggleSettings then ns.ToggleSettings() end
    end)
    UpdateLockIcon()

    ------------------------------------------------------------------
    -- Body / scroll area
    ------------------------------------------------------------------
    local body = CreateFrame("Frame", nil, window)
    body:SetPoint("TOPLEFT", window, "TOPLEFT", 5, -(HEADER_H + 5))
    body:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -5, 5)

    local scrollBox = CreateFrame("Frame", nil, body, "WowScrollBoxList")
    local scrollBR = CreateFrame("Frame", nil, body)
    scrollBR:SetSize(1, 1)
    scrollBR:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -8, 0)

    local scrollBar = CreateFrame("EventFrame", nil, body, "MinimalScrollBar")
    scrollBar:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, 0)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollBR, "BOTTOMRIGHT", 0, 0)
    scrollBar:SetWidth(6)

    if scrollBar.Back then scrollBar.Back:SetAlpha(0) end
    if scrollBar.Forward then scrollBar.Forward:SetAlpha(0) end
    if scrollBar.Track then
        for _, key in ipairs({ "Begin", "Middle", "End" }) do
            local tex = scrollBar.Track[key]
            if tex then tex:SetAlpha(0) end
        end
        local thumb = scrollBar.Track.Thumb
        if thumb then
            for _, key in ipairs({ "Begin", "Middle", "End" }) do
                local tex = thumb[key]
                if tex then tex:SetAlpha(0) end
            end
            local thumbBG = thumb:CreateTexture(nil, "ARTWORK")
            thumbBG:SetTexture(ns.FLAT)
            thumbBG:SetPoint("TOPLEFT", 1, -1)
            thumbBG:SetPoint("BOTTOMRIGHT", -1, 1)
            thumb._tdmBG = thumbBG
        end
    end

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(RowHeight())
    view:SetElementExtentCalculator(function(_, elementData)
        if elementData and elementData.kind == "spell" then return SpellRowHeight() end
        return RowHeight()
    end)
    view:SetPadding(0, 0, 0, 0, 2)

    local dataProvider = CreateDataProvider()

    ------------------------------------------------------------------
    -- Rows
    ------------------------------------------------------------------
    local function MakeValueFS(parent)
        local fs = MakeFont(parent, ns.GetFontSize(), "primary", "RIGHT")
        return fs
    end

    local function BuildRow(button)
        button:SetHeight(RowHeight())
        button:EnableMouse(true)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local card = button:CreateTexture(nil, "BACKGROUND")
        card:SetTexture(ns.FLAT)
        card:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -ROW_PAD_Y)
        card:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, ROW_PAD_Y)
        card:SetVertexColor(0.025, 0.025, 0.032, 0.94)
        button.card = card

        local rankBG = button:CreateTexture(nil, "BORDER")
        rankBG:SetTexture(ns.FLAT)
        rankBG:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
        rankBG:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0)
        rankBG:SetWidth(RANK_W)
        button.rankBG = rankBG

        local rankFS = MakeFont(button, math.max(9, ns.GetFontSize() - 1), "secondary", "CENTER")
        rankFS:SetPoint("CENTER", rankBG, "CENTER", 0, 0)
        rankFS:SetWidth(RANK_W)
        button.rankFS = rankFS

        local iconBG = button:CreateTexture(nil, "BORDER")
        iconBG:SetTexture(ns.FLAT)
        iconBG:SetVertexColor(0.08, 0.08, 0.095, 0.96)
        iconBG:SetPoint("LEFT", rankBG, "RIGHT", 3, 0)
        button.iconBG = iconBG

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetPoint("CENTER", iconBG, "CENTER")
        button.icon = icon

        local bar = CreateFrame("StatusBar", nil, button)
        bar:SetStatusBarTexture(ns.GetBarTexture())
        bar:SetPoint("TOPLEFT", iconBG, "TOPRIGHT", ICON_GAP, 0)
        bar:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0)
        button.bar = bar
        button.fill = bar:GetStatusBarTexture()

        local track = bar:CreateTexture(nil, "BACKGROUND")
        track:SetTexture(ns.FLAT)
        track:SetAllPoints()
        track:SetVertexColor(0.04, 0.04, 0.05, 0.92)
        button.track = track

        local sheen = bar:CreateTexture(nil, "ARTWORK", nil, 0)
        sheen:SetTexture(TEX_ROW)
        sheen:SetAllPoints(bar)
        sheen:SetBlendMode("ADD")
        sheen:SetAlpha(0.055)
        button.rowSheen = sheen

        local expanded = button:CreateTexture(nil, "OVERLAY")
        expanded:SetTexture(ns.FLAT)
        expanded:SetWidth(2)
        expanded:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
        expanded:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0)
        expanded:Hide()
        button.groupAccent = expanded

        local nameFS = MakeFont(bar, ns.GetFontSize(), "primary", "LEFT")
        nameFS:SetPoint("LEFT", bar, "LEFT", 7, ns.GetFontNudge())
        button.nameFS = nameFS

        button.rateFS = MakeValueFS(bar)
        button.totalFS = MakeValueFS(bar)
        button.pctFS = MakeValueFS(bar)

        local selfTag = MakeFont(bar, 7, "muted", "CENTER")
        selfTag:SetText("YOU")
        selfTag:SetSize(22, 10)
        selfTag:Hide()
        button.selfTag = selfTag

        local hover = button:CreateTexture(nil, "HIGHLIGHT")
        hover:SetTexture(ns.FLAT)
        hover:SetAllPoints(card)
        hover:SetVertexColor(1, 1, 1, 0.065)

        button:SetScript("OnEnter", function(self)
            if self.fill then self.fill:SetAlpha(math.min(1, (ns.BAR_ALPHA or 0.5) + 0.28)) end
            if self.icon then self.icon:SetAlpha(1) end
            if not (ns.db and ns.db.showBarTooltips) then return end
            local ed = self._elementData
            if not ed then return end
            if ed.kind == "spell" then
                if not ed.isEmpty and ns.BuildSpellTooltip then ns.BuildSpellTooltip(self, ed) end
            elseif ns.BuildBarTooltip then
                ns.BuildBarTooltip(self, ed, state.meterType, state.sessionType)
            end
        end)
        button:SetScript("OnLeave", function(self)
            if self.fill then self.fill:SetAlpha(ns.BAR_ALPHA or 0.5) end
            if self.icon then self.icon:SetAlpha(ns.ICON_ALPHA or 0.7) end
            HideTip()
        end)

        button:SetScript("OnClick", function(self, mouseButton)
            local ed = self._elementData
            if not ed or ed.kind == "spell" then return end

            if state.meterType == Enum.DamageMeterType.Deaths then
                local rid = ed.deathRecapID
                if Safe(rid) and rid > 0 and ns.ShowDeathRecap then
                    local pname = ed.name
                    if Safe(pname) and ns.db.stripRealm then pname = ns.StripRealm(pname) end
                    ns.ShowDeathRecap(rid, Safe(pname) and pname or "?", Safe(ed.classFilename) and ed.classFilename or nil)
                end
                return
            end

            if not Safe(ed.sourceGUID) then return end
            if mouseButton == "RightButton" then
                local playerName = Safe(ed.name) and ed.name or "?"
                if Safe(playerName) and ns.db.stripRealm then playerName = ns.StripRealm(playerName) end
                if ns.ShowSpellBreakdown then
                    ns.ShowSpellBreakdown(playerName, ed.sourceGUID, state.meterType, state.sessionType,
                        Safe(ed.classFilename) and ed.classFilename or nil)
                end
                return
            end

            if state.expandedGUID == ed.sourceGUID then
                state.expandedGUID = nil
            else
                state.expandedGUID = ed.sourceGUID
            end
            state.CollectData()
        end)
    end

    local function LayoutRow(button, isSpell)
        local h = isSpell and SpellRowHeight() or RowHeight()
        button:SetHeight(h)
        local visualH = math.max(14, h - ROW_PAD_Y * 2)
        local iconSize = math.max(12, visualH - 4)

        if isSpell then
            button.rankBG:Hide()
            button.rankFS:Hide()
            button.iconBG:ClearAllPoints()
            button.iconBG:SetPoint("LEFT", button, "LEFT", SPELL_INDENT, 0)
        else
            button.rankBG:Show()
            button.rankFS:Show()
            button.iconBG:ClearAllPoints()
            button.iconBG:SetPoint("LEFT", button.rankBG, "RIGHT", 3, 0)
        end
        button.iconBG:SetSize(iconSize + 4, iconSize + 4)
        button.icon:SetSize(iconSize, iconSize)

        button.bar:ClearAllPoints()
        button.bar:SetPoint("TOPLEFT", button.iconBG, "TOPRIGHT", ICON_GAP, 0)
        button.bar:SetPoint("BOTTOMRIGHT", button.card, "BOTTOMRIGHT", 0, 0)
    end

    local function UpdateSpellRow(button, data)
        LayoutRow(button, true)
        button._elementData = data
        button.groupAccent:Show()
        local ar, ag, ab = AccentColor(0.9)
        button.groupAccent:SetVertexColor(ar, ag, ab, 0.85)
        button.selfTag:Hide()

        if data.isEmpty then
            button.iconBG:Hide()
            button.icon:Hide()
            button.bar:ClearAllPoints()
            button.bar:SetPoint("TOPLEFT", button, "TOPLEFT", SPELL_INDENT, -ROW_PAD_Y)
            button.bar:SetPoint("BOTTOMRIGHT", button.card, "BOTTOMRIGHT", 0, 0)
            button.bar:SetMinMaxValues(0, 1)
            button.bar:SetValue(0)
            if button.fill then button.fill:SetAlpha(0) end
            button.nameFS:ClearAllPoints()
            button.nameFS:SetPoint("LEFT", button.bar, "LEFT", 7, 0)
            button.nameFS:SetPoint("RIGHT", button.bar, "RIGHT", -7, 0)
            button.nameFS:SetText(data.name or "")
            SetFontRole(button.nameFS, "muted")
            button.rateFS:Hide()
            button.totalFS:Hide()
            button.pctFS:Hide()
            if button.actionFS then button.actionFS:Hide() end
            return
        end

        button.iconBG:Show()
        button.icon:Show()
        button.icon:SetTexture(data.icon or 134400)
        button.icon:SetAlpha(0.86)
        button.rankBG:Hide()
        button.rankFS:Hide()

        local classFile = Safe(data.classFilename) and data.classFilename or nil
        local r, g, b = ns.ClassColor(classFile)
        button.bar:SetStatusBarTexture(ns.GetBarTexture())
        button.fill = button.bar:GetStatusBarTexture()
        button.bar:SetStatusBarColor(r, g, b, 1)
        button.fill:SetGradient("HORIZONTAL",
            CreateColor(r * 0.40, g * 0.40, b * 0.40, 1),
            CreateColor(r * 0.12, g * 0.12, b * 0.12, 1))
        button.fill:SetAlpha(math.max(0.24, (ns.BAR_ALPHA or 0.5) * 0.68))
        button.rowSheen:SetAlpha(0.025)

        local maxAmount = data.maxAmount or 1
        if Safe(maxAmount) and maxAmount <= 0 then maxAmount = 1 end
        button.bar:SetMinMaxValues(0, maxAmount)
        button.bar:SetValue(data.totalAmount or 0)

        button.nameFS:SetText(data.displayName or data.name or "?")
        SetFontRole(button.nameFS, "primary")
        ns.PopulateColumnValues(button, data)
        SetFontRole(button.rateFS, "primary")
        SetFontRole(button.totalFS, "secondary")
        SetFontRole(button.pctFS, "muted")
        local prev = ns.AnchorColumns(button)
        button.nameFS:ClearAllPoints()
        button.nameFS:SetPoint("LEFT", button.bar, "LEFT", 7, ns.GetFontNudge())
        if prev then
            button.nameFS:SetPoint("RIGHT", prev, "LEFT", -6, 0)
        else
            button.nameFS:SetPoint("RIGHT", button.bar, "RIGHT", -7, 0)
        end
    end

    local function UpdatePlayerRow(button, ed)
        LayoutRow(button, false)
        button._elementData = ed
        ApplyRankStyle(button, ed.rank)
        button.rowSheen:SetAlpha(0.055)
        button.iconBG:Show()

        local classFile = Safe(ed.classFilename) and ed.classFilename or nil
        local r, g, b = ns.ClassColor(classFile)
        button.bar:SetStatusBarTexture(ns.GetBarTexture())
        button.fill = button.bar:GetStatusBarTexture()
        button.bar:SetStatusBarColor(r, g, b, 1)
        button.fill:SetGradient("HORIZONTAL",
            CreateColor(Clamp01(r * 0.78), Clamp01(g * 0.78), Clamp01(b * 0.78), 1),
            CreateColor(Clamp01(r * 0.24), Clamp01(g * 0.24), Clamp01(b * 0.24), 1))
        button.fill:SetAlpha(ns.BAR_ALPHA or 0.5)

        local maxAmount = ed.maxAmount or 1
        if Safe(maxAmount) and maxAmount <= 0 then maxAmount = 1 end
        button.bar:SetMinMaxValues(0, maxAmount)
        button.bar:SetValue(ed.totalAmount or 0)

        if Safe(ed.specIconID) and ed.specIconID > 0 then
            button.icon:SetTexture(ed.specIconID)
            button.icon:Show()
        else
            button.icon:SetTexture(134400)
            button.icon:Show()
        end
        button.icon:SetAlpha(ns.ICON_ALPHA or 0.7)

        local name = ed.name
        if Safe(name) then
            if ns.db.stripRealm then name = ns.StripRealm(name) end
            button.nameFS:SetText(name or "")
        else
            button.nameFS:SetText(name or "")
        end
        SetFontRole(button.nameFS, "primary")

        ns.PopulateColumnValues(button, ed)
        SetFontRole(button.rateFS, "primary")
        SetFontRole(button.totalFS, "secondary")
        SetFontRole(button.pctFS, "muted")

        local expanded = Safe(ed.sourceGUID) and state.expandedGUID and ed.sourceGUID == state.expandedGUID
        button.groupAccent:SetShown(expanded and true or false)
        local ar, ag, ab = AccentColor(1)
        button.groupAccent:SetVertexColor(ar, ag, ab, 0.95)

        local isSelf = Safe(ed.isLocalPlayer) and ed.isLocalPlayer or false
        button.selfTag:SetShown(isSelf and true or false)
        if isSelf then
            button.selfTag:ClearAllPoints()
            button.selfTag:SetPoint("LEFT", button.nameFS, "RIGHT", 5, 0)
        end

        local prev = ns.AnchorColumns(button)
        button.nameFS:ClearAllPoints()
        button.nameFS:SetPoint("LEFT", button.bar, "LEFT", 7, ns.GetFontNudge())
        if prev then
            button.nameFS:SetPoint("RIGHT", prev, "LEFT", -6, 0)
        else
            button.nameFS:SetPoint("RIGHT", button.bar, "RIGHT", -7, 0)
        end
    end

    local function UpdateRow(button, data)
        local font, size = ns.GetFont(), ns.GetFontSize()
        if button._fontPath ~= font or button._fontSize ~= size then
            button.nameFS:SetFont(font, size, "OUTLINE")
            button.rateFS:SetFont(font, size, "OUTLINE")
            button.totalFS:SetFont(font, math.max(8, size - 1), "OUTLINE")
            button.pctFS:SetFont(font, math.max(8, size - 1), "OUTLINE")
            button.rankFS:SetFont(font, math.max(9, size - 1), "OUTLINE")
            button.selfTag:SetFont(font, 7, "OUTLINE")
            if button.actionFS then button.actionFS:SetFont(font, size, "OUTLINE") end
            button._fontPath, button._fontSize = font, size
        end
        if data.kind == "spell" then
            UpdateSpellRow(button, data)
        else
            UpdatePlayerRow(button, data)
        end
    end

    view:SetElementInitializer("Button", function(button, elementData)
        if not button.bar then BuildRow(button) end
        UpdateRow(button, elementData)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar,
        {
            CreateAnchor("TOPLEFT", body, "TOPLEFT", 0, 0),
            CreateAnchor("BOTTOMRIGHT", scrollBR, "BOTTOMRIGHT", -8, 0),
        },
        {
            CreateAnchor("TOPLEFT", body, "TOPLEFT", 0, 0),
            CreateAnchor("BOTTOMRIGHT", scrollBR, "BOTTOMRIGHT", 0, 0),
        })
    scrollBox:SetDataProvider(dataProvider)

    ------------------------------------------------------------------
    -- Pinned self row
    ------------------------------------------------------------------
    local selfBar = CreateFrame("Button", nil, body)
    selfBar:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
    selfBar:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -8, 0)
    BuildRow(selfBar)
    selfBar:Hide()

    local selfSep = body:CreateTexture(nil, "OVERLAY")
    selfSep:SetTexture(ns.FLAT)
    selfSep:SetHeight(1)
    selfSep:SetPoint("BOTTOMLEFT", selfBar, "TOPLEFT", 0, 1)
    selfSep:SetPoint("BOTTOMRIGHT", selfBar, "TOPRIGHT", 0, 1)
    selfSep:Hide()

    local function SetSelfBarShown(shown)
        scrollBR:ClearAllPoints()
        if shown then
            selfBar:SetHeight(RowHeight())
            scrollBR:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -8, RowHeight() + 3)
            selfBar:Show()
            selfSep:Show()
        else
            scrollBR:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -8, 0)
            selfBar:Hide()
            selfSep:Hide()
        end
    end

    ------------------------------------------------------------------
    -- Resize grip
    ------------------------------------------------------------------
    local resizeHandle = CreateFrame("Button", nil, window)
    resizeHandle:SetSize(15, 15)
    resizeHandle:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -1, 1)
    resizeHandle:SetFrameLevel(window:GetFrameLevel() + 20)
    local grip1 = resizeHandle:CreateTexture(nil, "OVERLAY")
    grip1:SetTexture(ns.FLAT)
    grip1:SetSize(8, 1)
    grip1:SetPoint("BOTTOMRIGHT", -2, 3)
    grip1:SetRotation(math.rad(-45))
    grip1:SetVertexColor(0.55, 0.55, 0.60, 0.60)
    resizeHandle:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton" and not cfg.locked then window:StartSizing("BOTTOMRIGHT") end
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        window:StopMovingOrSizing()
        SavePosition()
        if ns.SnapRefreshChain then ns.SnapRefreshChain(window) end
    end)

    ------------------------------------------------------------------
    -- Data collection / stable snapshot semantics
    ------------------------------------------------------------------
    function state.ClearData()
        dataProvider:Flush()
        state.elements = {}
        selfBar._elementData = nil
        SetSelfBarShown(false)
    end

    function state.CollectData()
        local session = C_DamageMeter.GetCombatSessionFromType(state.sessionType, state.meterType)
        if not session or issecretvalue(session) then return false end
        local sources = session.combatSources
        if not sources or issecretvalue(sources) or #sources == 0 then return false end

        local sessionTotal = 0
        if sources[1] and Safe(sources[1].totalAmount) then
            for _, source in ipairs(sources) do
                if Safe(source.totalAmount) then sessionTotal = sessionTotal + source.totalAmount end
            end
        end

        local maxAmount = sources[1] and sources[1].totalAmount or 1
        local isAction = ns.ACTIONS_TYPES[state.meterType] or false
        local maxEntries = isAction and 5 or #sources
        local elements = {}
        local expandFound = false

        for i, source in ipairs(sources) do
            if i > maxEntries then break end
            local guid = source.sourceGUID
            elements[#elements + 1] = {
                rank = i,
                name = source.name,
                classFilename = source.classFilename,
                specIconID = source.specIconID,
                totalAmount = source.totalAmount,
                amountPerSecond = source.amountPerSecond,
                maxAmount = maxAmount,
                sessionTotal = sessionTotal,
                sourceGUID = guid,
                isLocalPlayer = source.isLocalPlayer,
                isActionType = isAction,
                deathRecapID = source.deathRecapID,
            }
            if state.expandedGUID and Safe(guid) and guid == state.expandedGUID then
                expandFound = true
                ns.AppendSpellRows(elements, state.sessionType, state.meterType,
                    guid, source.totalAmount, Safe(source.classFilename) and source.classFilename or nil)
            end
        end

        if state.expandedGUID and not expandFound then state.expandedGUID = nil end
        state.elements = elements

        -- Commit only after the complete replacement exists. A transient
        -- unreadable C_DamageMeter result therefore never blanks the meter.
        dataProvider:Flush()
        selfBar._elementData = nil
        SetSelfBarShown(false)
        dataProvider:InsertTable(elements)

        if ns.db and ns.db.showSelfBar then
            local selfSource, selfRank
            for i, source in ipairs(sources) do
                local isSelf = source.isLocalPlayer
                if Safe(isSelf) and isSelf then
                    selfSource = source
                    selfRank = i
                    break
                end
            end
            if selfSource then
                selfBar._elementData = {
                    rank = selfRank,
                    name = selfSource.name,
                    classFilename = selfSource.classFilename,
                    specIconID = selfSource.specIconID,
                    totalAmount = selfSource.totalAmount,
                    amountPerSecond = selfSource.amountPerSecond,
                    maxAmount = maxAmount,
                    sessionTotal = sessionTotal,
                    sourceGUID = selfSource.sourceGUID,
                    isLocalPlayer = true,
                    isActionType = isAction,
                    deathRecapID = selfSource.deathRecapID,
                }
                SetSelfBarShown(true)
                UpdateRow(selfBar, selfBar._elementData)
            end
        end
        return true
    end

    function state.ScheduleRefresh()
        state.CollectData()
    end

    ------------------------------------------------------------------
    -- Header navigation
    ------------------------------------------------------------------
    local function SyncTickers()
        if ns.SyncCombatTickers then ns.SyncCombatTickers() end
    end

    local function CommitViewChange()
        state.dataGeneration = state.dataGeneration + 1
        if ns.HideSpellBreakdown then ns.HideSpellBreakdown() end
        state.ClearData()
        state.CollectData()
        state.UpdateHeader()
        SyncTickers()
    end

    catBtn:SetScript("OnClick", function()
        local info = ns.TYPE_INFO[state.meterType]
        local currentCat = info and info.catIdx or 1
        local nextCat = ns.GetNextEnabledCatIdx(currentCat)
        if not nextCat or nextCat == currentCat then return end
        state.meterType = ns.METER_CATEGORIES[nextCat].types[1].type
        cfg.meterType = state.meterType
        CommitViewChange()
    end)
    catBtn:SetScript("OnEnter", function(self)
        local ar, ag, ab = AccentColor(1)
        self:SetBackdropBorderColor(ar, ag, ab, 0.9)
        ShowTip(self, L["TIP_CATEGORY"])
    end)
    catBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.35, 0.04, 0.07, 0.65)
        HideTip()
    end)

    typeBtn:SetScript("OnClick", function()
        local info = ns.TYPE_INFO[state.meterType]
        if not info then return end
        local cat = ns.METER_CATEGORIES[info.catIdx]
        local currentIdx = 1
        for i, entry in ipairs(cat.types) do
            if entry.type == state.meterType then currentIdx = i; break end
        end
        state.meterType = cat.types[(currentIdx % #cat.types) + 1].type
        cfg.meterType = state.meterType
        CommitViewChange()
    end)
    typeBtn:SetScript("OnEnter", function(self) ShowTip(self, L["TIP_TYPE"]) end)
    typeBtn:SetScript("OnLeave", HideTip)

    sessionBtn:SetScript("OnClick", function()
        local currentIdx = 1
        for i, opt in ipairs(ns.SESSION_OPTIONS) do
            if opt.type == state.sessionType then currentIdx = i; break end
        end
        state.sessionType = ns.SESSION_OPTIONS[(currentIdx % #ns.SESSION_OPTIONS) + 1].type
        cfg.sessionType = state.sessionType
        CommitViewChange()
    end)
    sessionBtn:SetScript("OnEnter", function(self) ShowTip(self, L["TIP_SESSION"]) end)
    sessionBtn:SetScript("OnLeave", HideTip)

    function state.UpdateHeader()
        local info = ns.TYPE_INFO[state.meterType]
        if not info then return end
        local catName = L[info.catName] or info.catName
        local typeName = L[info.key] or info.key
        local sessKey = ns.SESSION_KEYS[state.sessionType]
        local sessionName = sessKey and L[sessKey] or L["CURRENT"]

        catText:SetText(string.upper(catName or ""))
        typeText:SetText(typeName or "")
        sessionText:SetText(sessionName or "")
        state.UpdateTimer()
    end

    local function ApplyTimerPosition()
        local pos = ns.db and ns.db.combatTimerPos or "RIGHT"
        timerFS:SetJustifyH(pos == "LEFT" and "LEFT" or "RIGHT")
    end

    function state.UpdateTimer()
        ApplyTimerPosition()
        if not (ns.db and ns.db.showCombatTimer) or not ns.RATE_PRIMARY[state.meterType] then
            timerFS:SetText("")
            return
        end
        local seconds
        local session = C_DamageMeter.GetCombatSessionFromType(state.sessionType, state.meterType)
        if session and not issecretvalue(session) then
            local d = session.durationSeconds
            if Safe(d) then seconds = d end
        end
        if seconds == nil and C_DamageMeter.GetSessionDurationSeconds then
            local ok, d = pcall(C_DamageMeter.GetSessionDurationSeconds, state.sessionType)
            if ok and Safe(d) then seconds = d end
        end
        if seconds == nil then
            timerFS:SetText("")
            return
        end
        timerFS:SetText(ns.FormatTimer(seconds))
        if ns.inCombat then
            local ar, ag, ab = AccentColor(1)
            timerFS:SetTextColor(ar, ag, ab)
        else
            SetFontRole(timerFS, "secondary")
        end
    end

    ------------------------------------------------------------------
    -- Live restyle helpers
    ------------------------------------------------------------------
    local function RefreshAccentColor()
        local ar, ag, ab = AccentColor(1)
        topAccent:SetVertexColor(ar, ag, ab, 0.98)
        headerSep:SetVertexColor(ar, ag, ab, 0.42)
        catText:SetTextColor(ar, ag, ab)
        selfSep:SetVertexColor(ar, ag, ab, 0.62)
        UpdateLockIcon()
        for _, button in scrollBox:EnumerateFrames() do
            if button._elementData then UpdateRow(button, button._elementData) end
        end
        if selfBar._elementData then UpdateRow(selfBar, selfBar._elementData) end
    end

    local function RefreshSkin()
        local alpha = ns.db and ns.db.bgAlpha or (ns.BG and ns.BG[4]) or 0.90
        local bc = ns.BORDER_COLOR or { 0.28, 0.28, 0.31, 0.8 }
        window:SetBackdropColor(ns.BG[1], ns.BG[2], ns.BG[3], alpha)
        window:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 0.8)
        local r, g, b, a = SurfaceColor(0.98)
        headerBG:SetVertexColor(r, g, b, a)
        local skin = ns.db and ns.db.skin or "DARK"
        headerSheen:SetAlpha(skin == "DARK" and 0.30 or 0.18)
        SetFontRole(typeText, "primary")
        SetFontRole(sessionText, "secondary")
        if not ns.inCombat then SetFontRole(timerFS, "secondary") end
        glow:SetAlpha(skin == "DARK" and 0.22 or 0.09)
        if scrollBar.Track and scrollBar.Track.Thumb and scrollBar.Track.Thumb._tdmBG then
            local c = ns.SCROLLBAR_THUMB or { 0.64, 0.08, 0.15 }
            scrollBar.Track.Thumb._tdmBG:SetVertexColor(c[1], c[2], c[3], 0.86)
        end
        RefreshAccentColor()
    end

    local function RefreshFonts()
        local font, size = ns.GetFont(), ns.GetFontSize()
        catText:SetFont(font, 8, "OUTLINE")
        typeText:SetFont(font, 12, "OUTLINE")
        sessionText:SetFont(font, 7, "OUTLINE")
        timerFS:SetFont(font, 9, "OUTLINE")
        for _, button in scrollBox:EnumerateFrames() do
            button._fontPath = nil
            if button._elementData then UpdateRow(button, button._elementData) end
        end
        selfBar._fontPath = nil
        if selfBar._elementData then UpdateRow(selfBar, selfBar._elementData) end
        state.UpdateHeader()
    end

    local function RefreshBarHeight()
        view:SetElementExtent(RowHeight())
        for _, button in scrollBox:EnumerateFrames() do
            if button._elementData then UpdateRow(button, button._elementData) end
        end
        if selfBar._elementData then
            selfBar:SetHeight(RowHeight())
            UpdateRow(selfBar, selfBar._elementData)
            SetSelfBarShown(true)
        else
            SetSelfBarShown(false)
        end
        state.CollectData()
    end

    ------------------------------------------------------------------
    -- Public window API expected by Database / Config / Snap
    ------------------------------------------------------------------
    local win = {
        frame = window,
        cfg = cfg,
        BumpGeneration = function() state.dataGeneration = state.dataGeneration + 1 end,
        ClearData = state.ClearData,
        Refresh = state.ScheduleRefresh,
        UpdateTimer = function() state.UpdateTimer() end,
        UpdateHeader = function() state.UpdateHeader() end,
        SetMeterType = function(meterType)
            state.meterType = meterType
            cfg.meterType = meterType
            CommitViewChange()
        end,
        SetSessionType = function(sessionType)
            state.sessionType = sessionType
            cfg.sessionType = sessionType
            CommitViewChange()
        end,
        GetMeterType = function() return state.meterType end,
        GetSessionType = function() return state.sessionType end,
        RefreshLockIcon = UpdateLockIcon,
        SetCombatAlpha = function(inCombat)
            if inCombat then
                window:SetAlpha(1)
            else
                window:SetAlpha(ns.db and ns.db.oocAlpha or 1)
            end
        end,
        SetResizeHandleShown = function(shown)
            resizeHandle:SetShown(shown and true or false)
        end,
        SavePosition = SavePosition,
        SetBGAlpha = function(alpha)
            window:SetBackdropColor(ns.BG[1], ns.BG[2], ns.BG[3], alpha)
        end,
        RefreshAccentColor = RefreshAccentColor,
        RefreshSkin = RefreshSkin,
        RefreshTimerPos = function()
            ApplyTimerPosition()
            state.UpdateTimer()
        end,
        RefreshFonts = RefreshFonts,
        RefreshBarHeight = RefreshBarHeight,
        SetSelfBarEnabled = function(shown)
            if not shown then
                selfBar._elementData = nil
                SetSelfBarShown(false)
                return
            end
            state.CollectData()
        end,
    }

    -- Initial visual pass. Data is populated by Core/Database after creation.
    RefreshSkin()
    state.UpdateHeader()

    return win
end

ns._meterUIV3 = true
