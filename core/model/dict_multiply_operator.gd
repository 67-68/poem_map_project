class_name DictMultiplyOperator extends Resource

@export var operators: Array[MultiplyOperator] = []

var _runtime_dict: Dictionary = {}
var _is_cached: bool = false

func _build_cache():
    if _is_cached: return
    for entry in operators:
        # 💀 防呆强化：策划在 Inspector 里完全可能留一个空的 Array 元素 (null)
        if entry != null and entry.key != "":
            # 🤓☝️ 核心修正：存入整个操作符对象 (Resource)，而不是存那个该死的枚举 int！
            _runtime_dict[entry.key] = entry 
    _is_cached = true

func match_and_multiply(prop_name: String, prop: int) -> int:
    _build_cache()
    
    if not _runtime_dict.has(prop_name):
        return prop
        
    # 现在这里拿到的才是真正的 MultiplyOperator 对象，可以安全调用 multiply
    return _runtime_dict[prop_name].multiply(prop)

func has_operator(name: String) -> bool:
    _build_cache()
    return _runtime_dict.has(name)
