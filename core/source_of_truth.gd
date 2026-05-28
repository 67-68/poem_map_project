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
        "LIBAI": 'relation_libai_4',

        # 诗词
        "POEM_BAIYE": 'POEM_YING_ZHI_1'
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
    }
}


# ============================================================
# URN Resource Config — URN_TYPE 到文件路径/数据库字段的映射
# ============================================================
# 用于 get_resource_through_urn 在编辑器模式下直接加载 .tres 资源
# 在非编辑器模式下，通过 db_field 在 database.gd 的字典中查找
# ============================================================
static var urn_resource_config: Dictionary = {
    URN.URN_TYPE.POET: {
        "registry": "res://data/tres_poet_data_registry.tres",
        "db_field": "poet_data",
    },
    URN.URN_TYPE.POEM: {
        "registry": "res://data/tres_poem_data_registry.tres",
        "db_field": "poem_data",
    },
    URN.URN_TYPE.FACTION: {
        "registry": "res://data/tres_factions_registry.tres",
        "db_field": "factions",
    },
    URN.URN_TYPE.MSGER: {
        "registry": "res://data/tres_msger_data_registry.tres",
        "db_field": "msger_data",
    },
    URN.URN_TYPE.HISTORY_EVENT: {
        "registry": "res://data/tres_history_event_registry.tres",
        "db_field": "history_events",
    },
    URN.URN_TYPE.END_RANDOM_EVENT: {
        "registry": "res://data/tres_end_random_events_registry.tres",
        "db_field": "end_random_events",
    },
    URN.URN_TYPE.FOCUSED_CHAT: {
        "registry": "res://data/tres_focused_chats_registry.tres",
        "db_field": "focused_chat_data",
    },
    URN.URN_TYPE.AMBITION: {
        "registry": "res://data/tres_ambitions_registry.tres",
        "db_field": "ambitions",
    },
    URN.URN_TYPE.TRAIT: {
        "registry": "res://data/tres_traits_registry.tres",
        "db_field": "traits",
    },
    URN.URN_TYPE.PROPERTY: {
        "registry": "res://data/tres_properties_registry.tres",
        "db_field": "properties",
    },
    URN.URN_TYPE.ACTION: {
        "registry": "res://data/tres_actions_registry.tres",
        "db_field": "actions",
    },
    URN.URN_TYPE.DECISION: {
        "registry": "res://data/tres_decisions_registry.tres",
        "db_field": "decisions",
    },
    URN.URN_TYPE.DECIDED_EVENT: {
        "registry": "res://data/tres_decided_events_registry.tres",
        "db_field": "decided_events",
    },
    URN.URN_TYPE.IMAGINARY: {
        "registry": "res://data/tres_imaginaries_registry.tres",
        "db_field": "imaginaries",
    },
    URN.URN_TYPE.TAG: {
        "registry": "res://data/tres_tags_registry.tres",
        "db_field": "tags",
    },
    URN.URN_TYPE.FLAG: {
        "registry": "res://data/flags_registry.tres",
        "db_field": "flags",
    },
    URN.URN_TYPE.LIFE_PATH_POINT: {
        "registry": "res://data/tres_path_points_registry.tres",
        "db_field": "life_path_points",
    },
    URN.URN_TYPE.LEGENDARY_POEM: {
        "registry": "res://data/tres_legendary_poems_registry.tres",
        "db_field": "legendary_poems",
    },
    URN.URN_TYPE.NORMAL_POEM_EVENT: {
        "registry": "res://data/tres_normal_poem_events_registry.tres",
        "db_field": "normal_poem_events",
    },
    URN.URN_TYPE.EVENT_OPTION: {
        "registry": "res://data/event_options_registry.tres",
        "db_field": "event_options",
    },
}
