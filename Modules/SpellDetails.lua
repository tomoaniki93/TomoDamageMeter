local ADDON_NAME, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Spell Details (Midnight / C_DamageMeter only)
--
-- Adds the DamageMeterCombatSpell.combatSpellDetails payload to the existing
-- spell tooltip. No CLEU, no combat-log parser, no ticker and no permanent
-- OnUpdate. Data is queried lazily on the first hover for the active breakdown
-- context, then cached until the player/context changes.
----------------------------------------------------------------------

local currentContext
local contextCache
local previousBuildSpellTooltip = ns.BuildSpellTooltip
local originalShowSpellBreakdown = ns.ShowSpellBreakdown
local originalShowTargetSpells = ns.ShowTargetSpells
local originalAppendSpellRows = ns.AppendSpellRows

local function IsSecret(value)
    return value ~= nil and issecretvalue and issecretvalue(value)
end

local function SafeString(value)
    if value == nil or IsSecret(value) then return nil end
    if type(value) ~= "string" or value == "" then return nil end
    return value
end

local function SafeNumber(value)
    if value == nil or IsSecret(value) or type(value) ~= "number" then return nil end
    return value
end

local function SafeBool(value)
    if value == nil or IsSecret(value) or type(value) ~= "boolean" then return nil end
    return value
end

local function CopyContext(ctx)
    if not ctx then return nil end
    return {
        sessionType = ctx.sessionType,
        sessionID = ctx.sessionID,
        meterType = ctx.meterType,
        sourceGUID = ctx.sourceGUID,
        sourceCreatureID = ctx.sourceCreatureID,
    }
end

local function SetContext(ctx)
    currentContext = CopyContext(ctx)
    contextCache = nil
end

local function SpellName(spellID)
    if not spellID or IsSecret(spellID) then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.name then return info.name end
    end
    return nil
end

local function SpellCreature(spell)
    return SafeString(spell and spell.creatureName) or ""
end

local function DetailKey(name, creature)
    return (name or "?") .. "\031" .. (creature or "")
end

local CLASSIFICATION_KEYS = {
    normal = "SPELL_DETAILS_NORMAL",
    elite = "SPELL_DETAILS_ELITE",
    rare = "SPELL_DETAILS_RARE",
    rareelite = "SPELL_DETAILS_RAREELITE",
    worldboss = "SPELL_DETAILS_WORLDBOSS",
    trivial = "SPELL_DETAILS_TRIVIAL",
    minus = "SPELL_DETAILS_MINUS",
}

local function ClassificationLabel(value)
    if not value then return nil end
    local key = CLASSIFICATION_KEYS[value]
    return key and (L[key] or value) or value
end

local function ReadOneDetail(raw)
    if not raw or IsSecret(raw) or type(raw) ~= "table" then return nil end

    local entry = {
        unitName = SafeString(raw.unitName),
        unitClassFilename = SafeString(raw.unitClassFilename),
        classification = SafeString(raw.classification),
        isPet = SafeBool(raw.isPet),
        isMob = SafeBool(raw.isMob),
        amount = SafeNumber(raw.amount),
        specIconID = SafeNumber(raw.specIconID),
    }

    if not entry.unitName and not entry.unitClassFilename and not entry.classification
        and entry.isPet == nil and entry.isMob == nil and entry.amount == nil
        and entry.specIconID == nil then
        return nil
    end
    return entry
end

local function CollectRawDetails(raw, out)
    if not raw or IsSecret(raw) or type(raw) ~= "table" then return end

    -- Retail currently exposes one DamageMeterCombatSpellUnitDetails record,
    -- but accepting an array as well makes the addon forward-compatible and
    -- harmless on builds/tools that describe the payload as a list.
    if raw.unitName ~= nil or raw.unitClassFilename ~= nil or raw.classification ~= nil
        or raw.amount ~= nil or raw.isPet ~= nil or raw.isMob ~= nil
        or raw.specIconID ~= nil then
        local one = ReadOneDetail(raw)
        if one then out[#out + 1] = one end
        return
    end

    for _, item in ipairs(raw) do
        local one = ReadOneDetail(item)
        if one then out[#out + 1] = one end
    end
end

local function MergeDetail(bucket, detail)
    local key = table.concat({
        detail.unitName or "",
        detail.unitClassFilename or "",
        detail.classification or "",
        detail.isPet and "P" or "",
        detail.isMob and "M" or "",
        tostring(detail.specIconID or 0),
    }, "\030")

    local hit = bucket.byKey[key]
    if hit then
        if hit.amount ~= nil and detail.amount ~= nil then
            hit.amount = hit.amount + detail.amount
        elseif hit.amount == nil then
            hit.amount = detail.amount
        end
        return
    end

    bucket.byKey[key] = detail
    bucket.list[#bucket.list + 1] = detail
end

local function QuerySource(ctx)
    if not ctx or not C_DamageMeter then return nil end
    if not ctx.meterType or not ctx.sourceGUID or IsSecret(ctx.sourceGUID) then return nil end

    local ok, source
    if ctx.sessionID ~= nil then
        if not C_DamageMeter.GetCombatSessionSourceFromID then return nil end
        ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromID,
            ctx.sessionID, ctx.meterType, ctx.sourceGUID, ctx.sourceCreatureID)
    else
        if not C_DamageMeter.GetCombatSessionSourceFromType or ctx.sessionType == nil then return nil end
        ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType,
            ctx.sessionType, ctx.meterType, ctx.sourceGUID, ctx.sourceCreatureID)
    end

    if not ok or not source or IsSecret(source) then return nil end
    local spells = source.combatSpells
    if not spells or IsSecret(spells) or type(spells) ~= "table" then return nil end
    return spells
end

local function BuildContextCache(ctx)
    local combatSpells = QuerySource(ctx)
    if not combatSpells then return nil end

    local cache = { byName = {}, bySpellID = {} }

    for _, spell in ipairs(combatSpells) do
        if spell and not IsSecret(spell) then
            local spellID = SafeNumber(spell.spellID)
            local name = spellID and SpellName(spellID)
            local creature = SpellCreature(spell)
            local rawDetails = spell.combatSpellDetails

            if name and rawDetails and not IsSecret(rawDetails) then
                local collected = {}
                CollectRawDetails(rawDetails, collected)
                if #collected > 0 then
                    local nameKey = DetailKey(name, creature)
                    local bucket = cache.byName[nameKey]
                    if not bucket then
                        bucket = { list = {}, byKey = {} }
                        cache.byName[nameKey] = bucket
                    end
                    for _, detail in ipairs(collected) do MergeDetail(bucket, detail) end

                    if spellID then
                        local idBucket = cache.bySpellID[spellID]
                        if not idBucket then
                            idBucket = { list = {}, byKey = {} }
                            cache.bySpellID[spellID] = idBucket
                        end
                        for _, detail in ipairs(collected) do MergeDetail(idBucket, detail) end
                    end
                end
            end
        end
    end

    local function SortBuckets(tbl)
        for _, bucket in pairs(tbl) do
            table.sort(bucket.list, function(a, b)
                return (a.amount or -1) > (b.amount or -1)
            end)
        end
    end
    SortBuckets(cache.byName)
    SortBuckets(cache.bySpellID)

    return cache
end

local function ContextFromData(data)
    local embedded = data and data._tdmSpellContext
    if embedded then return embedded end

    if data and data.meterType and (data.sessionType ~= nil or data.sessionID ~= nil)
        and data.sourceGUID then
        return {
            sessionType = data.sessionType,
            sessionID = data.sessionID,
            meterType = data.meterType,
            sourceGUID = data.sourceGUID,
            sourceCreatureID = data.sourceCreatureID,
        }
    end
    return currentContext
end

function ns.GetAdvancedSpellUnitDetails(data)
    if not data then return nil end
    local ctx = ContextFromData(data)
    if not ctx then return nil end

    -- Cache is scoped to the active standalone context. Inline rows carry their
    -- own context and are queried on demand without becoming a background job.
    local cache
    if ctx == currentContext or (currentContext and ctx.sourceGUID == currentContext.sourceGUID
        and ctx.meterType == currentContext.meterType
        and ctx.sessionType == currentContext.sessionType
        and ctx.sessionID == currentContext.sessionID) then
        if contextCache == nil then contextCache = BuildContextCache(ctx) or false end
        cache = contextCache ~= false and contextCache or nil
    else
        cache = BuildContextCache(ctx)
    end
    if not cache then return nil end

    local spellID = SafeNumber(data.spellID)
    if spellID and cache.bySpellID[spellID] then
        return cache.bySpellID[spellID].list
    end

    local name = SafeString(data.name)
    if not name then return nil end
    local creature = SafeString(data.creatureName) or ""
    local bucket = cache.byName[DetailKey(name, creature)]
    return bucket and bucket.list or nil
end

local function AddBaseTooltip(owner, data)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    local name = SafeString(data.name) or "?"
    local icon = SafeNumber(data.icon)
    if icon then
        name = string.format("|T%d:16:16:0:0|t %s", icon, name)
    end
    GameTooltip:AddLine(name, 1, 1, 1)

    local total = SafeNumber(data.total or data.totalAmount)
    local perSec = SafeNumber(data.perSec or data.amountPerSecond)
    local pct = SafeNumber(data.pct)
    if total then
        GameTooltip:AddDoubleLine(L["BREAKDOWN_COL_TOTAL"] or "Total", ns.FormatNumber(total, "1dec"),
            0.70, 0.70, 0.74, 1, 1, 1)
    end
    if perSec then
        GameTooltip:AddDoubleLine("/s", ns.FormatNumber(perSec, "1dec"),
            0.70, 0.70, 0.74, 1, 1, 1)
    end
    if pct then
        GameTooltip:AddDoubleLine("%", string.format("%.1f%%", pct),
            0.70, 0.70, 0.74, 1, 1, 1)
    end

    local creature = SafeString(data.creatureName)
    if creature then
        GameTooltip:AddDoubleLine(L["SPELL_DETAILS_CASTER"] or "Caster", creature,
            0.70, 0.70, 0.74, 0.85, 0.85, 0.90)
    end
    local overkill = SafeNumber(data.overkill)
    if overkill and overkill > 0 then
        GameTooltip:AddDoubleLine(L["SPELL_DETAILS_OVERKILL"] or "Overkill", ns.FormatNumber(overkill, "1dec"),
            0.85, 0.42, 0.42, 1, 0.38, 0.38)
    end
    if data.isAvoidable then
        GameTooltip:AddLine(L["SPELL_DETAILS_AVOIDABLE"] or "Avoidable", 1, 0.45, 0.12)
    end
    if data.isDeadly then
        GameTooltip:AddLine(L["SPELL_DETAILS_DEADLY"] or "Killing blow", 1, 0.18, 0.18)
    end
end

local function UnitDisplay(detail)
    local name = detail.unitName or "?"
    if detail.specIconID and detail.specIconID > 0 then
        name = string.format("|T%d:14:14:0:0|t %s", detail.specIconID, name)
    end

    local tags = {}
    if detail.isPet then tags[#tags + 1] = L["SPELL_DETAILS_PET"] or "Pet" end
    if detail.isMob then tags[#tags + 1] = L["SPELL_DETAILS_MOB"] or "Mob" end
    local classification = ClassificationLabel(detail.classification)
    if classification and classification ~= "normal" then tags[#tags + 1] = classification end
    if #tags > 0 then name = name .. " |cff8a8a99[" .. table.concat(tags, ", ") .. "]|r" end
    return name
end

local function AddAdvancedLines(data)
    local details = ns.GetAdvancedSpellUnitDetails(data)
    if not details or #details == 0 then return false end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["SPELL_DETAILS_UNIT"] or "Unit details", 0.88, 0.08, 0.18)

    local spellTotal = SafeNumber(data.total or data.totalAmount)
    local shown = math.min(#details, 6)
    for i = 1, shown do
        local detail = details[i]
        local left = UnitDisplay(detail)
        local right = ""
        if detail.amount ~= nil then
            right = ns.FormatNumber(detail.amount, "1dec")
            if spellTotal and spellTotal > 0 then
                right = right .. string.format("  (%.1f%%)", detail.amount / spellTotal * 100)
            end
        end

        local r, g, b = 0.90, 0.90, 0.93
        local classColor = detail.unitClassFilename and RAID_CLASS_COLORS[detail.unitClassFilename]
        if classColor then r, g, b = classColor.r, classColor.g, classColor.b end
        GameTooltip:AddDoubleLine(left, right, r, g, b, 0.88, 0.88, 0.92)
    end
    if #details > shown then
        GameTooltip:AddLine(string.format("+%d", #details - shown), 0.50, 0.50, 0.55)
    end
    return true
end

function ns.BuildSpellTooltip(owner, data)
    if previousBuildSpellTooltip then
        previousBuildSpellTooltip(owner, data)
    else
        AddBaseTooltip(owner, data)
    end
    AddAdvancedLines(data)
    GameTooltip:Show()
end

-- Capture the active player/session before the existing breakdown populates.
if originalShowSpellBreakdown then
    ns.ShowSpellBreakdown = function(playerName, sourceGUID, meterType, sessionType, classFilename)
        SetContext({
            sessionType = sessionType,
            meterType = meterType,
            sourceGUID = sourceGUID,
        })
        return originalShowSpellBreakdown(playerName, sourceGUID, meterType, sessionType, classFilename)
    end
end

-- Segment view: the source is the local player; combatSpellDetails contains the
-- counterpart unit information supplied by Blizzard for the spell.
if originalShowTargetSpells then
    ns.ShowTargetSpells = function(targetName, sourceCreatureID, sessionID)
        SetContext({
            sessionID = sessionID,
            meterType = Enum.DamageMeterType.DamageDone,
            sourceGUID = UnitGUID("player"),
        })
        return originalShowTargetSpells(targetName, sourceCreatureID, sessionID)
    end
end

-- Inline spell rows can carry an explicit context without changing the existing
-- DamageMeter renderer. This wrapper simply annotates rows created by the
-- already-existing AppendSpellRows function.
if originalAppendSpellRows then
    ns.AppendSpellRows = function(elements, sessionType, meterType, sourceGUID, ...)
        local first = #elements + 1
        local results = { originalAppendSpellRows(elements, sessionType, meterType, sourceGUID, ...) }
        for i = first, #elements do
            local row = elements[i]
            if row and row.kind == "spell" then
                row._tdmSpellContext = {
                    sessionType = sessionType,
                    meterType = meterType,
                    sourceGUID = sourceGUID,
                }
            end
        end
        return unpack(results)
    end
end
