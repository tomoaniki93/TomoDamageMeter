local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Number Formatting
----------------------------------------------------------------------

-- Custom breakpoints for AbbreviateNumbers (compact / no decimals)
local BREAKPOINTS_SHORT = {
    { breakpoint = 1000000000, significandDivisor = 1000000000, fractionDivisor = 1, abbreviation = "B", abbreviationIsGlobal = false },
    { breakpoint = 1000000,    significandDivisor = 1000000,    fractionDivisor = 1, abbreviation = "M", abbreviationIsGlobal = false },
    { breakpoint = 1000,       significandDivisor = 1000,       fractionDivisor = 1, abbreviation = "K", abbreviationIsGlobal = false },
    { breakpoint = 1,          significandDivisor = 1,          fractionDivisor = 1, abbreviation = "",  abbreviationIsGlobal = false },
}
local OPTS_SHORT = { breakpointData = BREAKPOINTS_SHORT }

-- 1-decimal
local BREAKPOINTS_1DEC = {
    { breakpoint = 1000000000, significandDivisor = 100000000, fractionDivisor = 10, abbreviation = "B", abbreviationIsGlobal = false },
    { breakpoint = 1000000,    significandDivisor = 100000,    fractionDivisor = 10, abbreviation = "M", abbreviationIsGlobal = false },
    { breakpoint = 1000,       significandDivisor = 100,       fractionDivisor = 10, abbreviation = "K", abbreviationIsGlobal = false },
    { breakpoint = 1,          significandDivisor = 0.1,       fractionDivisor = 10, abbreviation = "",  abbreviationIsGlobal = false },
}
local OPTS_1DEC = { breakpointData = BREAKPOINTS_1DEC }

-- 2-decimal
local BREAKPOINTS_2DEC = {
    { breakpoint = 1000000000, significandDivisor = 10000000, fractionDivisor = 100, abbreviation = "B", abbreviationIsGlobal = false },
    { breakpoint = 1000000,    significandDivisor = 10000,    fractionDivisor = 100, abbreviation = "M", abbreviationIsGlobal = false },
    { breakpoint = 1000,       significandDivisor = 10,       fractionDivisor = 100, abbreviation = "K", abbreviationIsGlobal = false },
    { breakpoint = 1,          significandDivisor = 0.01,      fractionDivisor = 100, abbreviation = "",  abbreviationIsGlobal = false },
}
local OPTS_2DEC = { breakpointData = BREAKPOINTS_2DEC }

function ns.FormatNumber(value, fmt)
    -- Sub-1000 values: handle explicitly for consistent precision
    if not issecretvalue(value) and value < 1000 then
        if fmt == "short" then
            return tostring(math.floor(value + 0.5))
        elseif fmt == "1dec" then
            return string.format("%.1f", value)
        elseif fmt == "2dec" then
            return string.format("%.2f", value)
        else -- "full"
            return string.format("%.1f", value)
        end
    end
    if fmt == "short" then
        return AbbreviateNumbers(value, OPTS_SHORT)
    elseif fmt == "1dec" then
        return AbbreviateNumbers(value, OPTS_1DEC)
    elseif fmt == "2dec" then
        return AbbreviateNumbers(value, OPTS_2DEC)
    else
        return AbbreviateLargeNumbers(value)
    end
end

----------------------------------------------------------------------
-- Column width measurement
----------------------------------------------------------------------

local FORMAT_CHARS = {
    short = 4,
    ["1dec"] = 6,
    ["2dec"] = 8,
    full  = 7,
    int   = 4,
    dec   = 6,
}

-- Extra chars for the total column (parentheses)
local TOTAL_EXTRA_CHARS = 2

local charWidthCache = {}
local measureFS = nil

local function GetCharWidth(fontSize)
    local fontPath = ns.db and ns.db.fontPath or ns.FONT
    local key = fontPath .. ":" .. fontSize
    if charWidthCache[key] then return charWidthCache[key] end
    if not measureFS then
        measureFS = UIParent:CreateFontString(nil, "ARTWORK")
    end
    measureFS:SetFont(fontPath, fontSize, "OUTLINE")
    measureFS:SetText("0000000000")
    local w = measureFS:GetStringWidth()
    local cw = w / 10
    charWidthCache[key] = cw
    return cw
end

function ns.ClearCharWidthCache()
    charWidthCache = {}
end

local COL_PAD = 4

local function ColPixelWidth(chars, fontSize)
    return math.ceil(chars * GetCharWidth(fontSize)) + COL_PAD
end

----------------------------------------------------------------------
-- Timer formatting
----------------------------------------------------------------------

function ns.FormatTimer(seconds)
    if not seconds or seconds <= 0 then return "" end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    if m > 0 then
        return string.format("%d:%02d", m, s)
    else
        return string.format("0:%02d", s)
    end
end

----------------------------------------------------------------------
-- Strip realm from "Name-Server"
----------------------------------------------------------------------

function ns.StripRealm(name)
    if not name then return name end
    if issecretvalue(name) then return name end
    local short = name:match("^([^%-]+)")
    return short or name
end

----------------------------------------------------------------------
-- Column value population
----------------------------------------------------------------------

-- Actions category types: display as simple integer count
ns.ACTIONS_TYPES = {
    [Enum.DamageMeterType.Interrupts] = true,
    [Enum.DamageMeterType.Dispels] = true,
    [Enum.DamageMeterType.Deaths] = true,
}

function ns.PopulateColumnValues(button, elementData)
    local total = elementData.totalAmount or 0
    local rate = elementData.amountPerSecond
    local sessionTotal = elementData.sessionTotal

    -- Actions category: show only integer total with trailing dot
    if elementData.isActionType then
        button.rateFS:SetText("")
        button.rateFS:Hide()
        button.totalFS:SetText("")
        button.totalFS:Hide()
        button.pctFS:SetText("")
        button.pctFS:Hide()

        if not button.actionFS then
            local fs = button.bar:CreateFontString(nil, "OVERLAY")
            fs:SetFont(ns.GetFont(), ns.GetFontSize(), "OUTLINE")
            fs:SetJustifyH("RIGHT")
            fs:SetShadowOffset(1, -1)
            fs:SetShadowColor(0, 0, 0, 0.4)
            button.actionFS = fs
        end
        button.actionFS:SetFont(ns.GetFont(), ns.GetFontSize(), "OUTLINE")
        -- totalAmount is a secret value during combat for action types.
        -- SetFormattedText is a C-side widget method: the formatting happens
        -- in C, not Lua, so it can accept secret values without taint.
        button.actionFS:SetFormattedText("%.0f.", total)
        button.actionFS:SetTextColor(unpack(ns.TEXT_PRIMARY))
        button.actionFS:ClearAllPoints()
        button.actionFS:SetPoint("RIGHT", button.bar, "RIGHT", -6, ns.GetFontNudge())
        button.actionFS:Show()
        return
    end

    -- Hide actionFS if it was created from a previous Actions view
    if button.actionFS then
        button.actionFS:Hide()
    end

    local fsMap = { rate = button.rateFS, total = button.totalFS, pct = button.pctFS }
    for _, col in ipairs(ns.db.columns) do
        local fs = fsMap[col.key]
        if col.show and col.key == "rate" and rate then
            fs:SetText(ns.FormatNumber(rate, col.fmt))
            fs:Show()
        elseif col.show and col.key == "total" then
            fs:SetText("(" .. ns.FormatNumber(total, col.fmt) .. ")")
            fs:Show()
        elseif col.show and col.key == "pct" and not issecretvalue(total)
            and sessionTotal and not issecretvalue(sessionTotal) and sessionTotal > 0 then
            local pctFmt = col.fmt == "dec" and "%.1f%%" or "%d%%"
            fs:SetText(string.format(pctFmt, total / sessionTotal * 100))
            fs:Show()
        elseif col.show and col.key == "pct" then
            fs:SetText("-")
            fs:Show()
        else
            fs:SetText("")
            fs:Hide()
        end
    end
end

----------------------------------------------------------------------
-- Column anchoring
----------------------------------------------------------------------

function ns.AnchorColumns(button)
    button.pctFS:ClearAllPoints()
    button.totalFS:ClearAllPoints()
    button.rateFS:ClearAllPoints()

    -- Actions mode: actionFS is the only right-side element
    if button.actionFS and button.actionFS:IsShown() then
        return button.actionFS
    end

    local fontSize = ns.GetFontSize()
    local fsMap = { rate = button.rateFS, total = button.totalFS, pct = button.pctFS }
    local prevFS = nil
    for i = #ns.db.columns, 1, -1 do
        local col = ns.db.columns[i]
        if col.show then
            local fs = fsMap[col.key]
            local chars = FORMAT_CHARS[col.fmt] or 6
            if col.key == "total" then chars = chars + TOTAL_EXTRA_CHARS end
            fs:SetWidth(ColPixelWidth(chars, fontSize))
            if not prevFS then
                fs:SetPoint("RIGHT", button.bar, "RIGHT", -4, ns.GetFontNudge())
            else
                fs:SetPoint("RIGHT", prevFS, "LEFT", -2, 0)
            end
            prevFS = fs
        end
    end
    return prevFS
end

----------------------------------------------------------------------
-- Inline spell sub-rows (expanded player in the main meter)
----------------------------------------------------------------------
-- Appends this player's spells as `kind == "spell"` element-data entries into
-- an existing element list, right after their player row. Pure data shaping:
-- ns.GetSpellBreakdown already returns fully-resolved plain numbers, so no
-- secret-value handling is needed past the parent-total fallback. The columns
-- reuse ns.PopulateColumnValues via totalAmount / amountPerSecond / sessionTotal,
-- where sessionTotal = the player's own total so the pct column reads as the
-- spell's share of that player (matching how a breakdown should look).
function ns.AppendSpellRows(elements, sessionType, meterType, guid, parentTotal, classFilename)
    local L = ns.L
    local spells = ns.GetSpellBreakdown(sessionType, meterType, guid)

    if not spells or #spells == 0 then
        elements[#elements + 1] = {
            kind = "spell",
            isEmpty = true,
            name = L["NO_DATA"],
            classFilename = classFilename,
        }
        return
    end

    -- Parent total may be a secret value mid-combat; fall back to the sum of
    -- the (already-resolved) spell totals so the pct column stays meaningful.
    local ptotal = parentTotal
    if ptotal == nil or issecretvalue(ptotal) then
        ptotal = 0
        for _, s in ipairs(spells) do ptotal = ptotal + (s.total or 0) end
    end

    local maxTotal = spells[1].total
    local info = ns.TYPE_INFO[meterType]
    local rateKey = info and info.key

    for i, s in ipairs(spells) do
        local dn = "|cff6a6a72" .. i .. ".|r " .. (s.name or "?")
        if s.creatureName then
            dn = dn .. "  |cff8a8a99(" .. s.creatureName .. ")|r"
        end
        elements[#elements + 1] = {
            kind            = "spell",
            classFilename   = classFilename,
            name            = s.name,          -- tooltip title
            displayName     = dn,              -- rendered label (rank + pet)
            icon            = s.icon,
            totalAmount     = s.total,
            amountPerSecond = s.perSec,
            sessionTotal    = ptotal,          -- pct column => share of player
            maxAmount       = maxTotal,        -- bar scale within the group
            isActionType    = false,
            -- Tooltip extras (read by ns.BuildSpellTooltip):
            total           = s.total,
            perSec          = s.perSec,
            pct             = s.pct,
            rateKey         = rateKey,
            creatureName    = s.creatureName,
            overkill        = s.overkill,
            isAvoidable     = s.isAvoidable,
            isDeadly        = s.isDeadly,
        }
    end
end

----------------------------------------------------------------------
-- Informative hover tooltips
----------------------------------------------------------------------
-- Both builders are pure display helpers. They run only on hover (never on
-- the combat hot path) and guard every value with issecretvalue before any
-- Lua-side arithmetic. Anything still secret is simply omitted from the
-- tooltip rather than risking taint.

local ICON_ESCAPE = "|T%d:14:14:0:0:64:64:5:59:5:59|t "

-- Player bar tooltip: identity + headline stat + a top-spell sublist.
-- @param owner Frame the tooltip anchors to
-- @param ed table the bar's element data (name / classFilename / totals / GUID)
-- @param meterType number Enum.DamageMeterType
-- @param sessionType number Enum.DamageMeterSessionType
function ns.BuildBarTooltip(owner, ed, meterType, sessionType)
    local L = ns.L
    local GT = GameTooltip
    GT:SetOwner(owner, "ANCHOR_RIGHT")
    GT:ClearLines()

    -- Title: player name, class-coloured when the class is known.
    local name = ed.name
    if name ~= nil and issecretvalue(name) then name = "?" end
    if name and ns.db and ns.db.stripRealm then name = ns.StripRealm(name) end
    local cc = ed.classFilename and RAID_CLASS_COLORS[ed.classFilename]
    if cc then
        GT:AddLine(name or "?", cc.r, cc.g, cc.b)
    else
        GT:AddLine(name or "?", 1, 1, 1)
    end

    local isAction = ns.ACTIONS_TYPES[meterType]

    -- Headline rate (DPS / HPS) for rate-primary meters, when readable.
    if ns.RATE_PRIMARY[meterType] then
        local rate = ed.amountPerSecond
        if rate ~= nil and not issecretvalue(rate) then
            local info = ns.TYPE_INFO[meterType]
            local label = (info and L[info.key]) or L["DPS"]
            GT:AddDoubleLine(label, ns.FormatNumber(rate, "1dec"), 0.7, 0.7, 0.7, 1, 1, 1)
        end
    end

    -- Total (+ share of the session) when readable.
    local total = ed.totalAmount
    if total ~= nil and not issecretvalue(total) then
        local right = ns.FormatNumber(total, isAction and "short" or "1dec")
        local st = ed.sessionTotal
        if st and not issecretvalue(st) and st > 0 then
            right = right .. string.format("  (%.1f%%)", total / st * 100)
        end
        GT:AddDoubleLine(L["TIP_TOTAL"], right, 0.7, 0.7, 0.7, 1, 1, 1)
    end

    -- Top-spell sublist (reuses the same data path as the breakdown window).
    if ed.sourceGUID and not issecretvalue(ed.sourceGUID) then
        local spells = ns.GetSpellBreakdown(sessionType, meterType, ed.sourceGUID)
        if spells and #spells > 0 then
            GT:AddLine(" ")
            GT:AddLine(L["TIP_TOP_SPELLS"], ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3])
            for i = 1, math.min(5, #spells) do
                local s = spells[i]
                local label = s.name or "?"
                if s.creatureName then
                    label = label .. "  |cff8a8a99(" .. s.creatureName .. ")|r"
                end
                if s.icon then label = ICON_ESCAPE:format(s.icon) .. label end
                local right = ns.FormatNumber(s.total, "1dec")
                if s.pct and s.pct > 0 then
                    right = string.format("%.0f%%  ", s.pct) .. right
                end
                GT:AddDoubleLine(label, right, 0.9, 0.9, 0.9, 0.78, 0.78, 0.82)
            end
        end
        GT:AddLine(" ")
        GT:AddLine(L["TIP_LEFT_EXPAND"], 0.2, 1, 0.2)
        GT:AddLine(L["TIP_RIGHT_WINDOW"], 0.45, 0.8, 0.45)
    end

    GT:Show()
end

-- Spell row tooltip (breakdown window): per-spell detail incl. the Midnight
-- extras (caster pet, overkill, avoidable / killing-blow flags).
-- @param owner Frame the tooltip anchors to
-- @param data table the spell row's element data
function ns.BuildSpellTooltip(owner, data)
    local L = ns.L
    local GT = GameTooltip
    GT:SetOwner(owner, "ANCHOR_RIGHT")
    GT:ClearLines()

    GT:AddLine(data.name or "?", 1, 1, 1)
    if data.creatureName then
        GT:AddLine(string.format(L["TIP_CAST_BY"], data.creatureName), 0.6, 0.6, 0.7)
    end

    if data.perSec and not issecretvalue(data.perSec) and data.perSec > 0 then
        local label = (data.rateKey and L[data.rateKey]) or L["DPS"]
        GT:AddDoubleLine(label, ns.FormatNumber(data.perSec, "1dec"), 0.7, 0.7, 0.7, 1, 1, 1)
    end

    if data.total and not issecretvalue(data.total) then
        local right = ns.FormatNumber(data.total, "1dec")
        if data.pct and data.pct > 0 then
            right = right .. string.format("  (%.1f%%)", data.pct)
        end
        GT:AddDoubleLine(L["TIP_TOTAL"], right, 0.7, 0.7, 0.7, 1, 1, 1)
    end

    if data.overkill and not issecretvalue(data.overkill) and data.overkill > 0 then
        GT:AddDoubleLine(L["TIP_OVERKILL"], ns.FormatNumber(data.overkill, "1dec"),
            0.7, 0.7, 0.7, 1, 0.5, 0.5)
    end

    if data.isAvoidable then
        GT:AddLine(L["TIP_AVOIDABLE"], 1, 0.82, 0.2)
    end
    if data.isDeadly then
        GT:AddLine(L["TIP_KILLING_BLOW"], 1, 0.3, 0.3)
    end

    GT:Show()
end

----------------------------------------------------------------------
-- Report to chat: data snapshot
----------------------------------------------------------------------

function ns.SnapshotReportData(meterType, sessionType)
    local L = ns.L
    local session = C_DamageMeter.GetCombatSessionFromType(sessionType, meterType)
    if not session or issecretvalue(session) then return nil end
    local sources = session.combatSources
    if not sources or #sources == 0 then return nil end

    local first = sources[1]
    if issecretvalue(first.name) or issecretvalue(first.totalAmount) then
        return nil
    end

    local info = ns.TYPE_INFO[meterType]
    local typeName = info and L[info.key] or "Unknown"
    local sessKey = ns.SESSION_KEYS[sessionType]
    local sessionName = sessKey and L[sessKey] or L["CURRENT"]
    local header = string.format(L["REPORT_HEADER"], typeName, sessionName)

    local isRate = ns.RATE_PRIMARY[meterType]
    local lines = {}
    for i, source in ipairs(sources) do
        if issecretvalue(source.name) or issecretvalue(source.totalAmount) then
            break
        end
        local name = ns.StripRealm(source.name) or "Unknown"
        local value = isRate and source.amountPerSecond or source.totalAmount
        local formatted = ns.FormatNumber(value, "1dec")
        lines[#lines + 1] = i .. ". " .. formatted .. "  " .. name
    end

    return { header = header, lines = lines }
end

----------------------------------------------------------------------
-- Report to chat: send helper
----------------------------------------------------------------------

function ns.SendReport(snapshot, channel, maxLines)
    local L = ns.L
    local lines = snapshot.lines
    if maxLines > 0 and maxLines < #lines then
        lines = { unpack(lines, 1, maxLines) }
    end

    if channel == "DEBUG" then
        print(L["ADDON_PREFIX"] .. snapshot.header)
        for _, line in ipairs(lines) do
            print(L["ADDON_PREFIX"] .. line)
        end
    else
        local target = nil
        if channel == "WHISPER" then
            target = UnitIsPlayer("target") and GetUnitName("target", true) or nil
            if not target or target == "" then
                print(L["ADDON_PREFIX"] .. L["REPORT_NO_TARGET"])
                return
            end
        end
        SendChatMessage(snapshot.header, channel, nil, target)
        for _, line in ipairs(lines) do
            SendChatMessage(line, channel, nil, target)
        end
    end
end