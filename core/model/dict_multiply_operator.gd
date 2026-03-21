class_name DictMultiplyOperator extends Resource

# 【给策划看的】为了让 Inspector 支持强类型和下拉菜单，我们只能用 Array
@export var operators: Array[MultiplyOperator] = []

# 【给程序用的】运行期缓存字典，查询速度 O(1)，告别恶心的 for 循环！
var _runtime_dict: Dictionary = {}
var _is_cached: bool = false

# 内部发电机：在第一次被调用时，自动把 Array 转化为 Dictionary
func _build_cache():
    if _is_cached: return
    for entry in operators:
        # 确保没有空值，避免报错
        if entry.name != "" and entry.operator != null:
            _runtime_dict[entry.name] = entry.operator
    _is_cached = true

# ==========================================
# 极简 API 接口
# ==========================================

func match_and_multiply(prop_name: String, prop: int) -> int: # 确保返回类型明确
    _build_cache()
    
    # 核心纠错：如果玩家在这个属性上没有 Buff，应该直接返回原值！不要报错！
    if not _runtime_dict.has(prop_name):
        return prop
        
    return _runtime_dict[prop_name].multiply(prop)

func has_operator(name: String) -> bool:
    _build_cache()
    return _runtime_dict.has(name)