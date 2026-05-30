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

func init_traits():
	var action_tracks = SourceOfTruth.debug_dashboard_state.action_tracks
	for track_name in action_tracks:
		var trait_uuid = action_tracks[track_name]
		add_trait(trait_uuid)	

func _ready():
	init_props()
	init_traits()
	
	current_location = 'yong_zhou'

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

	# 使用新的调用方式，先检查操作符是否存在
	if ambition and ambition.buffer_to_prop and ambition.buffer_to_prop.has_operator(stat_name):
		amount_to_change = ambition.buffer_to_prop.match_and_multiply(stat_name, amount_to_change)
	
	if ambition and ambition.buffer_to_region and ambition.buffer_to_region.has_operator(current_location):
		amount_to_change = ambition.buffer_to_region.match_and_multiply(current_location, amount_to_change)
	
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
	
	stat.val = data
	Logging.info('set stat %s to %d' % [stat_name, data])
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
