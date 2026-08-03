extends Node
## NoteManager — 笔记触发中枢 Autoload
##
## 职责：
##   1. 加载 Database.notes 中的全部 Note
##   2. 建立 _notes_by_prop 索引（PropertyRequirement 剪枝）
##   3. 监听属性/Flag/Trait 变化信号，匹配 Note.requirement
##   4. 触发时更新 Note.triggered + GameSave + 发射信号
##
## Autoload 顺序：在 Database 之后注册

# ═══════════════════════════════════════════════════════════
# 状态
# ═══════════════════════════════════════════════════════════

## 所有 Note：{ uuid: Note }
var _all_notes: Dictionary = {}

## Property 索引：{ prop_name: [Note, ...] }
## 仅在 Note.requirement is PropertyRequirement 时入索引
var _notes_by_prop: Dictionary = {}

## 其他 Requirement 类型的笔记（Flag / Trait 等），全量遍历
var _other_notes: Array[Note] = []

## StackSize 触发型笔记（trigger_on_stack_queue_threshold > 0）
## 不走 Property/Flag/Trait 钩子，由 stack_queue_total_changed 信号驱动
var _stack_queue_notes: Array[Note] = []

# ═══════════════════════════════════════════════════════════
# 生命周期
# ═══════════════════════════════════════════════════════════

func _ready() -> void:
	Logging.info("[NoteManager] _ready 开始")
	_load_and_index()
	_register_hooks()
	Logging.info("[NoteManager] _ready 完成 — 共 %d 条笔记，%d 条属性索引，%d 条其他" % [
		_all_notes.size(), _notes_by_prop.size(), _other_notes.size()
	])


func _load_and_index() -> void:
	_all_notes = Database.notes.duplicate()
	_notes_by_prop.clear()
	_other_notes.clear()
	_stack_queue_notes.clear()

	for uuid in _all_notes:
		var note: Note = _all_notes[uuid] as Note
		if note == null:
			continue

		# StackSize 触发型优先分流
		if note.trigger_on_stack_queue_threshold > 0:
			_stack_queue_notes.append(note)
			Logging.info("[NoteManager] StackSize 触发型 Note: uuid=%s, threshold=%d" % [note.uuid, note.trigger_on_stack_queue_threshold])
		# 判断 requirement 类型
		elif note.requirement != null and note.requirement is PropertyRequirement:
			var prop_req: PropertyRequirement = note.requirement as PropertyRequirement
			var prop_name: String = prop_req.property
			if prop_name.is_empty():
				Logging.warn("[NoteManager] Note '%s' 的 PropertyRequirement 属性名为空" % note.uuid)
				_other_notes.append(note)
				continue
			if not _notes_by_prop.has(prop_name):
				_notes_by_prop[prop_name] = []
			_notes_by_prop[prop_name].append(note)
		else:
			_other_notes.append(note)


func _register_hooks() -> void:
	# Property 变化钩子
	if not PlayerState.player_stat_changed.is_connected(_on_prop_changed):
		PlayerState.player_stat_changed.connect(_on_prop_changed)

	# Flag 变化钩子
	if not EventBus.on_flag_change.is_connected(_on_flag_changed):
		EventBus.on_flag_change.connect(_on_flag_changed)

	# Trait 变化钩子
	if not EventBus.on_trait_change.is_connected(_on_trait_changed):
		EventBus.on_trait_change.connect(_on_trait_changed)

	# Stack/Queue 变更钩子
	if not EventBus.stack_queue_total_changed.is_connected(_on_stack_queue_changed):
		EventBus.stack_queue_total_changed.connect(_on_stack_queue_changed)


# ═══════════════════════════════════════════════════════════
# 信号处理器
# ═══════════════════════════════════════════════════════════

func _is_triggered(note: Note) -> bool:
	return GameSave.data.triggered_note_uuids.has(note.uuid)


func _on_prop_changed(prop_name: String) -> void:
	var candidates: Array = _notes_by_prop.get(prop_name, [])
	if candidates.is_empty():
		return

	for note: Note in candidates:
		if _is_triggered(note):
			continue
		if _check_requirement(note):
			_do_trigger(note)


func _on_flag_changed() -> void:
	for note: Note in _other_notes:
		if _is_triggered(note):
			continue
		if note.requirement == null:
			continue
		if note.requirement is FlagRequirement or note.requirement is TraitRequirement:
			if _check_requirement(note):
				_do_trigger(note)


func _on_trait_changed() -> void:
	for note: Note in _other_notes:
		if _is_triggered(note):
			continue
		if note.requirement == null:
			continue
		if note.requirement is TraitRequirement:
			if _check_requirement(note):
				_do_trigger(note)


## Stack/Queue 总条目数变更时检查 StackSize 触发型 Note
func _on_stack_queue_changed(total: int) -> void:
	for note: Note in _stack_queue_notes:
		if _is_triggered(note):
			continue
		if total >= note.trigger_on_stack_queue_threshold:
			Logging.info("[NoteManager] StackSize 触发! uuid=%s, total=%d, threshold=%d" % [note.uuid, total, note.trigger_on_stack_queue_threshold])
			_do_trigger(note)


# ═══════════════════════════════════════════════════════════
# 判定与触发
# ═══════════════════════════════════════════════════════════

func _check_requirement(note: Note) -> bool:
	if note.requirement == null:
		# 无 requirement 视为无条件触发
		return true
	return note.requirement.compare(PlayerState)


func _do_trigger(note: Note) -> void:
	note.triggered = true

	# 持久化
	if not GameSave.data.triggered_note_uuids.has(note.uuid):
		GameSave.data.triggered_note_uuids.append(note.uuid)

	Logging.info("[NoteManager] 笔记触发: uuid=%s, name='%s'" % [note.uuid, note.name])

	# 发射信号 — RightInfoPanel 监听此信号显示 SpecialLabel
	EventBus.note_triggered.emit(note.uuid)


# ═══════════════════════════════════════════════════════════
# 公开 API
# ═══════════════════════════════════════════════════════════

## 获取所有已触发的 Note（按触发顺序）
func get_triggered_notes() -> Array[Note]:
	var result: Array[Note] = []
	var triggered_uuids: Array[String] = GameSave.data.triggered_note_uuids
	for uuid in triggered_uuids:
		var note: Note = _all_notes.get(uuid) as Note
		if note != null:
			result.append(note)
	return result


## 获取已触发笔记数量
func get_triggered_count() -> int:
	return GameSave.data.triggered_note_uuids.size()


## 获取所有笔记的总数
func get_total_count() -> int:
	return _all_notes.size()


## 按 uuid 获取 Note
func get_note(uuid: String) -> Note:
	return _all_notes.get(uuid) as Note
