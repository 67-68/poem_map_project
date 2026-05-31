@tool
class_name ContextFetchOperators extends BaseOperator

@export var fetched_key: String
@export var datasource_name: String
@export var prop_from_result: String
@export var key_stored_context: String

# 🏷️ 可选 URN 前缀：如果设置，提取的值会被包裹为 "urn:{urn_prefix}:{extracted}"
# 例如 urn_prefix = "poem_taste"，提取 value = "libai_taste" → 存入 "urn:poem_taste:libai_taste"
@export var urn_prefix: String = ""


func init(_context: Dictionary) -> Dictionary:
	# ── 校验：三个配置项都必须有值 ──
	if not datasource_name or not key_stored_context or not fetched_key:
		Logging.err('ContextFetchOperators: missing required config — datasource_name=%s, key_stored_context=%s, fetched_key=%s' % [datasource_name, key_stored_context, fetched_key])
		return _context

	# ── 从上下文中取出要查的 key ──
	var key = _context.get(fetched_key)
	if key == null:
		Logging.err("ContextFetchOperators: key '%s' not found in context" % fetched_key)
		return _context

	# ── 查表 ──
	var database = Database.get(datasource_name)
	var result

	if database == null:
		Logging.warn("ContextFetchOperators: table '%s' not found in Database, falling back to find_from_all (性能开销)" % datasource_name)
		result = Database.find_from_all(key)
	else:
		result = database.get(key)

	if result == null:
		Logging.err("ContextFetchOperators: no result found for key '%s' from table '%s'" % [key, datasource_name])
		return _context

	# ── 处理返回值：基本类型直接存，对象类型提取属性 ──
	var is_basic_type = (result is String) or (result is int) or (result is float) or (result is bool)

	if is_basic_type:
		_context[key_stored_context] = result
		Logging.info("ContextFetchOperators: stored basic value '%s' into context[%s]" % [str(result), key_stored_context])
		return _context

	# 非基本类型 → 需要指定提取哪个属性
	if not prop_from_result:
		Logging.err("ContextFetchOperators: result is a non-basic type (%s) but no 'prop_from_result' specified — storing object in context is dangerous!" % typeof(result))
		return _context

	var extracted = result.get(prop_from_result)
	if extracted == null:
		Logging.err("ContextFetchOperators: property '%s' not found on result object (type: %s)" % [prop_from_result, typeof(result)])
		return _context

	# ── URN 拼装：如果设置了 urn_prefix，把 bare ID 包装成完整 URN ──
	if not urn_prefix.is_empty() and extracted is String:
		var urn = "urn:%s:%s" % [urn_prefix, extracted]
		_context[key_stored_context] = urn
		Logging.info("ContextFetchOperators: stored URN '%s' (from property '%s' with prefix '%s') into context[%s]" % [urn, prop_from_result, urn_prefix, key_stored_context])
	else:
		_context[key_stored_context] = extracted
		Logging.info("ContextFetchOperators: stored property '%s' (value: %s) into context[%s]" % [prop_from_result, str(extracted), key_stored_context])
	return _context


func operate():
	# init 阶段已完成所有工作，operate 阶段无需额外操作
	pass
