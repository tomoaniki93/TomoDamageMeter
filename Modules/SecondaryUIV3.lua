local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Secondary UI V3 / Patch 12B
--
-- Visual-system harmonisation for the analysis windows introduced before
-- Meter UI V3. The underlying feature modules remain untouched; this file
-- decorates their already-created frames after their normal public Show/Open
-- entry points run.
--
-- No combat collection, CLEU parser, ticker or permanent OnUpdate is added.
----------------------------------------------------------------------

local TEX_ROOT   = "Interface\\AddOns\\TomoDamageMeter\\Assets\\Textures\\"
local TEX_LOGO   = TEX_ROOT .. "TDM_Icon_64"
local TEX_HEADER = TEX_ROOT .. "TDM_HeaderSheen_256x32"
local TEX_GLOW   = TEX_ROOT .. "TDM_FrameGlow_128"
local TEX_ROW    = TEX_ROOT .. "TDM_RowSheen_256x32"

local RED = { 0.96, 0.035, 0.085 }
local DARK = { 0.018, 0.018, 0.024 }
local DARK_2 = { 0.050, 0.050, 0.062 }
local BORDER = { 0.32, 0.32, 0.36 }

local BADGES = {
    enUS = { spell = "SPELL ANALYSIS", target = "SEGMENTS / TARGETS", death = "DEATH RECAP", run = "RUN SCORECARD", history = "RUN ARCHIVE", pulls = "A / B PULL LAB", performance = "PERFORMANCE" },
    frFR = { spell = "ANALYSE SORTS", target = "SEGMENTS / CIBLES", death = "RÉCAP DÉCÈS", run = "BILAN RUN", history = "HISTORIQUE", pulls = "COMPARAISON A / B", performance = "PERFORMANCE" },
    deDE = { spell = "ZAUBERANALYSE", target = "SEGMENTE / ZIELE", death = "TODESRÜCKBLICK", run = "RUN-ÜBERSICHT", history = "VERLAUF", pulls = "PULL A / B", performance = "LEISTUNG" },
    esES = { spell = "ANÁLISIS HECHIZOS", target = "SEGMENTOS / OBJETIVOS", death = "RESUMEN MUERTES", run = "RESUMEN RUN", history = "HISTORIAL", pulls = "PULL A / B", performance = "RENDIMIENTO" },
    itIT = { spell = "ANALISI INCANTESIMI", target = "SEGMENTI / BERSAGLI", death = "RIEPILOGO MORTI", run = "RIEPILOGO RUN", history = "CRONOLOGIA", pulls = "PULL A / B", performance = "PRESTAZIONI" },
    ptBR = { spell = "ANÁLISE DE MAGIAS", target = "SEGMENTOS / ALVOS", death = "RESUMO DE MORTES", run = "RESUMO DA RUN", history = "HISTÓRICO", pulls = "PULL A / B", performance = "DESEMPENHO" },
    ruRU = { spell = "АНАЛИЗ ЗАКЛИНАНИЙ", target = "СЕГМЕНТЫ / ЦЕЛИ", death = "ОБЗОР СМЕРТЕЙ", run = "ИТОГ ЗАБЕГА", history = "ИСТОРИЯ", pulls = "ПУЛЛ A / B", performance = "ЭФФЕКТИВНОСТЬ" },
    zhCN = { spell = "技能分析", target = "战斗段 / 目标", death = "死亡回顾", run = "副本总结", history = "副本历史", pulls = "战斗 A / B", performance = "表现" },
    zhTW = { spell = "技能分析", target = "戰鬥段 / 目標", death = "死亡回顧", run = "副本總結", history = "副本歷史", pulls = "戰鬥 A / B", performance = "表現" },
}
BADGES.esMX = BADGES.esES
local B = BADGES[GetLocale()] or BADGES.enUS

local SPECS = {
    TomoDMSpellBreakdown = {
        badge = B.spell,
        icon = function() return ns.TEX_DETAILS end,
        watermark = "SPELLS",
    },
    TomoDMTargetBreakdown = {
        badge = B.target,
        badgeRight = -146,
        icon = function() return ns.TEX_TARGET end,
        watermark = "TARGETS",
    },
    TomoDMDeathRecap = {
        badge = B.death,
        icon = function() return ns.TEX_CLOSE end,
        watermark = "RECAP",
    },
    TomoDMRunRecap = {
        badge = B.run,
        icon = function() return ns.TEX_DETAILS end,
        watermark = "RUN",
    },
    TomoDMRunHistory = {
        badge = B.history,
        icon = function() return ns.TEX_DETAILS end,
        watermark = "HISTORY",
    },
    TomoDMPullCompare = {
        badge = B.pulls,
        icon = function() return ns.TEX_TARGET end,
        watermark = "COMPARE",
    },
    TomoDMRunCompare = {
        badge = B.performance,
        icon = function() return ns.TEX_DETAILS end,
        watermark = "PERF",
    },
}

local function Accent(alpha)
    local a = ns.ACCENT
    if a then
        return a[1] or RED[1], a[2] or RED[2], a[3] or RED[3], alpha or a[4] or 1
    end
    return RED[1], RED[2], RED[3], alpha or 1
end

local function Font(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.GetFont and ns.GetFont() or STANDARD_TEXT_FONT, size, "OUTLINE")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.65)
    if color then fs:SetTextColor(unpack(color)) end
    return fs
end

local function SafeSize(region)
    local okW, w = pcall(region.GetWidth, region)
    local okH, h = pcall(region.GetHeight, region)
    if not okW or not okH then return 0, 0 end
    return tonumber(w) or 0, tonumber(h) or 0
end

local function IsButton(frame)
    return frame and frame.GetObjectType and frame:GetObjectType() == "Button"
end

local function MakeBorderTexture(frame, point1, point2, w, h)
    local tex = frame:CreateTexture(nil, "OVERLAY", nil, 6)
    tex:SetTexture(ns.FLAT or "Interface\\BUTTONS\\WHITE8X8")
    tex:SetPoint(unpack(point1))
    tex:SetPoint(unpack(point2))
    if w then tex:SetWidth(w) end
    if h then tex:SetHeight(h) end
    return tex
end

local function EnsureShell(frame, spec)
    if not frame or frame._tdmSecondaryV3 then return end
    frame._tdmSecondaryV3 = true

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = ns.FLAT or "Interface\\BUTTONS\\WHITE8X8",
            edgeFile = ns.FLAT or "Interface\\BUTTONS\\WHITE8X8",
            edgeSize = 1,
        })
        frame:SetBackdropColor(DARK[1], DARK[2], DARK[3], 0.975)
        frame:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 0.92)
    end

    local glow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    glow:SetTexture(TEX_GLOW)
    glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -7, 7)
    glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 7, -7)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.20)
    frame._tdmV3Glow = glow

    local topAccent = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    topAccent:SetTexture(ns.FLAT or "Interface\\BUTTONS\\WHITE8X8")
    topAccent:SetHeight(2)
    topAccent:SetPoint("TOPLEFT", frame, "TOPLEFT")
    topAccent:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    frame._tdmV3TopAccent = topAccent

    local hotCap = frame:CreateTexture(nil, "OVERLAY", nil, 8)
    hotCap:SetTexture(ns.FLAT or "Interface\\BUTTONS\\WHITE8X8")
    hotCap:SetSize(52, 1)
    hotCap:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -1)
    hotCap:SetVertexColor(1, 1, 1, 0.56)

    local headerSheen = frame:CreateTexture(nil, "BACKGROUND", nil, 4)
    headerSheen:SetTexture(TEX_HEADER)
    headerSheen:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -2)
    headerSheen:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -2)
    headerSheen:SetHeight(30)
    headerSheen:SetAlpha(0.22)
    frame._tdmV3HeaderSheen = headerSheen

    local identity = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    identity:SetSize(24, 22)
    identity:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -5)
    identity:SetFrameLevel(frame:GetFrameLevel() + 35)
    identity:SetBackdrop({ bgFile = ns.FLAT, edgeFile = ns.FLAT, edgeSize = 1 })
    identity:SetBackdropColor(0.075, 0.075, 0.090, 0.98)
    identity:SetBackdropBorderColor(0.30, 0.30, 0.34, 0.95)
    frame._tdmV3Identity = identity

    local icon = identity:CreateTexture(nil, "ARTWORK")
    icon:SetSize(13, 13)
    icon:SetPoint("CENTER")
    local texture = spec.icon and spec.icon()
    icon:SetTexture(texture or TEX_LOGO)
    icon:SetVertexColor(1, 1, 1, 0.92)
    frame._tdmV3IdentityIcon = icon

    local badge = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    badge:SetHeight(18)
    badge:SetPoint("TOPRIGHT", frame, "TOPRIGHT", spec.badgeRight or -62, -7)
    badge:SetWidth(math.max(76, (#(spec.badge or "TDM") * 6) + 18))
    badge:SetFrameLevel(frame:GetFrameLevel() + 34)
    badge:SetBackdrop({ bgFile = ns.FLAT, edgeFile = ns.FLAT, edgeSize = 1 })
    badge:SetBackdropColor(0.055, 0.055, 0.068, 0.98)
    badge:SetBackdropBorderColor(0.25, 0.25, 0.29, 0.88)
    frame._tdmV3Badge = badge

    local badgeAccent = badge:CreateTexture(nil, "OVERLAY")
    badgeAccent:SetTexture(ns.FLAT)
    badgeAccent:SetWidth(2)
    badgeAccent:SetPoint("TOPLEFT")
    badgeAccent:SetPoint("BOTTOMLEFT")
    frame._tdmV3BadgeAccent = badgeAccent

    local badgeFS = Font(badge, 8, { 0.82, 0.82, 0.86 }, "CENTER")
    badgeFS:SetPoint("CENTER", 1, ns.GetFontNudge and ns.GetFontNudge() or 0)
    badgeFS:SetText(spec.badge or "TDM")
    frame._tdmV3BadgeFS = badgeFS

    local wmLogo = frame:CreateTexture(nil, "BACKGROUND", nil, -4)
    wmLogo:SetTexture(TEX_LOGO)
    wmLogo:SetSize(66, 66)
    wmLogo:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 8)
    wmLogo:SetAlpha(0.024)
    frame._tdmV3WatermarkLogo = wmLogo

    local wmText = Font(frame, 20, { 1, 1, 1 }, "RIGHT")
    wmText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 9)
    wmText:SetText(spec.watermark or "TDM")
    wmText:SetAlpha(0.035)
    frame._tdmV3WatermarkText = wmText
end

local function StyleScrollbar(scrollbar)
    if not scrollbar or scrollbar._tdmV3Scrollbar then return end
    if not scrollbar.Track then return end
    scrollbar._tdmV3Scrollbar = true

    local track = scrollbar.Track
    if track.Begin then track.Begin:SetAlpha(0) end
    if track.End then track.End:SetAlpha(0) end
    if track.Middle then
        track.Middle:SetVertexColor(0.10, 0.10, 0.13, 0.55)
    end

    local thumb = track.Thumb or scrollbar.Thumb
    if thumb then
        if thumb.SetVertexColor then
            local r, g, b = Accent(0.80)
            thumb:SetVertexColor(r, g, b, 0.80)
        end
    end

    if scrollbar.Back then scrollbar.Back:SetAlpha(0) end
    if scrollbar.Forward then scrollbar.Forward:SetAlpha(0) end
end

local function StyleCompactButton(button)
    if not button or button._tdmV3Button then return end
    local w, h = SafeSize(button)
    if w <= 0 or h <= 0 or h > 38 or w > 260 then return end
    button._tdmV3Button = true

    local bg = button:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetTexture(ns.FLAT)
    bg:SetAllPoints()
    bg:SetVertexColor(DARK_2[1], DARK_2[2], DARK_2[3], 0.82)
    button._tdmV3ButtonBG = bg

    local line = button:CreateTexture(nil, "ARTWORK")
    line:SetTexture(ns.FLAT)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 0)
    line:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 0)
    local ar, ag, ab = Accent(0.52)
    line:SetVertexColor(ar, ag, ab, 0.52)
    button._tdmV3ButtonLine = line

    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetTexture(ns.FLAT)
    hover:SetAllPoints()
    hover:SetVertexColor(1, 1, 1, 0.055)
end

local function StyleRow(frame, index)
    if not frame or frame._tdmV3Row then return end
    local w, h = SafeSize(frame)
    if w < 180 or h < 17 or h > 36 then return end
    frame._tdmV3Row = true

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -2)
    bg:SetTexture(ns.FLAT)
    bg:SetAllPoints()
    local alpha = (index or 1) % 2 == 0 and 0.095 or 0.055
    bg:SetVertexColor(1, 1, 1, alpha)
    frame._tdmV3RowBG = bg

    local sheen = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    sheen:SetTexture(TEX_ROW)
    sheen:SetAllPoints()
    sheen:SetAlpha(0.045)
    frame._tdmV3RowSheen = sheen

    if IsButton(frame) then
        local hover = frame:CreateTexture(nil, "HIGHLIGHT")
        hover:SetTexture(ns.FLAT)
        hover:SetAllPoints()
        hover:SetVertexColor(1, 1, 1, 0.050)
    end
end

local function Walk(frame, depth, indexState)
    if not frame or depth > 6 or not frame.GetChildren then return end
    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        if child then
            StyleScrollbar(child)
            local w, h = SafeSize(child)

            if IsButton(child) then
                if w >= 180 and h >= 17 and h <= 36 then
                    indexState.n = indexState.n + 1
                    StyleRow(child, indexState.n)
                else
                    StyleCompactButton(child)
                end
            elseif w >= 260 and h >= 17 and h <= 32 then
                indexState.n = indexState.n + 1
                StyleRow(child, indexState.n)
            end

            Walk(child, depth + 1, indexState)
        end
    end
end

local function RefreshShell(frame)
    if not frame or not frame._tdmSecondaryV3 then return end
    local r, g, b = Accent(1)

    if frame._tdmV3TopAccent then frame._tdmV3TopAccent:SetVertexColor(r, g, b, 0.98) end
    if frame._tdmV3BadgeAccent then frame._tdmV3BadgeAccent:SetVertexColor(r, g, b, 0.95) end
    if frame._tdmV3Glow then
        frame._tdmV3Glow:SetVertexColor(r, g, b, 0.52)
        frame._tdmV3Glow:SetAlpha(0.18)
    end

    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(0.30 + r * 0.14, 0.30 + g * 0.08, 0.33 + b * 0.08, 0.90)
    end
end

local function ApplyToFrame(name)
    local frame = _G[name]
    local spec = SPECS[name]
    if not frame or not spec then return end

    EnsureShell(frame, spec)
    RefreshShell(frame)
    Walk(frame, 0, { n = 0 })
end

function ns.ApplySecondaryUIV3(frameOrName)
    if type(frameOrName) == "string" then
        ApplyToFrame(frameOrName)
        return
    end
    if not frameOrName then return end
    local name = frameOrName.GetName and frameOrName:GetName()
    if name and SPECS[name] then
        EnsureShell(frameOrName, SPECS[name])
        RefreshShell(frameOrName)
        Walk(frameOrName, 0, { n = 0 })
    end
end

local function ApplyVisibleFrames()
    for name in pairs(SPECS) do
        local frame = _G[name]
        if frame and frame:IsShown() then
            ApplyToFrame(name)
        end
    end
end

local function HookPublic(name, frameNames)
    if type(ns[name]) ~= "function" then return end
    hooksecurefunc(ns, name, function()
        for _, frameName in ipairs(frameNames) do
            ApplyToFrame(frameName)
        end
    end)
end

-- Existing analysis-window entry points. The hooks run only after the feature's
-- own function completes, so no data read or control flow is changed here.
HookPublic("ShowSpellBreakdown", { "TomoDMSpellBreakdown" })
HookPublic("ShowTargetBreakdown", { "TomoDMTargetBreakdown" })
HookPublic("ShowSegmentEnemies", { "TomoDMTargetBreakdown" })
HookPublic("ShowDeathRecap", { "TomoDMDeathRecap" })
HookPublic("ShowRunRecap", { "TomoDMRunRecap", "TomoDMRunCompare" })
HookPublic("RefreshRunCompare", { "TomoDMRunCompare" })
HookPublic("OpenRunHistory", { "TomoDMRunHistory" })
HookPublic("ToggleRunHistory", { "TomoDMRunHistory" })
HookPublic("RefreshRunHistory", { "TomoDMRunHistory" })
HookPublic("OpenPullCompare", { "TomoDMPullCompare" })
HookPublic("TogglePullCompare", { "TomoDMPullCompare" })

-- Pull Compare adds a Compare button to Target Breakdown lazily. Styling the
-- target frame again after this integration runs catches that new control.
HookPublic("OpenPullCompare", { "TomoDMTargetBreakdown" })

if ns.OnSkinChanged then
    ns.OnSkinChanged(function()
        ApplyVisibleFrames()
    end)
end

-- Exposed for diagnostics / manual refresh without forcing any window open.
function ns.RefreshSecondaryUIV3()
    ApplyVisibleFrames()
end
