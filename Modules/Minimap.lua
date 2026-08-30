local ADDON_NAME, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Minimap Button + Addon Compartment
--
-- Native implementation: no LibDBIcon / Ace dependency and no permanent
-- OnUpdate. OnUpdate exists only while the user is actively dragging.
--
-- 2.7.9: orbit geometry follows the same rule used by TomoSync / LibDBIcon-
-- style buttons: the CENTER of the button sits on the minimap edge. No extra
-- icon-half or arbitrary outer offset is added.
----------------------------------------------------------------------

local ICON_TEXTURE = "Interface\\AddOns\\TomoDamageMeter\\Assets\\Textures\\TDM_Minimap_64"
local DEFAULT_ANGLE = 225
local DEFAULT_SCALE = 1
local BUTTON_SIZE = 34

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi * 0.5 end
    if x == 0 and y < 0 then return -math.pi * 0.5 end
    return 0
end

local button

local function T(key, fallback)
    local value = L and L[key]
    if value and value ~= key then return value end
    return fallback or key
end

local function EnsureDB()
    if not ns.db then return nil end
    ns.db.minimap = ns.db.minimap or {}
    if ns.db.minimap.hide == nil then ns.db.minimap.hide = false end
    if ns.db.minimap.angle == nil then ns.db.minimap.angle = DEFAULT_ANGLE end
    if ns.db.minimap.scale == nil then ns.db.minimap.scale = DEFAULT_SCALE end
    return ns.db.minimap
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

local function AreAllLocked()
    if not ns.windows or #ns.windows == 0 then return false end
    for _, win in ipairs(ns.windows) do
        if not (win.cfg and win.cfg.locked) then return false end
    end
    return true
end

local function SetAllLocked(locked)
    for _, win in ipairs(ns.windows or {}) do
        if win.cfg then win.cfg.locked = locked and true or false end
        if win.RefreshLockIcon then win.RefreshLockIcon() end
    end
end

----------------------------------------------------------------------
-- Orbit geometry
----------------------------------------------------------------------

local function ApplyPosition()
    if not button or not Minimap then return end
    local db = EnsureDB()
    if not db then return end

    local angle = math.rad(tonumber(db.angle) or DEFAULT_ANGLE)
    local x = math.cos(angle)
    local y = math.sin(angle)

    -- Match normal minimap-button placement: the button CENTER rides directly
    -- on the visible minimap edge. This is intentionally independent of the
    -- button's own size/scale.
    local radius = (Minimap:GetWidth() or 140) * 0.5

    -- TomoSync-compatible square projection. Round minimaps use the normal
    -- circular radius. A square minimap projects the direction vector onto the
    -- nearest square edge so the icon still sits on the border.
    local shape = (GetMinimapShape and GetMinimapShape()) or "ROUND"
    if shape == "SQUARE" then
        local m = math.max(math.abs(x), math.abs(y))
        if m > 0 then
            x = x / m
            y = y / m
        end
    end

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x * radius, y * radius)
end

local function ApplyScale()
    if not button then return end
    local db = EnsureDB()
    if not db then return end
    local scale = tonumber(db.scale) or DEFAULT_SCALE
    scale = math.max(0.70, math.min(1.50, scale))
    db.scale = scale
    button:SetScale(scale)
end

local function ApplyShown()
    if not button then return end
    local db = EnsureDB()
    if not db then return end
    button:SetShown(not db.hide)
end

local function UpdateAngleFromCursor()
    local db = EnsureDB()
    if not db or not button or not Minimap then return end

    local centerX, centerY = Minimap:GetCenter()
    if not centerX or not centerY then return end

    -- Use the minimap's effective scale, not UIParent's. This keeps cursor
    -- tracking correct when the minimap itself is scaled by another addon.
    local scale = Minimap:GetEffectiveScale()
    if not scale or scale <= 0 then return end

    local cursorX, cursorY = GetCursorPosition()
    cursorX, cursorY = cursorX / scale, cursorY / scale

    local angle = math.deg(Atan2(cursorY - centerY, cursorX - centerX))
    if angle < 0 then angle = angle + 360 end
    db.angle = angle
    ApplyPosition()
end

----------------------------------------------------------------------
-- Quick menu / tooltip
----------------------------------------------------------------------

local function OpenQuickMenu(owner)
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        if ns.ToggleSettings then ns.ToggleSettings("minimap") end
        return
    end

    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("TomoDamageMeter")

        root:CreateButton(T("MINIMAP_OPEN_SETTINGS", "Open settings"), function()
            if ns.ToggleSettings then ns.ToggleSettings() end
        end)

        root:CreateButton(
            IsMetersVisible()
                and T("MINIMAP_HIDE_METERS", "Hide meters")
                or T("MINIMAP_SHOW_METERS", "Show meters"),
            function()
                SetMetersVisible(not IsMetersVisible())
                if ns.RefreshSettingsV2 then ns.RefreshSettingsV2() end
            end)

        root:CreateButton(
            AreAllLocked()
                and T("MINIMAP_UNLOCK_ALL", "Unlock all")
                or T("MINIMAP_LOCK_ALL", "Lock all"),
            function()
                SetAllLocked(not AreAllLocked())
                if ns.RefreshSettingsV2 then ns.RefreshSettingsV2() end
            end)

        root:CreateButton(T("MINIMAP_RESET_DATA", "Reset combat data"), function()
            C_DamageMeter.ResetAllCombatSessions()
        end)

        if ns.ToggleRunRecap then
            root:CreateButton(T("RUN_RECAP", "Run Recap"), function()
                ns.ToggleRunRecap()
            end)
        end

        root:CreateButton(T("MINIMAP_HIDE_BUTTON", "Hide minimap button"), function()
            ns.SetMinimapButtonShown(false)
            if ns.RefreshSettingsV2 then ns.RefreshSettingsV2() end
        end)
    end)
end

local function ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText("|cffe1142bTDM|r  TomoDamageMeter", 1, 1, 1)
    GameTooltip:AddLine(T("MINIMAP_TOOLTIP_LEFT", "Left click: open settings"), 0.82, 0.82, 0.84)
    GameTooltip:AddLine(T("MINIMAP_TOOLTIP_RIGHT", "Right click: quick actions"), 0.82, 0.82, 0.84)
    GameTooltip:AddLine(T("MINIMAP_TOOLTIP_DRAG", "Drag: move around minimap"), 0.82, 0.82, 0.84)
    GameTooltip:Show()
end

----------------------------------------------------------------------
-- Button creation
----------------------------------------------------------------------

local function CreateButton()
    if button or not Minimap then return button end

    button = CreateFrame("Button", "TomoDamageMeterMinimapButton", Minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON_TEXTURE)
    icon:SetAllPoints()
    icon:SetTexCoord(0, 1, 0, 1)
    button._icon = icon

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints()
    highlight:SetAlpha(0.55)

    button:SetScript("OnEnter", function(self)
        ShowTooltip(self)
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", UpdateAngleFromCursor)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        UpdateAngleFromCursor()
        self._dragEndedAt = GetTime()
    end)

    button:SetScript("OnClick", function(self, mouseButton)
        if self._dragEndedAt and GetTime() - self._dragEndedAt < 0.15 then
            return
        end
        if mouseButton == "RightButton" then
            OpenQuickMenu(self)
        else
            if ns.ToggleSettings then ns.ToggleSettings() end
        end
    end)

    if Minimap.HookScript then
        Minimap:HookScript("OnSizeChanged", ApplyPosition)
    end

    ApplyScale()
    ApplyPosition()
    ApplyShown()
    return button
end

function ns.InitializeMinimap()
    EnsureDB()
    CreateButton()
end

function ns.SetMinimapButtonShown(shown)
    local db = EnsureDB()
    if not db then return end
    db.hide = not shown
    ApplyShown()
end

function ns.SetMinimapButtonScale(scale)
    local db = EnsureDB()
    if not db then return end
    db.scale = tonumber(scale) or DEFAULT_SCALE
    ApplyScale()
    -- The center remains on the same minimap edge regardless of button scale.
    ApplyPosition()
end

function ns.ResetMinimapButtonPosition()
    local db = EnsureDB()
    if not db then return end
    db.angle = DEFAULT_ANGLE
    db.scale = DEFAULT_SCALE
    db.hide = false
    ApplyScale()
    ApplyPosition()
    ApplyShown()
end

function ns.OpenMinimapQuickMenu(owner)
    OpenQuickMenu(owner or button)
end

----------------------------------------------------------------------
-- Blizzard Addon Compartment
----------------------------------------------------------------------

_G.TomoDamageMeter_OnAddonCompartmentClick = function(_, mouseButton)
    if mouseButton == "RightButton" then
        SetMetersVisible(not IsMetersVisible())
        if ns.RefreshSettingsV2 then ns.RefreshSettingsV2() end
    else
        if ns.ToggleSettings then ns.ToggleSettings() end
    end
end

_G.TomoDamageMeter_OnAddonCompartmentEnter = function(owner)
    ShowTooltip(owner)
end

_G.TomoDamageMeter_OnAddonCompartmentLeave = function()
    GameTooltip:Hide()
end
