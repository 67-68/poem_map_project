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
    ACTION_EXPLORATION
}

enum PROPS {
	OFFICIAL_PRESTIGE,
	LITERARY_FAME,
	TALENT,
    MONEY,
    HEALTH,
    EMOTION
}

static func to_str(item) -> String:
    var name = ACTION_TAGS.keys().get(item)
    if not name: name = AREA_TAGS.keys().get(item)
    if not name: name = PROPS.keys().get(item)
    else:
        Logging.err("Invalid area tag: " + str(item))
        return "default_storable_item"
    if name:
        return name.to_lower()
    Logging.err("Invalid area tag: " + str(item))
    return "default_storable_item"