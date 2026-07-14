@tool
class_name BaseOperator extends Resource

# 让子类自己定义，自己决定叫什么
# 只要方法没问题就行
var hint: String = '' # 无论是什么hint，可以在operate完成之后展示

func operate():
    """
    执行这个operator, 根据具体的value类型，例如str/int
    执行添加trait/property的操作
    """
    Logging.warn('someone call the super method of stat operator, which is mean to be rewrite from child class')

func show_hint(hint_: String = ''):
    var msg = hint if not hint else hint_
    EventBus.request_toast.emit(msg, 1)

## 契约方法：返回该Operator引用的flag ID数组
## 子类应该重写此方法以声明它依赖哪些flag
func get_referenced_flags() -> Array:
    return []

## 契约方法：返回该Operator提供的flag ID数组
## 子类应该重写此方法以声明它设置/修改哪些flag
func get_provided_flags() -> Array:
    return []

func get_demanded_flags() -> Array:
    return []

## 契约方法：返回该Operator引用的trait UUID数组
## 子类应该重写此方法以声明它依赖哪些trait
func get_referenced_traits() -> Array:
    return []

## 契约方法：返回该Operator提供的trait UUID数组
## 子类应该重写此方法以声明它添加/修改哪些trait
func get_provided_traits() -> Array:
    return []

func get_demanded_traits() -> Array:
    return []

## 契约方法：返回该 Operator 的人类可读向量预览文本（用于 Alt 工具提示）。
## 子类应重写此方法以提供有意义的预览文本。
## 返回空字符串表示该 Operator 不在 Alt 预览中显示。
func describe_preview() -> String:
    return ""

func init(_context: Dictionary) -> Dictionary:
    return _context

func on_exit(_context: Dictionary) -> Dictionary:
    return _context