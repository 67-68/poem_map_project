class_name BaseEventPicker extends Resource
# 用来获取一个事件的uuid，不负责执行
@export var event_uuid: String = ''

func pick(_ctx: Dictionary):
    return event_uuid