local ADDON_NAME, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Fight History - 2.8.3
--
-- Persists completed dungeon / raid combats in SavedVariables so Blizzard's
-- single Expired / Previous Fight slot is no longer the only historical view.
-- Reads C_DamageMeter only from combat/event handlers and stores plain numbers.
----------------------------------------------------------------------

local HISTORY_LIMIT = 80
local LEFT_ROWS = 11
local PLAYER_ROWS = 14
local HISTORY_LAUNCHER_ICON = "Interface\\AddOns\\TomoDamageMeter\\Assets\\Textures\\history"

local frame
local selectedFight
local page = 1
local bossesOnly = false
local mode = "damage"
local playerPage = 1
local activeEncounter

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

local function Accent()
    local c = ns.ACCENT or { 0.88, 0.08, 0.18, 1 }
    return c[1] or 0.88, c[2] or 0.08, c[3] or 0.18
end

local function SetBackdrop(target, r, g, b, a, br, bg, bb, ba)
    target:SetBackdrop({
        bgFile = ns.FLAT or "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = ns.FLAT or "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 1,
    })
    target:SetBackdropColor(r, g, b, a)
    target:SetBackdropBorderColor(br, bg, bb, ba)
end

local function Font(parent, size, role, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont((ns.GetFont and ns.GetFont()) or STANDARD_TEXT_FONT, size, "OUTLINE")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    local c = role == "muted" and ns.TEXT_MUTED
        or role == "secondary" and ns.TEXT_SECONDARY
        or role == "label" and ns.TEXT_LABEL
        or ns.TEXT_PRIMARY
        or { 1, 1, 1 }
    fs:SetTextColor(c[1] or 1, c[2] or 1, c[3] or 1)
    return fs
end

local function MakeButton(parent, width, label)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, 24)
    SetBackdrop(button, 0.025, 0.025, 0.032, 0.92, 0.20, 0.20, 0.23, 0.82)
    local text = Font(button, 9, "secondary", "CENTER")
    text:SetPoint("CENTER")
    text:SetText(label or "")
    button._text = text
    button:SetScript("OnEnter", function(self)
        local r, g, b = Accent()
        self:SetBackdropColor(r * 0.14, g * 0.14, b * 0.14, 0.98)
        self:SetBackdropBorderColor(r, g, b, 0.86)
        self._text:SetTextColor(1, 1, 1)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.025, 0.025, 0.032, 0.92)
        self:SetBackdropBorderColor(0.20, 0.20, 0.23, 0.82)
        local c = ns.TEXT_SECONDARY or { 0.55, 0.55, 0.55 }
        self._text:SetTextColor(c[1] or 0.55, c[2] or 0.55, c[3] or 0.55)
    end)
    return button
end

local function EnsureDB()
    if not ns.db then return nil end
    if type(ns.db.fightHistory) ~= "table" then ns.db.fightHistory = {} end
    return ns.db
end

local function InTrackedInstance()
    local ok, name, instanceType, difficultyID, _, _, _, instanceID = pcall(GetInstanceInfo)
    if not ok or Secret(instanceType) then return nil end
    if instanceType ~= "party" and instanceType ~= "raid" and instanceType ~= "scenario" then return nil end
    return {
        instanceName = SafeText(name, "?"),
        instanceType = instanceType,
        difficultyID = SafeNumber(difficultyID),
        instanceID = SafeNumber(instanceID),
    }
end

local function EnsurePlayer(players, source)
    local guid = source.sourceGUID
    if Secret(guid) then guid = nil end
    local name = SafeText(source.name, nil)
    if not name then return nil end
    local key = guid or name
    local player = players[key]
    if not player then
        player = {
            guid = guid,
            name = name,
            classFile = not Secret(source.classFilename) and source.classFilename or nil,
            specIconID = not Secret(source.specIconID) and source.specIconID or nil,
            damage = 0, healing = 0, damageTaken = 0, avoidable = 0,
            absorbs = 0, interrupts = 0, dispels = 0, deaths = 0,
        }
        players[key] = player
    end
    return player
end

local function LatestSessionInfo()
    if not C_DamageMeter or not C_DamageMeter.GetAvailableCombatSessions then return nil, nil end
    local ok, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
    if not ok or not sessions or Secret(sessions) or #sessions == 0 then return nil, nil end
    -- Blizzard returns the combat-session list in chronological order; the last
    -- entry is the newest completed segment.  Keeping the session ID lets the
    -- history collector read a stable segment instead of whichever fight happens
    -- to be exposed as Current a moment later.
    local info = sessions[#sessions]
    if not info or Secret(info) then return nil, nil end
    local sessionID = info.sessionID
    if Secret(sessionID) or type(sessionID) ~= "number" then sessionID = nil end
    return sessionID, SafeText(info.name, nil)
end

local function ReadSession(sessionID, meterType)
    if meterType == nil or not C_DamageMeter then return nil end
    if sessionID ~= nil and C_DamageMeter.GetCombatSessionFromID then
        local ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, sessionID, meterType)
        if ok and session and not Secret(session) then return session end
        -- A stable ID must never silently fall back to Current: that could mix
        -- two different fights if one metric is unavailable for the saved ID.
        return nil
    end
    if not C_DamageMeter.GetCombatSessionFromType then return nil end
    local st = Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current
    if st == nil then return nil end
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, st, meterType)
    if ok and session and not Secret(session) then return session end
    return nil
end

local function ReadMetric(players, sessionID, meterType, field)
    local session = ReadSession(sessionID, meterType)
    if not session then return 0 end
    local sources = session.combatSources
    if not sources or Secret(sources) then return SafeNumber(session.durationSeconds) end
    for _, source in ipairs(sources) do
        local total = source.totalAmount
        if not Secret(total) and type(total) == "number" and total ~= 0 then
            local player = EnsurePlayer(players, source)
            if player then player[field] = (player[field] or 0) + total end
        end
    end
    return SafeNumber(session.durationSeconds)
end

local function ReadTopEnemy(sessionID)
    local mt = Enum and Enum.DamageMeterType and Enum.DamageMeterType.EnemyDamageTaken
    if mt == nil then return nil end
    local session = ReadSession(sessionID, mt)
    if not session then return nil end
    local sources = session.combatSources
    if not sources or Secret(sources) or #sources == 0 then return nil end
    return SafeText(sources[1].name, nil)
end

local function CaptureSnapshot(sessionID, sessionName)
    local instance = InTrackedInstance()
    if not instance then return nil end
    local players = {}
    local duration = 0
    local D = Enum and Enum.DamageMeterType
    if not D then return nil end

    local damageType = D.DamageDone or D.Dps
    local healingType = D.HealingDone or D.Hps
    duration = math.max(duration, ReadMetric(players, sessionID, damageType, "damage"))
    duration = math.max(duration, ReadMetric(players, sessionID, healingType, "healing"))
    duration = math.max(duration, ReadMetric(players, sessionID, D.DamageTaken, "damageTaken"))
    duration = math.max(duration, ReadMetric(players, sessionID, D.AvoidableDamageTaken, "avoidable"))
    duration = math.max(duration, ReadMetric(players, sessionID, D.Absorbs, "absorbs"))
    duration = math.max(duration, ReadMetric(players, sessionID, D.Interrupts, "interrupts"))
    duration = math.max(duration, ReadMetric(players, sessionID, D.Dispels, "dispels"))
    duration = math.max(duration, ReadMetric(players, sessionID, D.Deaths, "deaths"))

    local list, meaningful = {}, false
    for _, player in pairs(players) do
        if (player.damage or 0) > 0 or (player.healing or 0) > 0 then meaningful = true end
        list[#list + 1] = player
    end
    if not meaningful then return nil end

    instance.players = list
    instance.duration = duration
    instance.sessionID = sessionID
    instance.enemy = sessionName or ReadTopEnemy(sessionID)
    instance.finished = time()
    return instance
end

local function CaptureCurrent()
    local sessionID, sessionName = LatestSessionInfo()
    return CaptureSnapshot(sessionID, sessionName)
end

-- Boss encounters have slightly different event timing from normal trash pulls:
-- ENCOUNTER_END can fire before Blizzard has appended the just-finished fight to
-- GetAvailableCombatSessions().  In that window LatestSessionInfo() still points
-- at the preceding trash pull.  Reading the Current session synchronously from
-- ENCOUNTER_END / PLAYER_REGEN_ENABLED gives us a plain-number fallback without
-- timer polling and prevents the boss from disappearing from persistent history.
local function CaptureLiveCurrent()
    return CaptureSnapshot(nil, nil)
end

local function MergeParts(parts)
    if not parts or #parts == 0 then return nil end
    local merged = {
        instanceName = parts[#parts].instanceName,
        instanceType = parts[#parts].instanceType,
        difficultyID = parts[#parts].difficultyID,
        instanceID = parts[#parts].instanceID,
        enemy = parts[#parts].enemy,
        finished = parts[#parts].finished,
        duration = 0,
        players = {},
    }
    if #parts == 1 then merged.sessionID = parts[1].sessionID end
    local byKey = {}
    for _, part in ipairs(parts) do
        merged.duration = merged.duration + SafeNumber(part.duration)
        for _, source in ipairs(part.players or {}) do
            local key = source.guid or source.name
            local target = byKey[key]
            if not target then
                target = {
                    guid = source.guid, name = source.name, classFile = source.classFile, specIconID = source.specIconID,
                    damage = 0, healing = 0, damageTaken = 0, avoidable = 0,
                    absorbs = 0, interrupts = 0, dispels = 0, deaths = 0,
                }
                byKey[key] = target
                merged.players[#merged.players + 1] = target
            end
            for _, field in ipairs({ "damage", "healing", "damageTaken", "avoidable", "absorbs", "interrupts", "dispels", "deaths" }) do
                target[field] = (target[field] or 0) + SafeNumber(source[field])
            end
        end
    end
    return merged
end

local function SaveFight(snapshot, encounter)
    local db = EnsureDB()
    if not db or not snapshot then return end

    snapshot.isBoss = encounter ~= nil
    snapshot.encounterID = encounter and encounter.id or nil
    snapshot.name = encounter and encounter.name or (snapshot.enemy or L["FIGHT_HISTORY_TRASH"] or "Trash")
    snapshot.success = encounter and encounter.success or nil
    snapshot.groupSize = encounter and encounter.groupSize or nil
    snapshot.difficultyID = (encounter and encounter.difficultyID) or snapshot.difficultyID

    -- PLAYER_REGEN_ENABLED and ENCOUNTER_END can both expose the same stable
    -- combat-session ID.  A rare event ordering can also save that session as
    -- trash just before ENCOUNTER_END identifies it as a boss.  In that case
    -- upgrade the existing row instead of discarding the boss metadata.
    if snapshot.sessionID ~= nil then
        for index, saved in ipairs(db.fightHistory) do
            if type(saved) == "table" and saved.sessionID == snapshot.sessionID then
                if snapshot.isBoss and not saved.isBoss then
                    db.fightHistory[index] = snapshot
                    if selectedFight == saved then selectedFight = snapshot end
                    if frame and frame:IsShown() then UpdateUI() end
                    if ns.RefreshSettingsV2 then ns.RefreshSettingsV2() end
                end
                return
            end
        end
    end

    table.insert(db.fightHistory, 1, snapshot)
    while #db.fightHistory > HISTORY_LIMIT do table.remove(db.fightHistory) end
    if frame and frame:IsShown() then selectedFight = snapshot end
    if ns.RefreshSettingsV2 then ns.RefreshSettingsV2() end
end

local function AppendEncounterPart(encounter, snapshot)
    if not encounter or not snapshot then return false end
    -- At ENCOUNTER_START the newest available segment still belongs to the
    -- previous pull. Ignore that baseline until Blizzard publishes a new ID.
    if #encounter.parts == 0 and snapshot.sessionID ~= nil
        and encounter.baselineSessionID ~= nil and snapshot.sessionID == encounter.baselineSessionID then
        return false
    end
    local count = #encounter.parts
    local last = count > 0 and encounter.parts[count] or nil
    if snapshot.sessionID ~= nil and last and last.sessionID == snapshot.sessionID then
        -- Same Blizzard segment observed by two end-of-combat events: keep the
        -- freshest snapshot rather than summing it twice.
        encounter.parts[count] = snapshot
    else
        encounter.parts[count + 1] = snapshot
    end
    return true
end

local function FinalizeEncounter(encounter)
    if not encounter or encounter.saved then return end
    local merged = MergeParts(encounter.parts)
    if not merged then merged = encounter.fallbackSnapshot end
    if not merged then return end
    encounter.saved = true
    SaveFight(merged, encounter)
end

local function FilteredHistory()
    local db = EnsureDB()
    local out = {}
    if not db then return out end
    for _, fight in ipairs(db.fightHistory) do
        if type(fight) == "table" and (not bossesOnly or fight.isBoss) then out[#out + 1] = fight end
    end
    return out
end

local function SortedPlayers(fight)
    local out = {}
    if not fight then return out end
    for _, player in ipairs(fight.players or {}) do out[#out + 1] = player end
    local field = mode == "healing" and "healing" or "damage"
    table.sort(out, function(a, b)
        local av, bv = SafeNumber(a[field]), SafeNumber(b[field])
        if av == bv then return SafeText(a.name, "") < SafeText(b.name, "") end
        return av > bv
    end)
    return out
end

local function UpdateUI()
    if not frame then return end
    local history = FilteredHistory()
    local pages = math.max(1, math.ceil(#history / LEFT_ROWS))
    if page > pages then page = pages end
    if page < 1 then page = 1 end

    frame._page:SetText(string.format("%d / %d", page, pages))
    frame._empty:SetShown(#history == 0)

    if not selectedFight or (bossesOnly and not selectedFight.isBoss) then selectedFight = history[1]; playerPage = 1 end

    local first = (page - 1) * LEFT_ROWS + 1
    for i, row in ipairs(frame._fightRows) do
        local entry = history[first + i - 1]
        row._fight = entry
        row:SetShown(entry ~= nil)
        if entry then
            row.kind:SetText(entry.isBoss and (L["FIGHT_HISTORY_BOSS"] or "Boss") or (L["FIGHT_HISTORY_TRASH"] or "Trash"))
            row.name:SetText(SafeText(entry.name, "?"))
            row.meta:SetText(string.format("%s  ·  %s", date("%d/%m %H:%M", entry.finished or time()), FormatClock(entry.duration)))
            local r, g, b = Accent()
            if entry == selectedFight then
                row:SetBackdropColor(r * 0.16, g * 0.16, b * 0.16, 0.96)
                row:SetBackdropBorderColor(r, g, b, 0.92)
            else
                row:SetBackdropColor(0.018, 0.018, 0.024, 0.86)
                row:SetBackdropBorderColor(0.16, 0.16, 0.19, 0.76)
            end
            row.kind:SetTextColor(entry.isBoss and r or 0.55, entry.isBoss and g or 0.55, entry.isBoss and b or 0.58)
        end
    end

    local fight = selectedFight
    frame._detailEmpty:SetShown(fight == nil)
    frame._detailTitle:SetText(fight and SafeText(fight.name, "?") or "")
    if fight then
        local result = ""
        if fight.isBoss and fight.success ~= nil then
            result = " · " .. (fight.success and (L["FIGHT_HISTORY_KILL"] or "Kill") or (L["FIGHT_HISTORY_WIPE"] or "Wipe"))
        end
        frame._detailMeta:SetText(string.format("%s · %s · %s%s",
            SafeText(fight.instanceName, "?"), date("%d/%m/%y %H:%M", fight.finished or time()), FormatClock(fight.duration), result))
    else
        frame._detailMeta:SetText("")
    end

    frame._damageButton._text:SetTextColor(mode == "damage" and 1 or 0.6, mode == "damage" and 1 or 0.6, mode == "damage" and 1 or 0.62)
    frame._healingButton._text:SetTextColor(mode == "healing" and 1 or 0.6, mode == "healing" and 1 or 0.6, mode == "healing" and 1 or 0.62)
    frame._rateHeader:SetText(mode == "healing" and "HPS" or "DPS")
    frame._totalHeader:SetText(mode == "healing" and (L["FIGHT_HISTORY_HEALING"] or "Healing") or (L["FIGHT_HISTORY_DAMAGE"] or "Damage"))

    local players = SortedPlayers(fight)
    local playerPages = math.max(1, math.ceil(#players / PLAYER_ROWS))
    if playerPage > playerPages then playerPage = playerPages end
    if playerPage < 1 then playerPage = 1 end
    frame._playerPage:SetText(string.format("%d/%d", playerPage, playerPages))
    local playerFirst = (playerPage - 1) * PLAYER_ROWS + 1
    local totalField = mode == "healing" and "healing" or "damage"
    for i, row in ipairs(frame._playerRows) do
        local rank = playerFirst + i - 1
        local player = players[rank]
        row:SetShown(player ~= nil)
        if player then
            local total = SafeNumber(player[totalField])
            local rate = (fight.duration or 0) > 0 and total / fight.duration or 0
            row.rank:SetText(rank)
            row.name:SetText(ns.StripRealm and ns.StripRealm(player.name) or player.name)
            row.rate:SetText(FormatNumber(rate))
            row.total:SetText(FormatNumber(total))
            row.interrupts:SetText(tostring(math.floor(SafeNumber(player.interrupts) + 0.5)))
            row.deaths:SetText(tostring(math.floor(SafeNumber(player.deaths) + 0.5)))
            local cc = player.classFile and RAID_CLASS_COLORS[player.classFile]
            if cc then row.name:SetTextColor(cc.r, cc.g, cc.b) else row.name:SetTextColor(1, 1, 1) end
        end
    end
end

local function EnsureFrame()
    if frame then return frame end
    frame = CreateFrame("Frame", "TomoDMFightHistory", UIParent, "BackdropTemplate")
    frame:SetSize(900, 565)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    SetBackdrop(frame, 0.005, 0.005, 0.008, 0.97, 0.28, 0.28, 0.31, 0.92)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    UISpecialFrames = UISpecialFrames or {}
    table.insert(UISpecialFrames, "TomoDMFightHistory")

    local r, g, b = Accent()
    local accent = frame:CreateTexture(nil, "OVERLAY")
    accent:SetTexture(ns.FLAT or "Interface\\BUTTONS\\WHITE8X8")
    accent:SetPoint("TOPLEFT", 1, -1); accent:SetPoint("TOPRIGHT", -1, -1); accent:SetHeight(3)
    accent:SetVertexColor(r, g, b, 1)

    local title = Font(frame, 15, "primary")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText(L["FIGHT_HISTORY"] or "Fight History")

    local close = MakeButton(frame, 28, "X")
    close:SetPoint("TOPRIGHT", -10, -8)
    close:SetScript("OnClick", function() frame:Hide() end)

    local all = MakeButton(frame, 92, L["FIGHT_HISTORY_ALL"] or "All fights")
    all:SetPoint("TOPLEFT", 16, -45)
    all:SetScript("OnClick", function() bossesOnly = false; page = 1; playerPage = 1; UpdateUI() end)
    local bosses = MakeButton(frame, 98, L["FIGHT_HISTORY_BOSSES"] or "Bosses only")
    bosses:SetPoint("LEFT", all, "RIGHT", 6, 0)
    bosses:SetScript("OnClick", function() bossesOnly = true; page = 1; playerPage = 1; UpdateUI() end)
    local clear = MakeButton(frame, 104, L["FIGHT_HISTORY_CLEAR"] or "Clear history")
    clear:SetPoint("TOPRIGHT", -16, -45)
    clear:SetScript("OnClick", function()
        local db = EnsureDB(); if db then db.fightHistory = {} end
        selectedFight = nil; page = 1; UpdateUI()
        if ns.RefreshSettingsV2 then ns.RefreshSettingsV2() end
    end)

    local left = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    left:SetPoint("TOPLEFT", 16, -78); left:SetSize(300, 438)
    SetBackdrop(left, 0.012, 0.012, 0.018, 0.90, 0.15, 0.15, 0.18, 0.78)

    frame._fightRows = {}
    for i = 1, LEFT_ROWS do
        local row = CreateFrame("Button", nil, left, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 6, -6 - ((i - 1) * 36)); row:SetSize(288, 33)
        SetBackdrop(row, 0.018, 0.018, 0.024, 0.86, 0.16, 0.16, 0.19, 0.76)
        row.kind = Font(row, 7, "muted")
        row.kind:SetPoint("TOPLEFT", 7, -5); row.kind:SetWidth(52)
        row.name = Font(row, 10, "primary")
        row.name:SetPoint("TOPLEFT", 61, -4); row.name:SetPoint("RIGHT", -7, 0)
        row.meta = Font(row, 8, "muted")
        row.meta:SetPoint("BOTTOMLEFT", 61, 4); row.meta:SetPoint("RIGHT", -7, 0)
        row:SetScript("OnClick", function(self) selectedFight = self._fight; playerPage = 1; UpdateUI() end)
        frame._fightRows[i] = row
    end

    local prev = MakeButton(frame, 80, L["FIGHT_HISTORY_PREV"] or "Previous")
    prev:SetPoint("BOTTOMLEFT", 16, 10)
    prev:SetScript("OnClick", function() page = math.max(1, page - 1); UpdateUI() end)
    local pageText = Font(frame, 9, "secondary", "CENTER")
    pageText:SetPoint("BOTTOMLEFT", 112, 18); pageText:SetWidth(100)
    frame._page = pageText
    local nextb = MakeButton(frame, 80, L["FIGHT_HISTORY_NEXT"] or "Next")
    nextb:SetPoint("BOTTOMLEFT", 226, 10)
    nextb:SetScript("OnClick", function() page = page + 1; UpdateUI() end)

    local detail = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    detail:SetPoint("TOPLEFT", 328, -78); detail:SetPoint("BOTTOMRIGHT", -16, 49)
    SetBackdrop(detail, 0.012, 0.012, 0.018, 0.90, 0.15, 0.15, 0.18, 0.78)

    frame._detailTitle = Font(detail, 14, "primary")
    frame._detailTitle:SetPoint("TOPLEFT", 12, -10); frame._detailTitle:SetPoint("RIGHT", -12, 0)
    frame._detailMeta = Font(detail, 8, "muted")
    frame._detailMeta:SetPoint("TOPLEFT", 12, -31); frame._detailMeta:SetPoint("RIGHT", -12, 0)

    frame._damageButton = MakeButton(detail, 86, L["FIGHT_HISTORY_DAMAGE"] or "Damage")
    frame._damageButton:SetPoint("TOPLEFT", 12, -52)
    frame._damageButton:SetScript("OnClick", function() mode = "damage"; playerPage = 1; UpdateUI() end)
    frame._healingButton = MakeButton(detail, 86, L["FIGHT_HISTORY_HEALING"] or "Healing")
    frame._healingButton:SetPoint("LEFT", frame._damageButton, "RIGHT", 6, 0)
    frame._healingButton:SetScript("OnClick", function() mode = "healing"; playerPage = 1; UpdateUI() end)

    frame._playerPrev = MakeButton(detail, 26, "<")
    frame._playerPrev:SetPoint("LEFT", frame._healingButton, "RIGHT", 16, 0)
    frame._playerPrev:SetScript("OnClick", function() playerPage = math.max(1, playerPage - 1); UpdateUI() end)
    frame._playerPage = Font(detail, 8, "muted", "CENTER")
    frame._playerPage:SetPoint("LEFT", frame._playerPrev, "RIGHT", 4, 0)
    frame._playerPage:SetWidth(56)
    frame._playerNext = MakeButton(detail, 26, ">")
    frame._playerNext:SetPoint("LEFT", frame._playerPage, "RIGHT", 4, 0)
    frame._playerNext:SetScript("OnClick", function() playerPage = playerPage + 1; UpdateUI() end)

    local headers = {
        { key = "rank", text = "#", x = 12, w = 24, align = "CENTER" },
        { key = "name", text = L["FIGHT_HISTORY_PLAYER"] or "Player", x = 42, w = 180, align = "LEFT" },
        { key = "rate", text = "DPS", x = 232, w = 76, align = "RIGHT" },
        { key = "total", text = L["FIGHT_HISTORY_DAMAGE"] or "Damage", x = 316, w = 92, align = "RIGHT" },
        { key = "interrupts", text = L["FIGHT_HISTORY_INTERRUPTS"] or "Int", x = 418, w = 44, align = "RIGHT" },
        { key = "deaths", text = L["FIGHT_HISTORY_DEATHS"] or "Deaths", x = 470, w = 55, align = "RIGHT" },
    }
    for _, h in ipairs(headers) do
        local fs = Font(detail, 8, "muted", h.align)
        fs:SetPoint("TOPLEFT", h.x, -88); fs:SetWidth(h.w); fs:SetText(h.text)
        if h.key == "rate" then frame._rateHeader = fs end
        if h.key == "total" then frame._totalHeader = fs end
    end

    frame._playerRows = {}
    for i = 1, PLAYER_ROWS do
        local row = CreateFrame("Frame", nil, detail)
        row:SetPoint("TOPLEFT", 8, -106 - ((i - 1) * 23)); row:SetPoint("TOPRIGHT", -8, -106 - ((i - 1) * 23)); row:SetHeight(21)
        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(ns.FLAT or "Interface\\BUTTONS\\WHITE8X8"); bg:SetAllPoints(); bg:SetVertexColor(1,1,1,0.025)
        end
        for _, h in ipairs(headers) do
            local fs = Font(row, 9, "secondary", h.align)
            fs:SetPoint("LEFT", h.x - 8, 0); fs:SetWidth(h.w); row[h.key] = fs
        end
        frame._playerRows[i] = row
    end

    frame._empty = Font(left, 10, "muted", "CENTER")
    frame._empty:SetPoint("CENTER", 0, 0); frame._empty:SetWidth(260); frame._empty:SetText(L["FIGHT_HISTORY_EMPTY"] or "No saved fights yet.")
    frame._detailEmpty = Font(detail, 11, "muted", "CENTER")
    frame._detailEmpty:SetPoint("CENTER", 0, 0); frame._detailEmpty:SetWidth(420); frame._detailEmpty:SetText(L["FIGHT_HISTORY_EMPTY"] or "No saved fights yet.")

    frame:Hide()
    UpdateUI()
    return frame
end

function ns.OpenFightHistory()
    EnsureDB()
    local history = FilteredHistory()
    if not selectedFight then selectedFight = history[1] end
    EnsureFrame():Show()
    UpdateUI()
end

function ns.ToggleFightHistory()
    local f = EnsureFrame()
    if f:IsShown() then f:Hide() else ns.OpenFightHistory() end
end

----------------------------------------------------------------------
-- Meter launcher
----------------------------------------------------------------------

local function AttachHistoryLauncher(win)
    if not win or not win.frame or win._fightHistoryLauncher then return end

    -- Second-row utility button aligned under Report, directly left of the
    -- Benchmark button that sits under Reset.  The two centers use the same
    -- 21 px column rhythm as the six native action buttons above them.
    local button = CreateFrame("Button", nil, win.frame, "BackdropTemplate")
    button:SetSize(20, 20)
    if win.HistoryLauncherAnchor then
        button:SetAllPoints(win.HistoryLauncherAnchor)
    else
        button:SetPoint("TOPRIGHT", win.frame, "TOPRIGHT", -28, -30)
    end
    button:SetFrameLevel(win.frame:GetFrameLevel() + 12)
    SetBackdrop(button, 0.025, 0.025, 0.032, 0.94, 0.20, 0.20, 0.23, 0.86)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(HISTORY_LAUNCHER_ICON)
    icon:SetSize(11, 11)
    icon:SetPoint("CENTER")
    local muted = ns.TEXT_MUTED or { 0.40, 0.40, 0.43 }
    icon:SetVertexColor(muted[1], muted[2], muted[3])
    button._icon = icon

    button:SetScript("OnClick", function()
        if ns.ToggleFightHistory then ns.ToggleFightHistory() end
    end)
    button:SetScript("OnEnter", function(self)
        local r, g, b = Accent()
        self:SetBackdropColor(r * 0.18, g * 0.18, b * 0.18, 0.98)
        self:SetBackdropBorderColor(r, g, b, 0.96)
        self._icon:SetVertexColor(1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["FIGHT_HISTORY_TIP"] or "Open persistent fight history", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        self:SetBackdropColor(0.025, 0.025, 0.032, 0.94)
        self:SetBackdropBorderColor(0.20, 0.20, 0.23, 0.86)
        local muted = ns.TEXT_MUTED or { 0.40, 0.40, 0.43 }
        self._icon:SetVertexColor(muted[1], muted[2], muted[3])
    end)

    win._fightHistoryLauncher = button
end

-- Benchmark wraps this factory first; FightHistory is loaded afterwards and
-- wraps the already-extended factory.  ADDON_LOADED creates the windows only
-- after both wrappers are installed, so every saved/new meter gets both icons.
if ns.CreateMeterWindow and not ns._fightHistoryWrappedCreateMeterWindow then
    ns._fightHistoryWrappedCreateMeterWindow = true
    local CreateMeterWindow = ns.CreateMeterWindow
    ns.CreateMeterWindow = function(cfg)
        local win = CreateMeterWindow(cfg)
        AttachHistoryLauncher(win)
        return win
    end
end

----------------------------------------------------------------------
-- Combat / encounter capture
----------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local function Register(event)
    if ns.SafeRegisterEvent then ns.SafeRegisterEvent(eventFrame, event)
    else pcall(eventFrame.RegisterEvent, eventFrame, event) end
end

Register("ADDON_LOADED")
Register("ENCOUNTER_START")
Register("ENCOUNTER_END")
Register("PLAYER_REGEN_ENABLED")
Register("DAMAGE_METER_CURRENT_SESSION_UPDATED")
Register("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == ADDON_NAME then EnsureDB() end
        return
    end
    if event == "PLAYER_LOGOUT" then return end

    if event == "ENCOUNTER_START" then
        -- Do not let an already-ended encounter vanish if the client starts the
        -- next one before publishing a historical session ID for the previous.
        if activeEncounter and activeEncounter.ended then
            FinalizeEncounter(activeEncounter)
        end

        local encounterID, encounterName, difficultyID, groupSize = ...
        local baselineSessionID = LatestSessionInfo()
        activeEncounter = {
            id = not Secret(encounterID) and encounterID or nil,
            name = SafeText(encounterName, L["FIGHT_HISTORY_BOSS"] or "Boss"),
            difficultyID = SafeNumber(difficultyID),
            groupSize = SafeNumber(groupSize),
            success = nil,
            ended = false,
            sawRegen = false,
            saved = false,
            baselineSessionID = baselineSessionID,
            parts = {},
        }
        return
    end

    if event == "ENCOUNTER_END" then
        local encounterID, _, difficultyID, groupSize, success = ...
        if activeEncounter and (activeEncounter.id == nil or Secret(encounterID) or activeEncounter.id == encounterID) then
            activeEncounter.difficultyID = SafeNumber(difficultyID) > 0 and SafeNumber(difficultyID) or activeEncounter.difficultyID
            activeEncounter.groupSize = SafeNumber(groupSize) > 0 and SafeNumber(groupSize) or activeEncounter.groupSize
            activeEncounter.success = not Secret(success) and success == 1 or false
            activeEncounter.ended = true

            -- The historical-session list can lag behind ENCOUNTER_END.  Keep a
            -- direct Current-session snapshot as a fallback before trying the
            -- stable-ID path.  Both reads happen synchronously in this event.
            local live = CaptureLiveCurrent()
            if live then activeEncounter.fallbackSnapshot = live end

            -- ENCOUNTER_END can arrive before or after PLAYER_REGEN_ENABLED.
            -- Try one stable event-side capture too; session-ID de-duplication
            -- makes a later regen/update harmless if it exposes the same segment.
            AppendEncounterPart(activeEncounter, CaptureCurrent())

            -- If regen was already seen, we now have either a stable segment or
            -- the direct Current fallback, so the boss is safe to persist.
            if activeEncounter.sawRegen and (#activeEncounter.parts > 0 or activeEncounter.fallbackSnapshot) then
                FinalizeEncounter(activeEncounter)
                activeEncounter = nil
                if frame and frame:IsShown() then UpdateUI() end
            end
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        local snapshot = CaptureCurrent()
        if activeEncounter then
            activeEncounter.sawRegen = true

            -- Keep the direct Current read as a fallback for boss fights whose
            -- historical session ID has not been published yet.
            local live = CaptureLiveCurrent()
            if live then activeEncounter.fallbackSnapshot = live end

            AppendEncounterPart(activeEncounter, snapshot)
            if activeEncounter.ended then
                FinalizeEncounter(activeEncounter)
                activeEncounter = nil
            end
        elseif snapshot then
            SaveFight(snapshot, nil)
        end
        if frame and frame:IsShown() then UpdateUI() end
        return
    end

    -- Some encounters finish with ENCOUNTER_END after the regen event.  The
    -- next damage-meter update is still an event-side readable context, so it
    -- provides a final chance to persist the boss without timer polling.
    if event == "DAMAGE_METER_CURRENT_SESSION_UPDATED" and activeEncounter and activeEncounter.ended then
        local live = CaptureLiveCurrent()
        if live then activeEncounter.fallbackSnapshot = live end
        AppendEncounterPart(activeEncounter, CaptureCurrent())
        if #activeEncounter.parts > 0 or activeEncounter.fallbackSnapshot then
            FinalizeEncounter(activeEncounter)
            activeEncounter = nil
            if frame and frame:IsShown() then UpdateUI() end
        end
    end
end)

----------------------------------------------------------------------
-- Slash / public API
----------------------------------------------------------------------

if SlashCmdList and SlashCmdList["TDM"] and not ns._fightHistorySlashWrapped then
    ns._fightHistorySlashWrapped = true
    local previous = SlashCmdList["TDM"]
    SlashCmdList["TDM"] = function(msg)
        local command = tostring(msg or ""):match("^%s*(.-)%s*$"):lower()
        if command == "fights" or command == "fight" then
            ns.ToggleFightHistory()
            return
        end
        previous(msg)
        if command == "help" then
            print((L["ADDON_PREFIX"] or "TDM: ") .. (L["CMD_HELP_FIGHTS"] or "  /tdm fights - open fight history"))
        end
    end
end

_G.TomoDamageMeter = _G.TomoDamageMeter or {}
_G.TomoDamageMeter.GetFightHistory = function()
    local db = EnsureDB()
    if not db then return {} end
    local out = {}
    for i, fight in ipairs(db.fightHistory) do out[i] = CopyTable(fight) end
    return out
end
