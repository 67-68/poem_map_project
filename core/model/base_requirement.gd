@tool
class_name BaseRequirements extends Resource
# 基础需求模板类，提供通用的需求判断功能

func compare(data) -> bool:
    return true

## 契约方法：返回该Requirement引用的flag ID数组
## 子类应该重写此方法以声明它依赖哪些flag
func get_referenced_flags() -> Array: # 实际上就是get_required_flags
    return []

## 契约方法：返回该Requirement引用的trait UUID数组
## 子类应该重写此方法以声明它依赖哪些trait
func get_referenced_traits() -> Array:
    return []