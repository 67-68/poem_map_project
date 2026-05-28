@tool
class_name MenuStartOperator extends BaseOperator

# 如果在使用编辑器，这一行是需要手动填入的poem taste
@export var resource_to_put_in_context: Resource
@export var key_of_resource_in_context: String
@export var next_event_key: String
var context: Dictionary

func init(context: Dictionary):
	breakpoint
	context[key_of_resource_in_context] = resource_to_put_in_context
	return context

func operate():
	EventBus.request_event_key.emit(next_event_key,context) # 此时的context已经被operators修改过一遍了
