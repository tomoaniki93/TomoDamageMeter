local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- SpellBridge: queries C_DamageMeter for per-spell breakdown data
----------------------------------------------------------------------
-- Uses C_DamageMeter.GetCombatSessionSourceFromType() which returns
-- a combatSpells array for a given source GUID.  No CLEU needed.
--
-- Each combatSpells entry (damagemeter_combat_spell) exposes more than
-- just amount/rate; the Midnight API also carries:
--   creatureName   -> pet / guardian that cast the spell
--   overkillAmount -> wasted (over-the-kill) portion
--   isAvoidable    -> flagged avoidable damage
--   isDeadly       -> spell delivered a killing blow
-- These were previously dropped on the floor; they now ride along on
-- every entry (each read guarded, since any field can be a secret value
-- mid-combat).
----------------------------------------------------------------------

local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo or GetSpellInfo

local DEBUG = false -- set to true to log C_DamageMeter pcall failures

local function GetSpellIcon(spellID)
    if not spellID or spellID == 0 then return 134400 end
    if issecretvalue and issecretvalue(spellID) then return 134400 end
    local info = GetSpellInfo(spellID)
    if info then
        return info.iconID or 134400
    end
    return 134400
end

local function GetSpellName(spellID)
    if not spellID or spellID == 0 then return "?" end
    if issecretvalue and issecretvalue(spellID) then return "?" end
    local info = GetSpellInfo(spellID)
    if info then
        return info.name or ("Spell " .. spellID)
    end
    return "Spell " .. spellID
end

----------------------------------------------------------------------
-- Optional enriched fields (Midnight). Each may be a secret value during
-- combat, so every read is individually guarded; missing fields stay nil.
----------------------------------------------------------------------

local function ReadSpellExtras(spell, entry)
    local creature = spell.creatureName
    if creature and not issecretvalue(creature) and creature ~= "" then
        entry.creatureName = creature
    end

    local overkill = spell.overkillAmount
    if overkill and not issecretvalue(overkill) and overkill > 0 then
        entry.overkill = overkill
    end

    local avoidable = spell.isAvoidable
    if avoidable ~= nil and not issecretvalue(avoidable) and avoidable then
        entry.isAvoidable = true
    end

    local deadly = spell.isDeadly
    if deadly ~= nil and not issecretvalue(deadly) and deadly then
        entry.isDeadly = true
    end
end

-- Build a single sorted entry from a raw combatSpells element.
local function MakeEntry(spell)
    local spellID     = spell.spellID
    local totalAmount = spell.totalAmount or 0

    if issecretvalue(spellID) or issecretvalue(totalAmount) or totalAmount <= 0 then
        return nil
    end

    local entry = {
        spellID = spellID,
        total   = totalAmount,
        perSec  = spell.amountPerSecond,
        name    = GetSpellName(spellID),
        icon    = GetSpellIcon(spellID),
    }
    ReadSpellExtras(spell, entry)
    return entry
end

-- Shared finalizer: sort by total desc and stamp per-spell percentages.
local function Finalize(sorted, grandTotal)
    table.sort(sorted, function(a, b) return a.total > b.total end)
    for _, entry in ipairs(sorted) do
        entry.pct = grandTotal > 0 and (entry.total / grandTotal * 100) or 0
    end
    return sorted, grandTotal
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

--- Returns a sorted array of spell entries for a GUID in the current session.
--- @param sessionType number Enum.DamageMeterSessionType
--- @param meterType number Enum.DamageMeterType
--- @param sourceGUID string
--- @return table|nil sortedSpells, number grandTotal
function ns.GetSpellBreakdown(sessionType, meterType, sourceGUID)
    if not C_DamageMeter or not C_DamageMeter.GetCombatSessionSourceFromType then
        return nil, 0
    end

    -- pcall: sourceGUID may be a secret value (enemy targets); the C API
    -- can resolve it internally but Lua-side errors must be caught.
    local ok, spellData = pcall(C_DamageMeter.GetCombatSessionSourceFromType, sessionType, meterType, sourceGUID)
    if not ok then
        if DEBUG then print(ns.L["ADDON_PREFIX"] .. "SpellBridge: GetCombatSessionSourceFromType failed: " .. tostring(spellData)) end
        return nil, 0
    end
    if not spellData or issecretvalue(spellData) then return nil, 0 end

    local combatSpells = spellData.combatSpells
    if not combatSpells or issecretvalue(combatSpells) or #combatSpells == 0 then return nil, 0 end

    local sorted = {}
    local grandTotal = 0

    for _, spell in ipairs(combatSpells) do
        local entry = MakeEntry(spell)
        if entry then
            sorted[#sorted + 1] = entry
            grandTotal = grandTotal + entry.total
        end
    end

    return Finalize(sorted, grandTotal)
end

--- Returns true if the meter type supports spell breakdown.
function ns.HasSpellBreakdown(meterType)
    -- Actions types (Interrupts, Dispels, Deaths) also have per-spell data
    return meterType ~= nil
end

--- Returns the player's spell breakdown for a specific combat segment.
--- Uses GetCombatSessionSourceFromID with DamageDone/HealingDone + playerGUID.
--- @param sessionID number
--- @param meterType number Enum.DamageMeterType (DamageDone or HealingDone)
--- @param sourceGUID string player GUID
--- @return table|nil sortedSpells, number grandTotal
function ns.GetSpellBreakdownBySegment(sessionID, meterType, sourceGUID)
    if not C_DamageMeter or not C_DamageMeter.GetCombatSessionSourceFromID then
        return nil, 0
    end

    local ok, spellData = pcall(C_DamageMeter.GetCombatSessionSourceFromID,
        sessionID, meterType, sourceGUID)
    if not ok then
        if DEBUG then print(ns.L["ADDON_PREFIX"] .. "SpellBridge: GetCombatSessionSourceFromID failed: " .. tostring(spellData)) end
        return nil, 0
    end
    if not spellData or issecretvalue(spellData) then return nil, 0 end

    local combatSpells = spellData.combatSpells
    if not combatSpells or issecretvalue(combatSpells) or #combatSpells == 0 then return nil, 0 end

    local sorted = {}
    local grandTotal = 0

    for _, spell in ipairs(combatSpells) do
        local entry = MakeEntry(spell)
        if entry then
            sorted[#sorted + 1] = entry
            grandTotal = grandTotal + entry.total
        end
    end

    return Finalize(sorted, grandTotal)
end

--- Stub: no external data to reset anymore
function ns.ResetSpellData()
    -- No-op: C_DamageMeter handles its own data lifecycle
end
