local ADDON_NAME, ns = ...
local L = ns.L
if not L then return end

----------------------------------------------------------------------
-- Fight History localization - 2.8.2
-- Covers the full history window and the boss-centric Settings page.
----------------------------------------------------------------------

local fightStrings = {
    enUS = {
        FIGHT_HISTORY = "Fight History", FIGHT_HISTORY_TIP = "Open persistent fight history",
        FIGHT_HISTORY_ALL = "All fights", FIGHT_HISTORY_BOSSES = "Bosses only",
        FIGHT_HISTORY_CLEAR = "Clear history", FIGHT_HISTORY_EMPTY = "No saved dungeon or raid fights yet.",
        FIGHT_HISTORY_DAMAGE = "Damage", FIGHT_HISTORY_HEALING = "Healing",
        FIGHT_HISTORY_BOSS = "Boss", FIGHT_HISTORY_TRASH = "Trash",
        FIGHT_HISTORY_PLAYER = "Player", FIGHT_HISTORY_RATE = "DPS", FIGHT_HISTORY_TOTAL = "Damage",
        FIGHT_HISTORY_INTERRUPTS = "Int", FIGHT_HISTORY_DEATHS = "Deaths",
        FIGHT_HISTORY_PREV = "Previous", FIGHT_HISTORY_NEXT = "Next",
        FIGHT_HISTORY_KILL = "Kill", FIGHT_HISTORY_WIPE = "Wipe",
        CMD_HELP_FIGHTS = "  /tdm fights - open persistent fight history",
    },
    frFR = {
        FIGHT_HISTORY = "Historique des combats", FIGHT_HISTORY_TIP = "Ouvrir l'historique persistant des combats",
        FIGHT_HISTORY_ALL = "Tous les combats", FIGHT_HISTORY_BOSSES = "Boss uniquement",
        FIGHT_HISTORY_CLEAR = "Effacer l'historique", FIGHT_HISTORY_EMPTY = "Aucun combat de donjon ou raid enregistré.",
        FIGHT_HISTORY_DAMAGE = "Dégâts", FIGHT_HISTORY_HEALING = "Soins",
        FIGHT_HISTORY_BOSS = "Boss", FIGHT_HISTORY_TRASH = "Trash",
        FIGHT_HISTORY_PLAYER = "Joueur", FIGHT_HISTORY_RATE = "DPS", FIGHT_HISTORY_TOTAL = "Dégâts",
        FIGHT_HISTORY_INTERRUPTS = "Int", FIGHT_HISTORY_DEATHS = "Morts",
        FIGHT_HISTORY_PREV = "Précédent", FIGHT_HISTORY_NEXT = "Suivant",
        FIGHT_HISTORY_KILL = "Tué", FIGHT_HISTORY_WIPE = "Échec",
        CMD_HELP_FIGHTS = "  /tdm fights - ouvrir l'historique persistant des combats",
    },
    deDE = {
        FIGHT_HISTORY = "Kampfverlauf", FIGHT_HISTORY_TIP = "Gespeicherten Kampfverlauf öffnen",
        FIGHT_HISTORY_ALL = "Alle Kämpfe", FIGHT_HISTORY_BOSSES = "Nur Bosse",
        FIGHT_HISTORY_CLEAR = "Verlauf löschen", FIGHT_HISTORY_EMPTY = "Noch keine Dungeon- oder Schlachtzugskämpfe gespeichert.",
        FIGHT_HISTORY_DAMAGE = "Schaden", FIGHT_HISTORY_HEALING = "Heilung",
        FIGHT_HISTORY_BOSS = "Boss", FIGHT_HISTORY_TRASH = "Trash",
        FIGHT_HISTORY_PLAYER = "Spieler", FIGHT_HISTORY_RATE = "DPS", FIGHT_HISTORY_TOTAL = "Schaden",
        FIGHT_HISTORY_INTERRUPTS = "Unt.", FIGHT_HISTORY_DEATHS = "Tode",
        FIGHT_HISTORY_PREV = "Zurück", FIGHT_HISTORY_NEXT = "Weiter",
        FIGHT_HISTORY_KILL = "Sieg", FIGHT_HISTORY_WIPE = "Wipe",
        CMD_HELP_FIGHTS = "  /tdm fights - gespeicherten Kampfverlauf öffnen",
    },
    esES = {
        FIGHT_HISTORY = "Historial de combates", FIGHT_HISTORY_TIP = "Abrir historial persistente de combates",
        FIGHT_HISTORY_ALL = "Todos", FIGHT_HISTORY_BOSSES = "Solo jefes",
        FIGHT_HISTORY_CLEAR = "Borrar historial", FIGHT_HISTORY_EMPTY = "Aún no hay combates de mazmorra o banda guardados.",
        FIGHT_HISTORY_DAMAGE = "Daño", FIGHT_HISTORY_HEALING = "Sanación",
        FIGHT_HISTORY_BOSS = "Jefe", FIGHT_HISTORY_TRASH = "Trash",
        FIGHT_HISTORY_PLAYER = "Jugador", FIGHT_HISTORY_RATE = "DPS", FIGHT_HISTORY_TOTAL = "Daño",
        FIGHT_HISTORY_INTERRUPTS = "Int", FIGHT_HISTORY_DEATHS = "Muertes",
        FIGHT_HISTORY_PREV = "Anterior", FIGHT_HISTORY_NEXT = "Siguiente",
        FIGHT_HISTORY_KILL = "Victoria", FIGHT_HISTORY_WIPE = "Wipe",
        CMD_HELP_FIGHTS = "  /tdm fights - abrir historial persistente de combates",
    },
    itIT = {
        FIGHT_HISTORY = "Cronologia combattimenti", FIGHT_HISTORY_TIP = "Apri cronologia persistente dei combattimenti",
        FIGHT_HISTORY_ALL = "Tutti", FIGHT_HISTORY_BOSSES = "Solo boss",
        FIGHT_HISTORY_CLEAR = "Cancella cronologia", FIGHT_HISTORY_EMPTY = "Nessun combattimento dungeon o raid salvato.",
        FIGHT_HISTORY_DAMAGE = "Danni", FIGHT_HISTORY_HEALING = "Cure",
        FIGHT_HISTORY_BOSS = "Boss", FIGHT_HISTORY_TRASH = "Trash",
        FIGHT_HISTORY_PLAYER = "Giocatore", FIGHT_HISTORY_RATE = "DPS", FIGHT_HISTORY_TOTAL = "Danni",
        FIGHT_HISTORY_INTERRUPTS = "Int", FIGHT_HISTORY_DEATHS = "Morti",
        FIGHT_HISTORY_PREV = "Precedente", FIGHT_HISTORY_NEXT = "Successivo",
        FIGHT_HISTORY_KILL = "Ucciso", FIGHT_HISTORY_WIPE = "Wipe",
        CMD_HELP_FIGHTS = "  /tdm fights - apri cronologia persistente dei combattimenti",
    },
    ptBR = {
        FIGHT_HISTORY = "Histórico de combates", FIGHT_HISTORY_TIP = "Abrir histórico persistente de combates",
        FIGHT_HISTORY_ALL = "Todos", FIGHT_HISTORY_BOSSES = "Somente chefes",
        FIGHT_HISTORY_CLEAR = "Limpar histórico", FIGHT_HISTORY_EMPTY = "Nenhuma luta de masmorra ou raide salva ainda.",
        FIGHT_HISTORY_DAMAGE = "Dano", FIGHT_HISTORY_HEALING = "Cura",
        FIGHT_HISTORY_BOSS = "Chefe", FIGHT_HISTORY_TRASH = "Trash",
        FIGHT_HISTORY_PLAYER = "Jogador", FIGHT_HISTORY_RATE = "DPS", FIGHT_HISTORY_TOTAL = "Dano",
        FIGHT_HISTORY_INTERRUPTS = "Int", FIGHT_HISTORY_DEATHS = "Mortes",
        FIGHT_HISTORY_PREV = "Anterior", FIGHT_HISTORY_NEXT = "Próximo",
        FIGHT_HISTORY_KILL = "Vitória", FIGHT_HISTORY_WIPE = "Wipe",
        CMD_HELP_FIGHTS = "  /tdm fights - abrir histórico persistente de combates",
    },
    ruRU = {
        FIGHT_HISTORY = "История боёв", FIGHT_HISTORY_TIP = "Открыть сохранённую историю боёв",
        FIGHT_HISTORY_ALL = "Все бои", FIGHT_HISTORY_BOSSES = "Только боссы",
        FIGHT_HISTORY_CLEAR = "Очистить историю", FIGHT_HISTORY_EMPTY = "Сохранённых боёв в подземельях и рейдах пока нет.",
        FIGHT_HISTORY_DAMAGE = "Урон", FIGHT_HISTORY_HEALING = "Исцеление",
        FIGHT_HISTORY_BOSS = "Босс", FIGHT_HISTORY_TRASH = "Трэш",
        FIGHT_HISTORY_PLAYER = "Игрок", FIGHT_HISTORY_RATE = "DPS", FIGHT_HISTORY_TOTAL = "Урон",
        FIGHT_HISTORY_INTERRUPTS = "Прер.", FIGHT_HISTORY_DEATHS = "Смерти",
        FIGHT_HISTORY_PREV = "Назад", FIGHT_HISTORY_NEXT = "Далее",
        FIGHT_HISTORY_KILL = "Убит", FIGHT_HISTORY_WIPE = "Вайп",
        CMD_HELP_FIGHTS = "  /tdm fights - открыть сохранённую историю боёв",
    },
    zhCN = {
        FIGHT_HISTORY = "战斗历史", FIGHT_HISTORY_TIP = "打开持久战斗历史",
        FIGHT_HISTORY_ALL = "全部战斗", FIGHT_HISTORY_BOSSES = "仅首领",
        FIGHT_HISTORY_CLEAR = "清除历史", FIGHT_HISTORY_EMPTY = "尚未保存地下城或团队战斗。",
        FIGHT_HISTORY_DAMAGE = "伤害", FIGHT_HISTORY_HEALING = "治疗",
        FIGHT_HISTORY_BOSS = "首领", FIGHT_HISTORY_TRASH = "小怪",
        FIGHT_HISTORY_PLAYER = "玩家", FIGHT_HISTORY_RATE = "DPS", FIGHT_HISTORY_TOTAL = "伤害",
        FIGHT_HISTORY_INTERRUPTS = "打断", FIGHT_HISTORY_DEATHS = "死亡",
        FIGHT_HISTORY_PREV = "上一页", FIGHT_HISTORY_NEXT = "下一页",
        FIGHT_HISTORY_KILL = "击杀", FIGHT_HISTORY_WIPE = "失败",
        CMD_HELP_FIGHTS = "  /tdm fights - 打开持久战斗历史",
    },
    zhTW = {
        FIGHT_HISTORY = "戰鬥歷史", FIGHT_HISTORY_TIP = "開啟持久戰鬥歷史",
        FIGHT_HISTORY_ALL = "全部戰鬥", FIGHT_HISTORY_BOSSES = "僅首領",
        FIGHT_HISTORY_CLEAR = "清除歷史", FIGHT_HISTORY_EMPTY = "尚未儲存地城或團隊戰鬥。",
        FIGHT_HISTORY_DAMAGE = "傷害", FIGHT_HISTORY_HEALING = "治療",
        FIGHT_HISTORY_BOSS = "首領", FIGHT_HISTORY_TRASH = "小怪",
        FIGHT_HISTORY_PLAYER = "玩家", FIGHT_HISTORY_RATE = "DPS", FIGHT_HISTORY_TOTAL = "傷害",
        FIGHT_HISTORY_INTERRUPTS = "斷法", FIGHT_HISTORY_DEATHS = "死亡",
        FIGHT_HISTORY_PREV = "上一頁", FIGHT_HISTORY_NEXT = "下一頁",
        FIGHT_HISTORY_KILL = "擊殺", FIGHT_HISTORY_WIPE = "失敗",
        CMD_HELP_FIGHTS = "  /tdm fights - 開啟持久戰鬥歷史",
    },
}

local settingsStrings = {
    enUS = {
        HISTORY_GUI = "History",
        HISTORY_GUI_DESC = "Boss-by-boss performance history from saved dungeon and raid fights.",
        HISTORY_GUI_BOSS = "Boss", HISTORY_GUI_NO_BOSS = "No saved boss fights yet.",
        HISTORY_GUI_PULLS = "Pulls", HISTORY_GUI_KILLS = "Kills",
        HISTORY_GUI_BEST_DPS = "Best DPS", HISTORY_GUI_BEST_HPS = "Best HPS", HISTORY_GUI_INTERRUPTS = "Interrupts",
        HISTORY_GUI_DATE = "Date", HISTORY_GUI_RESULT = "Result", HISTORY_GUI_TIME = "Time",
        HISTORY_GUI_DPS = "DPS", HISTORY_GUI_HPS = "HPS", HISTORY_GUI_INT = "Int", HISTORY_GUI_DISPELS = "Disp",
        HISTORY_GUI_DEATHS = "Deaths", HISTORY_GUI_AVOIDABLE = "Avoidable",
        HISTORY_GUI_KILL = "Kill", HISTORY_GUI_WIPE = "Wipe", HISTORY_GUI_PREV = "Previous", HISTORY_GUI_NEXT = "Next",
        HISTORY_GUI_OPEN_FULL = "Open full history", HISTORY_GUI_SELECT_TIP = "Left click: choose boss  •  Right click: previous boss",
    },
    frFR = {
        HISTORY_GUI = "Historique",
        HISTORY_GUI_DESC = "Historique des performances boss par boss pour les combats de donjon et raid enregistrés.",
        HISTORY_GUI_BOSS = "Boss", HISTORY_GUI_NO_BOSS = "Aucun combat de boss enregistré.",
        HISTORY_GUI_PULLS = "Pulls", HISTORY_GUI_KILLS = "Kills",
        HISTORY_GUI_BEST_DPS = "Meilleur DPS", HISTORY_GUI_BEST_HPS = "Meilleur HPS", HISTORY_GUI_INTERRUPTS = "Interruptions",
        HISTORY_GUI_DATE = "Date", HISTORY_GUI_RESULT = "Résultat", HISTORY_GUI_TIME = "Durée",
        HISTORY_GUI_DPS = "DPS", HISTORY_GUI_HPS = "HPS", HISTORY_GUI_INT = "Int", HISTORY_GUI_DISPELS = "Disp",
        HISTORY_GUI_DEATHS = "Morts", HISTORY_GUI_AVOIDABLE = "Évitable",
        HISTORY_GUI_KILL = "Tué", HISTORY_GUI_WIPE = "Échec", HISTORY_GUI_PREV = "Précédent", HISTORY_GUI_NEXT = "Suivant",
        HISTORY_GUI_OPEN_FULL = "Ouvrir l'historique complet", HISTORY_GUI_SELECT_TIP = "Clic gauche : choisir le boss  •  Clic droit : boss précédent",
    },
    deDE = {
        HISTORY_GUI = "Verlauf", HISTORY_GUI_DESC = "Bossbezogener Leistungsverlauf aus gespeicherten Dungeon- und Schlachtzugskämpfen.",
        HISTORY_GUI_BOSS = "Boss", HISTORY_GUI_NO_BOSS = "Noch keine Bosskämpfe gespeichert.",
        HISTORY_GUI_PULLS = "Pulls", HISTORY_GUI_KILLS = "Siege", HISTORY_GUI_BEST_DPS = "Beste DPS", HISTORY_GUI_BEST_HPS = "Beste HPS", HISTORY_GUI_INTERRUPTS = "Unterbrechungen",
        HISTORY_GUI_DATE = "Datum", HISTORY_GUI_RESULT = "Ergebnis", HISTORY_GUI_TIME = "Zeit", HISTORY_GUI_DPS = "DPS", HISTORY_GUI_HPS = "HPS", HISTORY_GUI_INT = "Unt.", HISTORY_GUI_DISPELS = "Bann", HISTORY_GUI_DEATHS = "Tode", HISTORY_GUI_AVOIDABLE = "Vermeidbar",
        HISTORY_GUI_KILL = "Sieg", HISTORY_GUI_WIPE = "Wipe", HISTORY_GUI_PREV = "Zurück", HISTORY_GUI_NEXT = "Weiter", HISTORY_GUI_OPEN_FULL = "Vollständigen Verlauf öffnen", HISTORY_GUI_SELECT_TIP = "Linksklick: Boss wählen  •  Rechtsklick: vorheriger Boss",
    },
    esES = {
        HISTORY_GUI = "Historial", HISTORY_GUI_DESC = "Historial de rendimiento por jefe de combates guardados de mazmorra y banda.",
        HISTORY_GUI_BOSS = "Jefe", HISTORY_GUI_NO_BOSS = "Aún no hay combates de jefe guardados.",
        HISTORY_GUI_PULLS = "Pulls", HISTORY_GUI_KILLS = "Victorias", HISTORY_GUI_BEST_DPS = "Mejor DPS", HISTORY_GUI_BEST_HPS = "Mejor HPS", HISTORY_GUI_INTERRUPTS = "Interrupciones",
        HISTORY_GUI_DATE = "Fecha", HISTORY_GUI_RESULT = "Resultado", HISTORY_GUI_TIME = "Tiempo", HISTORY_GUI_DPS = "DPS", HISTORY_GUI_HPS = "HPS", HISTORY_GUI_INT = "Int", HISTORY_GUI_DISPELS = "Disp", HISTORY_GUI_DEATHS = "Muertes", HISTORY_GUI_AVOIDABLE = "Evitable",
        HISTORY_GUI_KILL = "Victoria", HISTORY_GUI_WIPE = "Wipe", HISTORY_GUI_PREV = "Anterior", HISTORY_GUI_NEXT = "Siguiente", HISTORY_GUI_OPEN_FULL = "Abrir historial completo", HISTORY_GUI_SELECT_TIP = "Clic izquierdo: elegir jefe  •  Clic derecho: jefe anterior",
    },
    itIT = {
        HISTORY_GUI = "Cronologia", HISTORY_GUI_DESC = "Cronologia delle prestazioni boss per boss dai combattimenti dungeon e raid salvati.",
        HISTORY_GUI_BOSS = "Boss", HISTORY_GUI_NO_BOSS = "Nessun combattimento boss salvato.",
        HISTORY_GUI_PULLS = "Pull", HISTORY_GUI_KILLS = "Uccisioni", HISTORY_GUI_BEST_DPS = "Miglior DPS", HISTORY_GUI_BEST_HPS = "Miglior HPS", HISTORY_GUI_INTERRUPTS = "Interruzioni",
        HISTORY_GUI_DATE = "Data", HISTORY_GUI_RESULT = "Risultato", HISTORY_GUI_TIME = "Tempo", HISTORY_GUI_DPS = "DPS", HISTORY_GUI_HPS = "HPS", HISTORY_GUI_INT = "Int", HISTORY_GUI_DISPELS = "Disp", HISTORY_GUI_DEATHS = "Morti", HISTORY_GUI_AVOIDABLE = "Evitabile",
        HISTORY_GUI_KILL = "Ucciso", HISTORY_GUI_WIPE = "Wipe", HISTORY_GUI_PREV = "Precedente", HISTORY_GUI_NEXT = "Successivo", HISTORY_GUI_OPEN_FULL = "Apri cronologia completa", HISTORY_GUI_SELECT_TIP = "Clic sinistro: scegli boss  •  Clic destro: boss precedente",
    },
    ptBR = {
        HISTORY_GUI = "Histórico", HISTORY_GUI_DESC = "Histórico de desempenho por chefe dos combates salvos de masmorra e raide.",
        HISTORY_GUI_BOSS = "Chefe", HISTORY_GUI_NO_BOSS = "Nenhuma luta de chefe salva ainda.",
        HISTORY_GUI_PULLS = "Pulls", HISTORY_GUI_KILLS = "Vitórias", HISTORY_GUI_BEST_DPS = "Melhor DPS", HISTORY_GUI_BEST_HPS = "Melhor HPS", HISTORY_GUI_INTERRUPTS = "Interrupções",
        HISTORY_GUI_DATE = "Data", HISTORY_GUI_RESULT = "Resultado", HISTORY_GUI_TIME = "Tempo", HISTORY_GUI_DPS = "DPS", HISTORY_GUI_HPS = "HPS", HISTORY_GUI_INT = "Int", HISTORY_GUI_DISPELS = "Disp", HISTORY_GUI_DEATHS = "Mortes", HISTORY_GUI_AVOIDABLE = "Evitável",
        HISTORY_GUI_KILL = "Vitória", HISTORY_GUI_WIPE = "Wipe", HISTORY_GUI_PREV = "Anterior", HISTORY_GUI_NEXT = "Próximo", HISTORY_GUI_OPEN_FULL = "Abrir histórico completo", HISTORY_GUI_SELECT_TIP = "Clique esquerdo: escolher chefe  •  direito: chefe anterior",
    },
    ruRU = {
        HISTORY_GUI = "История", HISTORY_GUI_DESC = "История результатов по боссам из сохранённых боёв подземелий и рейдов.",
        HISTORY_GUI_BOSS = "Босс", HISTORY_GUI_NO_BOSS = "Сохранённых боёв с боссами пока нет.",
        HISTORY_GUI_PULLS = "Пуллы", HISTORY_GUI_KILLS = "Победы", HISTORY_GUI_BEST_DPS = "Лучший DPS", HISTORY_GUI_BEST_HPS = "Лучший HPS", HISTORY_GUI_INTERRUPTS = "Прерывания",
        HISTORY_GUI_DATE = "Дата", HISTORY_GUI_RESULT = "Результат", HISTORY_GUI_TIME = "Время", HISTORY_GUI_DPS = "DPS", HISTORY_GUI_HPS = "HPS", HISTORY_GUI_INT = "Прер.", HISTORY_GUI_DISPELS = "Дисп.", HISTORY_GUI_DEATHS = "Смерти", HISTORY_GUI_AVOIDABLE = "Избег.",
        HISTORY_GUI_KILL = "Убит", HISTORY_GUI_WIPE = "Вайп", HISTORY_GUI_PREV = "Назад", HISTORY_GUI_NEXT = "Далее", HISTORY_GUI_OPEN_FULL = "Открыть полную историю", HISTORY_GUI_SELECT_TIP = "ЛКМ: выбрать босса  •  ПКМ: предыдущий босс",
    },
    zhCN = {
        HISTORY_GUI = "历史", HISTORY_GUI_DESC = "按首领查看已保存地下城和团队战斗中的表现历史。",
        HISTORY_GUI_BOSS = "首领", HISTORY_GUI_NO_BOSS = "尚未保存首领战斗。",
        HISTORY_GUI_PULLS = "尝试", HISTORY_GUI_KILLS = "击杀", HISTORY_GUI_BEST_DPS = "最佳 DPS", HISTORY_GUI_BEST_HPS = "最佳 HPS", HISTORY_GUI_INTERRUPTS = "打断",
        HISTORY_GUI_DATE = "日期", HISTORY_GUI_RESULT = "结果", HISTORY_GUI_TIME = "时间", HISTORY_GUI_DPS = "DPS", HISTORY_GUI_HPS = "HPS", HISTORY_GUI_INT = "打断", HISTORY_GUI_DISPELS = "驱散", HISTORY_GUI_DEATHS = "死亡", HISTORY_GUI_AVOIDABLE = "可避免",
        HISTORY_GUI_KILL = "击杀", HISTORY_GUI_WIPE = "失败", HISTORY_GUI_PREV = "上一页", HISTORY_GUI_NEXT = "下一页", HISTORY_GUI_OPEN_FULL = "打开完整历史", HISTORY_GUI_SELECT_TIP = "左键：选择首领  •  右键：上一个首领",
    },
    zhTW = {
        HISTORY_GUI = "歷史", HISTORY_GUI_DESC = "依首領查看已儲存地城與團隊戰鬥中的表現歷史。",
        HISTORY_GUI_BOSS = "首領", HISTORY_GUI_NO_BOSS = "尚未儲存首領戰鬥。",
        HISTORY_GUI_PULLS = "嘗試", HISTORY_GUI_KILLS = "擊殺", HISTORY_GUI_BEST_DPS = "最佳 DPS", HISTORY_GUI_BEST_HPS = "最佳 HPS", HISTORY_GUI_INTERRUPTS = "斷法",
        HISTORY_GUI_DATE = "日期", HISTORY_GUI_RESULT = "結果", HISTORY_GUI_TIME = "時間", HISTORY_GUI_DPS = "DPS", HISTORY_GUI_HPS = "HPS", HISTORY_GUI_INT = "斷法", HISTORY_GUI_DISPELS = "驅散", HISTORY_GUI_DEATHS = "死亡", HISTORY_GUI_AVOIDABLE = "可避免",
        HISTORY_GUI_KILL = "擊殺", HISTORY_GUI_WIPE = "失敗", HISTORY_GUI_PREV = "上一頁", HISTORY_GUI_NEXT = "下一頁", HISTORY_GUI_OPEN_FULL = "開啟完整歷史", HISTORY_GUI_SELECT_TIP = "左鍵：選擇首領  •  右鍵：上一個首領",
    },
}

local function Install(strings)
    local selected = strings[GetLocale()] or strings.enUS
    for key, fallback in pairs(strings.enUS) do
        L[key] = selected[key] or fallback
    end
end

Install(fightStrings)
Install(settingsStrings)
