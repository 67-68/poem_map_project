@tool
class_name ENUMS
enum AREA_TAGS { # 包括地区特性和地区本身?
    AREA_HORSE_WEALTH,
    AREA_EXCESSIVE_OFFICIAL,
}
"
DEPRECIATED!!!
DEPRECIATED!!!
DEPRECIATED!!!
"
enum ACTION_TAGS { 
    # NOW use 4-part tag format: {category}_{subcategory}_{type}_{specific}
    # Example: "action_travel_parting_withLiBai"
    #使用_来代替标签的:符号
    ACTOR_HEALTH_SICK_GENERAL, # 病痛/衰老# 
    ACTOR_HEALTH_DRUNK_GENERAL, # 宿醉/狂歌
    ACTOR_WEALTH_BROKE_GENERAL, # 穷困潦倒
    ACTOR_EMOTION_DESPAIR_GENERAL, # 极度郁结
    ACTOR_EMOTION_AMBITION_GENERAL, # 功名壮志
    
    SOCIAL_NATURE_AUTUMN_GENERAL, # 秋风/落叶/肃杀
    SOCIAL_NATURE_SPRING_GENERAL, # 春江/花月/复苏
    SOCIAL_FAMINE_STARVING_GENERAL, # 饿殍/流民
    SOCIAL_WAR_RUIN_GENERAL, # 废墟/烽火/白骨
    SOCIAL_COURT_PROSPER_GENERAL, # 极乐/奢靡/胡旋
    SOCIAL_COURT_CORRUPT_GENERAL, # 倾轧/权臣/谗言
    
    ACTION_TRAVEL_PARTING_GENERAL, # 霸桥送别/孤帆
    ACTION_TRAVEL_EXILE_GENERAL, # 贬谪/蜀道/风雪
    ACTION_RELATION_FRIEND_GENERAL, # 知音/夜雨对床
    ACTION_RELATION_PATRON_GENERAL, # 权贵/朱门
    
    INTEL_VIBE_ZEN_GENERAL, # 空山/古刹/禅意
    INTEL_VIBE_TAO_GENERAL, # 求仙/丹药/狂傲
    INTEL_VIBE_HISTORY_GENERAL, # 废垒/夕阳/沧桑

    ACTION_MAIN_BAIYE_GENERAL, # 基本的六种标签。每个行动都需要有对应的标签，每个对应的“主线任务事件”也需要有
    ACTION_MAIN_JIAOYOU_GENERAL, # 交游 instead of 送别
    ACTION_MAIN_DENGGAO_GENERAL,
    ACTION_MAIN_FANGSHI_GENERAL,
    ACTION_MAIN_FENGZHAO_GENERAL,
    ACTION_MAIN_DUZHUO_GENERAL,

    # 死亡
    ACTOR_HEALTH_DEATH_GENERAL,

    # 灵感特殊行动
    ACTION_SPECIAL_DEEPSEEK_GENERAL # organize thuought
}

enum PROPS {
    OFFICIAL_PRESTIGE,
    LITERARY_FAME,
    TALENT,
    MONEY,
    HEALTH,

    # 注意，以下这几个和上面的不是一个类型的，他们是 0 -> 100(最大)的
    FATIGUE, # 短期的疲惫，行动点 影响才华产出效率
    BURNOUT, # 长期的精神疲惫，精神疾病
    DRUNK, # 双刃剑：降低理性，但可能提供某些意象的获取折扣
    SICK, # 疲劳，到达阈值直接强制睡觉。把那个该死的 STRESS 删了！
    INSPIRATION  # 灵感（这玩意其实更像一种代币或 Buffer，用来兑换意象）
}

# 2. 核心情绪层 (The Soul - 意象生成的真正温床，建议采用双向坐标系)
# 不要用非黑即白的单向词汇，情绪是有正负极的！
enum EMOTION {
    SORROW,     # 愁苦/悲凉 (替代 DESPAIR，更具诗意，涵盖送别与怀古)
    ARROGANCE,  # 狂傲/得意 (涵盖饮酒作乐、金榜题名、无视权贵)
    ANGER,      # 愤懑 (涵盖被贬、目睹不公)
    TRANQUILITY, # 旷达/空灵 (涵盖山水田园、修道、释怀)
    # 3. 结果/特殊驱动力 (The Catalysts)
    AMBITION,    # 世俗的野心（想做官、想入世），用于区分李白和杜甫的路线
}

enum RELATION_TARGET {
    LIBAI,
    HUSHANG, # 商人
    LILINFU,
    JIWEN,
    YOUXIANGFU, # 右相府
    QINGLIU,
    GAOSHI,
    WANGWEI,
    ZHENGQIAN, # 郑虔
    WAIQI, # 外戚
    YANGGUOZHONG,
    GUOGUOFUREN, # 虢国夫人 
}

enum PROVINCES { 
    # 注意！！这里的地区不可以直接对应province.id 这只是用来对应事件和地区的。 
    # eg. 地区YONG_ZHOU雍州实际上对应长安CHANG_AN
    CHANG_AN
}

enum TRAITS {
    WANDERING_WITHOUT_LIVING_PLACE,
    
    # 第一等级诗词
    POEM__GAN_YE__1, # _ + _ -> : # 这里的两个下划线的设计应该是为了兼容四段式的A:B:C:D设计，如果我本来就不是这样的，我直接使用一个就行了（比如下面的主线行动等级)
    POEM__YING_ZHI__1, # 这里的1是最低级，不是0!
    POEM__ZENG_DA__1,
    POEM__HUAI_GU__1,
    POEM__JI_LV__1,
    POEM__SHAN_SHUI_1,

    # 主线行动等级标签
    MAIN_BAIYE_1,
    MAIN_BAIYE_2,
    MAIN_BAIYE_3,
    MAIN_BAIYE_4,
    
    MAIN_JIAOYOU_1,
    MAIN_JIAOYOU_2,
    MAIN_JIAOYOU_3,
    
    MAIN_DENGGAO_1,
    MAIN_DENGGAO_2,
    MAIN_DENGGAO_3,
    
    MAIN_FANGSHI_1,
    MAIN_FANGSHI_2,
    MAIN_FANGSHI_3,
    
    MAIN_FENGZHAO_1,
    MAIN_FENGZHAO_2,
    MAIN_FENGZHAO_3,
    MAIN_FENGZHAO_4,
    
    MAIN_DUZHUO_1,
    MAIN_DUZHUO_2,
    MAIN_DUZHUO_3,
    
    # 角色状态特性
    OFFICIAL,
    CORRUPT,
    PROUD,
    BRAVE,
    COWARDLY,
    CAUTIOUS,
    BUDDHIST,
    CONFIDENT,
    MERCHANT,
    DILIGENT,
    FEARFUL,
    WEAK,
    CRIMINAL,
    
    # 事件链特性
    CHAIN_STRANGE_POET_1,
    CHAIN_STRANGE_POET_2,
    CHAIN_STRANGE_POET_3,
    
    # 社会关系特性
    CONNECTED,
    JOYFUL,
    RESPECTED,
}

enum POEM_TYPE {
    GAN_YE, 
    YING_ZHI,
    ZENG_DA,
    HUAI_GU,
    JI_LV,
    SHAN_SHUI
}

enum ACTION_TYPE {
    BAI_YE, # 拜谒
    SONG_BIE,
    DENG_GAO,
    FANG_SHI, # 坊市
    FENG_ZHAO, # 奉召
    DU_ZHUO # 独酌
}

static func to_traits_str(item) -> String:
    var name = TRAITS.keys().get(item)
    name = name.replace('__',':')
    if name: return name.to_lower()
    Logging.err("Invalid trait: " + str(item))
    return "default_storable_item"

static func from_traits_str(str_name: String) -> int:
    var normalized = str_name.to_lower().replace(':', '__')
    for i in range(TRAITS.size()):
        var key = TRAITS.keys()[i]
        if key.to_lower() == normalized:
            return i
    Logging.err("Invalid trait string: " + str_name)
    return -1

static func to_action_str(item) -> String:
    var name = ACTION_TAGS.keys().get(item)
    if name:
        name = name.replace("_", ":")
        return name.to_lower()
    #breakpoint
    Logging.err("Invalid action tag: " + str(item))
    return "default_storable_item"

static func to_area_str(item) -> String:
    var name = AREA_TAGS.keys().get(item)
    if name:
        return name.to_lower()
    Logging.err("Invalid area tag: " + str(item))
    return "default_storable_item"

static func to_prop_str(item) -> String:
    var name = PROPS.keys().get(item)
    if name:
        return name.to_lower()
    Logging.err("Invalid prop tag: " + str(item))
    return "default_storable_item"

static func to_province_str(item) -> String:
    var name = PROVINCES.keys().get(item)
    if name:
        return name.to_lower()
    Logging.err("Invalid province tag: " + str(item))
    return "default_storable_item"

static func to_emotion_str(item) -> String:
    var name = EMOTION.keys().get(item)
    if name:
        name = name.replace("_", ":")
        return name.to_lower()
    Logging.err("Invalid volatile stat: " + str(item))
    return "default_storable_item"

static func to_relation_str(item) -> String:
    var name = RELATION_TARGET.keys().get(item)
    if name:
        return name.to_lower()
    Logging.err("Invalid province tag: " + str(item))
    return "default_storable_item"


# ============================================================
# URN System - 统一资源名称标识符
# ============================================================
# URN 格式: urn:poem_map:<resource-type>:<resource-id>
# 示例:     urn:poem_map:poet:libai_001
#           urn:poem_map:poem:jiang_jin_jiu
#           urn:poem_map:action:travel_parting_withLiBai
# ============================================================

enum URN_TYPE {
    POET,               # poet_data — 诗人数据
    POEM,               # poem_data — 诗词数据
    FACTION,            # factions — 势力
    PROVINCE,           # base_province — 基础省份（CSV）
    TERRITORY,          # territories — 领土（CSV）
    MSGER,              # msger_data — 消息者数据
    HISTORY_EVENT,      # history_events — 历史事件
    RANDOM_EVENT,       # random_events — 随机事件
    END_RANDOM_EVENT,   # end_random_events — 结局随机事件
    CHAT_BUBBLE,        # chat_bubble_data — 聊天气泡
    FOCUSED_CHAT,       # focused_chat_data — 聚焦对话
    AMBITION,           # ambitions — 抱负/雄心
    TRAIT,              # traits — 特性
    PROPERTY,           # properties — 属性
    ACTION,             # actions — 行动
    DECISION,           # decisions — 决策
    DECIDED_EVENT,      # decided_events — 已决定事件
    IMAGINARY,          # imaginaries — 想象物
    TAG,                # tags — 标签
    FLAG,               # flags — 标记
    LIFE_PATH_POINT,    # life_path_points — 人生轨迹点
    LEGENDARY_POEM,     # legendary_poems — 传奇诗词
    NORMAL_POEM_EVENT,  # normal_poem_events — 普通诗词事件
    CITY,               # cities（内部合并用）
    EVENT_OPTION,       # event_options — 事件选项（.tres 资源）
}

static func urn_type_to_str(type: int) -> String:
    """将 URN_TYPE enum 值转换为 URN 资源类型字符串（小写+连字符）"""
    var names = URN_TYPE.keys()
    if type >= 0 and type < names.size():
        return names[type].to_lower().replace("_", "-")
    Logging.err("Invalid URN type enum value: " + str(type))
    return "unknown"

static func make_urn(type: int, resource_id: String) -> String:
    """生成完整的 URN 字符串: urn:poem_map:<type>:<id>"""
    var type_str = urn_type_to_str(type)
    if type_str == "unknown":
        Logging.err("Failed to create URN for type " + str(type) + " with id " + resource_id)
    return "urn:poem_map:%s:%s" % [type_str, resource_id]

static func parse_urn(urn: String) -> Dictionary:
    """解析 URN 字符串，返回 { namespace, type, resource_id }
    若解析失败返回空字典并打错误日志
    """
    var parts = urn.split(":")
    if parts.size() != 4:
        Logging.err("Invalid URN format: " + urn + " — expected 'urn:poem_map:<type>:<id>'")
        return {}
    if parts[0] != "urn" or parts[1] != "poem_map":
        Logging.err("Invalid URN namespace: " + urn + " — expected 'urn:poem_map:...'")
        return {}
    return {
        "namespace": parts[1],
        "type": parts[2],
        "resource_id": parts[3]
    }

static func find_urn_type(type_str: String) -> int:
    """通过字符串查找对应的 URN_TYPE enum 值，未找到返回 -1"""
    var normalized = type_str.to_lower().replace("-", "_")
    var names = URN_TYPE.keys()
    for i in range(names.size()):
        if names[i].to_lower() == normalized:
            return i
    Logging.err("Unknown URN type string: " + type_str)
    return -1