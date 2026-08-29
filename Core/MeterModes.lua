local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Additional native C_DamageMeter modes (v2.5)
--
-- This file only extends metadata created by Core/Init.lua.  It does not
-- collect combat data and it does not register any events/tickers/CLEU.
----------------------------------------------------------------------

if not Enum or not Enum.DamageMeterType or not Enum.DamageMeterSessionType then
    return
end

local function FindType(cat, meterType)
    if not cat or not cat.types then return nil end
    for index, info in ipairs(cat.types) do
        if info.type == meterType then
            return index
        end
    end
    return nil
end

local function RegisterType(catIndex, meterType, key, afterType)
    if meterType == nil or ns.TYPE_INFO[meterType] then return end

    local cat = ns.METER_CATEGORIES[catIndex]
    if not cat then return end

    local insertAt = #cat.types + 1
    if afterType ~= nil then
        local afterIndex = FindType(cat, afterType)
        if afterIndex then insertAt = afterIndex + 1 end
    end

    table.insert(cat.types, insertAt, {
        type = meterType,
        key = key,
    })

    ns.TYPE_INFO[meterType] = {
        catIdx = catIndex,
        key = key,
        catName = cat.name,
        catShort = cat.short,
        catColor = ns[cat.color],
    }
end

-- Preserve the familiar category entry points: cycling into Damage still lands
-- on DPS and cycling into Healing still lands on HPS.  The new total-based view
-- is inserted directly after the matching rate view.
RegisterType(
    1,
    Enum.DamageMeterType.DamageDone,
    "DAMAGE_DONE",
    Enum.DamageMeterType.Dps
)

RegisterType(
    2,
    Enum.DamageMeterType.HealingDone,
    "HEALING_DONE",
    Enum.DamageMeterType.Hps
)

-- Explicit semantic marker for consumers that want to distinguish cumulative
-- totals from DPS/HPS later.  RATE_PRIMARY intentionally remains DPS/HPS only,
-- so reports for these new views use totalAmount and the combat timer does not
-- pretend that Damage Done / Healing Done are rate meters.
ns.TOTAL_PRIMARY = ns.TOTAL_PRIMARY or {}
if Enum.DamageMeterType.DamageDone ~= nil then
    ns.TOTAL_PRIMARY[Enum.DamageMeterType.DamageDone] = true
end
if Enum.DamageMeterType.HealingDone ~= nil then
    ns.TOTAL_PRIMARY[Enum.DamageMeterType.HealingDone] = true
end

-- Blizzard's Expired session is the previous completed fight.  Put it between
-- Current and Overall so header-click cycling is intuitive:
-- Current -> Previous Fight -> Overall -> Current.
local expired = Enum.DamageMeterSessionType.Expired
if expired ~= nil and not ns.SESSION_KEYS[expired] then
    table.insert(ns.SESSION_OPTIONS, 2, {
        type = expired,
        key = "PREVIOUS",
    })
    ns.SESSION_KEYS[expired] = "PREVIOUS"
end
