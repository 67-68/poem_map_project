@tool
class_name RandomEvent extends BaseEvent
# 那种在事件池随机抽取的

# 🚨 @tool 模式下类继承链可能未完全加载，BaseEvent 上定义的
# `pre_event_interrupter_sequence` 属性可能不可达。
# 直接赋值会触发 Godot ERR_FAIL → abort 调用方函数 💀
#
# 通过 _set()/_get()/_get_property_list() 兜底：
# - 常规属性查找失败时，_set() 将值存入 _interruption_seq_fallback
# - _get() 返回 fallback 值（供 @tool 模式下读取）
# - _get_property_list() 在 fallback 被激活时注册该属性到 property list，
#   确保 .tres 序列化能正确保存 💾
#
# 非 @tool 模式下继承链正常，_set() 不会被触发，无副作用。
var _interruption_seq_fallback: Array = []
var _interruption_seq_fallback_used: bool = false

func _set(property: StringName, value: Variant) -> bool:
    if property == &"pre_event_interrupter_sequence":
        _interruption_seq_fallback = value
        _interruption_seq_fallback_used = true
        return true
    return false

func _get(property: StringName) -> Variant:
    if property == &"pre_event_interrupter_sequence" and _interruption_seq_fallback_used:
        return _interruption_seq_fallback
    return null

func _get_property_list() -> Array:
    # 只在 fallback 被激活时（即 @tool 模式下属性不可达）才注册，
    # 避免与正常继承链注册的 @export 属性冲突
    if _interruption_seq_fallback_used:
        return [{
            "name": &"pre_event_interrupter_sequence",
            "type": TYPE_ARRAY,
            "usage": PROPERTY_USAGE_DEFAULT
        }]
    return []


@export var weight: float = 10.0
@export var requirement: BaseRequirements
# on_enter_result（原名 event_result）已提升到 BaseEvent.on_enter_result
# 保留注释以提示迁移，不再在此处 @export

# 从 context DSL 解析出的自定义参数，init 时通过 merge_context 合并入 context
var custom_context_params: Dictionary = {}

# ──────────────────────────────────────────────
# on_enter — 舞台置景
# ──────────────────────────────────────────────
# 重写 BaseEvent.on_enter()，在事件级结果执行之前先合并自定义参数。
#
# 执行顺序：
#   1. custom_context_params merge → context 注入 CSV/DSL 参数
#   2. super.on_enter() → event_result.init() + event_result.operate()
#
# 这确保 event_result 中的 operator 可以读取到 custom_context_params 注入的字段。
# ──────────────────────────────────────────────
func on_enter(context: Dictionary) -> void:
    # 将 CSV context 中的自定义参数合并进 init context
    # 必须在 event_result 之前执行，因为 operator 可能依赖这些参数
    if not custom_context_params.is_empty():
        Util.merge_context(context, custom_context_params)
    
    # 执行事件级结果（舞台置景）
    super.on_enter(context)


func init(context: Dictionary) -> Array:
    # on_enter 已在 super.init() → BaseEvent.init() 中调用，
    # 所有前置逻辑（custom_context_params merge + event_result）已在 on_enter 中完成。
    var all_options = super.init(context)
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
