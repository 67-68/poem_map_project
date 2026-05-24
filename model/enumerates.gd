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
    # 标准行动action. 可以在任何城市触发相应的事件
    ACTION_EXERCISE,
    ACTION_REST,
    ACTION_WORK,
    ACTION_STUDY,
    ACTION_SOCIAL,
    ACTION_EXPLORATION,
    CHANGAN_ELITE,
    POLITICAL_FACTION,
    HIGH_CONSUMPTION,
    SEEK_PATRONAGE,
    HUMILIATION,
    LITERARY_DISPLAY,
    MARKET,
    INTELLIGENCE,
    LOWER_CLASS,
    INSPIRATION,
    ROYAL_PROXIMITY,
    NATURE,
    STUDY,
    SOLITUDE,
    HEALTH_RISK,
    DESPIRATION,
    DRUNK,
    SCANDAL,
    DEATH, # 普通筛选的时候排除，专门用来做死亡事件
    CHAOTIC_WORLD,
    # above: depreciated
    
    #使用_来代替标签的:符号
    ACTOR_HEALTH_SICK, # 病痛/衰老# 
    ACTOR_HEALTH_DRUNK, # 宿醉/狂歌
    ACTOR_WEALTH_BROKE, # 穷困潦倒
    ACTOR_EMOTION_DESPAIR, # 极度郁结
    ACTOR_EMOTION_AMBITION, # 功名壮志
    
    SOCIAL_NATURE_AUTUMN, # 秋风/落叶/肃杀
    SOCIAL_NATURE_SPRING, # 春江/花月/复苏
    SOCIAL_FAMINE_STARVING, # 饿殍/流民
    SOCIAL_WAR_RUIN, # 废墟/烽火/白骨
    SOCIAL_COURT_PROSPER, # 极乐/奢靡/胡旋
    SOCIAL_COURT_CORRUPT, # 倾轧/权臣/谗言
    
    ACTION_TRAVEL_PARTING, # 霸桥送别/孤帆
    ACTION_TRAVEL_EXILE, # 贬谪/蜀道/风雪
    ACTION_RELATION_FRIEND, # 知音/夜雨对床
    ACTION_RELATION_PATRON, # 权贵/朱门
    
    INTEL_VIBE_ZEN, # 空山/古刹/禅意
    INTEL_VIBE_TAO, # 求仙/丹药/狂傲
    INTEL_VIBE_HISTORY, # 废垒/夕阳/沧桑

    ACTION_BAI_YE, # 基本的六种标签。每个行动都需要有对应的标签，每个对应的“主线任务事件”也需要有
    ACTION_SONG_BIE,
    ACTION_DENG_GAO,
    ACTION_FANG_SHI,
    ACTION_FENG_ZHAO,
    ACTION_DU_ZHUO,

    # ABOVE ARE DEPRECIATED
    # NOW use 4-part tag format: {category}_{subcategory}_{type}_{specific}
    # Example: "action_travel_parting_withLiBai"
    ACTOR_HEALTH_DEATH_GENERAL
}

enum PROPS {
	OFFICIAL_PRESTIGE,
	LITERARY_FAME,
	TALENT,
    MONEY,
    HEALTH,
    FATIGUE, # 影响才华产出效率
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



enum PROVINCES { 
    # 注意！！这里的地区不可以直接对应province.id 这只是用来对应事件和地区的。 
    # eg. 地区YONG_ZHOU雍州实际上对应长安CHANG_AN
    CHANG_AN
}

enum TRAITS {
    ORDINARY_PEOPLE,
    LV_NINE_OFFICIAL,
    WANDERING_WITHOUT_LIVING_PLACE,
    
    # 第一等级诗词
    POEM__GAN_YE__1, # _ + _ -> :
    POEM__YING_ZHI__1, # 这里的1是最低级，不是0!
    POEM__ZENG_DA__1,
    POEM__HUAI_GU__1,
    POEM__JI_LV__1,
    POEM__SHAN_SHUI_1
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

static func to_action_str(item) -> String:
    var name = ACTION_TAGS.keys().get(item)
    if name:
        name = name.replace("_", ":")
        return name.to_lower()
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
