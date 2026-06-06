@tool
class_name GuaranteeNextOperator extends BaseOperator

## 要保证触发的事件 key，下一次事件抽取将强制命中此事件
@export var event_key: String

## 可选：限定保证仅在指定 main_tag 的抽奖中生效。
## 留空（空字符串）表示通用保证，直接通过 find_triggerable_item 旁路所有 filter 强制命中。
@export var main_tag: String = ""

func operate():
    Logging.info("[GuaranteeNextOperator] Guaranteeing next event: " + event_key + " (main_tag: '" + main_tag + "')")
    EventManager.guarantee_next.emit(event_key, main_tag)
    Logging.info("[GuaranteeNextOperator] Guarantee set, next draw will force event: " + event_key + " (main_tag: '" + main_tag + "')")


# ─── 契约方法 ───

func get_referenced_flags() -> Array:
    return []

func get_provided_flags() -> Array:
    return []

func get_demanded_flags() -> Array:
    return []

func get_referenced_traits() -> Array:
    return []

func get_provided_traits() -> Array:
    return []

func get_demanded_traits() -> Array:
    return []
