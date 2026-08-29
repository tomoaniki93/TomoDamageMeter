local ADDON_NAME, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Run History
--
-- Interactive history browser for the compact plain-number records already
-- written by RunRecap. No C_DamageMeter query is made here: this module is a
-- pure SavedVariables/UI consumer, so it is safe to open at any time.
----------------------------------------------------------------------

local WINDOW_WIDTH = 820
local WINDOW_HEIGHT = 540
local HEADER_HEIGHT = 31
local FILTER_HEIGHT = 38
local COL_HEIGHT = 22
local ROW_HEIGHT = 28
local MAX_ROWS = 10

local WORDS = {
    enUS = {
        title = "Run History", dungeon = "Dungeon", key = "Key", all = "All",
        date = "Date", time = "Time", interrupts = "Int.", deaths = "Deaths",
        avoidable = "Avoidable", selectA = "A", selectB = "B", clear = "Clear A/B",
        compare = "Compare A / B", noRuns = "No stored run for this filter.",
        chooseTwo = "Choose two runs with A and B to compare them.",
        currentMap = "Current dungeon", previous = "Previous dungeon", next = "Next dungeon",
    },
    frFR = {
        title = "Historique des runs", dungeon = "Donjon", key = "Clé", all = "Toutes",
        date = "Date", time = "Temps", interrupts = "Int.", deaths = "Morts",
        avoidable = "Évitable", selectA = "A", selectB = "B", clear = "Effacer A/B",
        compare = "Comparer A / B", noRuns = "Aucun run enregistré pour ce filtre.",
        chooseTwo = "Choisissez deux runs avec A et B pour les comparer.",
        currentMap = "Donjon actuel", previous = "Donjon précédent", next = "Donjon suivant",
    },
    deDE = {
        title = "Run-Verlauf", dungeon = "Dungeon", key = "Stufe", all = "Alle",
        date = "Datum", time = "Zeit", interrupts = "Unterbr.", deaths = "Tode",
        avoidable = "Vermeidbar", selectA = "A", selectB = "B", clear = "A/B löschen",
        compare = "A / B vergleichen", noRuns = "Keine gespeicherten Runs für diesen Filter.",
        chooseTwo = "Wähle zwei Runs mit A und B zum Vergleichen.",
        currentMap = "Aktueller Dungeon", previous = "Vorheriger Dungeon", next = "Nächster Dungeon",
    },
    esES = {
        title = "Historial de runs", dungeon = "Mazmorra", key = "Clave", all = "Todas",
        date = "Fecha", time = "Tiempo", interrupts = "Int.", deaths = "Muertes",
        avoidable = "Evitable", selectA = "A", selectB = "B", clear = "Borrar A/B",
        compare = "Comparar A / B", noRuns = "No hay runs guardados para este filtro.",
        chooseTwo = "Elige dos runs con A y B para compararlos.",
        currentMap = "Mazmorra actual", previous = "Mazmorra anterior", next = "Mazmorra siguiente",
    },
    itIT = {
        title = "Cronologia run", dungeon = "Dungeon", key = "Chiave", all = "Tutte",
        date = "Data", time = "Tempo", interrupts = "Int.", deaths = "Morti",
        avoidable = "Evitabile", selectA = "A", selectB = "B", clear = "Cancella A/B",
        compare = "Confronta A / B", noRuns = "Nessuna run salvata per questo filtro.",
        chooseTwo = "Scegli due run con A e B per confrontarle.",
        currentMap = "Dungeon attuale", previous = "Dungeon precedente", next = "Dungeon successivo",
    },
    ptBR = {
        title = "Histórico de runs", dungeon = "Masmorra", key = "Chave", all = "Todas",
        date = "Data", time = "Tempo", interrupts = "Int.", deaths = "Mortes",
        avoidable = "Evitável", selectA = "A", selectB = "B", clear = "Limpar A/B",
        compare = "Comparar A / B", noRuns = "Nenhuma run salva para este filtro.",
        chooseTwo = "Escolha duas runs com A e B para compará-las.",
        currentMap = "Masmorra atual", previous = "Masmorra anterior", next = "Próxima masmorra",
    },
    ruRU = {
        title = "История забегов", dungeon = "Подземелье", key = "Ключ", all = "Все",
        date = "Дата", time = "Время", interrupts = "Сбив.", deaths = "Смерти",
        avoidable = "Избегаемый", selectA = "A", selectB = "B", clear = "Очистить A/B",
        compare = "Сравнение A / B", noRuns = "Нет сохранённых забегов для этого фильтра.",
        chooseTwo = "Выберите два забега кнопками A и B для сравнения.",
        currentMap = "Текущее подземелье", previous = "Предыдущее", next = "Следующее",
    },
    zhCN = {
        title = "挑战历史", dungeon = "地下城", key = "钥匙", all = "全部",
        date = "日期", time = "时间", interrupts = "打断", deaths = "死亡",
        avoidable = "可规避", selectA = "A", selectB = "B", clear = "清除 A/B",
        compare = "比较 A / B", noRuns = "此筛选条件下没有已保存记录。",
        chooseTwo = "使用 A 和 B 选择两个记录进行比较。",
        currentMap = "当前地下城", previous = "上一个地下城", next = "下一个地下城",
    },
    zhTW = {
        title = "挑戰歷史", dungeon = "地城", key = "鑰匙", all = "全部",
        date = "日期", time = "時間", interrupts = "斷法", deaths = "死亡",
        avoidable = "可避免", selectA = "A", selectB = "B", clear = "清除 A/B",
        compare = "比較 A / B", noRuns = "此篩選條件下沒有已儲存紀錄。",
        chooseTwo = "使用 A 和 B 選擇兩個紀錄進行比較。",
        currentMap = "目前地城", previous = "上一個地城", next = "下一個地城",
    },
}
local W = WORDS[GetLocale()] or WORDS.enUS

local METRICS = {
    { field = "dps",        label = function() return L["DPS"] or "DPS" end,                           fmt = "1dec", better = "high" },
    { field = "hps",        label = function() return L["HPS"] or "HPS" end,                           fmt = "1dec", better = "high" },
    { field = "interrupts", label = function() return W.interrupts end,                                    fmt = "int",  better = "high" },
    { field = "deaths",     label = function() return W.deaths end,                                        fmt = "int",  better = "low"  },
    { field = "avoidable",  label = function() return W.avoidable end,                                     fmt = "1dec", better = "low"  },
    { field = "duration",   label = function() return W.time end,                                          fmt = "time", better = "low"  },
}

local frame
local rowFrames = {}
local compareRows = {}
local selectedMapID
local keyFilter
local selectedA
local selectedB
local visibleEntries = {}
local mapOptions = {}
local keyOptions = {}

local function PlayerName()
    local name, realm = UnitFullName("player")
    if not name then name = UnitName("player") end
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
end

local function FindPlayer(entry)
    if type(entry) ~= "table" or type(entry.players) ~= "table" then return nil end
    local guid = UnitGUID("player")
    if guid and entry.players[guid] then return entry.players[guid] end

    local name = PlayerName()
    local shortName = name and ns.StripRealm(name) or name
    for _, p in pairs(entry.players) do
        local pn = p.name and ns.StripRealm(p.name) or p.name
        if shortName and pn == shortName then return p end
    end
    return nil
end

local function FormatValue(value, fmt)
    if type(value) ~= "number" then return "-" end
    if fmt == "time" then return ns.FormatTimer(math.max(0, value)) end
    return ns.FormatNumber(value, fmt)
end

local function MetricValue(entry, player, field)
    if field == "duration" then return entry and entry.duration end
    return player and player[field]
end

local function DeltaText(a, b, metric)
    if type(a) ~= "number" or type(b) ~= "number" then return "-", 0 end
    local diff = b - a
    if math.abs(diff) < 0.0001 then return "0", 0 end
    local good = (metric.better == "high" and diff > 0) or (metric.better == "low" and diff < 0)
    local quality = good and 1 or -1
    if metric.fmt == "time" then
        local sign = diff > 0 and "+" or "-"
        return sign .. ns.FormatTimer(math.abs(diff)), quality
    end
    if math.abs(a) < 0.0001 then return "-", 0 end
    return string.format("%+.1f%%", (diff / a) * 100), quality
end

local function SetQualityColor(fs, quality)
    if quality > 0 then
        fs:SetTextColor(0.30, 0.95, 0.38)
    elseif quality < 0 then
        fs:SetTextColor(1.00, 0.24, 0.28)
    else
        ns.Tint(fs, "muted")
    end
end

local function MapLabel(mapID)
    for _, option in ipairs(mapOptions) do
        if option.mapID == mapID then return option.label end
    end
    return tostring(mapID or "-")
end

local function RebuildMapOptions(preferredMapID)
    wipe(mapOptions)
    local history = ns.db and ns.db.runHistory or nil
    if type(history) == "table" then
        for key, list in pairs(history) do
            if type(list) == "table" and #list > 0 then
                local mapID = tonumber(key) or key
                local first = list[1]
                local label = (first and first.zoneName) or ("Map " .. tostring(mapID))
                mapOptions[#mapOptions + 1] = { mapID = mapID, label = label }
            end
        end
    end
    table.sort(mapOptions, function(a, b)
        local al, bl = string.lower(a.label or ""), string.lower(b.label or "")
        if al == bl then return tostring(a.mapID) < tostring(b.mapID) end
        return al < bl
    end)

    if #mapOptions == 0 then
        selectedMapID = nil
        return
    end

    local wanted = preferredMapID or selectedMapID
    if wanted ~= nil then
        for _, option in ipairs(mapOptions) do
            if tostring(option.mapID) == tostring(wanted) then
                selectedMapID = option.mapID
                return
            end
        end
    end
    selectedMapID = mapOptions[1].mapID
end

local function CycleMap(direction)
    if #mapOptions == 0 then return end
    local index = 1
    for i, option in ipairs(mapOptions) do
        if tostring(option.mapID) == tostring(selectedMapID) then index = i; break end
    end
    index = ((index - 1 + direction) % #mapOptions) + 1
    selectedMapID = mapOptions[index].mapID
    keyFilter = nil
    selectedA, selectedB = nil, nil
end

local function RebuildKeyOptions()
    wipe(keyOptions)
    local seen = {}
    local list = _G.TomoDamageMeter and _G.TomoDamageMeter.GetRunHistory
        and _G.TomoDamageMeter.GetRunHistory(selectedMapID) or {}
    for _, entry in ipairs(list or {}) do
        if type(entry.keyLevel) == "number" and not seen[entry.keyLevel] then
            seen[entry.keyLevel] = true
            keyOptions[#keyOptions + 1] = entry.keyLevel
        end
    end
    table.sort(keyOptions)

    if keyFilter ~= nil and not seen[keyFilter] then keyFilter = nil end
end

local function CycleKey(direction)
    local options = { false }
    for _, level in ipairs(keyOptions) do options[#options + 1] = level end
    local index = 1
    for i, value in ipairs(options) do
        if (value == false and keyFilter == nil) or value == keyFilter then index = i; break end
    end
    index = ((index - 1 + direction) % #options) + 1
    keyFilter = options[index] == false and nil or options[index]
    selectedA, selectedB = nil, nil
end

local function RebuildVisibleEntries()
    wipe(visibleEntries)
    if not selectedMapID then return end
    local list = _G.TomoDamageMeter and _G.TomoDamageMeter.GetRunHistory
        and _G.TomoDamageMeter.GetRunHistory(selectedMapID) or {}
    for _, entry in ipairs(list or {}) do
        if keyFilter == nil or entry.keyLevel == keyFilter then
            visibleEntries[#visibleEntries + 1] = entry
            if #visibleEntries >= MAX_ROWS then break end
        end
    end
end

local function ButtonBackdrop(btn, active, secondary)
    if active then
        btn:SetBackdropColor(secondary and 0.16 or 0.34, secondary and 0.16 or 0.025, secondary and 0.18 or 0.05, 0.98)
        btn:SetBackdropBorderColor(secondary and 0.82 or 0.96, secondary and 0.82 or 0.06, secondary and 0.86 or 0.12, 0.95)
    else
        btn:SetBackdropColor(0.055, 0.055, 0.065, 0.96)
        btn:SetBackdropBorderColor(0.24, 0.24, 0.28, 0.82)
    end
end

local function MakeButton(parent, width, height, text)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop({ bgFile = ns.FLAT, edgeFile = ns.FLAT, edgeSize = 1 })
    ButtonBackdrop(btn, false)
    local fs = btn:CreateFontString(nil, "ARTWORK")
    fs:SetFont(ns.GetFont(), 10, "OUTLINE")
    fs:SetPoint("CENTER", 0, ns.GetFontNudge())
    fs:SetText(text or "")
    fs:SetTextColor(0.92, 0.92, 0.94)
    btn._fs = fs
    btn:SetScript("OnEnter", function(self)
        if not self._active then self:SetBackdropBorderColor(0.78, 0.08, 0.14, 0.92) end
    end)
    btn:SetScript("OnLeave", function(self)
        ButtonBackdrop(self, self._active, self._secondary)
    end)
    return btn
end

local function SavePosition(self)
    if not ns.db then return end
    local point, _, relPoint, x, y = self:GetPoint(1)
    ns.db.runHistoryPosition = { point = point, relPoint = relPoint, x = x, y = y }
end

local function RestorePosition(self)
    local pos = ns.db and ns.db.runHistoryPosition
    self:ClearAllPoints()
    if type(pos) == "table" and pos.point and pos.relPoint then
        self:SetPoint(pos.point, UIParent, pos.relPoint, pos.x or 0, pos.y or 0)
    else
        self:SetPoint("CENTER", UIParent, "CENTER", 0, 15)
    end
end

local function EnsureFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "TomoDMRunHistory", UIParent, "BackdropTemplate")
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition(self) end)
    frame:SetBackdrop({ bgFile = ns.FLAT, edgeFile = ns.FLAT, edgeSize = 1 })
    frame:SetBackdropColor(0.008, 0.008, 0.012, 0.97)
    frame:SetBackdropBorderColor(0.42, 0.035, 0.07, 0.94)
    RestorePosition(frame)
    tinsert(UISpecialFrames, "TomoDMRunHistory")

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(HEADER_HEIGHT)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SavePosition(frame) end)

    local headerBG = header:CreateTexture(nil, "BACKGROUND")
    headerBG:SetTexture(ns.FLAT)
    headerBG:SetVertexColor(0.05, 0.05, 0.06, 0.99)
    headerBG:SetAllPoints()

    local title = header:CreateFontString(nil, "ARTWORK")
    title:SetFont(ns.GetFont(), 13, "OUTLINE")
    title:SetPoint("LEFT", 10, ns.GetFontNudge())
    title:SetText(W.title)
    title:SetTextColor(1, 1, 1)

    local subtitle = header:CreateFontString(nil, "ARTWORK")
    subtitle:SetFont(ns.GetFont(), 10, "OUTLINE")
    subtitle:SetPoint("LEFT", title, "RIGHT", 9, 0)
    ns.Tint(subtitle, "secondary")
    frame._subtitle = subtitle

    local close = MakeButton(header, 27, 25, "×")
    close:SetPoint("RIGHT", -3, 0)
    close._fs:SetFont(ns.GetFont(), 15, "OUTLINE")
    close:SetScript("OnClick", function() frame:Hide() end)

    local redLine = frame:CreateTexture(nil, "OVERLAY")
    redLine:SetTexture(ns.FLAT)
    redLine:SetVertexColor(0.96, 0.035, 0.085, 0.96)
    redLine:SetHeight(2)
    redLine:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
    redLine:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")

    local filter = CreateFrame("Frame", nil, frame)
    filter:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 8, -7)
    filter:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -8, -7)
    filter:SetHeight(FILTER_HEIGHT)

    local mapPrev = MakeButton(filter, 28, 27, "‹")
    mapPrev:SetPoint("LEFT", 0, 0)
    local mapBtn = MakeButton(filter, 285, 27, "")
    mapBtn:SetPoint("LEFT", mapPrev, "RIGHT", 5, 0)
    local mapNext = MakeButton(filter, 28, 27, "›")
    mapNext:SetPoint("LEFT", mapBtn, "RIGHT", 5, 0)
    frame._mapBtn = mapBtn

    mapPrev:SetScript("OnClick", function() CycleMap(-1); ns.RefreshRunHistory() end)
    mapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mapBtn:SetScript("OnClick", function(_, button) CycleMap(button == "RightButton" and -1 or 1); ns.RefreshRunHistory() end)
    mapNext:SetScript("OnClick", function() CycleMap(1); ns.RefreshRunHistory() end)

    local keyPrev = MakeButton(filter, 28, 27, "‹")
    keyPrev:SetPoint("LEFT", mapNext, "RIGHT", 18, 0)
    local keyBtn = MakeButton(filter, 125, 27, "")
    keyBtn:SetPoint("LEFT", keyPrev, "RIGHT", 5, 0)
    local keyNext = MakeButton(filter, 28, 27, "›")
    keyNext:SetPoint("LEFT", keyBtn, "RIGHT", 5, 0)
    frame._keyBtn = keyBtn

    keyPrev:SetScript("OnClick", function() CycleKey(-1); ns.RefreshRunHistory() end)
    keyBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    keyBtn:SetScript("OnClick", function(_, button) CycleKey(button == "RightButton" and -1 or 1); ns.RefreshRunHistory() end)
    keyNext:SetScript("OnClick", function() CycleKey(1); ns.RefreshRunHistory() end)

    local clearBtn = MakeButton(filter, 105, 27, W.clear)
    clearBtn:SetPoint("RIGHT", 0, 0)
    clearBtn:SetScript("OnClick", function()
        selectedA, selectedB = nil, nil
        ns.RefreshRunHistory()
    end)

    local colHeader = CreateFrame("Frame", nil, frame)
    colHeader:SetPoint("TOPLEFT", filter, "BOTTOMLEFT", 0, -2)
    colHeader:SetPoint("TOPRIGHT", filter, "BOTTOMRIGHT", 0, -2)
    colHeader:SetHeight(COL_HEIGHT)

    local columnBG = colHeader:CreateTexture(nil, "BACKGROUND")
    columnBG:SetTexture(ns.FLAT)
    columnBG:SetVertexColor(1, 1, 1, 0.025)
    columnBG:SetAllPoints()

    local columns = {
        { text = W.date,       x = 8,   w = 118, justify = "LEFT" },
        { text = W.key,        x = 130, w = 45,  justify = "RIGHT" },
        { text = W.time,       x = 184, w = 64,  justify = "RIGHT" },
        { text = L["DPS"] or "DPS", x = 258, w = 82, justify = "RIGHT" },
        { text = L["HPS"] or "HPS", x = 350, w = 82, justify = "RIGHT" },
        { text = W.interrupts, x = 442, w = 48,  justify = "RIGHT" },
        { text = W.deaths,     x = 500, w = 54,  justify = "RIGHT" },
        { text = W.avoidable,  x = 564, w = 82,  justify = "RIGHT" },
        { text = W.selectA,    x = 682, w = 32,  justify = "CENTER" },
        { text = W.selectB,    x = 722, w = 32,  justify = "CENTER" },
    }
    for _, c in ipairs(columns) do
        local fs = colHeader:CreateFontString(nil, "ARTWORK")
        fs:SetFont(ns.GetFont(), 9, "OUTLINE")
        fs:SetPoint("LEFT", c.x, 0)
        fs:SetWidth(c.w)
        fs:SetJustifyH(c.justify)
        fs:SetText(c.text)
        ns.Tint(fs, "muted")
    end

    local rowsAnchor = CreateFrame("Frame", nil, frame)
    rowsAnchor:SetPoint("TOPLEFT", colHeader, "BOTTOMLEFT", 0, -1)
    rowsAnchor:SetPoint("TOPRIGHT", colHeader, "BOTTOMRIGHT", 0, -1)
    rowsAnchor:SetHeight(MAX_ROWS * ROW_HEIGHT)
    frame._rowsAnchor = rowsAnchor

    local noRuns = rowsAnchor:CreateFontString(nil, "ARTWORK")
    noRuns:SetFont(ns.GetFont(), 11, "OUTLINE")
    noRuns:SetPoint("TOP", 0, -38)
    noRuns:SetText(W.noRuns)
    ns.Tint(noRuns, "muted")
    noRuns:Hide()
    frame._noRuns = noRuns

    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, rowsAnchor)
        row:SetHeight(ROW_HEIGHT - 1)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(ns.FLAT)
        bg:SetAllPoints()
        bg:SetVertexColor(1, 1, 1, (i % 2 == 0) and 0.028 or 0.012)
        row._bg = bg

        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetTexture(ns.FLAT)
        hover:SetVertexColor(0.75, 0.05, 0.10, 0.10)
        hover:SetAllPoints()

        local function Cell(x, width, justify)
            local fs = row:CreateFontString(nil, "ARTWORK")
            fs:SetFont(ns.GetFont(), 10, "OUTLINE")
            fs:SetPoint("LEFT", x, ns.GetFontNudge())
            fs:SetWidth(width)
            fs:SetJustifyH(justify or "RIGHT")
            return fs
        end

        row.date = Cell(8, 118, "LEFT")
        row.key = Cell(130, 45)
        row.duration = Cell(184, 64)
        row.dps = Cell(258, 82)
        row.hps = Cell(350, 82)
        row.interrupts = Cell(442, 48)
        row.deaths = Cell(500, 54)
        row.avoidable = Cell(564, 82)

        local aBtn = MakeButton(row, 28, 21, W.selectA)
        aBtn:SetPoint("LEFT", 686, 0)
        local bBtn = MakeButton(row, 28, 21, W.selectB)
        bBtn:SetPoint("LEFT", 726, 0)
        row.aBtn, row.bBtn = aBtn, bBtn

        aBtn:SetScript("OnClick", function()
            local entry = row._entry
            if not entry then return end
            if selectedA == entry then
                selectedA = nil
            else
                selectedA = entry
                if selectedB == entry then selectedB = nil end
            end
            ns.RefreshRunHistory()
        end)
        bBtn:SetScript("OnClick", function()
            local entry = row._entry
            if not entry then return end
            if selectedB == entry then
                selectedB = nil
            else
                selectedB = entry
                if selectedA == entry then selectedA = nil end
            end
            ns.RefreshRunHistory()
        end)

        rowFrames[i] = row
    end

    local compare = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    compare:SetPoint("TOPLEFT", rowsAnchor, "BOTTOMLEFT", 0, -8)
    compare:SetPoint("TOPRIGHT", rowsAnchor, "BOTTOMRIGHT", 0, -8)
    compare:SetHeight(143)
    compare:SetBackdrop({ bgFile = ns.FLAT, edgeFile = ns.FLAT, edgeSize = 1 })
    compare:SetBackdropColor(0.025, 0.025, 0.032, 0.97)
    compare:SetBackdropBorderColor(0.20, 0.20, 0.24, 0.88)
    frame._compare = compare

    local compareTitle = compare:CreateFontString(nil, "ARTWORK")
    compareTitle:SetFont(ns.GetFont(), 11, "OUTLINE")
    compareTitle:SetPoint("TOPLEFT", 9, -8)
    compareTitle:SetText(W.compare)
    compareTitle:SetTextColor(1, 1, 1)

    local aSummary = compare:CreateFontString(nil, "ARTWORK")
    aSummary:SetFont(ns.GetFont(), 9, "OUTLINE")
    aSummary:SetPoint("TOPLEFT", 128, -9)
    aSummary:SetWidth(245)
    aSummary:SetJustifyH("LEFT")
    ns.Tint(aSummary, "secondary")
    frame._aSummary = aSummary

    local bSummary = compare:CreateFontString(nil, "ARTWORK")
    bSummary:SetFont(ns.GetFont(), 9, "OUTLINE")
    bSummary:SetPoint("TOPLEFT", 385, -9)
    bSummary:SetWidth(245)
    bSummary:SetJustifyH("LEFT")
    ns.Tint(bSummary, "secondary")
    frame._bSummary = bSummary

    local hint = compare:CreateFontString(nil, "ARTWORK")
    hint:SetFont(ns.GetFont(), 10, "OUTLINE")
    hint:SetPoint("CENTER", 0, -8)
    hint:SetText(W.chooseTwo)
    ns.Tint(hint, "muted")
    frame._compareHint = hint

    local colX = { 8, 150, 272, 394 }
    local headings = { "", "A", "B", "Δ B/A" }
    for i, text in ipairs(headings) do
        local fs = compare:CreateFontString(nil, "ARTWORK")
        fs:SetFont(ns.GetFont(), 9, "OUTLINE")
        fs:SetPoint("TOPLEFT", colX[i], -29)
        fs:SetWidth(i == 1 and 130 or 108)
        fs:SetJustifyH(i == 1 and "LEFT" or "RIGHT")
        fs:SetText(text)
        ns.Tint(fs, "muted")
    end

    for i, metric in ipairs(METRICS) do
        local y = -47 - (i - 1) * 15
        local r = {}
        r.label = compare:CreateFontString(nil, "ARTWORK")
        r.label:SetFont(ns.GetFont(), 9, "OUTLINE")
        r.label:SetPoint("TOPLEFT", colX[1], y)
        r.label:SetWidth(130)
        r.label:SetJustifyH("LEFT")

        local function Value(x)
            local fs = compare:CreateFontString(nil, "ARTWORK")
            fs:SetFont(ns.GetFont(), 9, "OUTLINE")
            fs:SetPoint("TOPLEFT", x, y)
            fs:SetWidth(108)
            fs:SetJustifyH("RIGHT")
            return fs
        end
        r.a = Value(colX[2])
        r.b = Value(colX[3])
        r.delta = Value(colX[4])
        compareRows[i] = r
    end

    if ns.DecorateTDMFrame then ns.DecorateTDMFrame(frame, "recap") end
    frame:Hide()
    return frame
end

local function EntrySummary(entry)
    if not entry then return "-" end
    local stamp = type(entry.finished) == "number" and date("%d/%m %H:%M", entry.finished) or "-"
    local key = entry.keyLevel and ("+" .. entry.keyLevel) or "-"
    return string.format("%s   %s   %s", stamp, key, ns.FormatTimer(entry.duration or 0))
end

local function RefreshCompare()
    local f = EnsureFrame()
    local ready = selectedA and selectedB
    f._compareHint:SetShown(not ready)

    f._aSummary:SetText("A  " .. EntrySummary(selectedA))
    f._bSummary:SetText("B  " .. EntrySummary(selectedB))

    local playerA = selectedA and FindPlayer(selectedA)
    local playerB = selectedB and FindPlayer(selectedB)

    for i, metric in ipairs(METRICS) do
        local row = compareRows[i]
        row.label:SetText(metric.label())
        if ready then
            local a = MetricValue(selectedA, playerA, metric.field)
            local b = MetricValue(selectedB, playerB, metric.field)
            local delta, quality = DeltaText(a, b, metric)
            row.a:SetText(FormatValue(a, metric.fmt))
            row.b:SetText(FormatValue(b, metric.fmt))
            row.delta:SetText(delta)
            ns.Tint(row.a, "secondary")
            row.b:SetTextColor(1, 1, 1)
            SetQualityColor(row.delta, quality)
            row.label:Show(); row.a:Show(); row.b:Show(); row.delta:Show()
        else
            row.label:Hide(); row.a:Hide(); row.b:Hide(); row.delta:Hide()
        end
    end
end

function ns.RefreshRunHistory()
    local f = EnsureFrame()
    RebuildMapOptions(selectedMapID)
    RebuildKeyOptions()
    RebuildVisibleEntries()

    local mapText = selectedMapID and MapLabel(selectedMapID) or "-"
    f._subtitle:SetText(mapText)
    f._mapBtn._fs:SetText(string.format("%s:  %s", W.dungeon, mapText))
    f._keyBtn._fs:SetText(string.format("%s:  %s", W.key, keyFilter and ("+" .. keyFilter) or W.all))

    f._noRuns:SetShown(#visibleEntries == 0)

    for i = 1, MAX_ROWS do
        local row = rowFrames[i]
        local entry = visibleEntries[i]
        row._entry = entry
        row:SetShown(entry ~= nil)
        if entry then
            local player = FindPlayer(entry)
            row.date:SetText(type(entry.finished) == "number" and date("%d/%m/%y %H:%M", entry.finished) or "-")
            row.key:SetText(entry.keyLevel and ("+" .. entry.keyLevel) or "-")
            row.duration:SetText(FormatValue(entry.duration, "time"))
            row.dps:SetText(FormatValue(player and player.dps, "1dec"))
            row.hps:SetText(FormatValue(player and player.hps, "1dec"))
            row.interrupts:SetText(FormatValue(player and player.interrupts, "int"))
            row.deaths:SetText(FormatValue(player and player.deaths, "int"))
            row.avoidable:SetText(FormatValue(player and player.avoidable, "1dec"))

            row.date:SetTextColor(0.90, 0.90, 0.92)
            ns.Tint(row.key, "accent")
            ns.Tint(row.duration, "secondary")
            row.dps:SetTextColor(1, 1, 1)
            ns.Tint(row.hps, "secondary")
            ns.Tint(row.interrupts, "secondary")
            ns.Tint(row.deaths, "secondary")
            ns.Tint(row.avoidable, "secondary")

            row.aBtn._active = selectedA == entry
            row.aBtn._secondary = false
            ButtonBackdrop(row.aBtn, row.aBtn._active, false)
            row.bBtn._active = selectedB == entry
            row.bBtn._secondary = true
            ButtonBackdrop(row.bBtn, row.bBtn._active, true)
        end
    end

    RefreshCompare()
end

function ns.OpenRunHistory(mapID)
    local snapshot = ns.GetRunSnapshot and ns.GetRunSnapshot()
    local preferred = mapID or (snapshot and snapshot.mapID) or selectedMapID
    RebuildMapOptions(preferred)
    keyFilter = nil
    selectedA, selectedB = nil, nil
    ns.RefreshRunHistory()
    EnsureFrame():Show()
end

function ns.ToggleRunHistory(mapID)
    local f = EnsureFrame()
    if f:IsShown() then
        f:Hide()
    else
        ns.OpenRunHistory(mapID)
    end
end

function ns.GetRunHistorySelection()
    return selectedMapID, keyFilter, selectedA, selectedB
end

if ns.OnSkinChanged then
    ns.OnSkinChanged(function()
        if frame and frame:IsShown() then
            frame:SetBackdropColor(0.008, 0.008, 0.012, 0.97)
            ns.RefreshRunHistory()
        end
    end)
end

----------------------------------------------------------------------
-- Slash integration
----------------------------------------------------------------------
if SlashCmdList and SlashCmdList["TDM"] and not ns._runHistorySlashWrapped then
    ns._runHistorySlashWrapped = true
    local PreviousTDMCommand = SlashCmdList["TDM"]
    SlashCmdList["TDM"] = function(msg)
        local command = tostring(msg or ""):match("^%s*(.-)%s*$"):lower()
        if command == "history" then
            ns.ToggleRunHistory()
            return
        end
        PreviousTDMCommand(msg)
        if command == "help" then
            print("/tdm history - " .. W.title)
        end
    end
end
