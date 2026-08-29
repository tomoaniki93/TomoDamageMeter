local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Visual V2
--
-- Premium TDM chrome layered on top of the existing meter implementation.
-- This module deliberately does not own data, rows, scrolling or input.  It
-- decorates each window once with static textures and refreshes only when a
-- skin/accent changes.  No ticker and no permanent OnUpdate are introduced.
----------------------------------------------------------------------

local TEX_ROOT = "Interface\\AddOns\\TomoDamageMeter\\Assets\\Textures\\"
local TEX_GLOW = TEX_ROOT .. "TDM_FrameGlow_128"
local TEX_HEADER = TEX_ROOT .. "TDM_HeaderSheen_256x32"
local TEX_ICON = TEX_ROOT .. "TDM_Icon_64"

local BRAND_R, BRAND_G, BRAND_B = 0.96, 0.035, 0.085
local decorated = setmetatable({}, { __mode = "k" })

local function IsTDMRedSkin()
    return not ns.db or (ns.db.skin or "DARK") == "DARK"
end

local function ChromeColor(kind)
    -- The settings window is the TDM product shell, not part of the selected
    -- meter skin. It must always keep the red/white TDM identity.
    if kind == "settings" or IsTDMRedSkin() then
        return BRAND_R, BRAND_G, BRAND_B
    end
    local c = ns.ACCENT or { BRAND_R, BRAND_G, BRAND_B }
    return c[1] or BRAND_R, c[2] or BRAND_G, c[3] or BRAND_B
end

local function HeaderHeight(kind)
    if kind == "settings" then return 49 end
    if kind == "meter" then return ns.HEADER_COMBINED or 37 end
    return 27
end

local function MakeLine(parent, layer, sublevel)
    local tex = parent:CreateTexture(nil, layer or "OVERLAY", nil, sublevel or 0)
    tex:SetTexture(ns.FLAT)
    return tex
end

local function RefreshDecoration(frame)
    local d = decorated[frame]
    if not d then return end

    local r, g, b = ChromeColor(d.kind)
    d.top:SetVertexColor(r, g, b, 0.98)
    d.left:SetVertexColor(r * 0.68, g * 0.68, b * 0.68, 0.78)
    d.right:SetVertexColor(r * 0.68, g * 0.68, b * 0.68, 0.78)
    d.bottom:SetVertexColor(r * 0.48, g * 0.48, b * 0.48, 0.70)
    d.separator:SetVertexColor(r, g, b, 0.52)
    d.cap:SetVertexColor(1, 1, 1, 0.60)

    if d.glow then
        -- Glow artwork itself is red. Keep it neutral rather than attempting to
        -- hue-shift it with SetVertexColor (multiplication cannot turn red art
        -- cleanly into blue/green). Non-TDM skins simply get less glow.
        d.glow:SetVertexColor(1, 1, 1, 1)
        d.glow:SetAlpha((d.kind == "settings" or IsTDMRedSkin()) and 0.34 or 0.14)
    end
    if d.sheen then
        d.sheen:SetVertexColor(1, 1, 1, 1)
        d.sheen:SetAlpha((d.kind == "settings" or IsTDMRedSkin()) and 0.44 or 0.28)
    end

    if frame.SetBackdropColor then
        if d.kind == "settings" then
            -- Fixed product-shell background: changing a meter skin must never
            -- recolour or restyle the options panel.
            frame:SetBackdropColor(0.025, 0.025, 0.030, 0.98)
        elseif IsTDMRedSkin() then
            local alpha = ns.db and ns.db.bgAlpha or (ns.BG and ns.BG[4]) or 0.90
            frame:SetBackdropColor(0.008, 0.008, 0.012, alpha)
        end
    end
    if frame.SetBackdropBorderColor then
        if d.kind == "settings" then
            frame:SetBackdropBorderColor(BRAND_R * 0.55, BRAND_G * 0.55, BRAND_B * 0.55, 0.90)
        else
            frame:SetBackdropBorderColor(r * 0.46, g * 0.46, b * 0.46, 0.86)
        end
    end
end

function ns.DecorateTDMFrame(frame, kind)
    if not frame then return end
    if decorated[frame] then
        RefreshDecoration(frame)
        return
    end

    kind = kind or "panel"

    -- Glow extends outside the actual frame. It is most visible at the four
    -- corners and is intentionally subtle enough not to look like a neon box.
    local glow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    glow:SetTexture(TEX_GLOW)
    glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -7, 7)
    glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 7, -7)
    glow:SetBlendMode("ADD")

    -- The visual layer never receives mouse input. It only carries static
    -- border/sheen textures, so normal header buttons and dragging stay intact.
    local layer = CreateFrame("Frame", nil, frame)
    layer:SetAllPoints(frame)
    layer:SetFrameLevel(frame:GetFrameLevel() + 24)

    local top = MakeLine(layer)
    top:SetHeight(2)
    top:SetPoint("TOPLEFT", layer, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", layer, "TOPRIGHT", 0, 0)

    local left = MakeLine(layer)
    left:SetWidth(1)
    left:SetPoint("TOPLEFT", layer, "TOPLEFT", 0, -2)
    left:SetPoint("BOTTOMLEFT", layer, "BOTTOMLEFT", 0, 0)

    local right = MakeLine(layer)
    right:SetWidth(1)
    right:SetPoint("TOPRIGHT", layer, "TOPRIGHT", 0, -2)
    right:SetPoint("BOTTOMRIGHT", layer, "BOTTOMRIGHT", 0, 0)

    local bottom = MakeLine(layer)
    bottom:SetHeight(1)
    bottom:SetPoint("BOTTOMLEFT", layer, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", layer, "BOTTOMRIGHT", 0, 0)

    local sepY = HeaderHeight(kind)
    local separator = MakeLine(layer)
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", layer, "TOPLEFT", 1, -sepY)
    separator:SetPoint("TOPRIGHT", layer, "TOPRIGHT", -1, -sepY)

    -- White hot-cap: a tiny highlight on the red top border, matching the
    -- metallic/red identity of the TDM logo without using animation.
    local cap = MakeLine(layer)
    cap:SetSize(kind == "settings" and 92 or 46, 1)
    cap:SetPoint("TOPLEFT", layer, "TOPLEFT", 8, -1)

    local sheen = layer:CreateTexture(nil, "ARTWORK", nil, -2)
    sheen:SetTexture(TEX_HEADER)
    sheen:SetPoint("TOPLEFT", layer, "TOPLEFT", 1, -2)
    sheen:SetPoint("TOPRIGHT", layer, "TOPRIGHT", -1, -2)
    sheen:SetHeight(math.max(18, sepY - 2))
    sheen:SetBlendMode("ADD")

    local watermark
    if kind == "meter" then
        watermark = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        watermark:SetTexture(TEX_ICON)
        watermark:SetSize(52, 52)
        watermark:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 7)
        watermark:SetAlpha(0.035)
    elseif kind == "breakdown" or kind == "recap" then
        watermark = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        watermark:SetTexture(TEX_ICON)
        watermark:SetSize(44, 44)
        watermark:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 7)
        watermark:SetAlpha(0.028)
    end

    decorated[frame] = {
        kind = kind,
        layer = layer,
        glow = glow,
        top = top,
        left = left,
        right = right,
        bottom = bottom,
        separator = separator,
        cap = cap,
        sheen = sheen,
        watermark = watermark,
    }

    RefreshDecoration(frame)
end

function ns.RefreshTDMVisuals()
    for frame in pairs(decorated) do
        RefreshDecoration(frame)
    end
end

----------------------------------------------------------------------
-- Main meter windows
----------------------------------------------------------------------

if ns.CreateMeterWindow and not ns._tdmVisualWrappedCreateMeter then
    ns._tdmVisualWrappedCreateMeter = true
    local CreateMeterWindow = ns.CreateMeterWindow
    ns.CreateMeterWindow = function(cfg)
        local win = CreateMeterWindow(cfg)
        if win and win.frame then
            ns.DecorateTDMFrame(win.frame, "meter")

            if win.RefreshSkin then
                local RefreshSkin = win.RefreshSkin
                win.RefreshSkin = function(...)
                    local out = { RefreshSkin(...) }
                    ns.DecorateTDMFrame(win.frame, "meter")
                    return unpack(out)
                end
            end
            if win.RefreshAccentColor then
                local RefreshAccentColor = win.RefreshAccentColor
                win.RefreshAccentColor = function(...)
                    local out = { RefreshAccentColor(...) }
                    ns.DecorateTDMFrame(win.frame, "meter")
                    return unpack(out)
                end
            end
        end
        return win
    end
end

----------------------------------------------------------------------
-- Singleton detail windows. Their internal constructors are local, so the
-- public Show* calls are the safest place to decorate immediately after first
-- creation. Repeated calls are O(1): DecorateTDMFrame only refreshes colours.
----------------------------------------------------------------------

local function WrapShow(apiName, globalFrameName, kind)
    local original = ns[apiName]
    if type(original) ~= "function" then return end
    local guardKey = "_tdmVisualWrapped_" .. apiName
    if ns[guardKey] then return end
    ns[guardKey] = true

    ns[apiName] = function(...)
        local out = { original(...) }
        ns.DecorateTDMFrame(_G[globalFrameName], kind)
        return unpack(out)
    end
end

WrapShow("ShowSpellBreakdown", "TomoDMSpellBreakdown", "breakdown")
WrapShow("ShowTargetSpells", "TomoDMSpellBreakdown", "breakdown")
WrapShow("ShowTargetBreakdown", "TomoDMTargetBreakdown", "breakdown")
WrapShow("ShowRunRecap", "TomoDMRunRecap", "recap")
WrapShow("ShowDeathRecap", "TomoDMDeathRecap", "recap")

if ns.OnSkinChanged then
    ns.OnSkinChanged(function()
        ns.RefreshTDMVisuals()
    end)
end
