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
    	"BAIYE": "main_baiye_1",
    	"FENGZHAO": "main_fengzhao_1",
    	"DUZHUO": "main_duzhuo_1",        # 正常
    	"DENGGAO": "main_denggao_1",      # 正常
    	"FANGSHI": "main_fangshi_1",
    	"JIAOYOU": "main_jiaoyou_1",  # 这些key其实没用，因为不需要分辨，全部塞进去trait就行了
        
        # 社交
        # _rumor/_close/_core/_enemy
        "LIBAI": 'relation_libai_rumor',

        # 诗词
        "POEM_BAIYE": 'poem_gan_ye_3', # 不要大写, 会出问题
        "POEM_BAIY": 'poem_gan_ye_2', # 不要大写, 会出问题
        'POEM_shanshui': 'poem_deng_gao_1'
    },
    
    # 维度 4：资源池 (The Expendables) - 核心六属性
    "resources": {
        "money": 50,
        "health": 100,
        "literary_fame": 50,
        "talent": 50,
        "progress": 0,
        "time": 10,
    },

    "emotions": {
        "sorrow": 50,
        "arrogance": 50,
        "anger": 50,
        "tranquility": 50,
        "ambition": 50,
    },

    "imaginaries": {
        # imaginary UUID -> 初始等级
        #"emotion:ambition": 2,
        "environment:snow": 1,
    },

    # 详细意象蓝图（basic_imaginaries）— 直接预填入 ImaginaryTag.basic_imaginaries
    # 每条是一个 Dict，格式同 PlayerState._on_request_add_imaginary 创建的结构：
    #   blueprint_id: 4 段式 tag（TARGET_ACTOR_DUFU_STH）
    #   contexts:     上下文标签列表
    #   tier:         品级（1/2/3）
    # 中间两段 ACTOR:DUFU（lowercase）用于匹配 ImainaryTag.uuid
    "basic_imaginaries": [
        {
            "blueprint_id": "TARGET_ENVIRONMENT_SNOW_WANDER",
            "contexts": ["winter", "exile"],
            "tier": 1,
        },
    ],

    "flags": {
        #"flag_relation_with_libai":30
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
    "poem": {
        "data_dir": "res://data/2_characters/poems/",
        "db_field": "poem_data",
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
    "legendary_poem": {
        "data_dir": "res://data/2_characters/poems/",
        "db_field": "legendary_poems",
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
