@tool
class_name RandomEvent extends BaseEvent
# 那种在事件池随机抽取的
@export var weight: float = 10.0
@export var requirement: BaseRequirements
# 事件级别的结果（即使不选任何选项也会执行）
@export var event_result: ChoiceResult

# 从 context DSL 解析出的自定义参数，init 时通过 merge_context 合并入 context
var custom_context_params: Dictionary = {}

func init(context: Dictionary) -> Array:
    # 将 CSV context 中的自定义参数合并进 init context
    if not custom_context_params.is_empty():
        Util.merge_context(context, custom_context_params)
    
    var all_options = super.init(context)
    if event_result:
        event_result.init(context)
        event_result.operate()

    return all_options

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
