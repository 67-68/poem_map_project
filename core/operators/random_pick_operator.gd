@tool
class_name RandomPickOperator extends BaseOperator

## 数据源名称，对应 Database 上的一个 Dictionary 属性
## 例如 "feihualing_imageries"
@export var datasource_name: String = ""

## 从每个结果对象中提取的字段名
## 例如 ImaginaryConcept 取 "uuid"
@export var prop_from_result: String = ""

## 选取结果存入 Context 的 Key（类型为 Array[String]）
@export var key_stored_context: String = ""

## 随机选取数量
@export var select_count: int = 4


func init(_context: Dictionary) -> Dictionary:
	# ── 校验 ──
	if datasource_name.is_empty():
		Logging.err("RandomPickOperator.init: datasource_name is empty")
		return _context

	if key_stored_context.is_empty():
		Logging.err("RandomPickOperator.init: key_stored_context is empty")
		return _context

	if select_count <= 0:
		Logging.warn("RandomPickOperator.init: select_count=%d <= 0, nothing to pick" % select_count)
		_context[key_stored_context] = []
		return _context

	# ── 获取数据源 ──
	var database = Database.get(datasource_name)
	if database == null:
		Logging.err("RandomPickOperator.init: datasource '%s' not found in Database" % datasource_name)
		return _context

	if not (database is Dictionary):
		Logging.err("RandomPickOperator.init: datasource '%s' is not a Dictionary (got %s)" % [datasource_name, typeof(database)])
		return _context

	# ── 随机选取 ──
	var all_values: Array = database.values()
	if all_values.is_empty():
		Logging.warn("RandomPickOperator.init: datasource '%s' is empty, nothing to pick" % datasource_name)
		_context[key_stored_context] = []
		return _context

	all_values.shuffle()
	var pick_count = mini(select_count, all_values.size())
	var selected = all_values.slice(0, pick_count)

	Logging.info("RandomPickOperator.init: randomly picked %d/%d items from '%s'" % [pick_count, all_values.size(), datasource_name])

	# ── 提取字段 ──
	var extracted_ids: Array[String] = []
	for item in selected:
		if item == null:
			Logging.warn("RandomPickOperator.init: null item in selection, skipping")
			continue

		var extracted = item.get(prop_from_result) if not prop_from_result.is_empty() else item
		if extracted == null:
			Logging.warn("RandomPickOperator.init: item has no property '%s', skipping" % prop_from_result)
			continue

		extracted_ids.append(str(extracted))
		Logging.debug("RandomPickOperator.init: picked [%s] -> %s" % [prop_from_result, str(extracted)])

	if extracted_ids.is_empty():
		Logging.warn("RandomPickOperator.init: no valid items extracted from selection")
		_context[key_stored_context] = []
		return _context

	_context[key_stored_context] = extracted_ids
	Logging.info("RandomPickOperator.init: stored %d picked IDs into context[%s]" % [extracted_ids.size(), key_stored_context])
	return _context


func operate() -> void:
	"""所有逻辑在 init() 中完成"""
	pass
