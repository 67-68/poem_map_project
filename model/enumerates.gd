class_name ENUMS
enum AREA_TAGS {
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

static func to_str(item) -> String:
    var name = ACTION_TAGS.keys().get(item)
    if not name: name = AREA_TAGS.keys().get(item)
    if not name: name = PROPS.keys().get(item)
    if not name: name = PROVINCES.keys().get(item)
    else:
        Logging.err("Invalid area tag: " + str(item))
        return "default_storable_item"
    if name:
        return name.to_lower()
    Logging.err("Invalid area tag: " + str(item))
    return "default_storable_item"