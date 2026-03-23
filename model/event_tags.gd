class_name StorableItem
enum AREA_TAGS {
    HORSE_WEALTH,
    EXCESSIVE_OFFICIAL
}

static func to_str(item) -> String:
    var name = AREA_TAGS.keys()[item]
    if name:
        return name.to_lower()
    Logging.err("Invalid area tag: " + str(item))
    return "default_storable_item"