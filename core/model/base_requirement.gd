@tool
class_name BaseRequirements extends Resource
# 基础需求模板类，提供通用的需求判断功能

## 可替换的失败提示文案。inspect / CSV / .tres 中均可直接配置。
## compare() 返回 false 时，调用方（EventBtn）会读取此字段展示给玩家。
@export var failed_hint: String = ""

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

func init(context: Dictionary) -> Dictionary: # load and store context
    return context

## 返回失败的提示文案。子类可重写此方法提供动态文案，
## 默认返回 @export failed_hint 字段的值（可从 CSV / .tres 中配置）。
func get_failed_hint() -> String:
    return failed_hint
