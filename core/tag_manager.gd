class_name TagManager extends GDScript

static func get_tag(tag_id: String) -> Tag: # 解析tag_id获取tag对象，如果是旧时代的三段式就加个:general变成新时代的四段式
    if ":" not in tag_id:
        tag_id += ":general"
    return Database.get_tag(tag_id)
