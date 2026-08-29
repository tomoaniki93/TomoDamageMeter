local ADDON_NAME, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Run Compare
--
-- Premium personal-performance card attached to Run Recap. It consumes only
-- the plain-number snapshots already stored by RunRecap; it never queries
-- C_DamageMeter itself, so it adds no secret-value or combat-path risk.
----------------------------------------------------------------------

local PANEL_HEIGHT = 208
local ROW_HEIGHT = 19
local MAX_COMPARE_RUNS = 5

local WORDS = {
    enUS = { title = "Performance", current = "Current", average = "Avg. 5", best = "Best", delta = "Delta", time = "Time", previous = "%d previous runs", noHistory = "No previous comparable run", history = "View history" },
    frFR = { title = "Performance", current = "Actuel", average = "Moy. 5", best = "Meilleur", delta = "Delta", time = "Temps", previous = "%d runs précédents", noHistory = "Aucun run précédent comparable", history = "Voir l'historique" },
    deDE = { title = "Leistung", current = "Aktuell", average = "Ø 5", best = "Bestwert", delta = "Delta", time = "Zeit", previous = "%d vorherige Runs", noHistory = "Kein vergleichbarer vorheriger Run", history = "Verlauf anzeigen" },
    esES = { title = "Rendimiento", current = "Actual", average = "Media 5", best = "Mejor", delta = "Delta", time = "Tiempo", previous = "%d runs anteriores", noHistory = "No hay runs anteriores comparables", history = "Ver historial" },
    itIT = { title = "Prestazioni", current = "Attuale", average = "Media 5", best = "Migliore", delta = "Delta", time = "Tempo", previous = "%d run precedenti", noHistory = "Nessun run precedente comparabile", history = "Vedi cronologia" },
    ptBR = { title = "Desempenho", current = "Atual", average = "Média 5", best = "Melhor", delta = "Delta", time = "Tempo", previous = "%d runs anteriores", noHistory = "Nenhum run anterior comparável", history = "Ver histórico" },
    ruRU = { title = "Результат", current = "Сейчас", average = "Сред. 5", best = "Лучшее", delta = "Дельта", time = "Время", previous = "%d прошлых забегов", noHistory = "Нет сопоставимых прошлых забегов", history = "Открыть историю" },
    zhCN = { title = "表现", current = "本次", average = "近5次均值", best = "最佳", delta = "变化", time = "时间", previous = "%d 次历史记录", noHistory = "没有可比较的历史记录", history = "查看历史" },
    zhTW = { title = "表現", current = "本次", average = "近5次平均", best = "最佳", delta = "變化", time = "時間", previous = "%d 次歷史紀錄", noHistory = "沒有可比較的歷史紀錄", history = "查看歷史" },
}
local W = WORDS[GetLocale()] or WORDS.enUS

local METRICS = {
    { field = "dps",        label = function() return L["DPS"] or "DPS" end,                       fmt = "1dec", better = "high" },
    { field = "hps",        label = function() return L["HPS"] or "HPS" end,                       fmt = "1dec", better = "high" },
    { field = "interrupts", label = function() return L["RECAP_COL_INT"] or "Interrupts" end,     fmt = "int",  better = "high" },
    { field = "deaths",     label = function() return L["RECAP_COL_DEATHS"] or "Deaths" end,      fmt = "int",  better = "low"  },
    { field = "avoidable",  label = function() return L["RECAP_COL_AVOIDABLE"] or "Avoidable" end, fmt = "1dec", better = "low"  },
    { field = "duration",   label = function() return W.time end,                                    fmt = "time", better = "low"  },
}

local panel
local rows = {}
local hookedRecap

local function PlayerName()
    local name, realm = UnitFullName("player")
    if not name then name = UnitName("player") end
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
end

local function FindSnapshotPlayer(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.players) ~= "table" then return nil end
    local guid = UnitGUID("player")
    local name = PlayerName()
    local shortName = name and ns.StripRealm(name) or name

    for _, p in ipairs(snapshot.players) do
        if guid and p.guid == guid then return p end
    end
    for _, p in ipairs(snapshot.players) do
        local pn = p.name and ns.StripRealm(p.name) or p.name
        if shortName and pn == shortName then return p end
    end
    return nil
end

local function FindHistoryPlayer(entry)
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

local function MetricValue(source, field, isHistoryEntry)
    if field == "duration" then
        return source and source.duration
    end
    if isHistoryEntry then
        return source and source.player and source.player[field]
    end
    return source and source[field]
end

local function NearlySame(a, b)
    if type(a) ~= "number" or type(b) ~= "number" then return false end
    local scale = math.max(math.abs(a), math.abs(b), 1)
    return math.abs(a - b) <= scale * 0.0005
end

local function SameAsSnapshot(entry, snapshot, snapshotPlayer)
    if not entry or not snapshot then return false end
    if entry.mapID and snapshot.mapID and entry.mapID ~= snapshot.mapID then return false end
    if entry.keyLevel ~= snapshot.keyLevel then return false end
    if not NearlySame(entry.duration or -1, snapshot.duration or -2) then return false end

    local hp = FindHistoryPlayer(entry)
    if not hp or not snapshotPlayer then return false end
    if snapshotPlayer.dps and hp.dps and not NearlySame(snapshotPlayer.dps, hp.dps) then return false end
    return true
end

local function PreviousRuns(snapshot, snapshotPlayer)
    local out = {}
    if not snapshot or not snapshot.mapID then return out end
    local history = _G.TomoDamageMeter and _G.TomoDamageMeter.GetRunHistory
        and _G.TomoDamageMeter.GetRunHistory(snapshot.mapID) or {}

    for _, entry in ipairs(history or {}) do
        if #out >= MAX_COMPARE_RUNS then break end
        if not SameAsSnapshot(entry, snapshot, snapshotPlayer) then
            local p = FindHistoryPlayer(entry)
            if p then
                out[#out + 1] = { entry = entry, player = p, duration = entry.duration }
            end
        end
    end
    return out
end

local function AverageAndBest(history, metric)
    local sum, count, best = 0, 0, nil
    for _, item in ipairs(history) do
        local value = MetricValue(item, metric.field, true)
        if type(value) == "number" then
            sum = sum + value
            count = count + 1
            if best == nil
                or (metric.better == "high" and value > best)
                or (metric.better == "low" and value < best) then
                best = value
            end
        end
    end
    if count == 0 then return nil, nil end
    return sum / count, best
end

local function FormatMetric(value, metric)
    if type(value) ~= "number" then return "-" end
    if metric.fmt == "time" then return ns.FormatTimer(math.max(0, value)) end
    return ns.FormatNumber(value, metric.fmt)
end

local function DeltaFor(current, average, metric)
    if type(current) ~= "number" or type(average) ~= "number" then return "-", 0 end
    local diff = current - average
    if math.abs(diff) < 0.0001 then return "0", 0 end

    local good = (metric.better == "high" and diff > 0) or (metric.better == "low" and diff < 0)
    local quality = good and 1 or -1

    if metric.fmt == "time" then
        local sign = diff > 0 and "+" or "-"
        return sign .. ns.FormatTimer(math.abs(diff)), quality
    end
    if math.abs(average) < 0.0001 then return "-", 0 end
    return string.format("%+.1f%%", (diff / average) * 100), quality
end

local function SetDeltaColor(fs, quality)
    if quality > 0 then
        fs:SetTextColor(0.30, 0.95, 0.38)
    elseif quality < 0 then
        fs:SetTextColor(1.00, 0.24, 0.28)
    else
        ns.Tint(fs, "muted")
    end
end

local function EnsurePanel(recap)
    if panel then return panel end

    panel = CreateFrame("Frame", "TomoDMRunCompare", UIParent, "BackdropTemplate")
    panel:SetSize(540, PANEL_HEIGHT)
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    panel:SetBackdrop({ bgFile = ns.FLAT, edgeFile = ns.FLAT, edgeSize = 1 })
    panel:SetBackdropColor(0.008, 0.008, 0.012, 0.96)
    panel:SetBackdropBorderColor(0.38, 0.035, 0.065, 0.92)

    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(28)

    local headerBG = header:CreateTexture(nil, "BACKGROUND")
    headerBG:SetTexture(ns.FLAT)
    headerBG:SetVertexColor(0.055, 0.055, 0.065, 0.98)
    headerBG:SetAllPoints()

    local title = header:CreateFontString(nil, "ARTWORK")
    title:SetFont(ns.GetFont(), 12, "OUTLINE")
    title:SetPoint("LEFT", 9, ns.GetFontNudge())
    title:SetText(W.title)
    title:SetTextColor(1, 1, 1)
    panel._title = title

    local subtitle = header:CreateFontString(nil, "ARTWORK")
    subtitle:SetFont(ns.GetFont(), 10, "OUTLINE")
    subtitle:SetPoint("RIGHT", -9, ns.GetFontNudge())
    subtitle:SetJustifyH("RIGHT")
    ns.Tint(subtitle, "secondary")
    panel._subtitle = subtitle

    local redLine = panel:CreateTexture(nil, "OVERLAY")
    redLine:SetTexture(ns.FLAT)
    redLine:SetVertexColor(0.96, 0.035, 0.085, 0.95)
    redLine:SetHeight(1)
    redLine:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
    redLine:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")

    local colY = -35
    local colMetricX, colCurrentX, colAverageX, colBestX, colDeltaX = 10, 188, 278, 368, 458
    local headings = {
        { text = W.current, x = colCurrentX },
        { text = W.average, x = colAverageX },
        { text = W.best, x = colBestX },
        { text = W.delta, x = colDeltaX },
    }
    for _, h in ipairs(headings) do
        local fs = panel:CreateFontString(nil, "ARTWORK")
        fs:SetFont(ns.GetFont(), 9, "OUTLINE")
        fs:SetPoint("TOPRIGHT", panel, "TOPLEFT", h.x + 68, colY)
        fs:SetWidth(68)
        fs:SetJustifyH("RIGHT")
        fs:SetText(h.text)
        ns.Tint(fs, "muted")
    end

    for i, metric in ipairs(METRICS) do
        local y = colY - 16 - (i - 1) * ROW_HEIGHT
        local row = {}

        local bg = panel:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(ns.FLAT)
        bg:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, y + 3)
        bg:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -6, y - ROW_HEIGHT + 4)
        bg:SetVertexColor(1, 1, 1, (i % 2 == 0) and 0.025 or 0.012)
        row.bg = bg

        local label = panel:CreateFontString(nil, "ARTWORK")
        label:SetFont(ns.GetFont(), 10, "OUTLINE")
        label:SetPoint("TOPLEFT", panel, "TOPLEFT", colMetricX, y)
        label:SetWidth(150)
        label:SetJustifyH("LEFT")
        label:SetText(metric.label())
        label:SetTextColor(0.88, 0.88, 0.90)
        row.label = label

        local function ValueFS(x)
            local fs = panel:CreateFontString(nil, "ARTWORK")
            fs:SetFont(ns.GetFont(), 10, "OUTLINE")
            fs:SetPoint("TOPRIGHT", panel, "TOPLEFT", x + 68, y)
            fs:SetWidth(68)
            fs:SetJustifyH("RIGHT")
            return fs
        end

        row.current = ValueFS(colCurrentX)
        row.average = ValueFS(colAverageX)
        row.best = ValueFS(colBestX)
        row.delta = ValueFS(colDeltaX)
        rows[i] = row
    end

    local historyBtn = CreateFrame("Button", nil, panel, "BackdropTemplate")
    historyBtn:SetSize(128, 24)
    historyBtn:SetPoint("BOTTOMRIGHT", -9, 8)
    historyBtn:SetBackdrop({ bgFile = ns.FLAT, edgeFile = ns.FLAT, edgeSize = 1 })
    historyBtn:SetBackdropColor(0.22, 0.02, 0.04, 0.98)
    historyBtn:SetBackdropBorderColor(0.88, 0.06, 0.12, 0.92)
    local historyFS = historyBtn:CreateFontString(nil, "ARTWORK")
    historyFS:SetFont(ns.GetFont(), 10, "OUTLINE")
    historyFS:SetPoint("CENTER", 0, ns.GetFontNudge())
    historyFS:SetText(W.history)
    historyFS:SetTextColor(1, 1, 1)
    historyBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.38, 0.025, 0.055, 1)
        self:SetBackdropBorderColor(1.00, 0.10, 0.18, 1)
    end)
    historyBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.22, 0.02, 0.04, 0.98)
        self:SetBackdropBorderColor(0.88, 0.06, 0.12, 0.92)
    end)
    historyBtn:SetScript("OnClick", function()
        if ns.OpenRunHistory then ns.OpenRunHistory(panel and panel._mapID) end
    end)
    panel._historyBtn = historyBtn

    panel:Hide()
    return panel
end

local function RefreshPanel(recap)
    local snapshot = ns.GetRunSnapshot and ns.GetRunSnapshot()
    local player = FindSnapshotPlayer(snapshot)
    if not snapshot or not player then
        if panel then panel:Hide() end
        return
    end

    local p = EnsurePanel(recap)
    p:ClearAllPoints()
    p:SetWidth(math.max(540, recap:GetWidth()))
    p:SetPoint("BOTTOM", recap, "TOP", 0, 6)

    local history = PreviousRuns(snapshot, player)
    p._mapID = snapshot.mapID
    local zone = snapshot.zoneName or ""
    local key = snapshot.keyLevel and (" +" .. snapshot.keyLevel) or ""
    p._title:SetText(W.title .. "  |cff999999-  " .. zone .. key .. "|r")
    if #history > 0 then
        p._subtitle:SetText(string.format(W.previous, #history))
    else
        p._subtitle:SetText(W.noHistory)
    end

    for i, metric in ipairs(METRICS) do
        local row = rows[i]
        local current = metric.field == "duration" and snapshot.duration or player[metric.field]
        local average, best = AverageAndBest(history, metric)
        local deltaText, quality = DeltaFor(current, average, metric)

        row.label:SetText(metric.label())
        row.current:SetText(FormatMetric(current, metric))
        row.average:SetText(FormatMetric(average, metric))
        row.best:SetText(FormatMetric(best, metric))
        row.delta:SetText(deltaText)

        row.current:SetTextColor(1, 1, 1)
        ns.Tint(row.average, "secondary")
        if best ~= nil and current ~= nil and NearlySame(current, best) then
            row.best:SetTextColor(0.96, 0.10, 0.16)
        else
            ns.Tint(row.best, "secondary")
        end
        SetDeltaColor(row.delta, quality)
    end

    if ns.DecorateTDMFrame then ns.DecorateTDMFrame(p, "recap") end
    p:Show()

    if not hookedRecap then
        hookedRecap = recap
        recap:HookScript("OnHide", function()
            if panel then panel:Hide() end
        end)
    end
end

if ns.ShowRunRecap and not ns._tdmRunCompareWrapped then
    ns._tdmRunCompareWrapped = true
    local ShowRunRecap = ns.ShowRunRecap
    ns.ShowRunRecap = function(...)
        local out = { ShowRunRecap(...) }
        local recap = _G.TomoDMRunRecap
        if recap and recap:IsShown() then RefreshPanel(recap) end
        return unpack(out)
    end
end

function ns.RefreshRunCompare()
    local recap = _G.TomoDMRunRecap
    if recap and recap:IsShown() then RefreshPanel(recap) end
end

if ns.OnSkinChanged then
    ns.OnSkinChanged(function()
        if panel and panel:IsShown() then
            panel:SetBackdropColor(0.008, 0.008, 0.012, 0.96)
            ns.RefreshRunCompare()
        end
    end)
end

