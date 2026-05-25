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
