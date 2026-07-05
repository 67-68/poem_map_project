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
##   1. 检查重复（已有该 Imaginary → talent +3）
##   2. 否则创建 Imaginary(level=level) 写入 Database.imaginaries_detail
##   3. 发射 EventBus.imaginary_changed 通知 UI 刷新

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


func operate():
	Logging.info("RollImaginaryOperator.operate: 开始执行，picked_uuid='%s', level=%d" % [_picked_uuid, level])

	if _picked_uuid.is_empty():
		Logging.err("RollImaginaryOperator.operate: _picked_uuid 为空，检查 init() 是否被正确调用")
		return

	# ── 重复检测：已有该 Imaginary → talent +3 ──
	if Database.imaginaries_detail.has(_picked_uuid):
		var player = _get_player_state()
		if player:
			player.append_stat("talent", 3)
		Logging.info("RollImaginaryOperator.operate: 重复 Imaginary '%s' → talent +3" % _picked_uuid)
		EventBus.imaginary_changed.emit()
		return

	# ── 新建 Imaginary ──
	var imaginary := Imaginary.new()
	imaginary.uuid = _picked_uuid

	# 从定义表加载 name
	var defs := _load_imaginary_defs()
	var def_data: Dictionary = defs.get(_picked_uuid, {})
	imaginary.name = str(def_data.get("name", _picked_uuid))
	imaginary.level = level
	imaginary.get_hint = _picked_hint
	imaginary.created_at_day = TimeService._total_days_elapsed

	Database.imaginaries_detail[_picked_uuid] = imaginary
	Logging.info("RollImaginaryOperator.operate: 新建 Imaginary '%s' (name=%s, level=%d, created_at_day=%d)" % [_picked_uuid, imaginary.name, imaginary.level, imaginary.created_at_day])

	# 通知 UI 更新
	EventBus.imaginary_changed.emit()


## 懒加载 + 缓存：每次调用都重新加载（确保拿到最新数据）
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
		var root := tree.root
		if root:
			return root.get_node_or_null("Game/PlayerState")
	return null
