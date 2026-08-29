local ADDON_NAME, ns = ...
local L = ns.L
if not L then return end

----------------------------------------------------------------------
-- v2.5 meter/session labels
--
-- Kept in a small extension file so Patch 10 does not rewrite the nine
-- existing locale files.  This avoids any risk of damaging strings that
-- were already validated in the 2.4.x test build.
----------------------------------------------------------------------

local translations = {
    enUS = {
        DAMAGE_DONE  = "Damage Done",
        HEALING_DONE = "Healing Done",
        PREVIOUS     = "Previous Fight",
    },
    frFR = {
        DAMAGE_DONE  = "Dégâts infligés",
        HEALING_DONE = "Soins prodigués",
        PREVIOUS     = "Combat précédent",
    },
    deDE = {
        DAMAGE_DONE  = "Verursachter Schaden",
        HEALING_DONE = "Gewirkte Heilung",
        PREVIOUS     = "Vorheriger Kampf",
    },
    esES = {
        DAMAGE_DONE  = "Daño infligido",
        HEALING_DONE = "Sanación realizada",
        PREVIOUS     = "Combate anterior",
    },
    esMX = {
        DAMAGE_DONE  = "Daño infligido",
        HEALING_DONE = "Sanación realizada",
        PREVIOUS     = "Combate anterior",
    },
    itIT = {
        DAMAGE_DONE  = "Danni inflitti",
        HEALING_DONE = "Cure effettuate",
        PREVIOUS     = "Combattimento precedente",
    },
    ptBR = {
        DAMAGE_DONE  = "Dano causado",
        HEALING_DONE = "Cura realizada",
        PREVIOUS     = "Combate anterior",
    },
    ruRU = {
        DAMAGE_DONE  = "Нанесённый урон",
        HEALING_DONE = "Исцеление",
        PREVIOUS     = "Предыдущий бой",
    },
    zhCN = {
        DAMAGE_DONE  = "造成伤害",
        HEALING_DONE = "治疗量",
        PREVIOUS     = "上一场战斗",
    },
    zhTW = {
        DAMAGE_DONE  = "造成傷害",
        HEALING_DONE = "治療量",
        PREVIOUS     = "上一場戰鬥",
    },
}

local locale = GetLocale and GetLocale() or "enUS"
local t = translations[locale] or translations.enUS

for key, value in pairs(t) do
    L[key] = value
end
