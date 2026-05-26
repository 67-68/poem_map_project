@tool
class_name TraitOperator extends BaseOperator

@export var _trait_key: ENUMS.TRAITS # refers to the trait in trait base
var trait_key: String:
    get():
        if str_traits and not str_traits.is_empty():
            return str_traits
        # 防御性检查：如果枚举值无效，返回空字符串而不是崩溃
        print("TraitOperator: string trait not set, use enum trait")
        if _trait_key != null:
            return ENUMS.to_traits_str(_trait_key)
        print("TraitOperator: both str_traits and _trait_key are null!")
        return ""

var str_traits: String = ""
@export var operator := REQ_OPERATOR.CRUD.ADD

func get_referenced_traits() -> Array:
    if trait_key.is_empty():
        return []
    # REMOVE操作需要先检查trait是否存在
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
