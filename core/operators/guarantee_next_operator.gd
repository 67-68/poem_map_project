@tool
class_name GuaranteeNextOperator extends BaseOperator

## 要保证触发的事件 key，下一次事件抽取将强制命中此事件
@export var event_key: String

func operate():
    Logging.info("[GuaranteeNextOperator] Guaranteeing next event: " + event_key)
    EventManager.guarantee_next.emit(event_key)
    Logging.info("[GuaranteeNextOperator] Guarantee set, next draw will force event: " + event_key)


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
