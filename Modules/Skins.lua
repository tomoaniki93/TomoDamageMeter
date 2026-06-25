local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Skins: named visual presets + LibSharedMedia-backed bar textures
----------------------------------------------------------------------

-- LibSharedMedia hookup (soft: the addon still works if LSM is ever absent)
local LSM = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
ns.LSM = LSM

local TEX_PATH = "Interface\\AddOns\\TomoDamageMeter\\Assets\\Textures\\"

-- Bundled statusbar textures, registered into LSM so they show up in the
-- texture picker alongside any textures other addons have registered.
ns.TEX_FLAT   = "Tomo Flat"
ns.TEX_SMOOTH = "Tomo Smooth"
ns.TEX_GLOSSY = "Tomo Glossy"

if LSM then
    LSM:Register("statusbar", ns.TEX_FLAT,   ns.FLAT)
    LSM:Register("statusbar", ns.TEX_SMOOTH, TEX_PATH .. "statusbar-smooth")
    LSM:Register("statusbar", ns.TEX_GLOSSY, TEX_PATH .. "statusbar-glossy")
end

----------------------------------------------------------------------
-- Texture resolution
----------------------------------------------------------------------

-- Resolve the active bar texture (DB key -> file path). Falls back to the
-- flat WHITE8X8 fill when LSM is missing or the key is unknown.
function ns.GetBarTexture()
    local lsm = ns.LSM
    local key = ns.db and ns.db.barTexture
    if lsm and key then
        local path = lsm:Fetch("statusbar", key, true) -- noDefault = true
        if path then return path end
    end
    return ns.FLAT
end

-- Option list for the texture dropdown: every statusbar registered in LSM,
-- sorted alphabetically. Falls back to the bundled flat fill if LSM is gone.
function ns.GetTextureList()
    local out = {}
    local lsm = ns.LSM
    if lsm then
        for _, key in ipairs(lsm:List("statusbar")) do
            out[#out + 1] = { value = key, label = key }
        end
    end
    if #out == 0 then
        out[1] = { value = ns.TEX_FLAT, label = ns.TEX_FLAT }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

----------------------------------------------------------------------
-- Skin registry
----------------------------------------------------------------------
-- Each preset bundles the structural look (background, header, border,
-- accent, bar fill texture/alpha and row density). Picking a skin in the
-- options seeds the individual settings (accent, bg opacity, bar height,
-- texture) so the user can still fine-tune on top of any preset.

ns.SKINS = {
    {
        key = "DARK", name = "SKIN_DARK",
        bg          = { 0.00, 0.00, 0.00 }, bgAlpha = 0.80,
        headerBg    = { 0.04, 0.08, 0.16, 1.00 },
        headerHover = { 0.10, 0.22, 0.44, 0.40 },
        border      = { 0.25, 0.25, 0.30, 0.70 },
        scrollThumb = { 0.15, 0.32, 0.60 },
        accent      = { 0.33, 0.70, 0.00 },
        barTexture  = "Tomo Flat",
        barAlpha    = 0.50,
        barSpacing  = 1,
        barHeight   = 21,
    },
    {
        key = "NEON", name = "SKIN_NEON",
        bg          = { 0.012, 0.008, 0.024 }, bgAlpha = 0.92,
        headerBg    = { 0.051, 0.027, 0.086, 1.00 },
        headerHover = { 0.80, 0.267, 1.00, 0.16 },
        border      = { 0.80, 0.267, 1.00, 0.35 },
        scrollThumb = { 0.55, 0.20, 0.85 },
        accent      = { 0.80, 0.267, 1.00 },
        barTexture  = "Tomo Smooth",
        barAlpha    = 0.62,
        barSpacing  = 1,
        barHeight   = 21,
    },
    {
        key = "MINIMAL", name = "SKIN_MINIMAL",
        bg          = { 0.027, 0.027, 0.035 }, bgAlpha = 0.85,
        headerBg    = { 0.05, 0.05, 0.06, 0.55 },
        headerHover = { 1.00, 1.00, 1.00, 0.06 },
        border      = { 1.00, 1.00, 1.00, 0.05 },
        scrollThumb = { 0.45, 0.45, 0.50 },
        accent      = { 0.60, 0.63, 0.66 },
        barTexture  = "Tomo Flat",
        barAlpha    = 0.45,
        barSpacing  = 0,
        barHeight   = 16,
    },
    {
        key = "GLOSSY", name = "SKIN_GLOSSY",
        bg          = { 0.04, 0.04, 0.06 }, bgAlpha = 0.90,
        headerBg    = { 0.09, 0.09, 0.12, 1.00 },
        headerHover = { 0.91, 0.70, 0.23, 0.14 },
        border      = { 0.49, 0.49, 0.54, 0.55 },
        scrollThumb = { 0.55, 0.45, 0.20 },
        accent      = { 0.91, 0.70, 0.23 },
        barTexture  = "Tomo Glossy",
        barAlpha    = 0.90,
        barSpacing  = 1,
        barHeight   = 21,
    },
}

ns.SKIN_BY_KEY = {}
for _, s in ipairs(ns.SKINS) do
    ns.SKIN_BY_KEY[s.key] = s
end

-- Option list for the skin dropdown (localized display names).
function ns.GetSkinList()
    local L = ns.L
    local out = {}
    for _, s in ipairs(ns.SKINS) do
        out[#out + 1] = { value = s.key, label = (L and L[s.name]) or s.key }
    end
    return out
end

----------------------------------------------------------------------
-- Skin application
----------------------------------------------------------------------

local skinCallbacks = {}

function ns.OnSkinChanged(fn)
    skinCallbacks[#skinCallbacks + 1] = fn
end

local function copy3(dst, src)
    dst[1], dst[2], dst[3] = src[1], src[2], src[3]
end

local function copy4(dst, src)
    dst[1], dst[2], dst[3], dst[4] = src[1], src[2], src[3], src[4]
end

-- Apply skin `key`. When `seedDefaults` is true (the user picked a skin in
-- the options) the per-setting DB values (accent, bg opacity, bar height,
-- bar texture) are overwritten with the preset's values. When false (the
-- login re-apply) only the structural look is set and saved user tweaks are
-- preserved.
function ns.ApplySkin(key, seedDefaults)
    local skin = ns.SKIN_BY_KEY[key]
    if not skin then
        skin = ns.SKIN_BY_KEY["DARK"]
        key = "DARK"
    end

    -- Structural look -> live Style tables (read live by the renderer)
    copy3(ns.BG, skin.bg)
    ns.BG[4] = skin.bgAlpha
    copy4(ns.HEADER_BG, skin.headerBg)
    copy4(ns.HEADER_HOVER_BG, skin.headerHover)
    copy4(ns.BORDER_COLOR, skin.border)
    if ns.SCROLLBAR_THUMB and skin.scrollThumb then
        copy3(ns.SCROLLBAR_THUMB, skin.scrollThumb)
    end
    copy3(ns.DEFAULT_ACCENT, skin.accent)
    ns.BAR_ALPHA   = skin.barAlpha
    ns.BAR_SPACING = skin.barSpacing

    if ns.db then
        ns.db.skin = key
        if seedDefaults then
            ns.db.bgAlpha    = skin.bgAlpha
            ns.db.barHeight  = skin.barHeight
            ns.db.barTexture = skin.barTexture
            ns.db.accentColor = { skin.accent[1], skin.accent[2], skin.accent[3] }
            ns.db.accentUseClassColor = false
        end
    end

    -- Re-derive accent from the DB (honours the seed above or a saved override)
    if ns.ApplyAccentColor then
        ns.ApplyAccentColor()
    end

    for _, fn in ipairs(skinCallbacks) do
        fn()
    end
end

----------------------------------------------------------------------
-- Live refresh: re-skin every open window in place (no /reload)
----------------------------------------------------------------------

ns.OnSkinChanged(function()
    if not ns.windows then return end
    for _, win in ipairs(ns.windows) do
        if win.RefreshSkin then win.RefreshSkin() end
        if win.RefreshAccentColor then win.RefreshAccentColor() end
        if win.RefreshBarHeight then win.RefreshBarHeight() end
    end
end)
