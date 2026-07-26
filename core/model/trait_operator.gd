@tool
class_name TraitOperator extends BaseOperator

@export var _trait_key: ENUMS.TRAITS # refers to the trait in trait base
@export var str_traits: String = "":
    set(value):
        str_traits = value
        # 当设置 str_traits 时，自动更新 _trait_key（如果存在于枚举中）
        if value and not value.is_empty():
            var enum_val = ENUMS.from_traits_str(value)
            if enum_val >= 0:
                _trait_key = enum_val

var trait_key: String:
    get():
        # 优先使用字符串形式，没有记录到enum的trait会在增加的时候失败，状态不同步
        if str_traits and not str_traits.is_empty():
            return str_traits
        # 回退到枚举形式
        if _trait_key != null:
            var trait_str = ENUMS.to_traits_str(_trait_key)
            # 自动补充 str_traits
            if trait_str and not trait_str.is_empty() and trait_str != "default_storable_item":
                str_traits = trait_str
            return trait_str
        return ""

@export var operator := REQ_OPERATOR.CRUD.ADD

func get_referenced_traits() -> Array:
    if trait_key.is_empty():
        return []
    if operator == REQ_OPERATOR.CRUD.REMOVE:
        return [trait_key]
    return []

func get_demanded_traits() -> Array:
    if trait_key.is_empty():
        return []
    if operator == REQ_OPERATOR.CRUD.REMOVE:
        return [trait_key]
    return []

func get_provided_traits() -> Array:
    if trait_key.is_empty():
        return []
    # ADD操作提供trait
    if operator == REQ_OPERATOR.CRUD.ADD:
        return [trait_key]
    return []

func operate():
    if operator == REQ_OPERATOR.CRUD.ADD:
        PlayerState.add_trait(trait_key)
        # 疾病诊断：如果添加的 trait 是 Disease 且有 on_enter_event，触发 guarantee_next
        var trait_obj = Database.get_trait(trait_key)
        if trait_obj is Disease and not trait_obj.on_enter_event.is_empty():
            EventManager.guarantee_next.emit(trait_obj.on_enter_event, "")
        _emit_float_text(trait_key)
    elif operator == REQ_OPERATOR.CRUD.REMOVE:
        PlayerState.remove_trait(trait_key)
    else:
        Logging.info('TraitOperator: unsupported operator %s for trait operations' % operator)

func describe_preview() -> String:
    if trait_key.is_empty():
        return ""
    var trait_obj = Database.get_trait(trait_key)
    if not trait_obj:
        return trait_key
    var cn_name = tr(trait_obj.name) if not trait_obj.name.is_empty() else trait_key
    if operator == REQ_OPERATOR.CRUD.ADD:
        return tr("CODE_TRAIT_OPERATOR_587CC92918") % cn_name
    elif operator == REQ_OPERATOR.CRUD.REMOVE:
        return tr("CODE_TRAIT_OPERATOR_9DBEC35E50") % cn_name
    return ""

func _emit_float_text(trait_name: String) -> void:
    if trait_name.is_empty():
        return
    var trait_obj = Database.get_trait(trait_name)
    if not trait_obj:
        return
    var text = trait_obj.description
    if text.is_empty():
        text = trait_obj.name
    if text.is_empty():
        return
    
    # FloatingText 现在使用 Control 自动定位到屏幕顶部居中
    EventBus.request_float_text.emit(text)
