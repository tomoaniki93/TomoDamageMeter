local ADDON_NAME, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Pull Compare
--
-- Side-by-side comparison of two completed C_DamageMeter combat segments.
-- The module is opened explicitly by the player; there is no ticker, polling
-- loop or combat-event listener. Historical segment reads are secret-guarded
-- and all UI maths only runs when the API returned ordinary Lua values.
----------------------------------------------------------------------

local WINDOW_WIDTH  = 900
local WINDOW_HEIGHT = 650
local HEADER_HEIGHT = 32
local CONTROL_HEIGHT = 58
local PLAYER_HEIGHT = 244
local ROW_HEIGHT = 25
local SPELL_ROW_HEIGHT = 24

local WORDS = {
    enUS = {
        title = "Pull Compare", compare = "Compare", damage = "Damage", healing = "Healing",
        reference = "A · Reference", candidate = "B · Compare", swap = "Swap A/B", refresh = "Refresh",
        players = "Players", spells = "Spell comparison", player = "Player", spell = "Spell",
        delta = "Delta", noSegments = "No combat segments available.", unreadable = "Segment data is not readable right now.",
        choosePlayer = "Click a player to compare spells.", noSpells = "No comparable spell data for this player.",
        segment = "Segment", total = "Total", currentMode = "Mode", openTip = "Compare two pulls / combat segments",
        help = "Open the pull / segment comparator",
    },
    frFR = {
        title = "Comparateur de pulls", compare = "Comparer", damage = "Dégâts", healing = "Soins",
        reference = "A · Référence", candidate = "B · Comparaison", swap = "Inverser A/B", refresh = "Actualiser",
        players = "Joueurs", spells = "Comparaison des sorts", player = "Joueur", spell = "Sort",
        delta = "Delta", noSegments = "Aucun segment de combat disponible.", unreadable = "Les données du segment ne sont pas lisibles pour le moment.",
        choosePlayer = "Cliquez sur un joueur pour comparer ses sorts.", noSpells = "Aucune donnée de sort comparable pour ce joueur.",
        segment = "Segment", total = "Total", currentMode = "Mode", openTip = "Comparer deux pulls / segments de combat",
        help = "Ouvrir le comparateur de pulls / segments",
    },
    deDE = {
        title = "Pull-Vergleich", compare = "Vergleichen", damage = "Schaden", healing = "Heilung",
        reference = "A · Referenz", candidate = "B · Vergleich", swap = "A/B tauschen", refresh = "Aktualisieren",
        players = "Spieler", spells = "Zaubervergleich", player = "Spieler", spell = "Zauber",
        delta = "Delta", noSegments = "Keine Kampfsegmente verfügbar.", unreadable = "Segmentdaten sind derzeit nicht lesbar.",
        choosePlayer = "Klicke einen Spieler an, um Zauber zu vergleichen.", noSpells = "Keine vergleichbaren Zauberdaten für diesen Spieler.",
        segment = "Segment", total = "Gesamt", currentMode = "Modus", openTip = "Zwei Pulls / Kampfsegmente vergleichen",
        help = "Pull-/Segment-Vergleich öffnen",
    },
    esES = {
        title = "Comparador de pulls", compare = "Comparar", damage = "Daño", healing = "Sanación",
        reference = "A · Referencia", candidate = "B · Comparar", swap = "Intercambiar A/B", refresh = "Actualizar",
        players = "Jugadores", spells = "Comparación de hechizos", player = "Jugador", spell = "Hechizo",
        delta = "Delta", noSegments = "No hay segmentos de combate disponibles.", unreadable = "Los datos del segmento no se pueden leer ahora.",
        choosePlayer = "Haz clic en un jugador para comparar hechizos.", noSpells = "No hay datos de hechizos comparables para este jugador.",
        segment = "Segmento", total = "Total", currentMode = "Modo", openTip = "Comparar dos pulls / segmentos de combate",
        help = "Abrir el comparador de pulls / segmentos",
    },
    itIT = {
        title = "Confronto pull", compare = "Confronta", damage = "Danni", healing = "Cure",
        reference = "A · Riferimento", candidate = "B · Confronto", swap = "Scambia A/B", refresh = "Aggiorna",
        players = "Giocatori", spells = "Confronto abilità", player = "Giocatore", spell = "Abilità",
        delta = "Delta", noSegments = "Nessun segmento di combattimento disponibile.", unreadable = "I dati del segmento non sono leggibili ora.",
        choosePlayer = "Clicca un giocatore per confrontare le abilità.", noSpells = "Nessun dato abilità confrontabile per questo giocatore.",
        segment = "Segmento", total = "Totale", currentMode = "Modalità", openTip = "Confronta due pull / segmenti di combattimento",
        help = "Apri il confronto pull / segmenti",
    },
    ptBR = {
        title = "Comparador de pulls", compare = "Comparar", damage = "Dano", healing = "Cura",
        reference = "A · Referência", candidate = "B · Comparar", swap = "Trocar A/B", refresh = "Atualizar",
        players = "Jogadores", spells = "Comparação de feitiços", player = "Jogador", spell = "Feitiço",
        delta = "Delta", noSegments = "Nenhum segmento de combate disponível.", unreadable = "Os dados do segmento não estão legíveis agora.",
        choosePlayer = "Clique em um jogador para comparar feitiços.", noSpells = "Nenhum dado de feitiço comparável para este jogador.",
        segment = "Segmento", total = "Total", currentMode = "Modo", openTip = "Comparar dois pulls / segmentos de combate",
        help = "Abrir comparador de pulls / segmentos",
    },
    ruRU = {
        title = "Сравнение пуллов", compare = "Сравнить", damage = "Урон", healing = "Исцеление",
        reference = "A · Эталон", candidate = "B · Сравнение", swap = "Поменять A/B", refresh = "Обновить",
        players = "Игроки", spells = "Сравнение заклинаний", player = "Игрок", spell = "Заклинание",
        delta = "Дельта", noSegments = "Нет доступных боевых сегментов.", unreadable = "Данные сегмента сейчас недоступны для чтения.",
        choosePlayer = "Выберите игрока для сравнения заклинаний.", noSpells = "Нет сопоставимых данных заклинаний для этого игрока.",
        segment = "Сегмент", total = "Всего", currentMode = "Режим", openTip = "Сравнить два пулла / боевых сегмента",
        help = "Открыть сравнение пуллов / сегментов",
    },
    zhCN = {
        title = "战斗段对比", compare = "对比", damage = "伤害", healing = "治疗",
        reference = "A · 基准", candidate = "B · 对比", swap = "交换 A/B", refresh = "刷新",
        players = "玩家", spells = "技能对比", player = "玩家", spell = "技能",
        delta = "变化", noSegments = "没有可用的战斗段。", unreadable = "当前无法读取该战斗段数据。",
        choosePlayer = "点击玩家以比较技能。", noSpells = "该玩家没有可比较的技能数据。",
        segment = "战斗段", total = "总量", currentMode = "模式", openTip = "比较两个战斗段",
        help = "打开战斗段对比",
    },
    zhTW = {
        title = "戰鬥段比較", compare = "比較", damage = "傷害", healing = "治療",
        reference = "A · 基準", candidate = "B · 比較", swap = "交換 A/B", refresh = "重新整理",
        players = "玩家", spells = "技能比較", player = "玩家", spell = "技能",
        delta = "變化", noSegments = "沒有可用的戰鬥段。", unreadable = "目前無法讀取該戰鬥段資料。",
        choosePlayer = "點擊玩家以比較技能。", noSpells = "該玩家沒有可比較的技能資料。",
        segment = "戰鬥段", total = "總量", currentMode = "模式", openTip = "比較兩個戰鬥段",
        help = "開啟戰鬥段比較",
    },
}
local W = WORDS[GetLocale()] or WORDS.enUS

local frame
local segments = {}
local indexA, indexB = 1, 2
local mode = "damage"
local playerRows = {}
local spellRows = {}
local currentPlayers = {}
local selectedPlayerKey

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

local function SafeNumber(v)
    if type(v) == "number" and not Secret(v) then return v end
    return 0
end

local function SafeText(v, fallback)
    if type(v) == "string" and not Secret(v) and v ~= "" then return v end
    return fallback or "?"
end

local function FormatValue(v)
    v = SafeNumber(v)
    if ns.FormatNumber then return ns.FormatNumber(v, "1dec") end
    if v >= 1000000 then return string.format("%.2fM", v / 1000000) end
    if v >= 1000 then return string.format("%.1fK", v / 1000) end
    return tostring(math.floor(v + 0.5))
end

local function FormatDelta(a, b)
    a, b = SafeNumber(a), SafeNumber(b)
    if a <= 0 and b <= 0 then return "-", 0.62, 0.62, 0.65 end
    if a <= 0 then return "NEW", 0.35, 0.95, 0.45 end
    local pct = ((b - a) / a) * 100
    if math.abs(pct) < 0.05 then return "0.0%", 0.65, 0.65, 0.68 end
    if pct > 0 then
        return string.format("+%.1f%%", pct), 0.35, 0.95, 0.45
    end
    return string.format("%.1f%%", pct), 1.00, 0.30, 0.30
end

local function MeterType()
    if mode == "healing" then
        return (Enum.DamageMeterType.HealingDone or Enum.DamageMeterType.Hps)
    end
    return (Enum.DamageMeterType.DamageDone or Enum.DamageMeterType.Dps)
end

local function GetSegmentLabel(sessionID, fallback)
    if not C_DamageMeter or not C_DamageMeter.GetCombatSessionFromID then return fallback end
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromID,
        sessionID, Enum.DamageMeterType.EnemyDamageTaken)
    if ok and session and not Secret(session) then
        local sources = session.combatSources
        if sources and not Secret(sources) and #sources > 0 then
            local name = sources[1].name
            if name and not Secret(name) then return ns.StripRealm and (ns.StripRealm(name) or name) or name end
        end
    end
    return fallback
end

local function LoadSegments()
    wipe(segments)
    if not C_DamageMeter or not C_DamageMeter.GetAvailableCombatSessions then return end
    local ok, list = pcall(C_DamageMeter.GetAvailableCombatSessions)
    if not ok or not list or Secret(list) then return end
    for i, entry in ipairs(list) do
        local id = entry.sessionID
        if id and not Secret(id) then
            local duration = SafeNumber(entry.durationSeconds)
            segments[#segments + 1] = {
                sessionID = id,
                duration = duration,
                label = GetSegmentLabel(id, W.segment .. " " .. i),
            }
        end
    end
    if #segments == 0 then
        indexA, indexB = 1, 1
    elseif #segments == 1 then
        indexA, indexB = 1, 1
    else
        indexA = math.min(indexA or 1, #segments)
        indexB = math.min(indexB or 2, #segments)
        if indexA == indexB then indexB = indexA == 1 and 2 or 1 end
    end
end

local function SegmentText(index)
    local s = segments[index]
    if not s then return "-" end
    local dur = s.duration > 0 and ("  |cff77777f" .. ns.FormatTimer(s.duration) .. "|r") or ""
    return string.format("%d. %s%s", index, s.label or (W.segment .. " " .. index), dur)
end

local function ReadPlayers(sessionID)
    local result = {}
    if not sessionID or not C_DamageMeter or not C_DamageMeter.GetCombatSessionFromID then return result, false end
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, sessionID, MeterType())
    if not ok or not session or Secret(session) then return result, false end
    local sources = session.combatSources
    if not sources or Secret(sources) then return result, false end

    for _, src in ipairs(sources) do
        local name = src.name
        if name and not Secret(name) then
            local fullName = tostring(name)
            local display = ns.StripRealm and (ns.StripRealm(fullName) or fullName) or fullName
            local guid = src.sourceGUID
            if guid and Secret(guid) then guid = nil end
            local classFile = src.classFilename
            if classFile and Secret(classFile) then classFile = nil end
            result[#result + 1] = {
                key = fullName,
                name = display,
                fullName = fullName,
                guid = guid,
                classFile = classFile,
                total = SafeNumber(src.totalAmount),
                rate = SafeNumber(src.amountPerSecond),
            }
        end
    end
    return result, true
end

local function MergePlayers(a, b)
    local map = {}
    for _, p in ipairs(a) do
        map[p.key] = { key = p.key, name = p.name, classFile = p.classFile, guidA = p.guid, a = p }
    end
    for _, p in ipairs(b) do
        local row = map[p.key]
        if not row then
            row = { key = p.key, name = p.name, classFile = p.classFile }
            map[p.key] = row
        end
        row.guidB = p.guid
        row.b = p
        if not row.classFile then row.classFile = p.classFile end
    end
    local out = {}
    for _, row in pairs(map) do out[#out + 1] = row end
    table.sort(out, function(x, y)
        local xv = math.max(x.a and x.a.rate or 0, x.b and x.b.rate or 0)
        local yv = math.max(y.a and y.a.rate or 0, y.b and y.b.rate or 0)
        if xv == yv then return (x.name or "") < (y.name or "") end
        return xv > yv
    end)
    for i, row in ipairs(out) do row.rank = i end
    return out
end

local function MergeSpells(spellsA, spellsB)
    local map = {}
    local function Add(list, side)
        for _, s in ipairs(list or {}) do
            local creature = s.creatureName and tostring(s.creatureName) or ""
            local key = tostring(s.name or "?") .. "\031" .. creature
            local row = map[key]
            if not row then
                row = {
                    key = key,
                    name = s.name or "?",
                    displayName = creature ~= "" and ((s.name or "?") .. "  |cff888891(" .. creature .. ")|r") or (s.name or "?"),
                    icon = s.icon,
                }
                map[key] = row
            end
            row[side] = s
            if not row.icon then row.icon = s.icon end
        end
    end
    Add(spellsA, "a")
    Add(spellsB, "b")
    local out = {}
    for _, row in pairs(map) do out[#out + 1] = row end
    table.sort(out, function(x, y)
        local xa = x.a and (x.a.perSec or x.a.total) or 0
        local xb = x.b and (x.b.perSec or x.b.total) or 0
        local ya = y.a and (y.a.perSec or y.a.total) or 0
        local yb = y.b and (y.b.perSec or y.b.total) or 0
        return math.max(xa or 0, xb or 0) > math.max(ya or 0, yb or 0)
    end)
    for i, row in ipairs(out) do row.rank = i end
    return out
end

local function SavePosition(self)
    if not ns.db then return end
    local point, _, relPoint, x, y = self:GetPoint(1)
    ns.db.pullComparePos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function RestorePosition(self)
    local p = ns.db and ns.db.pullComparePos
    self:ClearAllPoints()
    if p and p.point then
        self:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
    else
        self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function Backdrop(frameObj, r, g, b, a)
    frameObj:SetBackdrop({ bgFile = ns.FLAT, edgeFile = ns.FLAT, edgeSize = 1 })
    frameObj:SetBackdropColor(r, g, b, a or 1)
    frameObj:SetBackdropBorderColor(0.30, 0.30, 0.34, 0.85)
end

local function MakeText(parent, size, color)
    local fs = parent:CreateFontString(nil, "ARTWORK")
    fs:SetFont(ns.GetFont(), size, "OUTLINE")
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end

local function MakeButton(parent, text, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    Backdrop(btn, 0.075, 0.075, 0.088, 0.98)
    local fs = MakeText(btn, 10, {1, 1, 1})
    fs:SetPoint("CENTER", 0, ns.GetFontNudge())
    fs:SetText(text)
    btn._text = fs
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.30, 0.025, 0.055, 1)
        self:SetBackdropBorderColor(0.92, 0.07, 0.16, 0.95)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.075, 0.075, 0.088, 0.98)
        self:SetBackdropBorderColor(0.30, 0.30, 0.34, 0.85)
    end)
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end

local function SetupScroll(scroll, child)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        local target = self:GetVerticalScroll() - delta * (ROW_HEIGHT * 2)
        self:SetVerticalScroll(math.max(0, math.min(range, target)))
    end)
    scroll:SetScrollChild(child)
end

local RefreshAll, RefreshSpells

local function EnsureWindow()
    if frame then return frame end

    local f = CreateFrame("Frame", "TomoDMPullCompare", UIParent, "BackdropTemplate")
    f:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition(self) end)
    Backdrop(f, 0.012, 0.012, 0.016, 0.98)
    f:SetBackdropBorderColor(0.72, 0.05, 0.12, 0.92)
    RestorePosition(f)
    if not tContains(UISpecialFrames, f:GetName()) then tinsert(UISpecialFrames, f:GetName()) end

    local topGlow = f:CreateTexture(nil, "BORDER")
    topGlow:SetTexture(ns.FLAT)
    topGlow:SetVertexColor(0.92, 0.04, 0.12, 0.95)
    topGlow:SetHeight(2)
    topGlow:SetPoint("TOPLEFT", 1, -1)
    topGlow:SetPoint("TOPRIGHT", -1, -1)

    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 1, -2)
    header:SetPoint("TOPRIGHT", -1, -2)
    header:SetHeight(HEADER_HEIGHT)
    local headerBG = header:CreateTexture(nil, "BACKGROUND")
    headerBG:SetTexture(ns.FLAT)
    headerBG:SetVertexColor(0.055, 0.055, 0.067, 1)
    headerBG:SetAllPoints()
    if ns.TEX_HEADER_SHEEN then
        local sheen = header:CreateTexture(nil, "ARTWORK")
        sheen:SetTexture(ns.TEX_HEADER_SHEEN)
        sheen:SetAlpha(0.28)
        sheen:SetAllPoints()
    end

    local mark = MakeText(header, 12, {0.95, 0.08, 0.16})
    mark:SetPoint("LEFT", 10, 0)
    mark:SetText("TDM")
    local title = MakeText(header, 13, {1, 1, 1})
    title:SetPoint("LEFT", mark, "RIGHT", 10, 0)
    title:SetText(W.title)
    f._title = title

    local close = MakeButton(header, "×", 28, 24, function() f:Hide() end)
    close:SetPoint("RIGHT", -4, 0)
    close._text:SetFont(ns.GetFont(), 16, "OUTLINE")

    local controls = CreateFrame("Frame", nil, f, "BackdropTemplate")
    controls:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 8, -8)
    controls:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -8, -8)
    controls:SetHeight(CONTROL_HEIGHT)
    Backdrop(controls, 0.035, 0.035, 0.043, 0.98)

    local aLabel = MakeText(controls, 9, {0.63, 0.63, 0.68})
    aLabel:SetPoint("TOPLEFT", 10, -8)
    aLabel:SetText(W.reference)
    local aPrev = MakeButton(controls, "‹", 24, 26, function()
        if #segments == 0 then return end
        indexA = ((indexA - 2) % #segments) + 1
        if #segments > 1 and indexA == indexB then indexA = ((indexA - 2) % #segments) + 1 end
        RefreshAll()
    end)
    aPrev:SetPoint("BOTTOMLEFT", 10, 7)
    local aMain = MakeButton(controls, "-", 286, 26, function()
        if #segments == 0 then return end
        indexA = (indexA % #segments) + 1
        if #segments > 1 and indexA == indexB then indexA = (indexA % #segments) + 1 end
        RefreshAll()
    end)
    aMain:SetPoint("LEFT", aPrev, "RIGHT", 4, 0)
    aMain._text:SetJustifyH("LEFT")
    aMain._text:ClearAllPoints(); aMain._text:SetPoint("LEFT", 8, 0); aMain._text:SetPoint("RIGHT", -8, 0)
    local aNext = MakeButton(controls, "›", 24, 26, function()
        if #segments == 0 then return end
        indexA = (indexA % #segments) + 1
        if #segments > 1 and indexA == indexB then indexA = (indexA % #segments) + 1 end
        RefreshAll()
    end)
    aNext:SetPoint("LEFT", aMain, "RIGHT", 4, 0)

    local bLabel = MakeText(controls, 9, {0.63, 0.63, 0.68})
    bLabel:SetPoint("TOPLEFT", 376, -8)
    bLabel:SetText(W.candidate)
    local bPrev = MakeButton(controls, "‹", 24, 26, function()
        if #segments == 0 then return end
        indexB = ((indexB - 2) % #segments) + 1
        if #segments > 1 and indexB == indexA then indexB = ((indexB - 2) % #segments) + 1 end
        RefreshAll()
    end)
    bPrev:SetPoint("BOTTOMLEFT", 376, 7)
    local bMain = MakeButton(controls, "-", 286, 26, function()
        if #segments == 0 then return end
        indexB = (indexB % #segments) + 1
        if #segments > 1 and indexB == indexA then indexB = (indexB % #segments) + 1 end
        RefreshAll()
    end)
    bMain:SetPoint("LEFT", bPrev, "RIGHT", 4, 0)
    bMain._text:SetJustifyH("LEFT")
    bMain._text:ClearAllPoints(); bMain._text:SetPoint("LEFT", 8, 0); bMain._text:SetPoint("RIGHT", -8, 0)
    local bNext = MakeButton(controls, "›", 24, 26, function()
        if #segments == 0 then return end
        indexB = (indexB % #segments) + 1
        if #segments > 1 and indexB == indexA then indexB = (indexB % #segments) + 1 end
        RefreshAll()
    end)
    bNext:SetPoint("LEFT", bMain, "RIGHT", 4, 0)

    local modeBtn = MakeButton(controls, W.damage, 88, 26, function(self)
        mode = mode == "damage" and "healing" or "damage"
        self._text:SetText(mode == "damage" and W.damage or W.healing)
        selectedPlayerKey = nil
        RefreshAll()
    end)
    modeBtn:SetPoint("BOTTOMRIGHT", -104, 7)
    local swapBtn = MakeButton(controls, "⇄", 38, 26, function()
        indexA, indexB = indexB, indexA
        RefreshAll()
    end)
    swapBtn:SetPoint("LEFT", modeBtn, "RIGHT", 5, 0)
    local refreshBtn = MakeButton(controls, "↻", 38, 26, function()
        LoadSegments()
        RefreshAll()
    end)
    refreshBtn:SetPoint("LEFT", swapBtn, "RIGHT", 5, 0)

    f._aMain, f._bMain, f._modeBtn = aMain, bMain, modeBtn

    local playersTitle = MakeText(f, 11, {0.94, 0.08, 0.16})
    playersTitle:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 2, -10)
    playersTitle:SetText(W.players)

    local playerHead = CreateFrame("Frame", nil, f)
    playerHead:SetPoint("TOPLEFT", playersTitle, "BOTTOMLEFT", 0, -5)
    playerHead:SetPoint("TOPRIGHT", controls, "BOTTOMRIGHT", -2, 0)
    playerHead:SetHeight(20)
    local phbg = playerHead:CreateTexture(nil, "BACKGROUND")
    phbg:SetTexture(ns.FLAT); phbg:SetVertexColor(0.05, 0.05, 0.06, 1); phbg:SetAllPoints()

    local function Head(parent, text, point, x, width, justify)
        local fs = MakeText(parent, 9, {0.48, 0.48, 0.53})
        fs:SetPoint(point, x, 0); fs:SetWidth(width); fs:SetJustifyH(justify or "RIGHT"); fs:SetText(text)
        return fs
    end
    Head(playerHead, "#", "LEFT", 4, 28, "LEFT")
    Head(playerHead, W.player, "LEFT", 36, 330, "LEFT")
    Head(playerHead, "A", "RIGHT", -250, 105)
    Head(playerHead, "B", "RIGHT", -138, 105)
    Head(playerHead, W.delta, "RIGHT", -8, 120)

    local playerScroll = CreateFrame("ScrollFrame", nil, f)
    playerScroll:SetPoint("TOPLEFT", playerHead, "BOTTOMLEFT", 0, -1)
    playerScroll:SetPoint("TOPRIGHT", playerHead, "BOTTOMRIGHT", 0, -1)
    playerScroll:SetHeight(PLAYER_HEIGHT)
    local playerChild = CreateFrame("Frame", nil, playerScroll)
    playerChild:SetWidth(1); playerChild:SetHeight(1)
    SetupScroll(playerScroll, playerChild)
    f._playerScroll, f._playerChild = playerScroll, playerChild

    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetTexture(ns.FLAT); divider:SetVertexColor(0.80, 0.05, 0.12, 0.55); divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", playerScroll, "BOTTOMLEFT", 0, -8)
    divider:SetPoint("TOPRIGHT", playerScroll, "BOTTOMRIGHT", 0, -8)

    local spellTitle = MakeText(f, 11, {0.94, 0.08, 0.16})
    spellTitle:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -10)
    spellTitle:SetText(W.spells)
    local selectedFS = MakeText(f, 10, {0.62, 0.62, 0.67})
    selectedFS:SetPoint("LEFT", spellTitle, "RIGHT", 10, 0)
    f._selectedFS = selectedFS

    local spellHead = CreateFrame("Frame", nil, f)
    spellHead:SetPoint("TOPLEFT", spellTitle, "BOTTOMLEFT", 0, -5)
    spellHead:SetPoint("TOPRIGHT", controls, "BOTTOMRIGHT", -2, 0)
    spellHead:SetHeight(20)
    local shbg = spellHead:CreateTexture(nil, "BACKGROUND")
    shbg:SetTexture(ns.FLAT); shbg:SetVertexColor(0.05, 0.05, 0.06, 1); shbg:SetAllPoints()
    Head(spellHead, "#", "LEFT", 4, 28, "LEFT")
    Head(spellHead, W.spell, "LEFT", 36, 330, "LEFT")
    Head(spellHead, "A /s", "RIGHT", -250, 105)
    Head(spellHead, "B /s", "RIGHT", -138, 105)
    Head(spellHead, W.delta, "RIGHT", -8, 120)

    local spellScroll = CreateFrame("ScrollFrame", nil, f)
    spellScroll:SetPoint("TOPLEFT", spellHead, "BOTTOMLEFT", 0, -1)
    spellScroll:SetPoint("TOPRIGHT", spellHead, "BOTTOMRIGHT", 0, -1)
    spellScroll:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
    local spellChild = CreateFrame("Frame", nil, spellScroll)
    spellChild:SetWidth(1); spellChild:SetHeight(1)
    SetupScroll(spellScroll, spellChild)
    f._spellScroll, f._spellChild = spellScroll, spellChild

    local noData = MakeText(f, 11, {0.52, 0.52, 0.57})
    noData:SetPoint("CENTER", playerScroll, "CENTER", 0, 0)
    noData:SetText(W.noSegments)
    noData:Hide()
    f._noData = noData

    local spellHint = MakeText(f, 10, {0.48, 0.48, 0.53})
    spellHint:SetPoint("CENTER", spellScroll, "CENTER", 0, 0)
    spellHint:SetText(W.choosePlayer)
    f._spellHint = spellHint

    frame = f
    return f
end

local function EnsurePlayerRow(i)
    if playerRows[i] then return playerRows[i] end
    local f = EnsureWindow()
    local row = CreateFrame("Button", nil, f._playerChild, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", f._playerChild, "TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
    row:SetPoint("RIGHT", f._playerScroll, "RIGHT", 0, 0)
    row:SetBackdrop({ bgFile = ns.FLAT })
    row:SetBackdropColor(0.025, 0.025, 0.031, i % 2 == 0 and 0.98 or 0.82)

    local rank = MakeText(row, 10, {0.55, 0.55, 0.60}); rank:SetPoint("LEFT", 4, 0); rank:SetWidth(28); rank:SetJustifyH("LEFT")
    local name = MakeText(row, 10, {1, 1, 1}); name:SetPoint("LEFT", 36, 0); name:SetWidth(330); name:SetJustifyH("LEFT")
    local a = MakeText(row, 10, {0.80, 0.80, 0.84}); a:SetPoint("RIGHT", -250, 0); a:SetWidth(105); a:SetJustifyH("RIGHT")
    local b = MakeText(row, 10, {1, 1, 1}); b:SetPoint("RIGHT", -138, 0); b:SetWidth(105); b:SetJustifyH("RIGHT")
    local delta = MakeText(row, 10, {0.65, 0.65, 0.68}); delta:SetPoint("RIGHT", -8, 0); delta:SetWidth(120); delta:SetJustifyH("RIGHT")
    local selectMark = row:CreateTexture(nil, "ARTWORK"); selectMark:SetTexture(ns.FLAT); selectMark:SetWidth(2); selectMark:SetPoint("TOPLEFT"); selectMark:SetPoint("BOTTOMLEFT"); selectMark:SetVertexColor(0.92,0.05,0.13,1); selectMark:Hide()

    row._rank, row._name, row._a, row._b, row._delta, row._mark = rank, name, a, b, delta, selectMark
    row:SetScript("OnEnter", function(self) self:SetBackdropColor(0.16, 0.025, 0.045, 0.94) end)
    row:SetScript("OnLeave", function(self)
        local idx = self._index or 1
        self:SetBackdropColor(0.025, 0.025, 0.031, idx % 2 == 0 and 0.98 or 0.82)
    end)
    row:SetScript("OnClick", function(self)
        if not self._data then return end
        selectedPlayerKey = self._data.key
        RefreshAll()
    end)
    row:SetScript("OnMouseUp", function(self, btn)
        if btn ~= "RightButton" or not self._data then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(self._data.name or "?", 1, 1, 1)
        GameTooltip:AddLine("A " .. W.total .. ": " .. FormatValue(self._data.a and self._data.a.total or 0), 0.75, 0.75, 0.80)
        GameTooltip:AddLine("B " .. W.total .. ": " .. FormatValue(self._data.b and self._data.b.total or 0), 0.95, 0.95, 1.00)
        GameTooltip:Show()
    end)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    playerRows[i] = row
    return row
end

local function EnsureSpellRow(i)
    if spellRows[i] then return spellRows[i] end
    local f = EnsureWindow()
    local row = CreateFrame("Frame", nil, f._spellChild)
    row:SetHeight(SPELL_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", f._spellChild, "TOPLEFT", 0, -((i - 1) * SPELL_ROW_HEIGHT))
    row:SetPoint("RIGHT", f._spellScroll, "RIGHT", 0, 0)
    local bg = row:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(ns.FLAT); bg:SetVertexColor(0.022,0.022,0.028, i % 2 == 0 and 0.96 or 0.78); bg:SetAllPoints()
    local rank = MakeText(row, 9, {0.52,0.52,0.57}); rank:SetPoint("LEFT", 4, 0); rank:SetWidth(28); rank:SetJustifyH("LEFT")
    local icon = row:CreateTexture(nil, "ARTWORK"); icon:SetSize(18,18); icon:SetPoint("LEFT", 36, 0)
    local name = MakeText(row, 9, {0.92,0.92,0.95}); name:SetPoint("LEFT", icon, "RIGHT", 5, 0); name:SetWidth(307); name:SetJustifyH("LEFT")
    local a = MakeText(row, 9, {0.76,0.76,0.80}); a:SetPoint("RIGHT", -250, 0); a:SetWidth(105); a:SetJustifyH("RIGHT")
    local b = MakeText(row, 9, {0.95,0.95,1}); b:SetPoint("RIGHT", -138, 0); b:SetWidth(105); b:SetJustifyH("RIGHT")
    local delta = MakeText(row, 9, {0.65,0.65,0.68}); delta:SetPoint("RIGHT", -8, 0); delta:SetWidth(120); delta:SetJustifyH("RIGHT")
    row._rank, row._icon, row._name, row._a, row._b, row._delta = rank, icon, name, a, b, delta
    spellRows[i] = row
    return row
end

RefreshSpells = function()
    local f = EnsureWindow()
    for _, row in ipairs(spellRows) do row:Hide() end
    if not selectedPlayerKey then
        f._selectedFS:SetText("")
        f._spellHint:SetText(W.choosePlayer)
        f._spellHint:Show()
        f._spellChild:SetHeight(1)
        return
    end

    local pdata
    for _, row in ipairs(currentPlayers) do if row.key == selectedPlayerKey then pdata = row break end end
    if not pdata then
        selectedPlayerKey = nil
        f._selectedFS:SetText("")
        f._spellHint:SetText(W.choosePlayer)
        f._spellHint:Show()
        f._spellChild:SetHeight(1)
        return
    end
    f._selectedFS:SetText("— " .. (pdata.name or "?"))

    local segA, segB = segments[indexA], segments[indexB]
    local spellsA, spellsB = {}, {}
    if segA and pdata.guidA and ns.GetSpellBreakdownBySegment then
        local list = ns.GetSpellBreakdownBySegment(segA.sessionID, MeterType(), pdata.guidA)
        if type(list) == "table" then spellsA = list end
    end
    if segB and pdata.guidB and ns.GetSpellBreakdownBySegment then
        local list = ns.GetSpellBreakdownBySegment(segB.sessionID, MeterType(), pdata.guidB)
        if type(list) == "table" then spellsB = list end
    end
    local merged = MergeSpells(spellsA, spellsB)
    if #merged == 0 then
        f._spellHint:SetText(W.noSpells)
        f._spellHint:Show()
        f._spellChild:SetHeight(1)
        return
    end
    f._spellHint:Hide()
    f._spellChild:SetHeight(math.max(1, #merged * SPELL_ROW_HEIGHT))
    f._spellScroll:SetVerticalScroll(0)
    for i, data in ipairs(merged) do
        local row = EnsureSpellRow(i)
        local av = data.a and (SafeNumber(data.a.perSec) > 0 and data.a.perSec or data.a.total) or 0
        local bv = data.b and (SafeNumber(data.b.perSec) > 0 and data.b.perSec or data.b.total) or 0
        local dtext, dr, dg, db = FormatDelta(av, bv)
        row._rank:SetText(i .. ".")
        row._icon:SetTexture(data.icon or 134400)
        row._name:SetText(data.displayName or data.name or "?")
        row._a:SetText(FormatValue(av))
        row._b:SetText(FormatValue(bv))
        row._delta:SetText(dtext); row._delta:SetTextColor(dr, dg, db)
        row:Show()
    end
end

RefreshAll = function()
    local f = EnsureWindow()
    f._aMain._text:SetText(SegmentText(indexA))
    f._bMain._text:SetText(SegmentText(indexB))
    f._modeBtn._text:SetText(mode == "damage" and W.damage or W.healing)

    for _, row in ipairs(playerRows) do row:Hide() end
    wipe(currentPlayers)

    if #segments == 0 then
        f._noData:SetText(W.noSegments); f._noData:Show()
        f._playerChild:SetHeight(1)
        selectedPlayerKey = nil
        RefreshSpells()
        return
    end

    local segA, segB = segments[indexA], segments[indexB]
    local a, readableA = ReadPlayers(segA and segA.sessionID)
    local b, readableB = ReadPlayers(segB and segB.sessionID)
    if not readableA or not readableB then
        f._noData:SetText(W.unreadable); f._noData:Show()
        f._playerChild:SetHeight(1)
        selectedPlayerKey = nil
        RefreshSpells()
        return
    end
    f._noData:Hide()
    currentPlayers = MergePlayers(a, b)
    f._playerChild:SetHeight(math.max(1, #currentPlayers * ROW_HEIGHT))
    f._playerScroll:SetVerticalScroll(0)

    local selectedExists = false
    for i, data in ipairs(currentPlayers) do
        if data.key == selectedPlayerKey then selectedExists = true end
        local row = EnsurePlayerRow(i)
        row._index = i; row._data = data
        row._rank:SetText(i .. ".")
        local rr, rg, rb = 1, 1, 1
        if ns.ClassColor then
            rr, rg, rb = ns.ClassColor(data.classFile)
        end
        if type(rr) ~= "number" then rr, rg, rb = 1, 1, 1 end
        row._name:SetText(data.name or "?"); row._name:SetTextColor(rr, rg, rb)
        local av = data.a and data.a.rate or 0
        local bv = data.b and data.b.rate or 0
        local dtext, dr, dg, db = FormatDelta(av, bv)
        row._a:SetText(FormatValue(av))
        row._b:SetText(FormatValue(bv))
        row._delta:SetText(dtext); row._delta:SetTextColor(dr, dg, db)
        row._mark:SetShown(data.key == selectedPlayerKey)
        row:Show()
    end
    if selectedPlayerKey and not selectedExists then selectedPlayerKey = nil end
    RefreshSpells()
end

local function OpenCompare(sessionA, sessionB)
    local f = EnsureWindow()
    LoadSegments()
    if sessionA or sessionB then
        for i, s in ipairs(segments) do
            if sessionA and s.sessionID == sessionA then indexA = i end
            if sessionB and s.sessionID == sessionB then indexB = i end
        end
    end
    if #segments > 1 and indexA == indexB then indexB = indexA == 1 and 2 or 1 end
    RefreshAll()
    f:Show()
    f:Raise()
end

function ns.OpenPullCompare(sessionA, sessionB)
    OpenCompare(sessionA, sessionB)
end

function ns.TogglePullCompare()
    local f = EnsureWindow()
    if f:IsShown() then f:Hide() else OpenCompare() end
end

----------------------------------------------------------------------
-- Target Breakdown integration
----------------------------------------------------------------------

local function EnsureTargetCompareButton()
    local target = _G.TomoDMTargetBreakdown
    if not target or target._tdmPullCompareButton then return end
    local btn = MakeButton(target, W.compare, 78, 20, function() ns.OpenPullCompare() end)
    btn:SetPoint("TOPRIGHT", target, "TOPRIGHT", -58, -4)
    btn:SetFrameLevel(target:GetFrameLevel() + 20)
    btn._text:SetFont(ns.GetFont(), 9, "OUTLINE")
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.34, 0.025, 0.055, 1)
        self:SetBackdropBorderColor(0.95, 0.08, 0.16, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(W.openTip, 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    target._tdmPullCompareButton = btn
end

if ns.ShowTargetBreakdown then
    local originalShowTargetBreakdown = ns.ShowTargetBreakdown
    ns.ShowTargetBreakdown = function(...)
        originalShowTargetBreakdown(...)
        EnsureTargetCompareButton()
    end
end

----------------------------------------------------------------------
-- Slash command integration. RunHistory already wraps /tdm; this wrapper is
-- loaded afterwards and simply chains to whichever handler exists at this point.
----------------------------------------------------------------------

do
    local previous = SlashCmdList and SlashCmdList["TDM"]
    if previous then
        SlashCmdList["TDM"] = function(msg)
            local command = strtrim(string.lower(msg or ""))
            if command == "pulls" or command == "compare" then
                ns.TogglePullCompare()
                return
            end
            if command == "help" then
                previous(msg)
                print("/tdm pulls - " .. W.help)
                return
            end
            previous(msg)
        end
    end
end
