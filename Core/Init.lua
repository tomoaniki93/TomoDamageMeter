local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Namespace Initialization
----------------------------------------------------------------------

ns.addonName = ADDON_NAME
ns.windows = {}
ns.inCombat = false

-- WoW: Forever (interface 16001) runs the Mainline client, but registering an
-- event the client does not know throws and aborts the calling file. Every
-- non-core event goes through this so a missing one only disables its feature.
function ns.SafeRegisterEvent(frame, event)
    local ok = pcall(frame.RegisterEvent, frame, event)
    return ok
end

-- Protected C_DamageMeter entry points. A raised error inside the refresh path
-- (expired session, API change, missing function on another client) would
-- otherwise abort the whole DAMAGE_METER_* handler. pcall does not change the
-- readability of the returned values: called in-handler, they stay readable.
function ns.GetSessionFromType(sessionType, meterType)
    if not (C_DamageMeter and C_DamageMeter.GetCombatSessionFromType) then return nil end
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, meterType)
    if ok then return session end
    return nil
end

function ns.ResetAllSessions()
    if C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then
        pcall(C_DamageMeter.ResetAllCombatSessions)
    end
end

-- Escape-to-close without UISpecialFrames. Inserting into (or reassigning)
-- that Blizzard global taints CloseSpecialWindows, which runs on the secure
-- Escape path and can surface as ADDON_ACTION_BLOCKED in combat.
--
-- The frame only takes keyboard input while shown and out of combat:
-- SetPropagateKeyboardInput is restricted in combat lockdown, so in combat the
-- frame never touches it and every key (Escape included) passes straight
-- through to the game. Out of combat, Escape is consumed and hides the frame;
-- every other key is propagated.
function ns.CloseOnEscape(frame)
    if not frame or frame._tdmCloseOnEscape then return end
    frame._tdmCloseOnEscape = true

    local function Arm(self)
        if InCombatLockdown() then return end
        self:EnableKeyboard(true)
        self:SetPropagateKeyboardInput(true)
    end

    frame:HookScript("OnShow", Arm)
    frame:HookScript("OnHide", function(self)
        if InCombatLockdown() then return end
        self:EnableKeyboard(false)
    end)
    frame:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then return end
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    if frame:IsShown() then Arm(frame) end
end

----------------------------------------------------------------------
-- Meter Type Metadata
----------------------------------------------------------------------

ns.METER_CATEGORIES = {
    { name = "DAMAGE", short = "D", color = "CAT_DAMAGE", types = {
        { type = Enum.DamageMeterType.Dps,                  key = "DPS" },
        { type = Enum.DamageMeterType.DamageTaken,          key = "DAMAGE_TAKEN" },
        { type = Enum.DamageMeterType.AvoidableDamageTaken, key = "AVOIDABLE" },
        { type = Enum.DamageMeterType.EnemyDamageTaken,     key = "ENEMY_DAMAGE" },
    }},
    { name = "HEALING", short = "H", color = "CAT_HEALING", types = {
        { type = Enum.DamageMeterType.Hps,     key = "HPS" },
        { type = Enum.DamageMeterType.Absorbs,  key = "ABSORBS" },
    }},
    { name = "ACTIONS", short = "A", color = "CAT_ACTIONS", types = {
        { type = Enum.DamageMeterType.Interrupts, key = "INTERRUPTS" },
        { type = Enum.DamageMeterType.Dispels,    key = "DISPELS" },
        { type = Enum.DamageMeterType.Deaths,     key = "DEATHS" },
    }},
}

-- Drop any meter type the client's Enum does not define (a nil type would be
-- a nil table index below and abort the file), then any category left empty.
for catIdx = #ns.METER_CATEGORIES, 1, -1 do
    local cat = ns.METER_CATEGORIES[catIdx]
    for i = #cat.types, 1, -1 do
        if cat.types[i].type == nil then
            table.remove(cat.types, i)
        end
    end
    if #cat.types == 0 then
        table.remove(ns.METER_CATEGORIES, catIdx)
    end
end

-- Reverse lookup: type -> category info
ns.TYPE_INFO = {}
for catIdx, cat in ipairs(ns.METER_CATEGORIES) do
    for _, t in ipairs(cat.types) do
        ns.TYPE_INFO[t.type] = {
            catIdx = catIdx,
            key = t.key,
            catName = cat.name,
            catShort = cat.short,
            catColor = ns[cat.color],
        }
    end
end

----------------------------------------------------------------------
-- Category Enable/Disable Helpers
----------------------------------------------------------------------

function ns.IsCategoryEnabled(catIdx)
    if not ns.db or not ns.db.disabledCategories then return true end
    local cat = ns.METER_CATEGORIES[catIdx]
    return cat and not ns.db.disabledCategories[cat.name]
end

function ns.IsTypeEnabled(meterType)
    local info = ns.TYPE_INFO[meterType]
    if not info then return false end
    return ns.IsCategoryEnabled(info.catIdx)
end

-- Returns the first enabled meter type, or DPS as ultimate fallback
function ns.GetFirstEnabledType()
    for catIdx, cat in ipairs(ns.METER_CATEGORIES) do
        if ns.IsCategoryEnabled(catIdx) then
            return cat.types[1].type
        end
    end
    return Enum.DamageMeterType.Dps
end

-- Returns the next enabled category index (wrapping), or nil if none
function ns.GetNextEnabledCatIdx(currentCatIdx)
    local total = #ns.METER_CATEGORIES
    for offset = 1, total do
        local idx = ((currentCatIdx - 1 + offset) % total) + 1
        if ns.IsCategoryEnabled(idx) then return idx end
    end
    return nil
end

-- Enforce: if a window's current type belongs to a disabled category, switch it
function ns.EnforceEnabledTypes()
    for _, win in ipairs(ns.windows) do
        if not ns.IsTypeEnabled(win.GetMeterType()) then
            win.SetMeterType(ns.GetFirstEnabledType())
        end
    end
end

-- Types where amountPerSecond is the primary display value
ns.RATE_PRIMARY = {}
for _, t in ipairs({ Enum.DamageMeterType.Dps, Enum.DamageMeterType.Hps }) do
    ns.RATE_PRIMARY[t] = true
end

-- Session options
ns.SESSION_OPTIONS = {
    { type = Enum.DamageMeterSessionType.Current, key = "CURRENT" },
    { type = Enum.DamageMeterSessionType.Overall, key = "OVERALL" },
}

ns.SESSION_KEYS = {}
for _, opt in ipairs(ns.SESSION_OPTIONS) do
    ns.SESSION_KEYS[opt.type] = opt.key
end

----------------------------------------------------------------------
-- Default Window Config
----------------------------------------------------------------------

ns.MAX_WINDOWS = 5

ns.DEFAULTS = {
    point = "CENTER",
    relPoint = "CENTER",
    x = 0,
    y = 0,
    width = 300,
    height = 250,
    meterType = Enum.DamageMeterType.Dps,
    sessionType = Enum.DamageMeterSessionType.Current,
    locked = false,
}

----------------------------------------------------------------------
-- Default Column Config
----------------------------------------------------------------------

ns.DEFAULT_COLUMNS = {
    { key = "rate",  show = true,  fmt = "1dec" },
    { key = "total", show = true,  fmt = "1dec" },
    { key = "pct",   show = false, fmt = "int" },
}

ns.FORMAT_OPTIONS = {
    rate  = { "short", "1dec", "2dec", "3dec", "full" },
    total = { "short", "1dec", "2dec", "3dec", "full" },
    pct   = { "int",  "dec" },
}

----------------------------------------------------------------------
-- Accent color system
----------------------------------------------------------------------

local accentCallbacks = {}

function ns.OnAccentChanged(fn)
    accentCallbacks[#accentCallbacks + 1] = fn
end

function ns.ApplyAccentColor()
    if ns.db and ns.db.accentUseClassColor then
        local _, classFile = UnitClass("player")
        local cc = RAID_CLASS_COLORS[classFile]
        if cc then
            ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3] = cc.r, cc.g, cc.b
            ns.db.accentColor = { cc.r, cc.g, cc.b }
        end
    else
        local c = ns.db and ns.db.accentColor
        if c then
            ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3] = c[1], c[2], c[3]
        else
            ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3] = unpack(ns.DEFAULT_ACCENT)
        end
    end
    for _, fn in ipairs(accentCallbacks) do
        fn()
    end
end

----------------------------------------------------------------------
-- Refresh all windows
----------------------------------------------------------------------

function ns.Refresh()
    for _, win in ipairs(ns.windows) do
        if win.Refresh then win.Refresh() end
    end
end