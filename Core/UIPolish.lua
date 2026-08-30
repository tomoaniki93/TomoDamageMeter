local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- UI Polish runtime fixes / 2.7.4
----------------------------------------------------------------------

local function CopyColor(c)
    if type(c) ~= "table" then return nil end
    return { c[1] or 0, c[2] or 0, c[3] or 0 }
end

local function ColorsClose(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    return math.abs((a[1] or 0) - (b[1] or 0)) < 0.015
       and math.abs((a[2] or 0) - (b[2] or 0)) < 0.015
       and math.abs((a[3] or 0) - (b[3] or 0)) < 0.015
end

local function PlayerClassColor()
    local _, classFile = UnitClass("player")
    local cc = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if not cc then return nil end
    return { cc.r, cc.g, cc.b }
end

local function NativeSkinAccent()
    local db = ns.db
    local skin = db and ns.SKIN_BY_KEY and ns.SKIN_BY_KEY[db.skin or "DARK"]
    if skin and type(skin.accent) == "table" then
        return CopyColor(skin.accent)
    end
    if type(ns.DEFAULT_ACCENT) == "table" then
        return CopyColor(ns.DEFAULT_ACCENT)
    end
    return { 0.88, 0.08, 0.18 }
end

-- Core/Init.lua owns the accent callback system. Keep that implementation,
-- but prevent class-colour mode from overwriting the persistent manual/skin
-- accent in SavedVariables.
local ApplyAccentColorBase = ns.ApplyAccentColor
if ApplyAccentColorBase and not ns._tdmUIPolishAccentWrapped274 then
    ns._tdmUIPolishAccentWrapped274 = true

    ns.ApplyAccentColor = function()
        local db = ns.db
        local preserve = db and db.accentUseClassColor and CopyColor(db.accentColor) or nil

        ApplyAccentColorBase()

        if db and db.accentUseClassColor and preserve then
            db.accentColor = preserve
        end
    end
end

-- Public toggle used by ConfigUIV2. Besides fixing new toggles, this also
-- repairs SavedVariables already polluted by 2.7.2 and earlier: when the saved
-- accent is identical to the player's class colour and no trustworthy backup
-- exists, disabling class colours restores the active skin's native accent.
function ns.SetClassColorMode(enabled)
    local db = ns.db
    if not db then return end

    enabled = enabled and true or false
    local classColor = PlayerClassColor()

    if enabled then
        if not db.accentUseClassColor then
            local current = CopyColor(db.accentColor)
            -- A legacy polluted value is not a useful backup. Restore from the
            -- selected skin instead (TDM Red => native red).
            if not current or (classColor and ColorsClose(current, classColor)) then
                current = NativeSkinAccent()
            end
            db.accentColorBeforeClass = current
        elseif type(db.accentColorBeforeClass) ~= "table" then
            -- Option was already ON when 2.7.4 loaded: this is the migration
            -- path for users coming directly from the affected 2.7.2/2.7.3 DB.
            local current = CopyColor(db.accentColor)
            if not current or (classColor and ColorsClose(current, classColor)) then
                current = NativeSkinAccent()
            end
            db.accentColorBeforeClass = current
        end

        db.accentUseClassColor = true
    else
        local restore = CopyColor(db.accentColorBeforeClass)
        if not restore then
            local current = CopyColor(db.accentColor)
            if current and not (classColor and ColorsClose(current, classColor)) then
                restore = current
            else
                restore = NativeSkinAccent()
            end
        end

        db.accentUseClassColor = false
        db.accentColor = restore or NativeSkinAccent()
        db.accentColorBeforeClass = nil
    end

    if ns.ApplyAccentColor then ns.ApplyAccentColor() end

    -- Repaint both the V3 rows and any legacy/secondary surfaces immediately.
    for _, win in ipairs(ns.windows or {}) do
        if win.RefreshAccentColor then win.RefreshAccentColor() end
        if win.Refresh then win.Refresh() end
    end
end
