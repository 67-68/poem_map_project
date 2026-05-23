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

signal ambition_changed(ambition)
signal player_stat_changed(prop_name)
signal location_changed(location)

func _ready():
	change_stat('official_prestige', 14)
	change_stat('literary_fame',50)
	change_stat('talent',50) # 如果才气不够就写不出春望，需要点各种事件来加才气
	add_trait(ENUMS.to_traits_str(ENUMS.TRAITS.ORDINARY_PEOPLE))
	current_location = 'yong_zhou'

func change_stat(stat_name, data):
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

func add_trait(trait_name):
	if trait_name is int:
		var int_trait = ENUMS.to_traits_str(trait_name)
		if not int_trait:
			Logging.err('do not find trait %s' % trait_name)
			return
		trait_name = int_trait

	if not traits.has(trait_name): traits.append(trait_name)

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
