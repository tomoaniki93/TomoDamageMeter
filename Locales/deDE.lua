local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Localization: German
----------------------------------------------------------------------

if GetLocale() ~= "deDE" then return end

local L = ns.L

-- General
L["ADDON_NAME"]     = "TomoDamageMeter"
L["ADDON_SHORT"]    = "Tomo"

-- Meter types
L["DPS"]            = "DPS"
L["HPS"]            = "HPS"
L["DAMAGE_TAKEN"]   = "Erlittener Schaden"
L["AVOIDABLE"]      = "Vermeidbar"
L["ENEMY_DAMAGE"]   = "Feindschaden"
L["ABSORBS"]        = "Absorbierungen"
L["INTERRUPTS"]     = "Unterbrechungen"
L["DISPELS"]        = "Entzauberungen"
L["DEATHS"]         = "Tode"

-- Categories
L["DAMAGE"]         = "Schaden"
L["HEALING"]        = "Heilung"
L["ACTIONS"]        = "Aktionen"

-- Sessions
L["CURRENT"]        = "Aktuell"
L["OVERALL"]        = "Gesamt"

-- Header / UI
L["RESET"]          = "Zurücksetzen"
L["LOCK"]           = "Sperren"
L["UNLOCK"]         = "Entsperren"
L["SETTINGS"]       = "Einstellungen"
L["REPORT"]         = "Bericht"
L["CLOSE"]          = "Schließen"

-- Format labels
L["FMT_COMPACT"]    = "Kompakt"
L["FMT_1DEC"]       = "1 Dez"
L["FMT_2DEC"]       = "2 Dez"
L["FMT_REGULAR"]    = "Regulär"
L["FMT_INT"]        = "Ganzzahl"
L["FMT_DEC"]        = "Dezimal"

-- Report
L["REPORT_HEADER"]          = "TomoDamageMeter: %s (%s)"
L["REPORT_NO_TARGET"]       = "Kein Flüsterziel. Wähle zuerst einen Spieler."
L["REPORT_NO_DATA"]         = "Keine Daten zum Berichten."
L["REPORT_CHANNEL_SAY"]     = "Sagen"
L["REPORT_CHANNEL_PARTY"]   = "Gruppe"
L["REPORT_CHANNEL_RAID"]    = "Schlachtzug"
L["REPORT_CHANNEL_GUILD"]   = "Gilde"
L["REPORT_CHANNEL_WHISPER"] = "Flüstern"

-- Settings
L["SETTINGS_TITLE"]             = "TomoDamageMeter Einstellungen"
L["SETTINGS_GENERAL"]           = "Allgemein"
L["SETTINGS_APPEARANCE"]        = "Aussehen"
L["SETTINGS_COLUMNS"]           = "Spalten"
L["SETTINGS_FONT_SIZE"]         = "Schriftgröße"
L["SETTINGS_FONT_FACE"]         = "Schriftart"
L["SETTINGS_BAR_HEIGHT"]        = "Balkenhöhe"
L["SETTINGS_BG_OPACITY"]        = "Hintergrundtransparenz"
L["SETTINGS_OOC_OPACITY"]       = "Transparenz außerhalb des Kampfes"
L["SETTINGS_BREAKDOWN_OPACITY"] = "Zauberdetail-Transparenz"
L["SETTINGS_STRIP_REALM"]       = "Realmname ausblenden"
L["SETTINGS_ACCENT_COLOR"]      = "Akzentfarbe"
L["SETTINGS_USE_CLASS_COLOR"]   = "Klassenfarbe verwenden"
L["SETTINGS_REPORT_CHANNEL"]    = "Berichtskanal"
L["SETTINGS_REPORT_LINES"]      = "Berichtszeilen"
L["SETTINGS_WINDOWS"]           = "Fenster"
L["SETTINGS_ADD_WINDOW"]        = "+ Hinzufügen"
L["SETTINGS_REMOVE_WINDOW"]     = "- Entfernen"
L["SETTINGS_WINDOW_COUNT"]      = "Fenster: %d / %d"
L["SETTINGS_COL_RATE"]          = "Rate (DPS/HPS)"
L["SETTINGS_COL_TOTAL"]         = "Gesamt"
L["SETTINGS_COL_PCT"]           = "Prozent"
L["SETTINGS_TAB_GENERAL"]       = "Allgemein"
L["SETTINGS_TAB_WINDOW"]        = "Fenster %d"
L["SETTINGS_METER_TYPE"]        = "Anzeigetyp"
L["SETTINGS_SESSION_TYPE"]      = "Sitzungstyp"
L["SETTINGS_LOCKED"]            = "Position gesperrt"

-- Slash commands
L["CMD_RESET"]          = "Daten zurückgesetzt."
L["CMD_LOCKED"]         = "Gesperrt"
L["CMD_UNLOCKED"]       = "Entsperrt"
L["CMD_HELP_HEADER"]    = "Befehle:"
L["CMD_HELP_TOGGLE"]    = "  /tdm — Einstellungen öffnen"
L["CMD_HELP_TOGGLE_VIS"]= "  /tdm toggle — Fenster ein-/ausblenden"
L["CMD_HELP_RESET"]     = "  /tdm reset — Alle Kampfdaten zurücksetzen"
L["CMD_HELP_LOCK"]      = "  /tdm lock — Fensterposition sperren/entsperren"
L["CMD_HELP_HELP"]      = "  /tdm help — diese Nachricht"

-- Auto-reset
L["SETTINGS_AUTO_RESET_INSTANCE"] = "Auto-Reset beim Instanzbeitritt"
L["SETTINGS_COMBAT_TIMER"] = "Kampf-Timer (DPS/HPS)"
L["SETTINGS_SELF_BAR"] = "Eigene Leiste anheften"
L["SETTINGS_BAR_TOOLTIPS"] = "Leisten-Tooltips (Mauszeiger)"
L["SETTINGS_TIMER_POSITION"] = "Position des Kampf-Timers"
L["TIMER_POS_RIGHT"] = "Rechts"
L["TIMER_POS_LEFT"] = "Links"
L["SETTINGS_CATEGORIES"] = "Kategorien"
L["SETTINGS_CATEGORIES_MIN"] = "Mindestens eine Kategorie muss aktiviert bleiben."
L["AUTO_RESET_MSG"]                = "Daten automatisch zurückgesetzt (Instanzbeitritt)."

-- Combat
L["COMBAT_SETTINGS_UNAVAILABLE"] = "Einstellungen im Kampf nicht verfügbar."
L["WAITING_COMBAT_END"]          = "Nicht verfügbar bis nach dem Kampf"

-- Detail
L["SPELL_BREAKDOWN"] = "Zauberaufteilung"
L["NO_DATA"]         = "Keine Daten verfügbar"
L["BREAKDOWN_SPELLS_LABEL"] = "Zauber"
L["BREAKDOWN_CRITS_LABEL"]  = "Krits"
L["BREAKDOWN_CRIT_RATE_LABEL"] = "Krit"
L["BREAKDOWN_COL_SPELL"] = "Zauber"
L["BREAKDOWN_COL_TOTAL"] = "Total"

-- Segments / Target Breakdown
L["SEGMENTS"] = "Segmente"
L["SEGMENT"] = "Segment"
L["SEGMENT_COL_NAME"] = "Begegnung"
L["TARGET_BREAKDOWN"] = "Zielaufschlüsselung"
L["TARGET_COL_NAME"] = "Ziel"

-- Tooltips
L["TIP_SETTINGS"] = "Einstellungen öffnen"
L["TIP_TARGET"] = "Zielaufschlüsselung"
L["TIP_DETAILS"] = "Zauberaufteilung"
L["TIP_LOCK"] = "Position sperren/entsperren"
L["TIP_REPORT"] = "Im Chat melden"
L["TIP_RESET"] = "Alle Daten zurücksetzen"
L["TIP_CATEGORY"] = "Klicken zum Kategoriewechsel"
L["TIP_TYPE"] = "Klicken zum Typwechsel"
L["TIP_SESSION"] = "Klicken zum Sitzungswechsel"

-- Tooltips (Mauszeiger)
L["TIP_TOP_SPELLS"] = "Top-Zauber"
L["TIP_TOTAL"] = "Gesamt"
L["TIP_OVERKILL"] = "Overkill"
L["TIP_AVOIDABLE"] = "Vermeidbarer Schaden"
L["TIP_KILLING_BLOW"] = "Todesstoß"
L["TIP_CAST_BY"] = "Gewirkt von %s"
L["TIP_CLICK_BREAKDOWN"] = "Klicken für Zauberaufschlüsselung"

-- Font names
L["FONT_FRIZ"] = "Fritz Quadrata"
L["FONT_ARIAL"] = "Arial Narrow"
L["FONT_2002"] = "2002"
L["FONT_MORPHEUS"] = "Morpheus"
L["FONT_SKURRI"] = "Skurri"

L["FILTER_PLAYERS"] = "Filtern..."
