local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- UI Polish locale extension / 2.7.5
----------------------------------------------------------------------

local locale = GetLocale()
local L = ns.L
if not L then return end

local strings = {
    enUS = {
        SETTINGS_COMBAT_TIMER = "Combat Timer",
        SETTINGS_GENERAL_DESC = "Core meter behavior, modules, categories and columns.",
        SETTINGS_SHOW_YOU_TAG = "Show the YOU tag on my row",
        SELF_TAG = "YOU",
    },
    frFR = {
        SETTINGS_COMBAT_TIMER = "Minuteur de combat",
        SETTINGS_GENERAL_DESC = "Comportement du compteur, modules, catégories et colonnes.",
        SETTINGS_SHOW_YOU_TAG = "Afficher le tag « VOUS » sur ma barre",
        SELF_TAG = "VOUS",
    },
    deDE = {
        SETTINGS_COMBAT_TIMER = "Kampftimer",
        SETTINGS_GENERAL_DESC = "Verhalten des Meters, Module, Kategorien und Spalten.",
        SETTINGS_SHOW_YOU_TAG = "Tag „DU“ in meiner Zeile anzeigen",
        SELF_TAG = "DU",
    },
    esES = {
        SETTINGS_COMBAT_TIMER = "Temporizador de combate",
        SETTINGS_GENERAL_DESC = "Comportamiento del medidor, módulos, categorías y columnas.",
        SETTINGS_SHOW_YOU_TAG = "Mostrar la etiqueta «TÚ» en mi fila",
        SELF_TAG = "TÚ",
    },
    esMX = {
        SETTINGS_COMBAT_TIMER = "Temporizador de combate",
        SETTINGS_GENERAL_DESC = "Comportamiento del medidor, módulos, categorías y columnas.",
        SETTINGS_SHOW_YOU_TAG = "Mostrar la etiqueta «TÚ» en mi fila",
        SELF_TAG = "TÚ",
    },
    itIT = {
        SETTINGS_COMBAT_TIMER = "Timer di combattimento",
        SETTINGS_GENERAL_DESC = "Comportamento del meter, moduli, categorie e colonne.",
        SETTINGS_SHOW_YOU_TAG = "Mostra l'etichetta «TU» sulla mia riga",
        SELF_TAG = "TU",
    },
    ptBR = {
        SETTINGS_COMBAT_TIMER = "Cronômetro de combate",
        SETTINGS_GENERAL_DESC = "Comportamento do medidor, módulos, categorias e colunas.",
        SETTINGS_SHOW_YOU_TAG = "Mostrar a etiqueta «VOCÊ» na minha linha",
        SELF_TAG = "VOCÊ",
    },
    ruRU = {
        SETTINGS_COMBAT_TIMER = "Таймер боя",
        SETTINGS_GENERAL_DESC = "Поведение счётчика, модули, категории и столбцы.",
        SETTINGS_SHOW_YOU_TAG = "Показывать метку «ВЫ» в моей строке",
        SELF_TAG = "ВЫ",
    },
    zhCN = {
        SETTINGS_COMBAT_TIMER = "战斗计时器",
        SETTINGS_GENERAL_DESC = "伤害统计器行为、模块、分类与列设置。",
        SETTINGS_SHOW_YOU_TAG = "在我的条目上显示“你”标签",
        SELF_TAG = "你",
    },
    zhTW = {
        SETTINGS_COMBAT_TIMER = "戰鬥計時器",
        SETTINGS_GENERAL_DESC = "傷害統計器行為、模組、分類與欄位設定。",
        SETTINGS_SHOW_YOU_TAG = "在我的列上顯示「你」標籤",
        SELF_TAG = "你",
    },
}

local set = strings[locale] or strings.enUS
for key, value in pairs(set) do
    L[key] = value
end
