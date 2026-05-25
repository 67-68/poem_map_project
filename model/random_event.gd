class_name RandomEvent extends BaseEvent
# 那种在事件池随机抽取的
@export var weight: float = 10.0
@export var requirement: BaseRequirements

# 会被使用time operator中的source tag匹配. 由于无法集合两个enum那就单独写再集合
var target_tags: Array[String] = []:
    get:
        var result_tags: Array[String] = []
        for tag in _action_tags:
            result_tags.append(ENUMS.to_action_str(tag))
        for tag in _area_tags:
            result_tags.append(ENUMS.to_area_str(tag))
        for tag in _target_tags:
            result_tags.append(tag)
        
        var final_res: Array[String] = []
        for tag in result_tags:
            final_res.append(TagManager.normalize_3part_depreciated_tag(tag))
        return final_res
    set(tags):
        _target_tags = tags

var _target_tags: Array[String] = []
# 为了csv数据输入服务，数据输入不是ENUM格式，需要额外地方存

@export var _action_tags: Array[ENUMS.ACTION_TAGS] = []
@export var _area_tags: Array[ENUMS.AREA_TAGS] = []
