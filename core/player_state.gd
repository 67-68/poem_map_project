extends Node
const _AmbitionData = preload("res://core/model/ambition_config.gd")
const _BaseOperator = preload("res://core/model/base_operator.gd")
const _DeferredLockActionOperator = preload("res://core/operators/deferred_lock_action_operator.gd")
const _FatigueManager = preload("res://core/fatigue_manager.gd")
const _Flag = preload("res://core/model/flag.gd")
const _ImaginaryConcept = preload("res://core/model/imaginary_concept.gd")
const _RelationFlagManager = preload("res://core/relation_flag_manager.gd")
const _SourceOfTruth = preload("res://core/source_of_truth.gd")
const _TempFlagOperator = preload("res://core/operators/temp_flag_operator.gd")
const _TierDeterminer = preload("res://core/tier_determiner.gd")
const _TimeOperator = preload("res://core/model/time_operator.gd")

@export var player_name: String = "杜甫"
@export var traits: Array[String] = [] # trait key string
@export var current_location: String = 'yong_zhou':
	set(val):
		current_location = val
		location_changed.emit(val)
	 	# 省份uuid
@export var ambition: AmbitionData
## 野心被激活时的累计总天数（用于计算剩余旬数）。-1 = 未激活。
var _ambition_start_total_days: int = -1
@export var current_action_tags: Array[String] = []
@export var created_poems: Array  ## 存储 Poem 对象，供墓碑等终局结算使用
var emotions: Dictionary = {}
var flags: Dictionary = {}  # flag_id -> value (str/int/bool)

## 🆕 重复行动疲惫系统：记录上一个被执行完成的 action 的 tag 集合
## 用于在下次执行同类型 action 时施加 20% 效益惩罚。
@export var last_action_tags: Array[String] = []

## 🆕 瞬态快照：当前正在执行的 action 是否与上次重复。
## 在 operators 执行前由 action_button 设置，PropertyOperator 读取。
## 仅在单次 operate 生命周期内有效。
var _is_repeated_action: bool = false

## 当前正在处理的事件上下文
## 由事件处理管道在处理事件前设置，包含 target_tag 等社交上下文信息。
## RelationFlagManager 的 favor 倍率系统依赖此字段判断社交目标。
var last_event: Dictionary = {}

# 存活于整个"玩法会话"（如整场宴会）的析构队列
# TempFlagOperator 会在这里注册反向清理算子
var session_deferred_cleanups: Array[BaseOperator] = []

## Imaginary 定义表，从 tools/data/imaginary_definitions.json 加载
## key: uuid (如 "snow"), value: Dictionary(name, concepts)
var _imaginary_defs: Dictionary = {}

signal ambition_changed(ambition)
signal player_stat_changed(prop_name)
signal location_changed(location)
signal emotion_changed(stat_name)

## 情绪即将变更时的信号钩子
## FatigueManager 监听此信号，根据疲劳值对情绪变化量施加疲劳倍率。
signal before_emotion_change(emo_name: String, delta: int)

## 属性即将变更时的信号钩子
## 在 append_stat() 中 trait 倍率计算之后、实际写入 stat.val 之前发射。
## RelationFlagManager 监听此信号，根据好感度对属性变化量施加社交倍率。
signal before_property_change(prop_name: String, delta: int)

## 🆕 重复行动疲惫系统：检查给定 tag 集合是否与 last_action_tags 有交集。
## 纯函数，无副作用 — 供 ActionHintBuilder (hover preview) 和 action_button (执行前快照) 共用。
## @param tags: 当前 action 的 tag 列表（SceneAction 用 [main_tag]，普通 Action 用 action_tags）
## @return true 表示当前 action 与上次执行的 action 类型相同
func is_action_repeated(tags: Array[String]) -> bool:
	if last_action_tags.is_empty() or tags.is_empty():
		return false
	for tag in tags:
		if tag in last_action_tags:
			Logging.info("PlayerState.is_action_repeated: tag '%s' 命中 last_action_tags=%s → 重复行动" % [tag, str(last_action_tags)])
			return true
	Logging.info("PlayerState.is_action_repeated: tags=%s 与 last_action_tags=%s 无交集 → 非重复" % [str(tags), str(last_action_tags)])
	return false

var _init_props_retry_count: int = 0
const MAX_INIT_PROPS_RETRY: int = 5

func init_props():
	var resources = SourceOfTruth.debug_dashboard_state.resources
	append_stat(ENUMS.PROPS.MONEY, resources.money)
	append_stat(ENUMS.PROPS.HEALTH, resources.health)
	append_stat(ENUMS.PROPS.LITERARY_FAME, resources.literary_fame)
	append_stat(ENUMS.PROPS.TALENT, resources.talent)
	append_stat(ENUMS.PROPS.PROGRESS, resources.progress)
	if not append_stat(ENUMS.PROPS.TIME, 10):
		breakpoint
		Logging.warn('init_props: TIME stat not found in Database, will retry via call_deferred')
		_init_props_retry_count = 0
		call_deferred("_retry_init_time")

func _retry_init_time():
	_init_props_retry_count += 1
	if _init_props_retry_count > MAX_INIT_PROPS_RETRY:
		Logging.err('_retry_init_time: exceeded max retry count %d, giving up' % MAX_INIT_PROPS_RETRY)
		return
	if append_stat(ENUMS.PROPS.TIME, 10):
		Logging.info('_retry_init_time: TIME stat initialized successfully on retry %d' % _init_props_retry_count)
	else:
		Logging.warn('_retry_init_time: TIME stat still not found, retry %d/%d' % [_init_props_retry_count, MAX_INIT_PROPS_RETRY])
		call_deferred("_retry_init_time")

func init_traits():
	var action_tracks = SourceOfTruth.debug_dashboard_state.action_tracks
	for track_name in action_tracks:
		var trait_uuid = action_tracks[track_name]
		add_trait(trait_uuid)

func init_flags():
	"""从 SourceOfTruth 加载初始 flag 到 PlayerState"""
	var flag_data = SourceOfTruth.debug_dashboard_state.flags
	for flag_id in flag_data:
		var flag_val = flag_data[flag_id]
		set_flag(flag_id, flag_val)
		Logging.info('init_flags: flag %s set to %s from SourceOfTruth' % [flag_id, str(flag_val)])

func init_imaginaries():
	"""从 SourceOfTruth 加载 Imaginary 详细碎片到 Database (V6: level 系统已删除)"""
	# —— 加载详细碎片（Imaginary） ——
	var basic_data = SourceOfTruth.debug_dashboard_state.get("basic_imaginaries", [])
	if basic_data.is_empty():
		Logging.info('init_imaginaries: no basic_imaginaries data in SourceOfTruth, skipping')
		return

	for entry in basic_data:
		var name = entry.get("name", "") as String
		if name.is_empty():
			Logging.warn('init_imaginaries: basic_imaginaries entry missing name, skipping')
			continue
		var raw_concepts = entry.get("concepts", [])
		var concepts_arr: Array[String] = []
		for c in raw_concepts:
			concepts_arr.append(str(c))

		var imaginary_uuid = name.to_lower()
		var imaginary = Database.get_imaginary_detail(imaginary_uuid)
		if not imaginary:
			imaginary = Imaginary.new()
			imaginary.uuid = imaginary_uuid
			imaginary.name = name
			imaginary.concepts = concepts_arr
			Database.imaginaries_detail[imaginary_uuid] = imaginary
			Logging.info("init_imaginaries: 新建 Imaginary '%s' (concepts=%s)" % [imaginary_uuid, str(concepts_arr)])

func init_emotions():
	"""从 SourceOfTruth 加载初始情绪值到 PlayerState"""
	var emotion_data = SourceOfTruth.debug_dashboard_state.get("emotions", {})
	if emotion_data.is_empty():
		Logging.info('init_emotions: no emotion data in SourceOfTruth, skipping')
		return

	for emo_name in emotion_data:
		var emo_val = emotion_data[emo_name] as int
		set_emotion(emo_name, emo_val)
		Logging.info('init_emotions: set %s to %d from SourceOfTruth' % [emo_name, emo_val])

func _ready():
	init_emotions()
	init_props()
	init_traits()
	init_flags()
	init_imaginaries()
	_load_imaginary_definitions()
	_connect_imaginary_signals()
	
	current_location = 'yong_zhou'


# ─── 意象获取信号处理 ─────────────────────────────────────────

func _load_imaginary_definitions():
	"""从 tools/data/imaginary_definitions.json 加载意象定义表"""
	var file = FileAccess.open("res://tools/data/imaginary_definitions.json", FileAccess.READ)
	if not file:
		Logging.warn("PlayerState._load_imaginary_definitions: 无法打开 imaginary_definitions.json，将使用降级行为")
		return
	var content = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		Logging.warn("PlayerState._load_imaginary_definitions: JSON 解析失败，将使用降级行为")
		return
	_imaginary_defs = parsed
	Logging.info("PlayerState._load_imaginary_definitions: 成功加载 %d 条意象定义" % _imaginary_defs.size())

func _connect_imaginary_signals():
	"""连接 EventBus.request_add_imaginary 信号"""
	EventBus.request_add_imaginary.connect(_on_request_add_imaginary)
	Logging.info("PlayerState: connected request_add_imaginary signal")


func _on_request_add_imaginary(tag: String):
	"""处理意象获取请求：V6 重复 Imaginary → talent +3"""
	if tag.is_empty():
		Logging.err("PlayerState._on_request_add_imaginary: tag 为空")
		return

	var imaginary_uuid = tag.to_lower()

	# ── 重复检测：已有该 Imaginary → 转 talent ──
	if Database.imaginaries_detail.has(imaginary_uuid):
		append_stat("talent", 3)
		Logging.info("PlayerState._on_request_add_imaginary: 重复 Imaginary '%s' → talent +3" % imaginary_uuid)
		EventBus.imaginary_changed.emit()
		return

	# ── 新建 Imaginary（详细碎片） ──
	var imaginary = Imaginary.new()
	imaginary.uuid = imaginary_uuid
	var def_data = _imaginary_defs.get(imaginary_uuid, {})
	imaginary.name = def_data.get("name", tag)
	var raw_concepts = def_data.get("concepts", [])
	var concepts_arr: Array[String] = []
	for c in raw_concepts:
		concepts_arr.append(str(c))
	imaginary.concepts = concepts_arr
	Database.imaginaries_detail[imaginary_uuid] = imaginary
	Logging.info("PlayerState._on_request_add_imaginary: 新建 Imaginary '%s' (name=%s, concepts=%s)" % [imaginary_uuid, imaginary.name, str(concepts_arr)])

	# 通知 UI 更新
	EventBus.imaginary_changed.emit()

func append_stat(stat_name, data) -> bool:
	if stat_name is int:
		var int_stat = ENUMS.to_prop_str(stat_name)
		if not int_stat:
			breakpoint
			Logging.err('do not find stat %s' % stat_name)
			return false
		stat_name = int_stat
	
	# _time → time 映射：外部只能通过 TimeOperator 操作 _`
	if stat_name == "_time":
		stat_name = "time"

	var stat = Database.get_property(stat_name)
	# 需要提前登记stat
	if not stat:
		Logging.err('do not find stat %s' % stat_name)
		return false

	var amount_to_change = data

	for t_name in traits:
		var t = Database.get_trait(t_name)
		if not t:
			Logging.warn('do not find trait %s in Database, skipping buffer calc' % t_name)
			continue
		if t.buffer_to_prop and t.buffer_to_prop.has_operator(stat_name):
			amount_to_change = t.buffer_to_prop.match_and_multiply(stat_name, amount_to_change)
		if t.buffer_to_region and t.buffer_to_region.has_operator(current_location):
			amount_to_change = t.buffer_to_region.match_and_multiply(current_location, amount_to_change)

	# ── 信号钩子：RelationFlagManager 在此根据好感度修正倍率 ──
	before_property_change.emit(stat_name, amount_to_change)
	var favor_multiplier = RelationFlagManager.get_and_reset_favor_multiplier()
	if favor_multiplier != 1.0:
		amount_to_change = int(amount_to_change * favor_multiplier)
		Logging.info("change stat %s: favor multiplier applied (*%.2f) → %d" % [stat_name, favor_multiplier, amount_to_change])

	# ── 信号钩子：FatigueManager 在此根据疲劳值修正倍率 ──
	var fatigue_multiplier = FatigueManager.get_and_reset_fatigue_multiplier()
	if fatigue_multiplier != 1.0:
		amount_to_change = int(amount_to_change * fatigue_multiplier)
		Logging.info("change stat %s: fatigue multiplier applied (*%.2f) → %d" % [stat_name, fatigue_multiplier, amount_to_change])

	Logging.info('change stat %s by %d' % [stat_name, amount_to_change])
	var new_val: int = stat.val + amount_to_change
	stat.set_val(new_val)
	player_stat_changed.emit(stat_name)

	if stat_name == "time" and new_val == 0:
		TimeService.advance_time(1)

	return true

func get_stat_val(stat_name):
	if stat_name is int:
		var int_stat = ENUMS.to_prop_str(stat_name)
		if not int_stat:
			Logging.err('do not find stat %s' % stat_name)
			return
		stat_name = int_stat
	
	var stat = Database.get_property(stat_name)
	if not stat:
		# ── 转接器：emotion 兼容（ambition 等非 stat 资源） ──
		if emotions.has(stat_name):
			return emotions[stat_name]
		Logging.err('do not find stat %s' % stat_name)
		return 0
	return stat.val

func set_stat_val(stat_name, data) -> bool:
	if stat_name is int:
		var int_stat = ENUMS.to_prop_str(stat_name)
		if not int_stat:
			Logging.err('do not find stat %s' % stat_name)
			return false
		stat_name = int_stat
	
	# _time → time 映射：外部只能通过 TimeOperator 操作 _time
	if stat_name == "_time":
		stat_name = "time"
	
	var stat = Database.get_property(stat_name)
	if not stat:
		Logging.err('do not find stat %s' % stat_name)
		return false
	
	stat.set_val(data)
	Logging.info('set stat %s to %d' % [stat_name, data])
	player_stat_changed.emit(stat_name)
	return true

func force_set_stat_val(stat_name, data):
	"""强制设值，跳过 hard_max 检查（用于 debug / 特殊场景）"""
	if stat_name is int:
		var int_stat = ENUMS.to_prop_str(stat_name)
		if not int_stat:
			Logging.err('do not find stat %s' % stat_name)
			return
		stat_name = int_stat
	
	var stat = Database.get_property(stat_name)
	if not stat:
		Logging.err('do not find stat %s' % stat_name)
		return
	
	stat.force_set_val(data)
	Logging.info('force set stat %s to %d (bypassed hard_max)' % [stat_name, data])
	player_stat_changed.emit(stat_name)

func get_emotion(stat_name):
	if stat_name is int:
		var int_stat = ENUMS.to_prop_str(stat_name)
		if not int_stat:
			Logging.err('do not find stat %s' % stat_name)
			return
		stat_name = int_stat
	
	if not emotions.has(stat_name):
		return 0
	return emotions[stat_name]

func append_emotion(stat_name, data):
	if stat_name is int:
		var int_stat = ENUMS.to_prop_str(stat_name)
		if not int_stat:
			Logging.err('do not find stat %s' % stat_name)
			return
		stat_name = int_stat
	
	if not emotions.has(stat_name):
		emotions[stat_name] = 0
	
	# ── 信号钩子：FatigueManager 在此根据疲劳值修正情绪倍率 ──
	before_emotion_change.emit(stat_name, data)
	var emotion_multiplier = FatigueManager.get_and_reset_emotion_multiplier()
	if emotion_multiplier != 1.0:
		data = int(data * emotion_multiplier)
		Logging.info("change emotion %s: fatigue multiplier applied (*%.2f) → %d" % [stat_name, emotion_multiplier, data])
	
	emotions[stat_name] += data
	Logging.info('change volatile stat %s by %d, new value: %d' % [stat_name, data, emotions[stat_name]])
	emotion_changed.emit(stat_name)

func set_emotion(emo_name, data):
	if emo_name is int:
		var int_stat = ENUMS.to_prop_str(emo_name)
		if not int_stat:
			Logging.err('do not find stat %s' % emo_name)
			return
		emo_name = int_stat
	
	emotions[emo_name] = data
	Logging.info('set volatile stat %s to %d' % [emo_name, data])
	emotion_changed.emit(emo_name)
	

func clear_emotion():
	# 清空volatile_stats
	emotions.clear()

func add_trait(trait_name):
	if trait_name is int:
		var int_trait = ENUMS.to_traits_str(trait_name)
		if not int_trait:
			Logging.err('do not find trait %s' % trait_name)
			return
		trait_name = int_trait

	if not traits.has(trait_name): traits.append(trait_name)
	EventBus.on_trait_change.emit()


func has_trait(trait_name):
	if trait_name is int:
		var int_trait = ENUMS.to_traits_str(trait_name)
		if not int_trait:
			# breakpoint
			Logging.err('do not find trait %s' % trait_name)
			return
		trait_name = int_trait
	return traits.has(trait_name)

func remove_trait(trait_name):
	if trait_name is int:
		var int_trait = ENUMS.to_traits_str(trait_name)
		if not int_trait:
			# breakpoint
			Logging.err('do not find trait %s' % trait_name)
			return
		trait_name = int_trait
	
	if traits.has(trait_name):
		traits.erase(trait_name)
	EventBus.on_trait_change.emit()

func get_traits():
	return traits

# ─── Flag ────────────────────────────────────────────────────────────
func _validate_flag_type(flag_id: String) -> String:
	"""根据 Database.flags 定义校验 flag 的类型，返回 'str'/'int'/'bool' 或空字符串"""
	var flag_def = Database.get_flag(flag_id)
	if not flag_def:
		Logging.err('flag %s not found in Database.flags' % flag_id)
		return ''
	if flag_def.type.is_empty():
		Logging.err('flag %s has no type defined' % flag_id)
		return ''
	return flag_def.type

## 注册一个虚拟 flag 到 Database.flags（运行时内存态，不持久化到 tres）。
## 用于 DeferredLockActionOperator 等需要在运行时动态创建计数器 flag 的场景。
## 如果 flag_id 已存在（可能是正式注册的 flag），不覆盖。
func register_virtual_flag(flag_id: String, type: String) -> void:
	if flag_id.is_empty():
		Logging.err("[PlayerState] register_virtual_flag: flag_id 为空")
		return
	if type not in ['str', 'int', 'bool']:
		Logging.err("[PlayerState] register_virtual_flag: 未知类型 %s" % type)
		return
	if Database.get_flag(flag_id) != null:
		Logging.debug("[PlayerState] register_virtual_flag: flag %s 已存在，跳过" % flag_id)
		return
	var virtual_flag = Flag.new()
	virtual_flag.type = type
	virtual_flag.uuid = flag_id
	virtual_flag.name = flag_id
	Database.flags[flag_id] = virtual_flag
	Logging.info("[PlayerState] 注册虚拟 flag: %s (type=%s)" % [flag_id, type])


func set_flag(flag_id: String, value, type: String = ''):
	if type.is_empty():
		type = _validate_flag_type(flag_id)
		if type.is_empty():
			return
	elif type not in ['str', 'int', 'bool']:
		Logging.err('set_flag: unknown type %s for flag %s' % [type, flag_id])
		return

	match type:
		'str':
			var str_val = str(value)
			if str_val == '':
				flags.erase(flag_id)
				Logging.info('flag %s removed (empty string)' % flag_id)
			else:
				flags[flag_id] = str_val
				Logging.info('flag %s set to str: %s' % [flag_id, str_val])
		'int':
			var int_val = int(value)
			if int_val == 0:
				flags.erase(flag_id)
				Logging.info('flag %s removed (zero int)' % flag_id)
			else:
				flags[flag_id] = int_val
				Logging.info('flag %s set to int: %d' % [flag_id, int_val])
		'bool':
			var bool_str = str(value).to_lower()
			var bool_val = bool_str == 'true' or bool_str == 't' or bool_str == '1' or bool_str == 'yes'
			if not bool_val:
				flags.erase(flag_id)
				Logging.info('flag %s removed (false bool)' % flag_id)
			else:
				flags[flag_id] = bool_val
				Logging.info('flag %s set to bool: %s' % [flag_id, bool_val])
	EventBus.on_flag_change.emit()

func append_flag(flag_id: String, value):
	if not flags.has(flag_id):
		var flag_type = _validate_flag_type(flag_id)
		if flag_type.is_empty():
			return
		if flag_type != 'int':
			Logging.err('append_flag: flag %s is not int type, cannot append' % flag_id)
			return
		flags[flag_id] = 0
	elif typeof(flags[flag_id]) != TYPE_INT:
		Logging.err('append_flag: flag %s stored value is not int' % flag_id)
		return

	flags[flag_id] += int(value)
	var new_val = flags[flag_id]
	Logging.info('flag %s appended by %d, new value: %d' % [flag_id, int(value), new_val])
	if new_val == 0:
		flags.erase(flag_id)
		Logging.info('flag %s removed (zero int after append)' % flag_id)
	EventBus.on_flag_change.emit()

func get_flag(flag_id: String):
	if flags.has(flag_id):
		return flags[flag_id]
	return null

func has_flag(flag_id: String) -> bool:
	return flags.has(flag_id)

func remove_flag(flag_id: String):
	if flags.erase(flag_id):
		Logging.info('flag %s removed' % flag_id)
	EventBus.on_flag_change.emit()

func set_ambition(ambition_key):
	var ambition_ = Database.get_ambition(ambition_key)
	if not ambition_:
		Logging.err('this ambition %s is non-exist' % ambition_key)
		return
	if ambition:
		for t in ambition.ambition_traits:
			remove_trait(t)
	ambition = ambition_
	for t in ambition.ambition_traits:
		add_trait(t)
	# 同步写入 emotions 字典，让 get_stat_val() 的 emotion 适配器能找到它
	emotions["ambition"] = 1.0
	# 记录野心激活时的累计天数，用于计算剩余旬数
	_ambition_start_total_days = TimeService._total_days_elapsed
	Logging.info("PlayerState: ambition '%s' activated at total_days=%d, deadline_xun=%d" % [ambition.name, _ambition_start_total_days, ambition.deadline_xun])
	ambition_changed.emit(ambition)

func clear_ambition():
	if ambition:
		for t in ambition.ambition_traits:
			remove_trait(t)
	ambition = null
	emotions.erase("ambition")
	_ambition_start_total_days = -1
	ambition_changed.emit(null)

## 返回当前野心还剩余多少旬。无野心或未启用倒计时返回 -1。
func get_ambition_remaining_xun() -> int:
	if not ambition or ambition.deadline_xun <= 0:
		return -1
	if _ambition_start_total_days < 0:
		return -1
	var current_days: int = TimeService._total_days_elapsed
	var elapsed_xun: int = (current_days - _ambition_start_total_days) / 10
	var remaining := ambition.deadline_xun - elapsed_xun
	# 底限钳制：不返回负数（过期后外显逻辑自行处理）
	return maxi(remaining, 0)

func get_location():
	var loc = Database.get_territory(current_location)
	if loc == null:
		loc = Database.get_province(current_location)
	if not loc:
		Logging.err('do not find location %s' % current_location)
		return null
	return loc


# ═══════════════════════════════════════════════════════
# 临时标志位清理系统
# ═══════════════════════════════════════════════════════

## 注册一个反向清理算子到会话级析构队列
## TempFlagOperator.operate() 内部会自动调用此方法
func defer_cleanup(cleanup_operator: BaseOperator):
	session_deferred_cleanups.append(cleanup_operator)
	Logging.info('defer_cleanup: registered cleanup for flag "%s"' % cleanup_operator.flag_id)


## 逆序执行所有已注册的清理算子（LIFO），然后清空队列
## 应在会话/场景切换时调用（如宴会结束、大规模场景切换）
func flush_cleanups():
	var count = session_deferred_cleanups.size()
	if count == 0:
		return

	Logging.info('flush_cleanups: executing %d deferred cleanups (LIFO order)' % count)

	# 逆序执行，后污染的先清理，保证状态回滚的安全
	for i in range(count - 1, -1, -1):
		var op = session_deferred_cleanups[i] as BaseOperator
		if op:
			op.operate()
		else:
			Logging.warn('flush_cleanups: null operator at index %d, skipping' % i)

	session_deferred_cleanups.clear()
	Logging.info('flush_cleanups: all cleanups executed, queue cleared')
