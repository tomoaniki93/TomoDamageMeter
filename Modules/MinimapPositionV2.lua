local ADDON_NAME, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Minimap Position V2 / 2.7.8
--
-- The original Minimap.lua uses Minimap:GetWidth()/2 + 15. On the modern
-- Retail minimap the frame is larger than the visible circular map texture,
-- so that additional +15 pushes the TDM icon too far outside compared with
-- normal minimap buttons.
--
-- This layer keeps the existing button, clicks, menu and SavedVariables, but
-- owns only its orbit geometry and drag placement.
----------------------------------------------------------------------

local BUTTON_SIZE = 34

-- Approximate difference between the Minimap frame edge and the visible disc.
-- The button half-size is then added back so the icon sits just outside the
-- visible map instead of orbiting outside the whole frame.
local FRAME_VISUAL_INSET = 15
local RING_GAP = 2

local installed = false

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi * 0.5 end
    if x == 0 and y < 0 then return -math.pi * 0.5 end
    return 0
end

local function GetDB()
    if not ns.db then return nil end
    ns.db.minimap = ns.db.minimap or {}
    if ns.db.minimap.angle == nil then ns.db.minimap.angle = 225 end
    if ns.db.minimap.scale == nil then ns.db.minimap.scale = 1 end
    return ns.db.minimap
end

local function GetButton()
    return _G.TomoDamageMeterMinimapButton
end

local function ApplyRingPosition()
    local button = GetButton()
    local db = GetDB()
    if not button or not db or not Minimap then return end

    local angle = math.rad(tonumber(db.angle) or 225)
    local width = tonumber(Minimap:GetWidth()) or 140
    local height = tonumber(Minimap:GetHeight()) or width
    local scale = math.max(0.70, math.min(1.50, tonumber(db.scale) or 1))

    local visualHalfButton = BUTTON_SIZE * scale * 0.5

    -- Use the visible-disc radius, not the full minimap-frame radius.
    -- At scale 1 this evaluates to frameHalf + 4 rather than frameHalf + 15,
    -- bringing the icon roughly 11 px inward compared with the old orbit.
    local radiusX = math.max(1, width * 0.5 - FRAME_VISUAL_INSET + visualHalfButton + RING_GAP)
    local radiusY = math.max(1, height * 0.5 - FRAME_VISUAL_INSET + visualHalfButton + RING_GAP)

    button:ClearAllPoints()
    button:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        math.cos(angle) * radiusX,
        math.sin(angle) * radiusY
    )
end

local function UpdateAngleFromCursor()
    local db = GetDB()
    local button = GetButton()
    if not db or not button or not Minimap then return end

    local uiScale = UIParent:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    cursorX, cursorY = cursorX / uiScale, cursorY / uiScale

    local centerX, centerY = Minimap:GetCenter()
    if not centerX or not centerY then return end

    local angle = math.deg(Atan2(cursorY - centerY, cursorX - centerX))
    if angle < 0 then angle = angle + 360 end
    db.angle = angle
    ApplyRingPosition()
end

local function Install()
    if installed then
        ApplyRingPosition()
        return
    end

    local button = GetButton()
    if not button or not Minimap then return end
    installed = true

    -- Replace only drag geometry. No permanent OnUpdate: it exists only while
    -- the user is actively dragging, exactly like the original implementation.
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", UpdateAngleFromCursor)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        UpdateAngleFromCursor()
        self._dragEndedAt = GetTime()
    end)

    Minimap:HookScript("OnSizeChanged", ApplyRingPosition)
    button:HookScript("OnShow", ApplyRingPosition)

    ApplyRingPosition()
end

-- Minimap.lua creates the button from InitializeMinimap during ADDON_LOADED.
-- Wrap that public entry point so this geometry layer installs immediately
-- after the native button exists.
local OriginalInitializeMinimap = ns.InitializeMinimap
if OriginalInitializeMinimap then
    ns.InitializeMinimap = function(...)
        local result = OriginalInitializeMinimap(...)
        Install()
        return result
    end
end

-- Keep the corrected orbit after scale or reset operations.
local OriginalSetScale = ns.SetMinimapButtonScale
if OriginalSetScale then
    ns.SetMinimapButtonScale = function(...)
        local result = OriginalSetScale(...)
        ApplyRingPosition()
        return result
    end
end

local OriginalReset = ns.ResetMinimapButtonPosition
if OriginalReset then
    ns.ResetMinimapButtonPosition = function(...)
        local result = OriginalReset(...)
        ApplyRingPosition()
        return result
    end
end

-- If a future load order creates the button before this file executes.
Install()

ns.RefreshMinimapRingPosition = ApplyRingPosition
