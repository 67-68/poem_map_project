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
    elif operator == REQ_OPERATOR.CRUD.REMOVE:
        PlayerState.remove_trait(trait_key)
    else:
        print('TraitOperator: unsupported operator %s for trait operations' % operator)
