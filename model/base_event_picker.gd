class_name BaseEventPicker extends Resource
## Picker 自身的 UUID（用于 Database 注册表索引，如 "rumu_qingliu_picker"）
## 区别于 event_uuid：uuid 标识 picker 本身，event_uuid 是 naive picker 直接返回的事件 key
@export var uuid: String = ""

## Naive picker 兜底字段：直接返回的事件 UUID（ArchetypeEventPicker 不使用此字段）
@export var event_uuid: String = ''

func pick(_ctx: Dictionary):
    return event_uuid