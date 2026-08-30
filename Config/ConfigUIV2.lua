local ADDON_NAME, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Settings V2
--
-- The original ConfigUI.lua stays loaded as a fallback/reference.  This file
-- is loaded afterwards and intentionally replaces only the public settings
-- entry points.  The V2 panel is persistent: pages and widgets are allocated
-- once, then refreshed in place.
----------------------------------------------------------------------

local settingsFrame

local RED       = { 0.88, 0.08, 0.18 }
local RED_HOVER = { 0.36, 0.04, 0.08, 0.96 }
local PANEL     = { 0.025, 0.025, 0.030, 0.98 }
local SURFACE   = { 0.055, 0.055, 0.065, 0.96 }
local SURFACE_2 = { 0.085, 0.085, 0.100, 0.96 }
local BORDER    = { 0.22, 0.22, 0.25, 0.85 }
local MUTED     = { 0.52, 0.52, 0.56 }
local WHITE     = { 1.00, 1.00, 1.00 }

local function T(key, fallback)
    local value = L and L[key]
    if value and value ~= key then return value end
    return fallback or key
end

local function SetFont(fs, size, color)
    fs:SetFont(ns.GetFont(), size, "OUTLINE")
    color = color or WHITE
    fs:SetTextColor(color[1], color[2], color[3])
    return fs
end

local function Backdrop(frame, bg, border)
    frame:SetBackdrop({
        bgFile = ns.FLAT,
        edgeFile = ns.FLAT,
        edgeSize = 1,
    })
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

local function MakeButton(parent, text, width, height, onClick, danger)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 120, height or 28)
    Backdrop(btn, danger and { 0.18, 0.025, 0.035, 0.96 } or SURFACE_2, BORDER)

    local gloss = btn:CreateTexture(nil, "ARTWORK", nil, -4)
    gloss:SetTexture("Interface\\AddOns\\TomoDamageMeter\\Assets\\Textures\\TDM_RowSheen_256x32")
    gloss:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    gloss:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
    gloss:SetHeight(math.max(8, (height or 28) * 0.55))
    gloss:SetAlpha(danger and 0.34 or 0.22)

    local label = SetFont(btn:CreateFontString(nil, "ARTWORK"), 10, WHITE)
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text or "")
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        if danger then
            self:SetBackdropColor(0.34, 0.035, 0.055, 1)
        else
            self:SetBackdropColor(RED_HOVER[1], RED_HOVER[2], RED_HOVER[3], RED_HOVER[4])
        end
        self:SetBackdropBorderColor(RED[1], RED[2], RED[3], 0.95)
    end)
    btn:SetScript("OnLeave", function(self)
        local bg = danger and { 0.18, 0.025, 0.035, 0.96 } or SURFACE_2
        self:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        self:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], BORDER[4])
    end)
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end

local function MakeSectionTitle(parent, text)
    local fs = SetFont(parent:CreateFontString(nil, "ARTWORK"), 11, RED)
    fs:SetText(text)
    return fs
end

local function MakeCard(parent)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Backdrop(card, SURFACE, BORDER)

    local gloss = card:CreateTexture(nil, "ARTWORK", nil, -5)
    gloss:SetTexture("Interface\\AddOns\\TomoDamageMeter\\Assets\\Textures\\TDM_RowSheen_256x32")
    gloss:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
    gloss:SetPoint("TOPRIGHT", card, "TOPRIGHT", -1, -1)
    gloss:SetHeight(26)
    gloss:SetAlpha(0.20)

    local accent = card:CreateTexture(nil, "OVERLAY")
    accent:SetTexture(ns.FLAT)
    accent:SetVertexColor(RED[1], RED[2], RED[3], 0.42)
    accent:SetHeight(1)
    accent:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", card, "TOPRIGHT", -1, -1)

    return card
end

local function IsMetersVisible()
    if ns.db and ns.db.windowsVisible ~= nil then
        return ns.db.windowsVisible and true or false
    end
    for _, win in ipairs(ns.windows or {}) do
        if win.frame and win.frame:IsShown() then return true end
    end
    return false
end

local function SetMetersVisible(shown)
    if ns.SetWindowsVisible then
        ns.SetWindowsVisible(shown)
        return
    end
    if ns.db then ns.db.windowsVisible = shown and true or false end
    for _, win in ipairs(ns.windows or {}) do
        if win.frame then win.frame:SetShown(shown and true or false) end
    end
end

local function AreAllWindowsLocked()
    if not ns.windows or #ns.windows == 0 then return false end
    for _, win in ipairs(ns.windows) do
        if not (win.cfg and win.cfg.locked) then return false end
    end
    return true
end

local function SetAllWindowsLocked(locked)
    for _, win in ipairs(ns.windows or {}) do
        if win.cfg then win.cfg.locked = locked and true or false end
        if win.RefreshLockIcon then win.RefreshLockIcon() end
    end
end

local function MeterLabel(win)
    if not win then return "-" end
    local info = ns.TYPE_INFO[win.GetMeterType()]
    return info and T(info.key, info.key) or "-"
end

local function SessionLabel(win)
    if not win then return "-" end
    local key = ns.SESSION_KEYS[win.GetSessionType()]
    return key and T(key, key) or "-"
end

local function ActiveSkinLabel()
    if not ns.db then return "-" end
    local skin = ns.SKIN_BY_KEY and ns.SKIN_BY_KEY[ns.db.skin or "DARK"]
    if skin then return T(skin.name, skin.key) end
    return ns.db.skin or "DARK"
end

local function RefreshAllWindows()
    for _, win in ipairs(ns.windows or {}) do
        if win.Refresh then win.Refresh() end
    end
end

local function ApplyColumnVisuals()
    for _, win in ipairs(ns.windows or {}) do
        if win.RefreshFonts then win.RefreshFonts() end
        if win.Refresh then win.Refresh() end
    end
end

local function CreateScrollPage(host)
    local page = CreateFrame("Frame", nil, host)
    page:SetAllPoints()

    local scroll = CreateFrame("ScrollFrame", nil, page)
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -12, 0)
    scroll:EnableMouseWheel(true)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll:SetScript("OnSizeChanged", function(self, width)
        child:SetWidth(math.max(width, 1))
    end)

    -- Thin TDM-red scrollbar. It stays hidden when the whole page fits, and
    -- appears automatically on pages such as Windows when their content grows.
    local bar = CreateFrame("Slider", nil, page)
    bar:SetOrientation("VERTICAL")
    bar:SetPoint("TOPRIGHT", -1, -3)
    bar:SetPoint("BOTTOMRIGHT", -1, 3)
    bar:SetWidth(5)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(false)

    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(ns.FLAT)
    track:SetAllPoints()
    track:SetVertexColor(0.12, 0.12, 0.14, 0.72)

    local thumb = bar:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture(ns.FLAT)
    thumb:SetSize(5, 36)
    thumb:SetVertexColor(RED[1], RED[2], RED[3], 0.92)
    bar:SetThumbTexture(thumb)
    bar:Hide()

    local maxRange = 0
    local syncing = false

    local function SyncBarFromScroll(offset)
        if maxRange <= 0 then return end
        syncing = true
        bar:SetValue(maxRange - math.max(0, math.min(maxRange, offset or 0)))
        syncing = false
    end

    bar:SetScript("OnValueChanged", function(_, value)
        if syncing then return end
        scroll:SetVerticalScroll(math.max(0, maxRange - value))
    end)

    scroll:SetScript("OnVerticalScroll", function(_, offset)
        SyncBarFromScroll(offset)
    end)

    scroll:SetScript("OnScrollRangeChanged", function(self, _, verticalRange)
        maxRange = math.max(0, verticalRange or 0)
        bar:SetMinMaxValues(0, maxRange)
        bar:SetShown(maxRange > 1)
        if maxRange > 1 then
            local viewport = math.max(1, self:GetHeight() or 1)
            local content = viewport + maxRange
            local trackHeight = math.max(1, bar:GetHeight() or viewport)
            thumb:SetHeight(math.max(28, math.min(trackHeight, trackHeight * viewport / content)))
            SyncBarFromScroll(self:GetVerticalScroll())
        end
    end)

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 34)))
    end)

    page.scroll = scroll
    page.scrollbar = bar
    page.content = child
    page:Hide()
    return page
end

local function NewStack(page)
    local parent = page.content
    local stack = { y = 0 }

    function stack:Title(text, subtitle)
        local title = SetFont(parent:CreateFontString(nil, "ARTWORK"), 18, WHITE)
        title:SetPoint("TOPLEFT", 4, -self.y)
        title:SetText(text)
        self.y = self.y + 27
        if subtitle then
            local sub = SetFont(parent:CreateFontString(nil, "ARTWORK"), 10, MUTED)
            sub:SetPoint("TOPLEFT", 4, -self.y)
            sub:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
            sub:SetJustifyH("LEFT")
            sub:SetText(subtitle)
            self.y = self.y + 25
        else
            self.y = self.y + 8
        end
    end

    function stack:Section(text)
        self.y = self.y + 8
        local fs = MakeSectionTitle(parent, text)
        fs:SetPoint("TOPLEFT", 4, -self.y)
        self.y = self.y + 21
    end

    function stack:Widget(widget, height)
        widget:SetParent(parent)
        widget:ClearAllPoints()
        widget:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -self.y)
        widget:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
        self.y = self.y + (height or widget:GetHeight() or 30) + 8
        return widget
    end

    function stack:Finish(extra)
        parent:SetHeight(self.y + (extra or 20))
    end

    return stack
end

local function CreateSettingsPanelV2()
    local frame = CreateFrame("Frame", "TomoDamageMeterSettingsV2", UIParent, "BackdropTemplate")
    frame:SetSize(780, 590)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    Backdrop(frame, PANEL, { RED[1], RED[2], RED[3], 0.72 })
    if ns.DecorateTDMFrame then
        ns.DecorateTDMFrame(frame, "settings")
    end

    if not tContains(UISpecialFrames, frame:GetName()) then
        table.insert(UISpecialFrames, frame:GetName())
    end

    ------------------------------------------------------------------
    -- Header
    ------------------------------------------------------------------
    local logo = frame:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\TomoDamageMeter\\Assets\\Textures\\TDM_Logo_Header_256x128")
    logo:SetSize(94, 42)
    logo:SetPoint("TOPLEFT", 8, -3)

    local title = SetFont(frame:CreateFontString(nil, "ARTWORK"), 13, WHITE)
    title:SetPoint("LEFT", logo, "RIGHT", 4, 0)
    title:SetText(T("SETTINGS_TITLE", "TomoDamageMeter"))

    local version
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
    elseif GetAddOnMetadata then
        version = GetAddOnMetadata(ADDON_NAME, "Version")
    end
    local versionFS = SetFont(frame:CreateFontString(nil, "ARTWORK"), 9, MUTED)
    versionFS:SetPoint("LEFT", title, "RIGHT", 8, 0)
    versionFS:SetText(version and ("v" .. version) or "")

    local topLine = frame:CreateTexture(nil, "ARTWORK")
    topLine:SetTexture(ns.FLAT)
    topLine:SetVertexColor(RED[1], RED[2], RED[3], 0.82)
    topLine:SetHeight(2)
    topLine:SetPoint("TOPLEFT", 0, -48)
    topLine:SetPoint("TOPRIGHT", 0, -48)

    local close = MakeButton(frame, "×", 30, 28, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -10, -10)
    close.label:SetFont(ns.GetFont(), 16, "OUTLINE")

    ------------------------------------------------------------------
    -- Sidebar + content host
    ------------------------------------------------------------------
    local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", 10, -60)
    sidebar:SetPoint("BOTTOMLEFT", 10, 10)
    sidebar:SetWidth(154)
    Backdrop(sidebar, { 0.018, 0.018, 0.022, 0.98 }, { 0.11, 0.11, 0.13, 0.9 })

    local host = CreateFrame("Frame", nil, frame)
    host:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 16, 0)
    host:SetPoint("BOTTOMRIGHT", -14, 14)

    local pages = {}
    local navButtons = {}
    local refreshables = {}
    local activePage = "dashboard"

    local function Track(widget)
        refreshables[#refreshables + 1] = widget
        return widget
    end

    local function SetPage(key)
        activePage = key
        for pageKey, page in pairs(pages) do
            page:SetShown(pageKey == key)
        end
        for pageKey, btn in pairs(navButtons) do
            if pageKey == key then
                btn:SetBackdropColor(0.23, 0.025, 0.045, 1)
                btn:SetBackdropBorderColor(RED[1], RED[2], RED[3], 0.95)
                -- Active navigation is intentionally unmistakable: red label + red frame.
                btn.label:SetTextColor(RED[1], RED[2], RED[3])
            else
                btn:SetBackdropColor(0.035, 0.035, 0.042, 0.98)
                btn:SetBackdropBorderColor(0.08, 0.08, 0.10, 0.8)
                btn.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
            end
        end
    end

    local nav = {
        { "dashboard",  T("SETTINGS_DASHBOARD", "Dashboard") },
        { "general",    T("SETTINGS_GENERAL", "General") },
        { "appearance", T("SETTINGS_APPEARANCE", "Appearance") },
        { "windows",    T("SETTINGS_WINDOWS", "Windows") },
        { "minimap",    T("SETTINGS_MINIMAP", "Minimap") },
        { "reports",    T("REPORT", "Report") },
    }

    local navY = -10
    for _, entry in ipairs(nav) do
        local key, label = entry[1], entry[2]
        local btn = MakeButton(sidebar, label, 134, 34, function() SetPage(key) end)
        btn:SetPoint("TOPLEFT", 10, navY)
        btn.label:ClearAllPoints()
        btn.label:SetPoint("LEFT", 12, 0)
        btn.label:SetJustifyH("LEFT")
        navButtons[key] = btn
        navY = navY - 40
    end

    local brand = SetFont(sidebar:CreateFontString(nil, "ARTWORK"), 9, MUTED)
    brand:SetPoint("BOTTOM", 0, 12)
    brand:SetText("TDM  •  TomoSuite")

    ------------------------------------------------------------------
    -- Dashboard
    ------------------------------------------------------------------
    local dashboard = CreateScrollPage(host)
    pages.dashboard = dashboard
    local ds = NewStack(dashboard)
    ds:Title(T("SETTINGS_DASHBOARD", "Dashboard"),
        T("SETTINGS_DASHBOARD_DESC", "Quick status and controls for TomoDamageMeter."))

    ds:Section(T("SETTINGS_STATUS", "Status"))

    local statusCard = MakeCard(dashboard.content)
    statusCard:SetPoint("TOPLEFT", 4, -ds.y)
    statusCard:SetPoint("RIGHT", dashboard.content, "RIGHT", -8, 0)
    statusCard:SetHeight(92)
    ds.y = ds.y + 102

    local visLabel = SetFont(statusCard:CreateFontString(nil, "ARTWORK"), 10, MUTED)
    visLabel:SetPoint("TOPLEFT", 14, -13)
    visLabel:SetText(T("SETTINGS_METERS", "Meters"))

    local visValue = SetFont(statusCard:CreateFontString(nil, "ARTWORK"), 12, WHITE)
    visValue:SetPoint("TOPLEFT", visLabel, "BOTTOMLEFT", 0, -4)

    local windowLabel = SetFont(statusCard:CreateFontString(nil, "ARTWORK"), 10, MUTED)
    windowLabel:SetPoint("TOP", statusCard, "TOP", 0, -13)
    windowLabel:SetText(T("SETTINGS_ACTIVE_WINDOWS", "Active windows"))

    local windowValue = SetFont(statusCard:CreateFontString(nil, "ARTWORK"), 12, WHITE)
    windowValue:SetPoint("TOP", windowLabel, "BOTTOM", 0, -4)

    local skinLabel = SetFont(statusCard:CreateFontString(nil, "ARTWORK"), 10, MUTED)
    skinLabel:SetPoint("TOPRIGHT", -14, -13)
    skinLabel:SetText(T("SETTINGS_ACTIVE_SKIN", "Active skin"))

    local skinValue = SetFont(statusCard:CreateFontString(nil, "ARTWORK"), 12, WHITE)
    skinValue:SetPoint("TOPRIGHT", skinLabel, "BOTTOMRIGHT", 0, -4)

    ds:Section(T("SETTINGS_QUICK_ACTIONS", "Quick actions"))

    local quick = MakeCard(dashboard.content)
    quick:SetPoint("TOPLEFT", 4, -ds.y)
    quick:SetPoint("RIGHT", dashboard.content, "RIGHT", -8, 0)
    quick:SetHeight(82)
    ds.y = ds.y + 92

    local visibilityBtn = MakeButton(quick, "", 128, 32, function()
        SetMetersVisible(not IsMetersVisible())
        if frame.Refresh then frame.Refresh() end
    end)
    visibilityBtn:SetPoint("TOPLEFT", 12, -13)

    local lockAllBtn = MakeButton(quick, "", 128, 32, function()
        SetAllWindowsLocked(not AreAllWindowsLocked())
        if frame.Refresh then frame.Refresh() end
    end)
    lockAllBtn:SetPoint("LEFT", visibilityBtn, "RIGHT", 10, 0)

    local resetBtn = MakeButton(quick, T("RESET", "Reset"), 128, 32, function()
        C_DamageMeter.ResetAllCombatSessions()
    end, true)
    resetBtn:SetPoint("LEFT", lockAllBtn, "RIGHT", 10, 0)

    local recapBtn = MakeButton(quick, T("RUN_RECAP", "Run Recap"), 128, 32, function()
        if ns.ToggleRunRecap then ns.ToggleRunRecap() end
    end)
    recapBtn:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)

    ds:Section(T("SETTINGS_WINDOW_OVERVIEW", "Window overview"))

    local overview = MakeCard(dashboard.content)
    overview:SetPoint("TOPLEFT", 4, -ds.y)
    overview:SetPoint("RIGHT", dashboard.content, "RIGHT", -8, 0)
    overview:SetHeight(174)
    ds.y = ds.y + 184

    local overviewRows = {}
    for i = 1, ns.MAX_WINDOWS do
        local row = CreateFrame("Frame", nil, overview)
        row:SetHeight(28)
        row:SetPoint("TOPLEFT", 10, -8 - (i - 1) * 31)
        row:SetPoint("RIGHT", overview, "RIGHT", -10, 0)

        local idx = SetFont(row:CreateFontString(nil, "ARTWORK"), 10, RED)
        idx:SetPoint("LEFT", 4, 0)
        idx:SetWidth(24)
        idx:SetJustifyH("LEFT")
        idx:SetText(i)

        local typeFS = SetFont(row:CreateFontString(nil, "ARTWORK"), 10, WHITE)
        typeFS:SetPoint("LEFT", 36, 0)
        typeFS:SetWidth(190)
        typeFS:SetJustifyH("LEFT")

        local sessionFS = SetFont(row:CreateFontString(nil, "ARTWORK"), 10, MUTED)
        sessionFS:SetPoint("LEFT", 235, 0)
        sessionFS:SetWidth(110)
        sessionFS:SetJustifyH("LEFT")

        local lockFS = SetFont(row:CreateFontString(nil, "ARTWORK"), 10, MUTED)
        lockFS:SetPoint("RIGHT", -6, 0)

        row.typeFS = typeFS
        row.sessionFS = sessionFS
        row.lockFS = lockFS
        overviewRows[i] = row
    end
    ds:Finish()

    ------------------------------------------------------------------
    -- General
    ------------------------------------------------------------------
    local general = CreateScrollPage(host)
    pages.general = general
    local gs = NewStack(general)
    gs:Title(T("SETTINGS_GENERAL", "General"),
        T("SETTINGS_GENERAL_DESC", "Core meter behavior, modules, categories and columns."))

    -- Two compact columns keep the default General page entirely visible at
    -- 1024x768-class layouts. The ScrollFrame remains as a safe fallback for
    -- unusually tall fonts / localisations and exposes a visible red scrollbar
    -- if content ever exceeds the viewport.
    local columnTop = gs.y
    local leftCol = CreateFrame("Frame", nil, general.content)
    leftCol:SetPoint("TOPLEFT", general.content, "TOPLEFT", 4, -columnTop)
    leftCol:SetSize(270, 390)

    local rightCol = CreateFrame("Frame", nil, general.content)
    rightCol:SetPoint("TOPLEFT", general.content, "TOPLEFT", 294, -columnTop)
    rightCol:SetPoint("RIGHT", general.content, "RIGHT", -8, 0)
    rightCol:SetHeight(390)

    local left = NewStack({ content = leftCol })
    local right = NewStack({ content = rightCol })

    left:Section(T("SETTINGS_GENERAL", "General"))

    Track(left:Widget(ns.Widgets.CreateCheckbox(leftCol, T("SETTINGS_STRIP_REALM", "Strip Realm Names"),
        function() return ns.db.stripRealm end,
        function(val)
            ns.db.stripRealm = val and true or false
            RefreshAllWindows()
        end), 24))

    Track(left:Widget(ns.Widgets.CreateCheckbox(leftCol, T("SETTINGS_USE_CLASS_COLOR", "Use Class Color"),
        function() return ns.db.accentUseClassColor end,
        function(val)
            if ns.SetClassColorMode then
                ns.SetClassColorMode(val and true or false)
            else
                ns.db.accentUseClassColor = val and true or false
                ns.ApplyAccentColor()
                for _, win in ipairs(ns.windows) do
                    if win.RefreshAccentColor then win.RefreshAccentColor() end
                    if win.Refresh then win.Refresh() end
                end
            end
        end), 24))

    Track(left:Widget(ns.Widgets.CreateCheckbox(leftCol, T("SETTINGS_AUTO_RESET_INSTANCE", "Auto-reset on instance entry"),
        function() return ns.db.autoResetOnInstance end,
        function(val) ns.db.autoResetOnInstance = val and true or false end), 24))

    Track(left:Widget(ns.Widgets.CreateCheckbox(leftCol, T("SETTINGS_COMBAT_TIMER", "Combat Timer (DPS/HPS)"),
        function() return ns.db.showCombatTimer end,
        function(val)
            ns.db.showCombatTimer = val and true or false
            for _, win in ipairs(ns.windows) do
                if win.UpdateTimer then win.UpdateTimer() end
            end
            if ns.SyncCombatTickers then ns.SyncCombatTickers() end
        end), 24))

    Track(left:Widget(ns.Widgets.CreateDropdown(leftCol, T("SETTINGS_TIMER_POSITION", "Combat Timer Position"), {
            { value = "RIGHT", label = T("TIMER_POS_RIGHT", "Right") },
            { value = "LEFT",  label = T("TIMER_POS_LEFT", "Left") },
        },
        function() return ns.db.combatTimerPos or "RIGHT" end,
        function(val)
            ns.db.combatTimerPos = val
            for _, win in ipairs(ns.windows) do
                if win.RefreshTimerPos then win.RefreshTimerPos() end
            end
        end), 30))

    Track(left:Widget(ns.Widgets.CreateCheckbox(leftCol, T("SETTINGS_SELF_BAR", "Pin My Own Bar"),
        function() return ns.db.showSelfBar end,
        function(val)
            ns.db.showSelfBar = val and true or false
            for _, win in ipairs(ns.windows) do
                if win.SetSelfBarEnabled then
                    win.SetSelfBarEnabled(ns.db.showSelfBar)
                elseif win.Refresh then
                    win.Refresh()
                end
            end
        end), 24))

    Track(left:Widget(ns.Widgets.CreateCheckbox(leftCol, T("SETTINGS_SHOW_YOU_TAG", "Show the YOU tag on my row"),
        function() return ns.db.showYouTag == true end,
        function(val)
            ns.db.showYouTag = val and true or false
            for _, win in ipairs(ns.windows) do
                if win.RefreshYouTag then
                    win.RefreshYouTag()
                elseif win.Refresh then
                    win.Refresh()
                end
            end
        end), 24))

    Track(left:Widget(ns.Widgets.CreateCheckbox(leftCol, T("SETTINGS_BAR_TOOLTIPS", "Bar Tooltips (hover)"),
        function() return ns.db.showBarTooltips end,
        function(val) ns.db.showBarTooltips = val and true or false end), 24))

    left:Section(T("SETTINGS_MODULES", "Modules"))

    Track(left:Widget(ns.Widgets.CreateCheckbox(leftCol, T("SETTINGS_DEATH_RECAP_AUTO", "Death recap popup on death"),
        function() return ns.db.deathRecapAutoShow end,
        function(val) ns.db.deathRecapAutoShow = val and true or false end), 24))

    Track(left:Widget(ns.Widgets.CreateCheckbox(leftCol, T("SETTINGS_RUN_RECAP_AUTO", "Show run recap at the end of a dungeon"),
        function() return ns.db.runRecapAutoShow ~= false end,
        function(val) ns.db.runRecapAutoShow = val and true or false end), 24))

    Track(left:Widget(ns.Widgets.CreateCheckbox(leftCol, T("SETTINGS_SNAP", "Snap windows to each other"),
        function() return ns.db.snapEnabled ~= false end,
        function(val) ns.db.snapEnabled = val and true or false end), 24))

    right:Section(T("SETTINGS_CATEGORIES", "Categories"))

    for catIdx, cat in ipairs(ns.METER_CATEGORIES) do
        Track(right:Widget(ns.Widgets.CreateCheckbox(rightCol, T(cat.name, cat.name),
            function() return ns.IsCategoryEnabled(catIdx) end,
            function(val)
                if not val then
                    local enabled = 0
                    for ci = 1, #ns.METER_CATEGORIES do
                        if ns.IsCategoryEnabled(ci) then enabled = enabled + 1 end
                    end
                    if enabled <= 1 then
                        print(T("ADDON_PREFIX", "TDM: ") .. T("SETTINGS_CATEGORIES_MIN", "At least one category must remain enabled."))
                        if frame.Refresh then frame.Refresh() end
                        return
                    end
                    ns.db.disabledCategories[cat.name] = true
                else
                    ns.db.disabledCategories[cat.name] = nil
                end
                ns.EnforceEnabledTypes()
                if frame.Refresh then frame.Refresh() end
            end), 24))
    end

    right:Section(T("SETTINGS_COLUMNS", "Columns"))

    local COLUMN_LABELS = {
        rate = "SETTINGS_COL_RATE",
        total = "SETTINGS_COL_TOTAL",
        pct = "SETTINGS_COL_PCT",
    }
    local FORMAT_LABELS = {
        short = "FMT_COMPACT",
        ["1dec"] = "FMT_1DEC",
        ["2dec"] = "FMT_2DEC",
        ["3dec"] = "FMT_3DEC",
        full = "FMT_REGULAR",
        int = "FMT_INT",
        dec = "FMT_DEC",
    }
    local function GetColumn(key)
        for _, col in ipairs(ns.db.columns or {}) do
            if col.key == key then return col end
        end
    end

    for _, colKey in ipairs({ "rate", "total", "pct" }) do
        Track(right:Widget(ns.Widgets.CreateCheckbox(rightCol, T(COLUMN_LABELS[colKey], colKey),
            function()
                local col = GetColumn(colKey)
                return col and col.show or false
            end,
            function(val)
                local col = GetColumn(colKey)
                if not col then return end
                col.show = val and true or false
                ApplyColumnVisuals()
            end), 24))

        Track(right:Widget(ns.Widgets.CreateDropdown(rightCol, T("SETTINGS_FORMAT", "Format"),
            function()
                local out = {}
                for _, fmt in ipairs(ns.FORMAT_OPTIONS[colKey] or {}) do
                    out[#out + 1] = { value = fmt, label = T(FORMAT_LABELS[fmt], fmt) }
                end
                return out
            end,
            function()
                local col = GetColumn(colKey)
                return col and col.fmt or "1dec"
            end,
            function(val)
                local col = GetColumn(colKey)
                if not col then return end
                col.fmt = val
                ApplyColumnVisuals()
            end), 30))
    end

    local columnsHeight = math.max(left.y, right.y)
    leftCol:SetHeight(columnsHeight)
    rightCol:SetHeight(columnsHeight)
    gs.y = columnTop + columnsHeight
    gs:Finish(8)

    ------------------------------------------------------------------
    -- Appearance
    ------------------------------------------------------------------
    local appearance = CreateScrollPage(host)
    pages.appearance = appearance
    local aps = NewStack(appearance)
    aps:Title(T("SETTINGS_APPEARANCE", "Appearance"),
        T("SETTINGS_APPEARANCE_DESC", "HUD styling. The settings panel keeps the TDM red/white identity."))

    aps:Section(T("SETTINGS_APPEARANCE", "Appearance"))

    Track(aps:Widget(ns.Widgets.CreateDropdown(appearance.content, T("SETTINGS_SKIN", "Skin"),
        ns.GetSkinList,
        function() return ns.db.skin or "DARK" end,
        function(val)
            ns.ApplySkin(val, true)
            if frame.Refresh then frame.Refresh() end
        end), 30))

    Track(aps:Widget(ns.Widgets.CreateDropdown(appearance.content, T("SETTINGS_BAR_TEXTURE", "Bar Texture"),
        ns.GetTextureList,
        function() return ns.db.barTexture or ns.TEX_FLAT end,
        function(val)
            ns.db.barTexture = val
            for _, win in ipairs(ns.windows) do
                if win.RefreshSkin then win.RefreshSkin() end
            end
        end), 30))

    local fontOptions = {}
    for _, entry in ipairs(ns.FONT_LIST) do
        fontOptions[#fontOptions + 1] = {
            value = entry.path,
            label = T(entry.key, entry.key),
            fontPath = entry.path,
        }
    end

    Track(aps:Widget(ns.Widgets.CreateDropdown(appearance.content, T("SETTINGS_FONT_FACE", "Font"),
        fontOptions,
        function() return ns.db.fontPath end,
        function(val)
            ns.db.fontPath = val
            if ns.ClearCharWidthCache then ns.ClearCharWidthCache() end
            for _, win in ipairs(ns.windows) do
                if win.RefreshFonts then win.RefreshFonts() end
            end
            if ns.RefreshBreakdownFonts then ns.RefreshBreakdownFonts() end
            if ns.RefreshTargetBreakdownFonts then ns.RefreshTargetBreakdownFonts() end
        end), 30))

    Track(aps:Widget(ns.Widgets.CreateSlider(appearance.content, T("SETTINGS_FONT_SIZE", "Font Size"),
        8, 22, 1,
        function() return ns.db.fontSize end,
        function(val)
            ns.db.fontSize = val
            if ns.ClearCharWidthCache then ns.ClearCharWidthCache() end
            for _, win in ipairs(ns.windows) do
                if win.RefreshFonts then win.RefreshFonts() end
            end
        end), 50))

    Track(aps:Widget(ns.Widgets.CreateSlider(appearance.content, T("SETTINGS_BAR_HEIGHT", "Bar Height"),
        14, 32, 1,
        function() return ns.db.barHeight end,
        function(val)
            ns.db.barHeight = val
            for _, win in ipairs(ns.windows) do
                if win.RefreshBarHeight then win.RefreshBarHeight() end
            end
        end), 50))

    Track(aps:Widget(ns.Widgets.CreateSlider(appearance.content, T("SETTINGS_BG_OPACITY", "Background Opacity"),
        0, 1, 0.05,
        function() return ns.db.bgAlpha end,
        function(val)
            ns.db.bgAlpha = val
            for _, win in ipairs(ns.windows) do
                if win.SetBGAlpha then win.SetBGAlpha(val) end
            end
        end), 50))

    Track(aps:Widget(ns.Widgets.CreateSlider(appearance.content, T("SETTINGS_OOC_OPACITY", "Out of Combat Opacity"),
        0.1, 1, 0.05,
        function() return ns.db.oocAlpha end,
        function(val)
            ns.db.oocAlpha = val
            if not ns.inCombat then
                for _, win in ipairs(ns.windows) do win.SetCombatAlpha(false) end
            end
        end), 50))

    Track(aps:Widget(ns.Widgets.CreateSlider(appearance.content, T("SETTINGS_BREAKDOWN_OPACITY", "Spell Breakdown Opacity"),
        0.1, 1, 0.05,
        function() return ns.db.breakdownAlpha end,
        function(val)
            ns.db.breakdownAlpha = val
            if ns.ApplyBreakdownAlpha then ns.ApplyBreakdownAlpha() end
        end), 50))
    aps:Finish()

    ------------------------------------------------------------------
    -- Windows
    ------------------------------------------------------------------
    local windows = CreateScrollPage(host)
    pages.windows = windows
    local ws = NewStack(windows)
    ws:Title(T("SETTINGS_WINDOWS", "Windows"),
        T("SETTINGS_WINDOWS_DESC", "Create and configure up to five independent meter windows."))

    local windowCount = SetFont(windows.content:CreateFontString(nil, "ARTWORK"), 10, MUTED)
    windowCount:SetPoint("TOPRIGHT", windows.content, "TOPRIGHT", -8, -5)

    local addWindow = MakeButton(windows.content, T("SETTINGS_ADD_WINDOW", "+ Add"), 116, 30, function()
        if #ns.windows >= ns.MAX_WINDOWS then return end
        ns.CreateNewWindow()
        if frame.Refresh then frame.Refresh() end
    end)
    addWindow:SetPoint("TOPLEFT", 4, -ws.y)
    ws.y = ws.y + 42

    local function MeterOptionsFlat()
        local out = {}
        for catIdx, cat in ipairs(ns.METER_CATEGORIES) do
            if ns.IsCategoryEnabled(catIdx) then
                for _, info in ipairs(cat.types) do
                    out[#out + 1] = info.type
                end
            end
        end
        return out
    end

    local function CycleMeter(win)
        local options = MeterOptionsFlat()
        if #options == 0 then return end
        local idx = 1
        for i, meterType in ipairs(options) do
            if meterType == win.GetMeterType() then idx = i; break end
        end
        win.SetMeterType(options[(idx % #options) + 1])
    end

    local function CycleSession(win)
        if #ns.SESSION_OPTIONS == 0 then return end
        local idx = 1
        for i, opt in ipairs(ns.SESSION_OPTIONS) do
            if opt.type == win.GetSessionType() then idx = i; break end
        end
        win.SetSessionType(ns.SESSION_OPTIONS[(idx % #ns.SESSION_OPTIONS) + 1].type)
    end

    local windowCards = {}
    for i = 1, ns.MAX_WINDOWS do
        local card = MakeCard(windows.content)
        card:SetPoint("TOPLEFT", 4, -ws.y)
        card:SetPoint("RIGHT", windows.content, "RIGHT", -8, 0)
        card:SetHeight(76)
        ws.y = ws.y + 86

        local name = SetFont(card:CreateFontString(nil, "ARTWORK"), 11, WHITE)
        name:SetPoint("TOPLEFT", 12, -10)
        name:SetText(string.format(T("SETTINGS_TAB_WINDOW", "Window %d"), i))

        local typeBtn = MakeButton(card, "", 180, 28, function()
            local win = ns.windows[i]
            if not win then return end
            CycleMeter(win)
            if frame.Refresh then frame.Refresh() end
        end)
        typeBtn:SetPoint("BOTTOMLEFT", 12, 10)

        local sessionBtn = MakeButton(card, "", 130, 28, function()
            local win = ns.windows[i]
            if not win then return end
            CycleSession(win)
            if frame.Refresh then frame.Refresh() end
        end)
        sessionBtn:SetPoint("LEFT", typeBtn, "RIGHT", 8, 0)

        local lockBtn = MakeButton(card, "", 104, 28, function()
            local win = ns.windows[i]
            if not win then return end
            win.cfg.locked = not win.cfg.locked
            if win.RefreshLockIcon then win.RefreshLockIcon() end
            if frame.Refresh then frame.Refresh() end
        end)
        lockBtn:SetPoint("LEFT", sessionBtn, "RIGHT", 8, 0)

        local removeBtn = MakeButton(card, T("SETTINGS_REMOVE_WINDOW", "- Remove"), 104, 28, function()
            if #ns.windows <= 1 then return end
            ns.RemoveWindow(i)
            if frame.Refresh then frame.Refresh() end
        end, true)
        removeBtn:SetPoint("LEFT", lockBtn, "RIGHT", 8, 0)

        card.name = name
        card.typeBtn = typeBtn
        card.sessionBtn = sessionBtn
        card.lockBtn = lockBtn
        card.removeBtn = removeBtn
        windowCards[i] = card
    end
    ws:Finish()

    ------------------------------------------------------------------
    -- Minimap
    ------------------------------------------------------------------
    local minimapPage = CreateScrollPage(host)
    pages.minimap = minimapPage
    local ms = NewStack(minimapPage)
    ms:Title(T("SETTINGS_MINIMAP", "Minimap"),
        T("SETTINGS_MINIMAP_DESC", "Control the TDM minimap button and its position."))

    ms:Section(T("SETTINGS_MINIMAP_BUTTON", "Minimap button"))

    Track(ms:Widget(ns.Widgets.CreateCheckbox(minimapPage.content,
        T("SETTINGS_MINIMAP_SHOW", "Show minimap button"),
        function()
            return not (ns.db.minimap and ns.db.minimap.hide)
        end,
        function(val)
            if ns.SetMinimapButtonShown then
                ns.SetMinimapButtonShown(val)
            end
        end), 24))

    Track(ms:Widget(ns.Widgets.CreateSlider(minimapPage.content,
        T("SETTINGS_MINIMAP_SCALE", "Button scale"),
        0.70, 1.50, 0.05,
        function()
            return (ns.db.minimap and ns.db.minimap.scale) or 1
        end,
        function(val)
            if ns.SetMinimapButtonScale then
                ns.SetMinimapButtonScale(val)
            end
        end), 50))

    local miniCard = MakeCard(minimapPage.content)
    miniCard:SetPoint("TOPLEFT", 4, -ms.y)
    miniCard:SetPoint("RIGHT", minimapPage.content, "RIGHT", -8, 0)
    miniCard:SetHeight(92)
    ms.y = ms.y + 102

    local miniInfo = SetFont(miniCard:CreateFontString(nil, "ARTWORK"), 10, MUTED)
    miniInfo:SetPoint("TOPLEFT", 12, -12)
    miniInfo:SetPoint("RIGHT", miniCard, "RIGHT", -12, 0)
    miniInfo:SetJustifyH("LEFT")
    miniInfo:SetText(T("SETTINGS_MINIMAP_HELP",
        "Left click opens TDM. Right click opens quick actions. Drag the button around the minimap to move it."))

    local restoreMini = MakeButton(miniCard,
        T("SETTINGS_MINIMAP_RESTORE", "Restore button"), 150, 30, function()
            if ns.SetMinimapButtonShown then ns.SetMinimapButtonShown(true) end
            if ns.ResetMinimapButtonPosition then ns.ResetMinimapButtonPosition() end
            if frame.Refresh then frame.Refresh() end
        end)
    restoreMini:SetPoint("BOTTOMLEFT", 12, 12)

    local toggleMini = MakeButton(miniCard,
        T("SETTINGS_MINIMAP_TOGGLE_METERS", "Show / Hide meters"), 170, 30, function()
            SetMetersVisible(not IsMetersVisible())
            if frame.Refresh then frame.Refresh() end
        end)
    toggleMini:SetPoint("LEFT", restoreMini, "RIGHT", 10, 0)

    ms:Section(T("SETTINGS_ADDON_COMPARTMENT", "Addon Compartment"))
    local compartmentInfo = SetFont(minimapPage.content:CreateFontString(nil, "ARTWORK"), 10, MUTED)
    compartmentInfo:SetPoint("TOPLEFT", 4, -ms.y)
    compartmentInfo:SetPoint("RIGHT", minimapPage.content, "RIGHT", -8, 0)
    compartmentInfo:SetJustifyH("LEFT")
    compartmentInfo:SetText(T("SETTINGS_ADDON_COMPARTMENT_DESC",
        "TDM also appears in Blizzard's Addon Compartment, so settings remain reachable even if the minimap button is hidden."))
    ms.y = ms.y + 54
    ms:Finish()

    ------------------------------------------------------------------
    -- Reports
    ------------------------------------------------------------------
    local reports = CreateScrollPage(host)
    pages.reports = reports
    local rs = NewStack(reports)
    rs:Title(T("REPORT", "Report"))

    rs:Section(T("REPORT", "Report"))
    local channelOptions = {
        { value = "AUTO",          label = T("REPORT_CHANNEL_AUTO", "Auto (group)") },
        { value = "INSTANCE_CHAT", label = T("REPORT_CHANNEL_INSTANCE", "Instance") },
        { value = "PARTY",         label = T("REPORT_CHANNEL_PARTY", "Party") },
        { value = "RAID",          label = T("REPORT_CHANNEL_RAID", "Raid") },
        { value = "GUILD",         label = T("REPORT_CHANNEL_GUILD", "Guild") },
        { value = "WHISPER",       label = T("REPORT_CHANNEL_WHISPER", "Whisper") },
        { value = "DEBUG",         label = T("REPORT_CHANNEL_SELF", "Print to self") },
    }

    Track(rs:Widget(ns.Widgets.CreateDropdown(reports.content, T("SETTINGS_REPORT_CHANNEL", "Report Channel"),
        channelOptions,
        function() return ns.db.reportChannel end,
        function(val) ns.db.reportChannel = val end), 30))

    Track(rs:Widget(ns.Widgets.CreateSlider(reports.content, T("SETTINGS_REPORT_LINES", "Report Lines"),
        1, 20, 1,
        function() return ns.db.reportLines end,
        function(val) ns.db.reportLines = val end), 50))

    local reportInfo = SetFont(reports.content:CreateFontString(nil, "ARTWORK"), 10, MUTED)
    reportInfo:SetPoint("TOPLEFT", 4, -rs.y)
    reportInfo:SetPoint("RIGHT", reports.content, "RIGHT", -8, 0)
    reportInfo:SetJustifyH("LEFT")
    reportInfo:SetText(T("REPORT_CHANNEL_RESTRICTED",
        "Say and Yell are restricted by the game; use a group channel for multi-line reports."))
    rs.y = rs.y + 45
    rs:Finish()

    ------------------------------------------------------------------
    -- Refresh
    ------------------------------------------------------------------
    frame.Refresh = function()
        for _, widget in ipairs(refreshables) do
            if widget.Refresh then widget.Refresh() end
        end

        local visible = IsMetersVisible()
        visValue:SetText(visible and T("SETTINGS_VISIBLE", "Visible") or T("SETTINGS_HIDDEN", "Hidden"))
        visValue:SetTextColor(visible and WHITE[1] or RED[1], visible and WHITE[2] or RED[2], visible and WHITE[3] or RED[3])
        windowValue:SetText(string.format("%d / %d", #ns.windows, ns.MAX_WINDOWS))
        skinValue:SetText(ActiveSkinLabel())

        visibilityBtn.label:SetText(visible
            and T("SETTINGS_HIDE_METERS", "Hide meters")
            or T("SETTINGS_SHOW_METERS", "Show meters"))
        lockAllBtn.label:SetText(AreAllWindowsLocked() and T("UNLOCK", "Unlock") or T("LOCK", "Lock"))

        for i, row in ipairs(overviewRows) do
            local win = ns.windows[i]
            row:SetShown(win ~= nil)
            if win then
                row.typeFS:SetText(MeterLabel(win))
                row.sessionFS:SetText(SessionLabel(win))
                row.lockFS:SetText(win.cfg.locked and T("LOCK", "Locked") or T("UNLOCK", "Unlocked"))
            end
        end

        windowCount:SetText(string.format(T("SETTINGS_WINDOW_COUNT", "Windows: %d / %d"), #ns.windows, ns.MAX_WINDOWS))
        addWindow:SetEnabled(#ns.windows < ns.MAX_WINDOWS)
        addWindow:SetAlpha(#ns.windows < ns.MAX_WINDOWS and 1 or 0.4)

        for i, card in ipairs(windowCards) do
            local win = ns.windows[i]
            card:SetShown(win ~= nil)
            if win then
                card.typeBtn.label:SetText(MeterLabel(win))
                card.sessionBtn.label:SetText(SessionLabel(win))
                card.lockBtn.label:SetText(win.cfg.locked and T("UNLOCK", "Unlock") or T("LOCK", "Lock"))
                card.removeBtn:SetEnabled(#ns.windows > 1)
                card.removeBtn:SetAlpha(#ns.windows > 1 and 1 or 0.35)
            end
        end

        SetPage(activePage)
    end

    frame.SetPage = SetPage
    SetPage("dashboard")
    frame:Refresh()
    frame:Hide()
    return frame
end

local function EnsureSettings()
    if not settingsFrame then
        settingsFrame = CreateSettingsPanelV2()
        ns.SettingsV2 = settingsFrame
    end
    return settingsFrame
end

function ns.OpenSettings(pageKey)
    local frame = EnsureSettings()
    frame:Refresh()
    if pageKey and frame.SetPage then frame.SetPage(pageKey) end
    frame:Show()
end

function ns.ToggleSettings(pageKey)
    local frame = EnsureSettings()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Refresh()
        if pageKey and frame.SetPage then frame.SetPage(pageKey) end
        frame:Show()
    end
end

function ns.RefreshSettingsV2()
    if settingsFrame and settingsFrame.Refresh then settingsFrame:Refresh() end
end

if ns.OnSkinChanged then
    ns.OnSkinChanged(function()
        if settingsFrame and settingsFrame.Refresh then settingsFrame:Refresh() end
    end)
end
