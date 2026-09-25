local ADDON_NAME, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- History Settings Page - 2.8.2
--
-- Embeds a boss-centric view of the persistent FightHistory data directly in
-- Settings V2.  It never reads C_DamageMeter; every value comes from the plain
-- SavedVariables snapshots captured by Modules/FightHistory.lua.
----------------------------------------------------------------------

local ROWS_PER_PAGE = 10
local W = L

local selectedBossKey
local pullPage = 1

local function Secret(v)
    return v ~= nil and issecretvalue and issecretvalue(v)
end

local function SafeNumber(v)
    if type(v) == "number" and not Secret(v) then return v end
    return 0
end

local function SafeText(v, fallback)
    if type(v) == "string" and not Secret(v) and v ~= "" then return v end
    return fallback or "?"
end

local function FormatNumber(v)
    v = SafeNumber(v)
    if ns.FormatNumber then return ns.FormatNumber(v, "1dec") end
    if math.abs(v) >= 1000000000 then return string.format("%.2fB", v / 1000000000) end
    if math.abs(v) >= 1000000 then return string.format("%.2fM", v / 1000000) end
    if math.abs(v) >= 1000 then return string.format("%.1fK", v / 1000) end
    return tostring(math.floor(v + 0.5))
end

local function FormatClock(seconds)
    seconds = math.max(0, math.floor(SafeNumber(seconds) + 0.5))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function GetHistory()
    local api = _G.TomoDamageMeter and _G.TomoDamageMeter.GetFightHistory
    if type(api) == "function" then
        local ok, history = pcall(api)
        if ok and type(history) == "table" then return history end
    end
    local out = {}
    if ns.db and type(ns.db.fightHistory) == "table" then
        for i, fight in ipairs(ns.db.fightHistory) do out[i] = fight end
    end
    return out
end

local function BossKey(fight)
    local instance = SafeNumber(fight.instanceID)
    local encounter = SafeNumber(fight.encounterID)
    local name = SafeText(fight.name, "?")
    return tostring(instance) .. ":" .. tostring(encounter) .. ":" .. name
end

local function BuildBossGroups()
    local byKey, groups = {}, {}
    for _, fight in ipairs(GetHistory()) do
        if type(fight) == "table" and fight.isBoss then
            local key = BossKey(fight)
            local group = byKey[key]
            if not group then
                group = {
                    key = key,
                    name = SafeText(fight.name, W.HISTORY_GUI_BOSS),
                    instanceName = SafeText(fight.instanceName, "?"),
                    encounterID = fight.encounterID,
                    instanceID = fight.instanceID,
                    latest = SafeNumber(fight.finished),
                    pulls = {},
                }
                byKey[key] = group
                groups[#groups + 1] = group
            end
            group.pulls[#group.pulls + 1] = fight
            if SafeNumber(fight.finished) > group.latest then group.latest = SafeNumber(fight.finished) end
        end
    end
    table.sort(groups, function(a, b)
        if a.latest == b.latest then return a.name < b.name end
        return a.latest > b.latest
    end)
    for _, group in ipairs(groups) do
        table.sort(group.pulls, function(a, b) return SafeNumber(a.finished) > SafeNumber(b.finished) end)
    end
    return groups
end

local function FindSelf(fight)
    if not fight then return nil end
    local playerGUID = UnitGUID and UnitGUID("player")
    local playerName, realm
    if UnitFullName then playerName, realm = UnitFullName("player") end
    if not playerName and UnitName then playerName = UnitName("player") end
    local fullName = playerName
    if playerName and realm and realm ~= "" then fullName = playerName .. "-" .. realm end

    for _, player in ipairs(fight.players or {}) do
        if playerGUID and player.guid and not Secret(player.guid) and player.guid == playerGUID then return player end
        local name = SafeText(player.name, nil)
        if name and (name == fullName or name == playerName) then return player end
        if name and ns.StripRealm and playerName and ns.StripRealm(name) == playerName then return player end
    end
    return nil
end

local function MakeFont(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "ARTWORK")
    fs:SetFont((ns.GetFont and ns.GetFont()) or STANDARD_TEXT_FONT, size, "OUTLINE")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    color = color or ns.TEXT_PRIMARY or { 1, 1, 1 }
    fs:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1)
    return fs
end

local function Backdrop(frame, bg, border)
    frame:SetBackdrop({ bgFile = ns.FLAT, edgeFile = ns.FLAT, edgeSize = 1 })
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

local function MakeButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 110, height or 26)
    Backdrop(btn, { 0.085, 0.085, 0.100, 0.96 }, { 0.22, 0.22, 0.25, 0.85 })
    local label = MakeFont(btn, 9, ns.TEXT_PRIMARY or { 1, 1, 1 }, "CENTER")
    label:SetPoint("CENTER")
    label:SetText(text or "")
    btn.label = label
    btn:SetScript("OnEnter", function(self)
        local c = ns.ACCENT or { 0.88, 0.08, 0.18 }
        self:SetBackdropColor((c[1] or 0.88) * 0.25, (c[2] or 0.08) * 0.25, (c[3] or 0.18) * 0.25, 1)
        self:SetBackdropBorderColor(c[1] or 0.88, c[2] or 0.08, c[3] or 0.18, 0.95)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.085, 0.085, 0.100, 0.96)
        self:SetBackdropBorderColor(0.22, 0.22, 0.25, 0.85)
    end)
    return btn
end

local function FindGroup(groups, key)
    for index, group in ipairs(groups) do
        if group.key == key then return group, index end
    end
    return groups[1], groups[1] and 1 or nil
end

function ns.CreateHistorySettingsPage(host)
    local page = CreateFrame("Frame", nil, host)
    page:SetAllPoints()

    local title = MakeFont(page, 18, ns.TEXT_PRIMARY or { 1, 1, 1 })
    title:SetPoint("TOPLEFT", 4, -2)
    title:SetText(W.HISTORY_GUI)

    local subtitle = MakeFont(page, 10, ns.TEXT_MUTED or { 0.52, 0.52, 0.56 })
    subtitle:SetPoint("TOPLEFT", 4, -30)
    subtitle:SetPoint("RIGHT", page, "RIGHT", -8, 0)
    subtitle:SetText(W.HISTORY_GUI_DESC)

    local bossLabel = MakeFont(page, 9, ns.TEXT_MUTED or { 0.52, 0.52, 0.56 })
    bossLabel:SetPoint("TOPLEFT", 4, -61)
    bossLabel:SetText(W.HISTORY_GUI_BOSS)

    local bossButton = MakeButton(page, "-", 325, 28)
    bossButton:SetPoint("TOPLEFT", 4, -78)
    bossButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local openFull = MakeButton(page, W.HISTORY_GUI_OPEN_FULL, 170, 28)
    openFull:SetPoint("TOPRIGHT", -8, -78)
    openFull:SetScript("OnClick", function()
        if ns.OpenFightHistory then ns.OpenFightHistory() end
    end)

    local summary = CreateFrame("Frame", nil, page, "BackdropTemplate")
    summary:SetPoint("TOPLEFT", 4, -116)
    summary:SetPoint("TOPRIGHT", -8, -116)
    summary:SetHeight(72)
    Backdrop(summary, { 0.055, 0.055, 0.065, 0.96 }, { 0.22, 0.22, 0.25, 0.85 })

    local summaryDefs = {
        { "pulls", W.HISTORY_GUI_PULLS },
        { "kills", W.HISTORY_GUI_KILLS },
        { "bestDps", W.HISTORY_GUI_BEST_DPS },
        { "bestHps", W.HISTORY_GUI_BEST_HPS },
        { "interrupts", W.HISTORY_GUI_INTERRUPTS },
    }
    page._summary = {}
    for i, def in ipairs(summaryDefs) do
        local cell = CreateFrame("Frame", nil, summary)
        cell:SetSize(110, 70)
        cell:SetPoint("LEFT", summary, "LEFT", 5 + ((i - 1) * 112), 0)
        local label = MakeFont(cell, 8, ns.TEXT_MUTED or { 0.52, 0.52, 0.56 }, "CENTER")
        label:SetPoint("TOP", 0, -13)
        label:SetText(def[2])
        local value = MakeFont(cell, 13, ns.TEXT_PRIMARY or { 1, 1, 1 }, "CENTER")
        value:SetPoint("TOP", label, "BOTTOM", 0, -5)
        value:SetText("-")
        page._summary[def[1]] = value
    end

    local headers = {
        { key = "date", text = W.HISTORY_GUI_DATE, x = 4, w = 78, align = "LEFT" },
        { key = "result", text = W.HISTORY_GUI_RESULT, x = 86, w = 48, align = "CENTER" },
        { key = "time", text = W.HISTORY_GUI_TIME, x = 138, w = 44, align = "RIGHT" },
        { key = "dps", text = W.HISTORY_GUI_DPS, x = 188, w = 70, align = "RIGHT" },
        { key = "hps", text = W.HISTORY_GUI_HPS, x = 264, w = 70, align = "RIGHT" },
        { key = "interrupts", text = W.HISTORY_GUI_INT, x = 340, w = 34, align = "RIGHT" },
        { key = "dispels", text = W.HISTORY_GUI_DISPELS, x = 380, w = 36, align = "RIGHT" },
        { key = "deaths", text = W.HISTORY_GUI_DEATHS, x = 422, w = 42, align = "RIGHT" },
        { key = "avoidable", text = W.HISTORY_GUI_AVOIDABLE, x = 470, w = 90, align = "RIGHT" },
    }

    for _, h in ipairs(headers) do
        local fs = MakeFont(page, 8, ns.TEXT_MUTED or { 0.52, 0.52, 0.56 }, h.align)
        fs:SetPoint("TOPLEFT", h.x, -202)
        fs:SetWidth(h.w)
        fs:SetText(h.text)
    end

    page._rows = {}
    for i = 1, ROWS_PER_PAGE do
        local row = CreateFrame("Frame", nil, page)
        row:SetPoint("TOPLEFT", 4, -220 - ((i - 1) * 23))
        row:SetPoint("TOPRIGHT", -8, -220 - ((i - 1) * 23))
        row:SetHeight(21)
        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetTexture(ns.FLAT)
            bg:SetAllPoints()
            bg:SetVertexColor(1, 1, 1, 0.025)
        end
        for _, h in ipairs(headers) do
            local fs = MakeFont(row, 9, ns.TEXT_SECONDARY or { 0.55, 0.55, 0.55 }, h.align)
            fs:SetPoint("LEFT", h.x - 4, 0)
            fs:SetWidth(h.w)
            row[h.key] = fs
        end
        page._rows[i] = row
    end

    local empty = MakeFont(page, 11, ns.TEXT_MUTED or { 0.52, 0.52, 0.56 }, "CENTER")
    empty:SetPoint("CENTER", page, "CENTER", 0, -35)
    empty:SetWidth(520)
    empty:SetText(W.HISTORY_GUI_NO_BOSS)
    page._empty = empty

    local prev = MakeButton(page, W.HISTORY_GUI_PREV, 92, 26)
    prev:SetPoint("BOTTOMLEFT", 4, 4)
    local pageText = MakeFont(page, 9, ns.TEXT_SECONDARY or { 0.55, 0.55, 0.55 }, "CENTER")
    pageText:SetPoint("LEFT", prev, "RIGHT", 8, 0)
    pageText:SetWidth(72)
    local nextb = MakeButton(page, W.HISTORY_GUI_NEXT, 92, 26)
    nextb:SetPoint("LEFT", pageText, "RIGHT", 8, 0)
    page._pageText = pageText

    local function Refresh()
        local groups = BuildBossGroups()
        local group, groupIndex = FindGroup(groups, selectedBossKey)
        if group then selectedBossKey = group.key else selectedBossKey = nil end

        bossButton:SetEnabled(group ~= nil)
        bossButton:SetAlpha(group and 1 or 0.45)
        if group then
            bossButton.label:SetText(group.name .. "  ·  " .. group.instanceName)
        else
            bossButton.label:SetText(W.HISTORY_GUI_NO_BOSS)
        end

        local pulls = group and group.pulls or {}
        local pages = math.max(1, math.ceil(#pulls / ROWS_PER_PAGE))
        if pullPage > pages then pullPage = pages end
        if pullPage < 1 then pullPage = 1 end
        pageText:SetText(string.format("%d / %d", pullPage, pages))
        prev:SetEnabled(pullPage > 1)
        prev:SetAlpha(pullPage > 1 and 1 or 0.4)
        nextb:SetEnabled(pullPage < pages)
        nextb:SetAlpha(pullPage < pages and 1 or 0.4)
        empty:SetShown(group == nil)

        local kills, bestDps, bestHps, totalInterrupts = 0, 0, 0, 0
        for _, fight in ipairs(pulls) do
            if fight.success then kills = kills + 1 end
            local player = FindSelf(fight)
            if player then
                local duration = math.max(0, SafeNumber(fight.duration))
                local dps = duration > 0 and SafeNumber(player.damage) / duration or 0
                local hps = duration > 0 and SafeNumber(player.healing) / duration or 0
                if dps > bestDps then bestDps = dps end
                if hps > bestHps then bestHps = hps end
                totalInterrupts = totalInterrupts + SafeNumber(player.interrupts)
            end
        end
        page._summary.pulls:SetText(tostring(#pulls))
        page._summary.kills:SetText(tostring(kills))
        page._summary.bestDps:SetText(FormatNumber(bestDps))
        page._summary.bestHps:SetText(FormatNumber(bestHps))
        page._summary.interrupts:SetText(tostring(math.floor(totalInterrupts + 0.5)))

        local first = (pullPage - 1) * ROWS_PER_PAGE + 1
        for i, row in ipairs(page._rows) do
            local fight = pulls[first + i - 1]
            row:SetShown(fight ~= nil)
            if fight then
                local player = FindSelf(fight)
                local duration = math.max(0, SafeNumber(fight.duration))
                local dps = player and duration > 0 and SafeNumber(player.damage) / duration or 0
                local hps = player and duration > 0 and SafeNumber(player.healing) / duration or 0
                row.date:SetText(date("%d/%m %H:%M", SafeNumber(fight.finished) > 0 and fight.finished or time()))
                row.result:SetText(fight.success and W.HISTORY_GUI_KILL or W.HISTORY_GUI_WIPE)
                if fight.success then row.result:SetTextColor(0.35, 0.95, 0.45) else row.result:SetTextColor(1.00, 0.30, 0.30) end
                row.time:SetText(FormatClock(duration))
                row.dps:SetText(FormatNumber(dps))
                row.hps:SetText(FormatNumber(hps))
                row.interrupts:SetText(tostring(math.floor(SafeNumber(player and player.interrupts) + 0.5)))
                row.dispels:SetText(tostring(math.floor(SafeNumber(player and player.dispels) + 0.5)))
                row.deaths:SetText(tostring(math.floor(SafeNumber(player and player.deaths) + 0.5)))
                row.avoidable:SetText(FormatNumber(SafeNumber(player and player.avoidable)))
            end
        end

        page._groups = groups
        page._groupIndex = groupIndex
    end

    bossButton:SetScript("OnClick", function(_, mouseButton)
        local groups = page._groups or BuildBossGroups()
        if #groups == 0 then return end
        local _, current = FindGroup(groups, selectedBossKey)
        current = current or 1

        if mouseButton == "RightButton" then
            current = current - 1
            if current < 1 then current = #groups end
            selectedBossKey = groups[current].key
            pullPage = 1
            Refresh()
            return
        end

        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(bossButton, function(_, root)
                root:CreateTitle(W.HISTORY_GUI_BOSS)
                for _, group in ipairs(groups) do
                    local entry = group
                    root:CreateButton(entry.name .. " — " .. entry.instanceName .. " (" .. #entry.pulls .. ")", function()
                        selectedBossKey = entry.key
                        pullPage = 1
                        Refresh()
                    end)
                end
            end)
        else
            current = (current % #groups) + 1
            selectedBossKey = groups[current].key
            pullPage = 1
            Refresh()
        end
    end)

    bossButton:SetScript("OnEnter", function(self)
        local c = ns.ACCENT or { 0.88, 0.08, 0.18 }
        self:SetBackdropColor((c[1] or 0.88) * 0.25, (c[2] or 0.08) * 0.25, (c[3] or 0.18) * 0.25, 1)
        self:SetBackdropBorderColor(c[1] or 0.88, c[2] or 0.08, c[3] or 0.18, 0.95)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(W.HISTORY_GUI_SELECT_TIP, 1, 1, 1)
        GameTooltip:Show()
    end)
    bossButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        self:SetBackdropColor(0.085, 0.085, 0.100, 0.96)
        self:SetBackdropBorderColor(0.22, 0.22, 0.25, 0.85)
    end)

    prev:SetScript("OnClick", function() pullPage = math.max(1, pullPage - 1); Refresh() end)
    nextb:SetScript("OnClick", function() pullPage = pullPage + 1; Refresh() end)

    page.Refresh = Refresh
    Refresh()
    page:Hide()
    return page
end
