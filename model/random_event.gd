class_name RandomEvent extends BaseEvent
# 那种在事件池随机抽取的
@export var weight: float

# 会被使用time operator中的source tag匹配. 由于无法集合两个enum那就单独写再集合
var target_tags: Array[String] = []:
    get:
        var result_tags: Array[String] = []
        for tag in _action_tags:
            result_tags.append(ENUMS.to_action_str(tag))
        for tag in _area_tags:
            result_tags.append(ENUMS.to_area_str(tag))
        return result_tags

@export var _action_tags: Array[ENUMS.ACTION_TAGS] = []
@export var _area_tags: Array[ENUMS.AREA_TAGS] = []
