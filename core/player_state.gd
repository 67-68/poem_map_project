extends Node
## PlayerState — 玩家可变状态的门面 (Façade)
## 所有持久化数据存储已迁移至 GameSave.data，本文件仅作为 API 兼容层
## 和信号发射器存在。SourceOfTruth 仅用于 _ready() 时的初始值注入。
const _AmbitionData = preload("res://core/model/ambition_config.gd")
const _BaseOperator = preload("res://core/model/base_operator.gd")
const _DeferredLockActionOperator = preload("res://core/operators/deferred_lock_action_operator.gd")
const _FatigueManager = preload("res://core/fatigue_manager.gd")
const _Flag = preload("res://core/model/flag.gd")
const _RelationFlagManager = preload("res://core/relation_flag_manager.gd")
const _SourceOfTruth = preload("res://core/source_of_truth.gd")
const _TempFlagOperator = preload("res://core/operators/temp_flag_operator.gd")
const _TierDeterminer = preload("res://core/tier_determiner.gd")

## ── 以下 @export var 均通过 getter/setter 代理到 GameSave.data ──

@export var player_name: String = "杜甫":
	get: return GameSave.data.player_name
	set(val): GameSave.data.player_name = val

@export var traits: Array[String] = []:
	get: return GameSave.data.traits
	set(val): GameSave.data.traits = val

## V8: 诗词面板上可展示的 Imaginary 数量上限（超过部分随机截断 + 溢出占位 Slot）
@export var max_imaginary_managable: int = 3

@export var current_location: String = 'yong_zhou':
	get: return GameSave.data.current_location
	set(val):
		GameSave.data.current_location = val
		location_changed.emit(val)

## AmbitionData — 运行时 getter 从 Database 按 UUID 实时解析，setter 存 UUID 到 GameSave
@export var ambition: AmbitionData:
	get:
		if GameSave.data.ambition_uuid.is_empty():
			return null
		return Database.get_ambition(GameSave.data.ambition_uuid)
	set(val):
		if val:
			GameSave.data.ambition_uuid = val.uuid
		else:
			GameSave.data.ambition_uuid = ""

@export var current_action_tags: Array[String] = []:
	get: return GameSave.data.current_action_tags
	set(val): GameSave.data.current_action_tags = val

@export var created_poems: Array = []:
	get: return GameSave.data.created_poems
	set(val): GameSave.data.created_poems = val

## emotions — 返回 GameSave.data.emotions 引用，外部可直接下标读写
var emotions: Dictionary:
	get: return GameSave.data.emotions
	set(val):
		GameSave.data.emotions.clear()
		for k in val:
			GameSave.data.emotions[k] = val[k]

## flags — 返回 GameSave.data.flags 引用，外部可直接下标读写
var flags: Dictionary:
	get: return GameSave.data.flags
	set(val):
		GameSave.data.flags.clear()
		for k in val:
			GameSave.data.flags[k] = val[k]

## 重复行动记录
@export var last_action_tags: Array[String] = []:
	get: return GameSave.data.last_action_tags
	set(val): GameSave.data.last_action_tags = val

## 瞬态快照：当前正在执行的 action 是否与上次重复（不可序列化）
var _is_repeated_action: bool = false

## 当前事件上下文（瞬态，不可序列化）
var last_event: Dictionary = {}

## 会话级析构队列（不可序列化）
var session_deferred_cleanups: Array[BaseOperator] = []

## Imaginary 定义表静态缓存
var _imaginary_defs: Dictionary = {}

signal ambition_changed(ambition)
signal player_stat_changed(prop_name)
signal location_changed(location)
signal emotion_changed(stat_name)
signal before_emotion_change(emo_name: String, delta: int)
signal before_property_change(prop_name: String, delta: int)

## 当前驻留地点，存储为 String key（xishi / pingkangfang / huangcheng）
## 持久化到 GameSave.data.stay_place
var stay_place: String:
	get: return GameSave.data.stay_place
	set(val):
		if val.is_empty():
			val = "xishi"
		GameSave.data.stay_place = val
		stay_place_changed.emit(val)

signal stay_place_changed(place_str: String)

# ════════════════════════════════════════════════════════════════
# 重复行动疲惫系统
# ════════════════════════════════════════════════════════════════

func is_action_repeated(tags: Array[String]) -> bool:
	if last_action_tags.is_empty() or tags.is_empty():
		return false
	for tag in tags:
		if tag in last_action_tags:
			Logging.info("PlayerState.is_action_repeated: tag '%s' 命中 last_action_tags=%s → 重复行动" % [tag, str(last_action_tags)])
			return true
	Logging.info("PlayerState.is_action_repeated: tags=%s 与 last_action_tags=%s 无交集 → 非重复" % [str(tags), str(last_action_tags)])
	return false


# ════════════════════════════════════════════════════════════════
# 初始化
# ════════════════════════════════════════════════════════════════

var _init_props_retry_count: int = 0
const MAX_INIT_PROPS_RETRY: int = 5

func init_props():
	var resources = SourceOfTruth.debug_dashboard_state.resources
	append_stat(ENUMS.PROPS.MONEY, resources.money)
	append_stat(ENUMS.PROPS.HEALTH, resources.health)
	append_stat(ENUMS.PROPS.PRESTIGE, resources.prestige)
	append_stat(ENUMS.PROPS.TALENT, resources.talent)
	append_stat(ENUMS.PROPS.PROGRESS, resources.progress)
	append_stat(ENUMS.PROPS.ASTUTENESS, resources.astuteness)
	append_stat(ENUMS.PROPS.COMPOSURE, resources.composure)
	append_stat(ENUMS.PROPS.INSPIRATION, resources.inspiration)
	append_stat(ENUMS.PROPS.MOMENTUM, resources.momentum)
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
	# ❌ 不再从 SourceOfTruth.action_tracks 注入主线等级 trait（如 main_baiye_1）
	# 之前是为了让左侧面板显示六个初始主线等级标签，
	# 现在需求已变为不再显示这些主线等级 trait。
	# 枚举值 MAIN_* 保留以维持 .tres 整数值稳定性。
	# 若需通过 trait 系统追踪主线进度，应改用 Tag/Flag 而非 enum trait。
	Logging.info("PlayerState.init_traits: 已跳过 SourceOfTruth.action_tracks 主线等级 trait 注入")

func init_flags():
	var flag_data = SourceOfTruth.debug_dashboard_state.flags
	for flag_id in flag_data:
		var flag_val = flag_data[flag_id]
		set_flag(flag_id, flag_val)
		Logging.info('init_flags: flag %s set to %s from SourceOfTruth' % [flag_id, str(flag_val)])

func init_imaginaries():
	var basic_data = SourceOfTruth.debug_dashboard_state.get("basic_imaginaries", [])
	if basic_data.is_empty():
		Logging.info('init_imaginaries: no basic_imaginaries data in SourceOfTruth, skipping')
		return

	for entry in basic_data:
		var name = entry.get("name", "") as String
		if name.is_empty():
			Logging.warn('init_imaginaries: basic_imaginaries entry missing name, skipping')
			continue

		var imaginary_uuid = name.to_lower()
		var imaginary = Database.get_imaginary_detail(imaginary_uuid)
		if not imaginary:
			imaginary = Imaginary.new()
			imaginary.uuid = imaginary_uuid
			imaginary.name = name
			imaginary.duration_xun = 2
			Database.imaginaries_detail[imaginary_uuid] = imaginary
			Logging.info("init_imaginaries: 新建 Imaginary '%s' (duration_xun=2)" % imaginary_uuid)

func init_emotions():
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


# ════════════════════════════════════════════════════════════════
# 意象获取信号处理
# ════════════════════════════════════════════════════════════════

func _load_imaginary_definitions():
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
	EventBus.request_add_imaginary.connect(_on_request_add_imaginary)
	Logging.info("PlayerState: connected request_add_imaginary signal")


func _on_request_add_imaginary(tag: String):
	if tag.is_empty():
		Logging.err("PlayerState._on_request_add_imaginary: tag 为空")
		return

	var imaginary_uuid = tag.to_lower()

	if Database.imaginaries_detail.has(imaginary_uuid):
		append_stat("talent", 3)
		Logging.info("PlayerState._on_request_add_imaginary: 重复 Imaginary '%s' → talent +3" % imaginary_uuid)
		EventBus.imaginary_changed.emit()
		return

	var imaginary = Imaginary.new()
	imaginary.uuid = imaginary_uuid
	var def_data = _imaginary_defs.get(imaginary_uuid, {})
	imaginary.name = def_data.get("name", tag)
	imaginary.duration_xun = 2
	Database.imaginaries_detail[imaginary_uuid] = imaginary
	Logging.info("PlayerState._on_request_add_imaginary: 新建 Imaginary '%s' (name=%s, duration_xun=2)" % [imaginary_uuid, imaginary.name])

	EventBus.imaginary_changed.emit()


# ════════════════════════════════════════════════════════════════
# 属性读写 — 真值在 GameSave.data.properties
# ════════════════════════════════════════════════════════════════

func append_stat(stat_name, data) -> bool:
	if stat_name is int:
		var int_stat = ENUMS.to_prop_str(stat_name)
		if not int_stat:
			breakpoint
			Logging.err('do not find stat %s' % stat_name)
			return false
		stat_name = int_stat
	
	if stat_name == "_time":
		stat_name = "time"

	# 获取 Property 模板（metadata：hard_max / soft_max / etc.）
	var prop_template = Database.get_property(stat_name)
	if not prop_template:
		Logging.err('do not find stat %s' % stat_name)
		return false

	# 从 GameSave.data 读取当前值
	var current_val: int = _ensure_prop_in_gamesave(stat_name)
	var amount_to_change = data

	# trait 倍率修正
	for t_name in traits:
		var t = Database.get_trait(t_name)
		if not t:
			Logging.warn('do not find trait %s in Database, skipping buffer calc' % t_name)
			continue
		if t.buffer_to_prop and t.buffer_to_prop.has_operator(stat_name):
			amount_to_change = t.buffer_to_prop.match_and_multiply(stat_name, amount_to_change)
		if t.buffer_to_region and t.buffer_to_region.has_operator(current_location):
			amount_to_change = t.buffer_to_region.match_and_multiply(current_location, amount_to_change)

	# RelationFlagManager 关系层级倍率（离散4态，直接查询不依赖信号钩子）
	var target_tag = last_event.get("target_tag", "")
	var is_good = RelationFlagManager.GOOD_PROPS.has(stat_name) or not RelationFlagManager.BAD_PROPS.has(stat_name)
	if not target_tag.is_empty() and (RelationFlagManager.GOOD_PROPS.has(stat_name) or RelationFlagManager.BAD_PROPS.has(stat_name)):
		var tier_multiplier = RelationFlagManager.get_tier_multiplier(target_tag, is_good)
		if tier_multiplier != 1.0:
			amount_to_change = int(amount_to_change * tier_multiplier)
			Logging.info("change stat %s: tier multiplier applied (*%.2f) → %d" % [stat_name, tier_multiplier, amount_to_change])

	before_property_change.emit(stat_name, amount_to_change)

	# FatigueManager 疲劳倍率
	var fatigue_multiplier = FatigueManager.get_and_reset_fatigue_multiplier()
	if fatigue_multiplier != 1.0:
		amount_to_change = int(amount_to_change * fatigue_multiplier)
		Logging.info("change stat %s: fatigue multiplier applied (*%.2f) → %d" % [stat_name, fatigue_multiplier, amount_to_change])

	Logging.info('change stat %s by %d' % [stat_name, amount_to_change])
	var new_val: int = current_val + amount_to_change
	
	# 应用 hard_max 约束
	if prop_template.hard_max >= 0 and new_val > prop_template.hard_max:
		new_val = prop_template.hard_max
	if new_val < 0:
		new_val = 0

	GameSave.data.properties[stat_name] = new_val
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
	
	# 优先从 GameSave.data.properties 读取
	if GameSave.data.properties.has(stat_name):
		return GameSave.data.properties[stat_name]
	
	# emotion 兼容适配器
	if emotions.has(stat_name):
		return emotions[stat_name]
	
	Logging.err('do not find stat %s' % stat_name)
	return 0


func set_stat_val(stat_name, data) -> bool:
	if stat_name is int:
		var int_stat = ENUMS.to_prop_str(stat_name)
		if not int_stat:
			Logging.err('do not find stat %s' % stat_name)
			return false
		stat_name = int_stat
	
	if stat_name == "_time":
		stat_name = "time"
	
	var prop_template = Database.get_property(stat_name)
	if not prop_template:
		Logging.err('do not find stat %s' % stat_name)
		return false
	
	var new_val: int = data
	if prop_template.hard_max >= 0 and new_val > prop_template.hard_max:
		new_val = prop_template.hard_max
	if new_val < 0:
		new_val = 0
	
	GameSave.data.properties[stat_name] = new_val
	Logging.info('set stat %s to %d' % [stat_name, data])
	player_stat_changed.emit(stat_name)
	return true


func force_set_stat_val(stat_name, data):
	if stat_name is int:
		var int_stat = ENUMS.to_prop_str(stat_name)
		if not int_stat:
			Logging.err('do not find stat %s' % stat_name)
			return
		stat_name = int_stat
	
	var prop_template = Database.get_property(stat_name)
	if not prop_template:
		Logging.err('do not find stat %s' % stat_name)
		return
	
	GameSave.data.properties[stat_name] = data
	Logging.info('force set stat %s to %d (bypassed hard_max)' % [stat_name, data])
	player_stat_changed.emit(stat_name)


func _ensure_prop_in_gamesave(stat_name: String) -> int:
	"""确保 GameSave.data.properties 中有该属性，不存在时从 Property 模板读取默认 val 写入"""
	if GameSave.data.properties.has(stat_name):
		return GameSave.data.properties[stat_name]
	
	var prop_template = Database.get_property(stat_name)
	if not prop_template:
		return 0
	
	var default_val: int = prop_template.val
	GameSave.data.properties[stat_name] = default_val
	return default_val


# ════════════════════════════════════════════════════════════════
# 情绪读写
# ════════════════════════════════════════════════════════════════

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
	emotions.clear()


# ════════════════════════════════════════════════════════════════
# 特质管理
# ════════════════════════════════════════════════════════════════

func add_trait(trait_name):
	if trait_name is int:
		var int_trait = ENUMS.to_traits_str(trait_name)
		if not int_trait:
			Logging.err('do not find trait %s' % trait_name)
			return
		trait_name = int_trait

	if not traits.has(trait_name):
		traits.append(trait_name)
		Logging.info("PlayerState: add_trait '%s', total=%d" % [trait_name, traits.size()])
	EventBus.on_trait_change.emit()

func has_trait(trait_name):
	if trait_name is int:
		var int_trait = ENUMS.to_traits_str(trait_name)
		if not int_trait:
			Logging.err('do not find trait %s' % trait_name)
			return
		trait_name = int_trait
	return traits.has(trait_name)

func remove_trait(trait_name):
	if trait_name is int:
		var int_trait = ENUMS.to_traits_str(trait_name)
		if not int_trait:
			Logging.err('do not find trait %s' % trait_name)
			return
		trait_name = int_trait
	
	if traits.has(trait_name):
		traits.erase(trait_name)
		Logging.info("PlayerState: remove_trait '%s', total=%d" % [trait_name, traits.size()])
	EventBus.on_trait_change.emit()

func get_traits():
	return traits

func get_active_time_penalties() -> Dictionary:
	var result := {}
	for trait_key in traits:
		var trait_res = Database.get_trait(trait_key)
		if trait_res and trait_res is Trait and trait_res.time_penalty > 0:
			result[trait_res.name] = trait_res.time_penalty
	Logging.info("[PlayerState] get_active_time_penalties: %d active penalties → %s" % [result.size(), str(result)])
	return result


# ════════════════════════════════════════════════════════════════
# Flag 管理
# ════════════════════════════════════════════════════════════════

func _validate_flag_type(flag_id: String) -> String:
	var flag_def = Database.get_flag(flag_id)
	if not flag_def:
		Logging.err('flag %s not found in Database.flags' % flag_id)
		return ''
	if flag_def.type.is_empty():
		Logging.err('flag %s has no type defined' % flag_id)
		return ''
	return flag_def.type

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


# ════════════════════════════════════════════════════════════════
# 野心管理
# ════════════════════════════════════════════════════════════════

func set_ambition(ambition_key):
	var ambition_ = Database.get_ambition(ambition_key)
	if not ambition_:
		Logging.err('this ambition %s is non-exist' % ambition_key)
		return
	if ambition:
		for t in ambition.ambition_traits:
			remove_trait(t)
	# setter stores UUID to GameSave.data.ambition_uuid
	ambition = ambition_
	for t in ambition.ambition_traits:
		add_trait(t)
	emotions["ambition"] = 1.0
	GameSave.data.ambition_start_days = TimeService._total_days_elapsed
	Logging.info("PlayerState: ambition '%s' activated at total_days=%d, deadline_xun=%d" % [ambition.name, GameSave.data.ambition_start_days, ambition.deadline_xun])
	ambition_changed.emit(ambition)

func clear_ambition():
	if ambition:
		for t in ambition.ambition_traits:
			remove_trait(t)
	ambition = null
	emotions.erase("ambition")
	GameSave.data.ambition_start_days = -1
	ambition_changed.emit(null)

func get_ambition_remaining_xun() -> int:
	if not ambition or ambition.deadline_xun <= 0:
		return -1
	if GameSave.data.ambition_start_days < 0:
		return -1
	var current_days: int = TimeService._total_days_elapsed
	var elapsed_xun: int = (current_days - GameSave.data.ambition_start_days) / 10
	var remaining := ambition.deadline_xun - elapsed_xun
	return maxi(remaining, 0)

func get_location():
	var loc = Database.get_territory(current_location)
	if loc == null:
		loc = Database.get_province(current_location)
	if not loc:
		Logging.err('do not find location %s' % current_location)
		return null
	return loc


# ════════════════════════════════════════════════════════════════
# 临时标志位清理系统
# ════════════════════════════════════════════════════════════════

func defer_cleanup(cleanup_operator: BaseOperator):
	session_deferred_cleanups.append(cleanup_operator)
	Logging.info('defer_cleanup: registered cleanup for flag "%s"' % cleanup_operator.flag_id)

func flush_cleanups():
	var count = session_deferred_cleanups.size()
	if count == 0:
		return

	Logging.info('flush_cleanups: executing %d deferred cleanups (LIFO order)' % count)

	for i in range(count - 1, -1, -1):
		var op = session_deferred_cleanups[i] as BaseOperator
		if op:
			op.operate()
		else:
			Logging.warn('flush_cleanups: null operator at index %d, skipping' % i)

	session_deferred_cleanups.clear()
	Logging.info('flush_cleanups: all cleanups executed, queue cleared')
