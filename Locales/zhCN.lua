local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Localization: Simplified Chinese
----------------------------------------------------------------------

if GetLocale() ~= "zhCN" then return end

local L = ns.L

-- General
L["ADDON_NAME"] = "TomoDamageMeter"
L["ADDON_SHORT"] = "Tomo"

-- Meter types
L["DPS"] = "DPS"
L["HPS"] = "HPS"
L["DAMAGE_TAKEN"] = "承受伤害"
L["AVOIDABLE"] = "可避免伤害"
L["ENEMY_DAMAGE"] = "敌人伤害"
L["ABSORBS"] = "吸收"
L["INTERRUPTS"] = "打断"
L["DISPELS"] = "驱散"
L["DEATHS"] = "死亡"

-- Categories
L["DAMAGE"] = "伤害"
L["HEALING"] = "治疗"
L["ACTIONS"] = "动作"

-- Sessions
L["CURRENT"] = "当前"
L["OVERALL"] = "总计"

-- Header / UI
L["RESET"] = "重置"
L["LOCK"] = "锁定"
L["UNLOCK"] = "解锁"
L["SETTINGS"] = "设置"
L["REPORT"] = "汇报"
L["CLOSE"] = "关闭"

-- Format labels
L["FMT_COMPACT"] = "紧凑"
L["FMT_1DEC"] = "1位小数"
L["FMT_2DEC"] = "2位小数"
L["FMT_REGULAR"] = "常规"
L["FMT_INT"] = "整数"
L["FMT_DEC"] = "小数"

-- Report
L["REPORT_HEADER"] = "TomoDamageMeter：%s (%s)"
L["REPORT_NO_TARGET"] = "没有密语目标。请先选择一名玩家。"
L["REPORT_NO_DATA"] = "没有可汇报的数据。"
L["REPORT_CHANNEL_SAY"] = "说话"
L["REPORT_CHANNEL_PARTY"] = "小队"
L["REPORT_CHANNEL_RAID"] = "团队"
L["REPORT_CHANNEL_GUILD"] = "公会"
L["REPORT_CHANNEL_WHISPER"] = "密语"

-- Settings
L["SETTINGS_TITLE"] = "TomoDamageMeter 设置"
L["SETTINGS_GENERAL"] = "常规"
L["SETTINGS_APPEARANCE"] = "外观"
L["SETTINGS_COLUMNS"] = "列"
L["SETTINGS_FONT_SIZE"] = "字体大小"
L["SETTINGS_FONT_FACE"] = "字体"
L["SETTINGS_BAR_HEIGHT"] = "条高度"
L["SETTINGS_BG_OPACITY"] = "背景不透明度"
L["SETTINGS_OOC_OPACITY"] = "脱离战斗不透明度"
L["SETTINGS_BREAKDOWN_OPACITY"] = "技能详情不透明度"
L["SETTINGS_STRIP_REALM"] = "隐藏服务器名称"
L["SETTINGS_ACCENT_COLOR"] = "强调色"
L["SETTINGS_USE_CLASS_COLOR"] = "使用职业颜色"
L["SETTINGS_REPORT_CHANNEL"] = "汇报频道"
L["SETTINGS_REPORT_LINES"] = "汇报行数"
L["SETTINGS_WINDOWS"] = "窗口"
L["SETTINGS_ADD_WINDOW"] = "+ 添加"
L["SETTINGS_REMOVE_WINDOW"] = "- 移除"
L["SETTINGS_WINDOW_COUNT"] = "窗口：%d / %d"
L["SETTINGS_COL_RATE"] = "速率 (DPS/HPS)"
L["SETTINGS_COL_TOTAL"] = "总计"
L["SETTINGS_COL_PCT"] = "百分比"
L["SETTINGS_TAB_GENERAL"] = "常规"
L["SETTINGS_TAB_WINDOW"] = "窗口 %d"
L["SETTINGS_METER_TYPE"] = "统计类型"
L["SETTINGS_SESSION_TYPE"] = "会话类型"
L["SETTINGS_LOCKED"] = "锁定位置"

-- Slash commands
L["CMD_RESET"] = "数据已重置。"
L["CMD_LOCKED"] = "已锁定"
L["CMD_UNLOCKED"] = "已解锁"
L["CMD_HELP_HEADER"] = "命令："
L["CMD_HELP_TOGGLE"] = "  /tdm — 打开设置"
L["CMD_HELP_TOGGLE_VIS"] = "  /tdm toggle — 切换窗口显示"
L["CMD_HELP_RESET"] = "  /tdm reset — 重置所有战斗数据"
L["CMD_HELP_LOCK"] = "  /tdm lock — 锁定/解锁窗口位置"
L["CMD_HELP_HELP"] = "  /tdm help — 显示此消息"

-- Auto-reset
L["SETTINGS_AUTO_RESET_INSTANCE"] = "进入副本时自动重置"
L["SETTINGS_COMBAT_TIMER"] = "战斗计时器 (DPS/HPS)"
L["SETTINGS_SELF_BAR"] = "固定我的条目"
L["SETTINGS_CATEGORIES"] = "类别"
L["SETTINGS_CATEGORIES_MIN"] = "至少需要保留一个类别。"
L["AUTO_RESET_MSG"] = "数据已自动重置（进入副本）。"

-- Combat
L["COMBAT_SETTINGS_UNAVAILABLE"] = "战斗中无法使用设置。"
L["WAITING_COMBAT_END"] = "战斗结束后才可用"

-- Detail
L["SPELL_BREAKDOWN"] = "技能详情"
L["NO_DATA"] = "暂无数据"
L["BREAKDOWN_SPELLS_LABEL"] = "技能"
L["BREAKDOWN_CRITS_LABEL"] = "暴击"
L["BREAKDOWN_CRIT_RATE_LABEL"] = "暴击"
L["BREAKDOWN_COL_SPELL"] = "技能"
L["BREAKDOWN_COL_TOTAL"] = "总计"

-- Segments / Target Breakdown
L["SEGMENTS"] = "战斗段"
L["SEGMENT"] = "战斗段"
L["SEGMENT_COL_NAME"] = "遭遇战"
L["TARGET_BREAKDOWN"] = "目标详情"
L["TARGET_COL_NAME"] = "目标"

-- Tooltips
L["TIP_SETTINGS"] = "打开设置"
L["TIP_TARGET"] = "目标详情"
L["TIP_DETAILS"] = "技能详情"
L["TIP_LOCK"] = "锁定/解锁位置"
L["TIP_REPORT"] = "汇报到聊天"
L["TIP_RESET"] = "重置所有数据"
L["TIP_CATEGORY"] = "点击切换类别"
L["TIP_TYPE"] = "点击切换统计类型"
L["TIP_SESSION"] = "点击切换会话"

-- Font names
L["FONT_FRIZ"] = "Fritz Quadrata"
L["FONT_ARIAL"] = "Arial Narrow"
L["FONT_2002"] = "2002"
L["FONT_MORPHEUS"] = "Morpheus"
L["FONT_SKURRI"] = "Skurri"
L["FILTER_PLAYERS"] = "筛选..."
