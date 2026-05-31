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
    # 这是你真正需要密切关注的"癌症分期"
    "action_tracks": {
        "BAIYE": "main_baiye_2",    # 当前处于：阶段2（幕僚）
        "FENGZHAO": "main_fengzhao_1",
        "DUZHUO": "main_duzhuo_1",        # 正常
        "DENGGAO": "main_denggao_1",      # 正常
        "FANGSHI": "main_fangshi_1", 
        "JIAOYOU": "main_jiaoyou_1",  # 这些key其实没用，因为不需要分辨，全部塞进去trait就行了
        
        # 社交
        # _rumor/_close/_core/_enemy
        "LIBAI": 'relation_libai_rumor',

        # 诗词
        "POEM_BAIYE": 'poem_ying_zhi_1', # 不要大写, 会出问题
        'POEM_shanshui': 'poem_deng_gao_1'
    },
    
    # 维度 4：资源池 (The Expendables) - 最不重要的底层数值
    "resources": {
        "money": 500,
        "health": 100,
        "official_prestige": 100,
        "literary_fame": 50,
        "talent": 50, # 如果才气不够就写不出春望，需要点各种事件来加才气
        "burnout": 0,
        "drunk": 0,
        "fatigue": 0,
        "sick": 0,
        "inspiration": 0,
    },

    "imaginaries": {
        # imaginary UUID -> 初始等级
        "emotion:ambition": 2,
    },

    "flags": {
        "flag_relation_with_libai":30
    }
}


# ============================================================
# URN Resource Config — URN_TYPE 到文件路径/数据库字段的映射
# ============================================================
# 用于 get_resource_through_urn 在编辑器模式下直接加载 .tres 资源
# 在非编辑器模式下，通过 db_field 在 database.gd 的字典中查找
# ============================================================
# 🚨 使用字符串 key 而不是 URN.URN_TYPE.XXX 枚举值。
# @tool 模式下跨脚本 enum 常量解析异常，会导致字典 get() 查找失败 💀
static var urn_resource_config: Dictionary = {
    "poet": {
        "registry": "res://data/tres_poet_data_registry.tres",
        "db_field": "poet_data",
    },
    "poem": {
    	"registry": "res://data/tres_poem_data_registry.tres",
    	"db_field": "poem_data",
    },
    "poem_taste": {
    	"registry": "res://data/poem_taste_registry.tres",
    	"db_field": "poem_taste",
    },
    "faction": {
        "registry": "res://data/tres_factions_registry.tres",
        "db_field": "factions",
    },
    "msger": {
        "registry": "res://data/tres_msger_data_registry.tres",
        "db_field": "msger_data",
    },
    "history_event": {
        "registry": "res://data/tres_history_event_registry.tres",
        "db_field": "history_events",
    },
    "end_random_event": {
        "registry": "res://data/tres_end_random_events_registry.tres",
        "db_field": "end_random_events",
    },
    "focused_chat": {
        "registry": "res://data/tres_focused_chats_registry.tres",
        "db_field": "focused_chat_data",
    },
    "ambition": {
        "registry": "res://data/tres_ambitions_registry.tres",
        "db_field": "ambitions",
    },
    "trait": {
        "registry": "res://data/tres_traits_registry.tres",
        "db_field": "traits",
    },
    "property": {
        "registry": "res://data/tres_properties_registry.tres",
        "db_field": "properties",
    },
    "action": {
        "registry": "res://data/tres_actions_registry.tres",
        "db_field": "actions",
    },
    "decision": {
        "registry": "res://data/tres_decisions_registry.tres",
        "db_field": "decisions",
    },
    "decided_event": {
        "registry": "res://data/tres_decided_events_registry.tres",
        "db_field": "decided_events",
    },
    "imaginary": {
        "registry": "res://data/tres_imaginaries_registry.tres",
        "db_field": "imaginaries",
    },
    "tag": {
        "registry": "res://data/tres_tags_registry.tres",
        "db_field": "tags",
    },
    "flag": {
        "registry": "res://data/flags_registry.tres",
        "db_field": "flags",
    },
    "life_path_point": {
        "registry": "res://data/tres_path_points_registry.tres",
        "db_field": "life_path_points",
    },
    "legendary_poem": {
        "registry": "res://data/tres_legendary_poems_registry.tres",
        "db_field": "legendary_poems",
    },
    "normal_poem_event": {
        "registry": "res://data/tres_normal_poem_events_registry.tres",
        "db_field": "normal_poem_events",
    },
    "event_option": {
        "registry": "res://data/event_options_registry.tres",
        "db_field": "event_options",
    },
    "state_transistor": {
        "registry": "res://data/tres_state_transistors_registry.tres",
        "db_field": "state_transistors",
    },
}
