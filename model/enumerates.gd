class_name ENUMS
enum AREA_TAGS { # 包括地区特性和地区本身?
    AREA_HORSE_WEALTH,
    AREA_EXCESSIVE_OFFICIAL,
}

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
    SCANDAL
}

enum PROPS {
	OFFICIAL_PRESTIGE,
	LITERARY_FAME,
	TALENT,
    MONEY,
    HEALTH,
    EMOTION
}

enum PROVINCES { 
    # 注意！！这里的地区不可以直接对应province.id 这只是用来对应事件和地区的。 
    # eg. 地区YONG_ZHOU雍州实际上对应长安CHANG_AN
    CHANG_AN
}

static func to_action_str(item) -> String:
    var name = ACTION_TAGS.keys().get(item)
    if name:
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