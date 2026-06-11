extends Node

@export var player_name: String = "杜甫"
@export var traits: Array[String] = [] # trait key string
@export var current_location: String = 'yong_zhou':
	set(val):
		current_location = val
		location_changed.emit(val)
	 	# 省份uuid
@export var ambition: AmbitionData
@export var current_action_tags: Array[String] = []
@export var created_poems: Array[String]
var emotions: Dictionary = {}
var flags: Dictionary = {}  # flag_id -> value (str/int/bool)

# 存活于整个"玩法会话"（如整场宴会）的析构队列
# TempFlagOperator 会在这里注册反向清理算子
var session_deferred_cleanups: Array[BaseOperator] = []

signal ambition_changed(ambition)
signal player_stat_changed(prop_name)
signal location_changed(location)
signal emotion_changed(stat_name)

func init_props():
	var resources = SourceOfTruth.debug_dashboard_state.resources
	append_stat(ENUMS.PROPS.OFFICIAL_PRESTIGE, resources.official_prestige)
	append_stat(ENUMS.PROPS.LITERARY_FAME, resources.literary_fame)
	append_stat(ENUMS.PROPS.TALENT, resources.talent)
	append_stat(ENUMS.PROPS.BURNOUT, resources.burnout)
	append_stat(ENUMS.PROPS.DRUNK, resources.drunk)
	append_stat(ENUMS.PROPS.FATIGUE, resources.fatigue)
	append_stat(ENUMS.PROPS.SICK, resources.sick)
	append_stat(ENUMS.PROPS.INSPIRATION, resources.inspiration)
	append_stat(ENUMS.PROPS.HEALTH, resources.health)
	append_stat(ENUMS.PROPS.CAREER_PROGRESS, resources.career_progress)
	append_stat(ENUMS.PROPS.MONEY, resources.money)

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
	"""从 SourceOfTruth 加载意象初始等级到 Database.imaginaries 中的 ImaginaryTag"""
	var imaginary_data = SourceOfTruth.debug_dashboard_state.get("imaginaries", {})
	if imaginary_data.is_empty():
		Logging.info('init_imaginaries: no imaginary data in SourceOfTruth, skipping')
		return

	for uuid in imaginary_data:
		var level = imaginary_data[uuid] as int
		if level <= 0:
			Logging.info('init_imaginaries: imaginary %s level <= 0 (%d), skipping' % [uuid, level])
			continue
		var imaginary = Database.imaginaries.get(uuid) as ImaginaryTag
		if not imaginary:
			Logging.warn('init_imaginaries: imaginary %s not found in Database.imaginaries, skipping' % uuid)
			continue
		imaginary.current_level = level
		Logging.info('init_imaginaries: set imaginary %s (%s) to level %d' % [uuid, imaginary.name, level])

func _ready():
	init_props()
	init_traits()
	init_flags()
	init_imaginaries()
	_connect_imaginary_signals()
	
	current_location = 'yong_zhou'


# ─── 意象获取信号处理 ─────────────────────────────────────────

func _connect_imaginary_signals():
	"""连接 EventBus.request_add_imaginary 信号"""
	EventBus.request_add_imaginary.connect(_on_request_add_imaginary)
	Logging.info("PlayerState: connected request_add_imaginary signal")


func _on_request_add_imaginary(tag: String):
	"""处理意象获取请求：解析 4 段式 tag，用中间两段匹配 Database.imaginaries 的 key，完整 tag 作为 blueprint_id 存入"""
	if tag.is_empty():
		Logging.err("PlayerState._on_request_add_imaginary: tag 为空")
		return

	# 解析 4 段式 tag，提取中间两段作为 ImaginaryTag 的 key
	# 例如 TARGET_MYTH_GIANTROC_DAYAN → 中间两段 MYTH:GIANTROC
	var segments = tag.split("_")
	if segments.size() < 3:
		Logging.err("PlayerState._on_request_add_imaginary: tag '%s' 段数不足 (%d)，需要至少 3 段" % [tag, segments.size()])
		return

	var imaginary_key = segments[1] + ":" + segments[2]
	# 注册表/资源文件中的 key 使用小写（如 myth:giantroc），tag 段是大写（如 MYTH:GIANTROC）
	var imaginary = Database.imaginaries.get(imaginary_key.to_lower()) as ImaginaryTag
	if not imaginary:
		Logging.err("PlayerState._on_request_add_imaginary: 从中间两段 '%s' 未找到对应的 ImaginaryTag（tag='%s'）" % [imaginary_key, tag])
		return

	# 每次都添加新条目（允许重复），完整 4 段 tag 作为 blueprint_id
	var new_entry = {
		"blueprint_id": tag,
		"contexts": []
	}
	imaginary.basic_imaginaries.append(new_entry)
	var count = imaginary.basic_imaginaries.size()
	Logging.info("PlayerState._on_request_add_imaginary: blueprint '%s' 已存入意象 '%s' (%s) (第 %d 条)，当前总量: %d" %
		[tag, imaginary_key, imaginary.name, count, count])

	# 通知 UI 更新
	EventBus.imaginary_changed.emit()

func append_stat(stat_name, data):
	if stat_name is int:
		var int_stat = ENUMS.to_prop_str(stat_name)
		if not int_stat:
			Logging.err('do not find stat %s' % stat_name)
			return
		stat_name = int_stat

	var stat = Database.properties.get(stat_name)
	# 需要提前登记stat
	if not stat:
		Logging.err('do not find stat %s' % stat_name)
		return

	var amount_to_change = data

	for t_name in traits:
		var t = Database.traits.get(t_name)
		if not t:
			Logging.err('do not find trait %s' % t_name)
			continue
		if t.buffer_to_prop and t.buffer_to_prop.has_operator(stat_name):
			amount_to_change = t.buffer_to_prop.match_and_multiply(stat_name, amount_to_change)
		if t.buffer_to_region and t.buffer_to_region.has_operator(current_location):
			amount_to_change = t.buffer_to_region.match_and_multiply(current_location, amount_to_change)

	Logging.info('change stat %s by %d' % [stat_name, amount_to_change])
	stat.val += amount_to_change # 永远执行加法
	# hard_max clamp
	if stat.hard_max >= 0 and stat.val > stat.hard_max:
		stat.val = stat.hard_max
		Logging.info('change stat %s clamped to hard_max=%d' % [stat_name, stat.hard_max])
	player_stat_changed.emit(stat_name)

func get_stat_val(stat_name):
	if stat_name is int:
		var int_stat = ENUMS.to_prop_str(stat_name)
		if not int_stat:
			Logging.err('do not find stat %s' % stat_name)
			return
		stat_name = int_stat
	
	var stat = Database.properties.get(stat_name)
	if not stat:
		Logging.err('do not find stat %s' % stat_name)
		return 0
	return stat.val

func set_stat_val(stat_name, data):
	if stat_name is int:
		var int_stat = ENUMS.to_prop_str(stat_name)
		if not int_stat:
			Logging.err('do not find stat %s' % stat_name)
			return
		stat_name = int_stat
	
	var stat = Database.properties.get(stat_name)
	if not stat:
		Logging.err('do not find stat %s' % stat_name)
		return
	
	# hard_max clamp
	if stat.hard_max >= 0 and data > stat.hard_max:
		data = stat.hard_max
		Logging.info('set stat %s clamped to hard_max=%d' % [stat_name, stat.hard_max])
	if data < 0:
		data = 0
		Logging.info('set stat %s clamped to min_val=0' % stat_name)
	
	stat.val = data
	Logging.info('set stat %s to %d' % [stat_name, data])
	player_stat_changed.emit(stat_name)

func force_set_stat_val(stat_name, data):
	"""强制设值，跳过 hard_max 检查（用于 debug / 特殊场景）"""
	if stat_name is int:
		var int_stat = ENUMS.to_prop_str(stat_name)
		if not int_stat:
			Logging.err('do not find stat %s' % stat_name)
			return
		stat_name = int_stat
	
	var stat = Database.properties.get(stat_name)
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
	EventBus.on_trait_change.emit()
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
	var flag_def = Database.flags.get(flag_id)
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
	if Database.flags.has(flag_id):
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
	var ambition_ = Database.ambitions.get(ambition_key)
	if not ambition_: 
		Logging.err('this ambition %s is non-exist' % ambition_key)
		return
	if ambition:
		for t in ambition.ambition_traits:
			remove_trait(t)
	ambition = ambition_
	for t in ambition.ambition_traits:
		add_trait(t)
	ambition_changed.emit(ambition)

func clear_ambition():
	if ambition:
		for t in ambition.ambition_traits:
			remove_trait(t)
	ambition = null
	ambition_changed.emit(null)

func get_location():
	var loc = Database.territories.get(current_location)
	if loc == null:
		loc = Database.base_province.get(current_location)
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
