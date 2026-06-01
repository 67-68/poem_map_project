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

# ──────────────────────────────────────────────
# 前缀匹配工具（用于 tag 系统革新）
# ──────────────────────────────────────────────

## 前缀匹配：短的 tag 作为前缀，匹配长的 tag
## 规则：
##   - 用短的 tag 去匹配长的 tag 的开头
##   - 必须按冒号分段匹配，防止 actor:health 误匹配 actor:healthcare
##   - 如果两 tag 长度相同，则全等匹配
##
## 示例：
##   prefix_match("actor:health", "actor:health:sick:general")  → true
##   prefix_match("actor:health", "actor:healthcare")           → false ❌ 分段边界
##   prefix_match("actor:health:sick", "actor:health:sick:general") → true
##   prefix_match("actor:health:sick:general", "actor:health")  → true (方向无关)
static func prefix_match(tag_a: String, tag_b: String) -> bool:
    var shorter = tag_a if tag_a.length() <= tag_b.length() else tag_b
    var longer = tag_a if tag_a.length() > tag_b.length() else tag_b
    
    if not longer.begins_with(shorter):
        return false
    
    # 确认分段边界：剩余部分要么为空，要么以 : 开头
    var remaining = longer.substr(shorter.length())
    return remaining.is_empty() or remaining.begins_with(":")
