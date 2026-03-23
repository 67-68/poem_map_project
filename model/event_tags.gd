class_name StorableItem
enum TAGS {
    AREA_HORSE_WEALTH,
    AREA_EXCESSIVE_OFFICIAL,
    ACTION_MOVE,
    ACTION_REST,
    ACTION_WORK,
    ACTION_STUDY,
    ACTION_SOCIAL,
    ACTION_EXPLORATION
}

static func to_str(item) -> String:
    var name = TAGS.keys()[item]
    if name:
        return name.to_lower()
    Logging.err("Invalid area tag: " + str(item))
    return "default_storable_item"