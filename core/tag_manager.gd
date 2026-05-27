class_name TagManager extends GDScript

static func get_tag(tag_id: String) -> Tag: # 解析tag_id获取tag对象，如果是旧时代的三段式就加个:general变成新时代的四段式
    if ":" not in tag_id:
        tag_id += ":general"
    return Database.tags.get(tag_id)

# 已废弃：废除字符串冒号分割协议，直接使用强类型引用
# static func get_imaginary_from_tag(tag: String) -> ImaginaryTag:
#     var parts = tag.split(":")
#     if parts.size() < 4:
#         Logging.err('tag have less than 4 parts: %s' % tag)
#         return null
#     var ima_uuid = parts[1] + ':' + parts[2]
#     var ima = Database.imaginaries.get(ima_uuid)
#     if not ima:
#         Logging.err('can not find imaginary %s for tag %s' % [ima_uuid, tag])
#         return
#     return ima

static func normalize_3part_depreciated_tag(tag: String):
    if tag.split(':').size() <= 3:
        tag += ":general"
    return tag
