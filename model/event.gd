class_name BaseEvent extends GameEntity
@export var options: Array[EventOption] = []
@export var example: String
@export var requirement: BaseRequirements
@export var audio: AudioStream = null

# 会被使用time operator中的source tag匹配. 由于无法集合两个enum那就单独写再集合
var target_tags: Array[String] = []:
    get:
        var result_tags: Array[String] = []
        result_tags.append_array(_action_tags.map(func(tag): return ENUMS.to_action_str(tag)))
        result_tags.append_array(_area_tags.map(func(tag): return ENUMS.to_area_str(tag)))
        return result_tags

@export var _action_tags: Array[ENUMS.ACTION_TAGS] = []
@export var _area_tags: Array[ENUMS.AREA_TAGS] = []
