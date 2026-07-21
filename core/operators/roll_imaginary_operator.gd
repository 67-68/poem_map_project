@tool
class_name RollImaginaryOperator extends BaseOperator
## 随机意象获取操作符 — 由 roll_imaginary DSL 解析生成。
##
## DSL 语法: roll_imaginary(level=2)
##
## init(context) 阶段:
##   1. 从 tools/data/imaginary_definitions.json 加载并过滤对应 level 的意象
##   2. 随机选一个，将其 get_hint 写入 context["imaginary_gain_hint"]
##
## operate() 阶段:
##   1. 检查 uuid 冲突：已有该 Imaginary → uuid 添加数字后缀（snow → snow1）
##   2. 创建 Imaginary(level=level, duration_xun=2) 写入 Database.imaginaries_detail
##   3. Lv2 注入 trait_effect_operations: health -5
##   4. 发射 EventBus.imaginary_changed 通知 UI 刷新

## 目标意象等级（1/2/3）
@export var level: int = 1

## init 阶段选中的意象 uuid
var _picked_uuid: String = ""

## init 阶段选中的 get_hint 文本
var _picked_hint: String = ""


func init(_context: Dictionary) -> Dictionary:
	if not _picked_uuid.is_empty():
		Logging.info("RollImaginaryOperator.init: 已初始化 uuid='%s'，跳过重新选取" % _picked_uuid)
		return _context
	Logging.info("RollImaginaryOperator.init: 开始随机选取 level=%d 的意象" % level)

	# ── 1. 加载意象定义表 ──
	var defs := _load_imaginary_defs()
	if defs.is_empty():
		Logging.err("RollImaginaryOperator.init: imaginary_definitions.json 为空或加载失败")
		return _context

	# ── 2. 过滤对应 level 的条目 ──
	var candidates: Array[Dictionary] = []
	for uuid in defs:
		var entry: Dictionary = defs[uuid]
		var entry_level = entry.get("level", 1)
		if entry_level == level:
			candidates.append({
				"uuid": uuid,
				"name": entry.get("name", uuid),
				"get_hint": entry.get("get_hint", ""),
			})

	if candidates.is_empty():
		Logging.warn("RollImaginaryOperator.init: 没有 level=%d 的意象，跳过" % level)
		return _context

	Logging.info("RollImaginaryOperator.init: 找到 %d 个 level=%d 的候选意象" % [candidates.size(), level])

	# ── 3. 随机选一个 ──
	candidates.shuffle()
	var picked: Dictionary = candidates[0]
	_picked_uuid = str(picked.get("uuid", ""))
	_picked_hint = str(picked.get("get_hint", ""))

	Logging.info("RollImaginaryOperator.init: 选中意象 '%s' (name=%s), hint='%s'" % [_picked_uuid, picked.get("name", ""), _picked_hint])

	# ── 4. 写入 context ──
	if not _picked_hint.is_empty():
		_context["imaginary_gain_hint"] = _picked_hint
		Logging.info("RollImaginaryOperator.init: context[imaginary_gain_hint] = '%s'" % _picked_hint)
	else:
		Logging.warn("RollImaginaryOperator.init: 选中意象 '%s' 的 get_hint 为空" % _picked_uuid)

	return _context


## describe_preview() — 供 ActionHintBuilder 多态调用，显示在 hover 预览的「结果」区
func describe_preview() -> String:
	if level <= 0:
		return tr("CODE_ROLL_IMAGINARY_OPERATOR_F52969836C")
	return tr("CODE_ROLL_IMAGINARY_OPERATOR_5E10AC6407") % level


func operate():
	Logging.info("RollImaginaryOperator.operate: 开始执行，picked_uuid='%s', level=%d" % [_picked_uuid, level])

	if _picked_uuid.is_empty():
		Logging.err("RollImaginaryOperator.operate: _picked_uuid 为空，检查 init() 是否被正确调用")
		return

	# ── 解析最终 uuid：已有该 Imaginary → 数字后缀化 ──
	var final_uuid := _picked_uuid
	if Database.imaginaries_detail.has(_picked_uuid):
		var counter := 1
		while Database.imaginaries_detail.has(_picked_uuid + str(counter)):
			counter += 1
		final_uuid = _picked_uuid + str(counter)
		Logging.info("RollImaginaryOperator.operate: 重复 Imaginary '%s' → 创建副本 uuid='%s'" % [_picked_uuid, final_uuid])

	# ── 新建 Imaginary ──
	var imaginary := Imaginary.new()
	imaginary.uuid = final_uuid

	# 从定义表加载 name（基于基础 uuid，无后缀）
	var defs := _load_imaginary_defs()
	var def_data: Dictionary = defs.get(_picked_uuid, {})
	imaginary.name = str(def_data.get("name", _picked_uuid))
	imaginary.level = level
	imaginary.get_hint = _picked_hint
	imaginary.duration_xun = 5  # V11: 所有等级统一 5 旬后到期删除
	imaginary.imaginary_type = str(def_data.get("type", ""))
	imaginary.created_at_day = TimeService._total_days_elapsed

	# 🆕 Lv2: 持有期每旬 -5 健康（走 trait_effect_operations）
	if level == 2:
		var hp_op := PropertyOperator.new()
		hp_op.property = "health"
		hp_op.value = -5
		imaginary.trait_effect_operations.append(hp_op)
		Logging.info("RollImaginaryOperator.operate: Lv2 Imaginary '%s' → trait_effect_operations: health -5" % final_uuid)

	Database.imaginaries_detail[final_uuid] = imaginary
	Logging.info("RollImaginaryOperator.operate: 新建 Imaginary '%s' (base=%s, name=%s, level=%d, type=%s, duration_xun=5, created_at_day=%d)" % [final_uuid, _picked_uuid, imaginary.name, imaginary.level, imaginary.imaginary_type, imaginary.created_at_day])

	# V11: FIFO 顶替 — 超出上限时删除最老的 Imaginary
	_enforce_imaginary_limit()

	# 通知 UI 更新
	EventBus.imaginary_changed.emit()


## 懒加载 + 缓存：每次调用都重新加载（确保拿到最新数据）


## V11: FIFO 顶替 — 超出 max_imaginary_managable 时删除最老的 Imaginary
func _enforce_imaginary_limit() -> void:
	var ps = _get_player_state()
	if not ps:
		Logging.err("RollImaginaryOperator._enforce_imaginary_limit: 无法获取 PlayerState，跳过 FIFO")
		return
	var limit: int = ps.max_imaginary_managable
	if Database.imaginaries_detail.size() <= limit:
		return

	var oldest_uuid: String = ""
	var oldest_day: int = 0x7FFFFFFF
	for uuid in Database.imaginaries_detail:
		var imag = Database.imaginaries_detail[uuid]
		if not imag is Imaginary:
			continue
		if imag.created_at_day < oldest_day:
			oldest_day = imag.created_at_day
			oldest_uuid = uuid
		elif imag.created_at_day == oldest_day and oldest_uuid.is_empty():
			oldest_uuid = uuid

	if not oldest_uuid.is_empty():
		var imag = Database.imaginaries_detail[oldest_uuid]
		Logging.info("RollImaginaryOperator._enforce_imaginary_limit: FIFO 顶替 — 删除最旧 Imaginary '%s' (type=%s, created_at_day=%d)" % [oldest_uuid, imag.imaginary_type if imag is Imaginary else "?", oldest_day])
		Database.imaginaries_detail.erase(oldest_uuid)
	else:
		Logging.err("RollImaginaryOperator._enforce_imaginary_limit: 无法找到最旧的 Imaginary")
static var _cached_defs: Dictionary = {}
static var _cached: bool = false

static func _load_imaginary_defs() -> Dictionary:
	if _cached:
		return _cached_defs

	var file := FileAccess.open("res://tools/data/imaginary_definitions.json", FileAccess.READ)
	if not file:
		Logging.err("RollImaginaryOperator._load_imaginary_defs: 无法打开 imaginary_definitions.json")
		return {}

	var content := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(content)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		Logging.err("RollImaginaryOperator._load_imaginary_defs: JSON 解析失败")
		return {}

	_cached_defs = parsed
	_cached = true
	Logging.info("RollImaginaryOperator._load_imaginary_defs: 成功加载 %d 条意象定义" % _cached_defs.size())
	return _cached_defs


static func _get_player_state():
	## 获取 PlayerState 实例
	var tree := Engine.get_main_loop()
	if tree and tree is SceneTree:
		var root = tree.root
		if root:
			return root.get_node_or_null("Game/PlayerState")
	return null
