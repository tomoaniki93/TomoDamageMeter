local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Combat Timer V3 / 2.7.5
--
-- Core/Database intentionally refreshes the original combat timer only for
-- RATE_PRIMARY meters (DPS/HPS). Meter UI V3 now exposes the session timer on
-- every meter type, so this lightweight companion ticker covers only the
-- non-rate windows. RATE_PRIMARY windows stay on the existing core ticker.
----------------------------------------------------------------------

local originalSyncCombatTickers = ns.SyncCombatTickers
local supplementalTicker
local eventFrame = CreateFrame("Frame")

local function IsWindowVisible(win)
    return win and win.frame and win.frame:IsShown()
end

local function IsSupplementalWindow(win)
    if not IsWindowVisible(win) or not win.GetMeterType then return false end
    local meterType = win.GetMeterType()
    return not (ns.RATE_PRIMARY and ns.RATE_PRIMARY[meterType])
end

local function RefreshSupplementalTimers()
    if not (ns.db and ns.db.showCombatTimer) then return end

    for _, win in ipairs(ns.windows or {}) do
        if IsSupplementalWindow(win) and win.UpdateTimer then
            win.UpdateTimer()
        end
    end
end

local function StopSupplementalTicker()
    if supplementalTicker then
        supplementalTicker:Cancel()
        supplementalTicker = nil
        ns._supplementalTimerTicker = nil
    end
end

local function HasSupplementalWindow()
    for _, win in ipairs(ns.windows or {}) do
        if IsSupplementalWindow(win) then return true end
    end
    return false
end

local function IsInCombat()
    if ns.inCombat then return true end
    if InCombatLockdown then return InCombatLockdown() and true or false end
    return false
end

local function SyncSupplementalTicker(forceCombat)
    local inCombat = forceCombat
    if inCombat == nil then inCombat = IsInCombat() end

    if inCombat
        and ns.db
        and ns.db.showCombatTimer
        and HasSupplementalWindow()
    then
        if not supplementalTicker then
            supplementalTicker = C_Timer.NewTicker(1, RefreshSupplementalTimers)
            ns._supplementalTimerTicker = supplementalTicker
        end
    else
        StopSupplementalTicker()
    end
end

-- Keep the public synchronization hook used by MeterUIV3 / ConfigUIV2, while
-- preserving the original Core/Database optimization for DPS/HPS.
ns.SyncCombatTickers = function()
    if originalSyncCombatTickers then
        originalSyncCombatTickers()
    end
    SyncSupplementalTicker()
end

eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- Do not rely on frame event-ordering for ns.inCombat.
        SyncSupplementalTicker(true)
        RefreshSupplementalTimers()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Final readable pass, then stop the one-second ticker.
        RefreshSupplementalTimers()
        StopSupplementalTicker()
    elseif event == "PLAYER_LOGOUT" then
        StopSupplementalTicker()
        eventFrame:UnregisterAllEvents()
    end
end)

ns.RefreshAllCombatTimers = function()
    for _, win in ipairs(ns.windows or {}) do
        if IsWindowVisible(win) and win.UpdateTimer then
            win.UpdateTimer()
        end
    end
    SyncSupplementalTicker()
end
