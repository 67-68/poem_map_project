@tool
class_name SourceOfTruth extends RefCounted
# also: console

static var debug_dashboard_state = {
	# 维度 1：宏观时代压迫 (The Macro Environment)
	"world_state": {
		"current_xun": 0,                     # 当前回合数（旬）
		# "active_era_tags": ["era_ye_wu_yi_xian"], # 当前激活的时代辐射（强行替换可测试不同历史阶段）
	},
	
	# 维度 2：野心与核心驱动力 (The Core Engine)
	"player_ambition": {
		# "current_ambition_id": "amb_power_hungry",
		# "deadline_xun": 45,                   # 悬顶之剑倒计时
	},
	
	# 维度 3：六大 Action 的反噬状态机 (The 6-Track Corruption State)
	# @deprecated 2026-07-10: 主线等级 trait 及对应 .tres 文件已全部删除。
	# PlayerState.init_traits() 不再从此处读取注入 trait。
	# 保留此 dict 是出于存档兼容性考虑（旧存档可能残留 main_* uuid 在 traits 数组中）。
	# 左侧面板 TraitGrid 已增加 main_ 前缀防御性过滤，不会展示。
	"action_tracks": {
		"BAIYE": "",
		"FENGZHAO": "",
		"DUZHUO": "",
		"DENGGAO": "",
		"FANGSHI": "",
		"JIAOYOU": "",
	},
	
	# 维度 4：资源池 (The Expendables) - 核心六属性
	"resources": {
		"money": 45,
		"health": 50,
		"time": 10,
		"astuteness": 0,
		"composure": 0,
		"inspiration": 0,
		"momentum": 0,
		"prestige": 0,
		"talent": 0,
		"progress": 0,
	},

	"emotions": {
		"sorrow": 50,
		"arrogance": 50,
		"anger": 50,
		"tranquility": 50,
		"ambition": 50,
	},

	"imaginaries": {
		# imaginary UUID → 初始等级（保留兼容）
	},

	# 开局初始意象 — init_imaginaries() 从此读取
	"basic_imaginaries": [
		{"name": "布衣"},
		{"name": "古砚"},
		{"name": "骐骥"},
	],

	# 详细碎片初始数据 — 预填入 Database.imaginaries_detail (Imaginary 对象)
	# V7: ImaginaryConcept 已删除，concepts 字段已删除

	"flags": {
		#"flag_relation_with_libai":30
	},

	# 开局 NPC person_state 覆盖
	# key = NPC uuid, value = 目标 person_state（如 "not_meet"）
	# 在 PlayerState.init_npc_person_states() 中应用
	"npc_person_state_overrides": {
		"jiwen": "know_about",
		"zhengqian": "know_about",
	}
}


# ============================================================
# URN Resource Config — URN_TYPE 到目录/数据库字段的映射
# ============================================================
# data_dir: 编辑器模式下使用 DirAccess 扫描此目录下的 .tres 文件
#            按 uuid 字段匹配 resource_id（零注册表文件 💀）
# db_field:  运行时模式下通过 Database.get(field) 从已加载字典查找
# ============================================================
# 🚨 使用字符串 key 而不是 URN.URN_TYPE.XXX 枚举值。
# @tool 模式下跨脚本 enum 常量解析异常，会导致字典 get() 查找失败 💀
static var urn_resource_config: Dictionary = {
	"poet": {
		"data_dir": "res://data/2_characters/poets/",
		"db_field": "poet_data",
	},
	"poem_taste": {
		"data_dir": "res://data/2_characters/poem_tastes/",
		"db_field": "poem_taste",
	},
	"faction": {
		"data_dir": "res://data/1_core_rules/factions/",
		"db_field": "factions",
	},
	"msger": {
		"data_dir": "res://data/2_characters/messenger_data/",
		"db_field": "msger_data",
	},
	"history_event": {
		"data_dir": "res://data/4_eras/events/history_events/",
		"db_field": "history_events",
	},
	"end_random_event": {
		"data_dir": "res://data/4_eras/events/end_random_events/",
		"db_field": "end_random_events",
	},
	"focused_chat": {
		"data_dir": "res://data/3_actions_pool/focused_chats/",
		"db_field": "focused_chat_data",
	},
	"ambition": {
		"data_dir": "res://data/1_core_rules/ambitions/",
		"db_field": "ambitions",
	},
	"trait": {
		"data_dir": "res://data/1_core_rules/traits/",
		"db_field": "traits",
	},
	"property": {
		"data_dir": "res://data/1_core_rules/properties/",
		"db_field": "properties",
	},
	"action": {
		"data_dir": "res://data/3_actions_pool/actions/",
		"db_field": "actions",
	},
	"decision": {
		"data_dir": "res://data/3_actions_pool/decisions/",
		"db_field": "decisions",
	},
	"decided_event": {
		"data_dir": "res://data/3_actions_pool/decided_events/",
		"db_field": "decided_events",
	},
	"imaginary": {
		"data_dir": "res://data/1_core_rules/imaginaries/",
		"db_field": "imaginaries",
	},
	"tag": {
		"data_dir": "",
		"db_field": "tags",
	},
	"flag": {
		"data_dir": "res://data/1_core_rules/flags/",
		"db_field": "flags",
	},
	"life_path_point": {
		"data_dir": "res://data/2_characters/life_path_points/",
		"db_field": "life_path_points",
	},
	"normal_poem_event": {
		"data_dir": "res://data/3_actions_pool/write_poem/",
		"db_field": "normal_poem_events",
	},
	"event_option": {
		"data_dir": "res://data/1_core_rules/event_options/",
		"db_field": "event_options",
	},
	"state_transistor": {
		"data_dir": "res://data/1_core_rules/state_transistors/",
		"db_field": "state_transistors",
	},
}
