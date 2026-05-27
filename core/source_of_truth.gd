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
    # 这是你真正需要密切关注的“癌症分期”
    "action_tracks": {
        "BAIYE": "main_baiye_2",    # 当前处于：阶段2（幕僚）
        "FENGZHAO": "main_fengzhao_1",
        "DUZHUO": "main_duzhuo_1",        # 正常
        "DENGGAO": "main_denggao_1",      # 正常
        "FANGSHI": "main_fangshi_1", 
        "JIAOYOU": "main_jiaoyou_1",  # 这些key其实没用，因为不需要分辨，全部塞进去trait就行了
        
        # 社交
        "LIBAI": 'relation_libai_4'
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