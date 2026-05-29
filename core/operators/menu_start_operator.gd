@tool
class_name MenuStartOperator extends BaseOperator

# 如果在使用编辑器，这一行是需要手动填入的poem taste
@export var resource_to_put_in_context: Resource
@export var key_of_resource_in_context: String
@export var next_event_key: String
var context: Dictionary

func init(context: Dictionary):
	# 🔒 深拷贝持有：MenuStartOperator 存储在 operate() 时使用的 context，
	# 必须拥有自己的副本，不能持有外部引用（防止外部变异导致脏数据）
	var sandbox = context.duplicate(true)
	
	# 如果本来的 context 已有内容，且自身没有资源要添加，
	# 则保留原 context 不被覆盖，避免下游事件丢失已积累的数据
	if not sandbox.is_empty() and (resource_to_put_in_context == null or key_of_resource_in_context.is_empty()):
		Logging.info("MenuStartOperator: 原有 context 非空，自身无资源，保留原 context 不变")
		self.context = sandbox
		return sandbox
	
	# 有资源要添加（操作沙盒副本，不影响调用方）
	if resource_to_put_in_context and not key_of_resource_in_context.is_empty():
		var old_val = sandbox.get(key_of_resource_in_context)
		sandbox[key_of_resource_in_context] = resource_to_put_in_context
		Logging.info("MenuStartOperator: 设置 context[%s] = %s (旧值: %s)" % [key_of_resource_in_context, str(resource_to_put_in_context), str(old_val)])
	else:
		Logging.warn("MenuStartOperator: resource 或 key 为空，未添加内容到 context")
	
	self.context = sandbox
	return sandbox

func operate():
	EventBus.request_event_key.emit(next_event_key, context) # context 此时已被 init 保留，包含之前积累的数据
