extends Node

var stats := {}
var traits: Array[Trait] = []
var current_location := "" # 省份uuid
@export var ambition: AmbitionData

signal ambition_changed(ambition)
signal player_stat_changed(prop_name)

func _ready():
	set_ambition(Global.ambitions.get('first_ambition'))
	change_stat('official_prestige', 50)
	change_stat('literary_fame',50)
	change_stat('talent',50) # 如果才气不够就写不出春望，需要点各种事件来加才气
	add_trait('offspring_of_du_shen_yan')

func change_stat(stat_name, data):
	if stat_name is int:
		var int_stat = translate_from_enum(stat_name)
		if not int_stat:
			Logging.err('do not find stat %s' % stat_name)
			return
		stat_name = int_stat

	if not stats.has(stat_name):
		stats[stat_name] = 0 # 初始化为 0

	var amount_to_change = data

	# 使用新的调用方式，先检查操作符是否存在
	if ambition and ambition.buffer_to_prop and ambition.buffer_to_prop.has_operator(stat_name):
		amount_to_change = ambition.buffer_to_prop.match_and_multiply(stat_name, amount_to_change)
	
	if ambition and ambition.buffer_to_region and ambition.buffer_to_region.has_operator(current_location):
		amount_to_change = ambition.buffer_to_region.match_and_multiply(current_location, amount_to_change)
	
	for t in traits:
		if t.buffer_to_prop and t.buffer_to_prop.has_operator(stat_name):
			amount_to_change = t.buffer_to_prop.match_and_multiply(stat_name, amount_to_change)
		if t.buffer_to_region and t.buffer_to_region.has_operator(current_location):
			amount_to_change = t.buffer_to_region.match_and_multiply(current_location, amount_to_change)

	stats[stat_name] += amount_to_change # 永远执行加法
	player_stat_changed.emit(stat_name)

func get_stat(stat_name):
	if stat_name is int:
		var int_stat = translate_from_enum(stat_name)
		if not int_stat:
			Logging.err('do not find stat %s' % stat_name)
			return
		stat_name = int_stat

	return stats.get(stat_name)

func add_trait(trait_name):
	if trait_name is int:
		var int_trait = translate_from_enum(trait_name)
		if not int_trait:
			Logging.err('do not find trait %s' % trait_name)
			return
		trait_name = int_trait

	if not traits.has(trait_name): traits.append(trait_name)

func has_trait(trait_name):
	if trait_name is int:
		var int_trait = translate_from_enum(trait_name)
		if not int_trait:
			Logging.err('do not find trait %s' % trait_name)
			return
		trait_name = int_trait
	return traits.has(trait_name)

func remove_trait(trait_name):
	if trait_name is int:
		var int_trait = translate_from_enum(trait_name)
		if not int_trait:
			Logging.err('do not find trait %s' % trait_name)
			return
		trait_name = int_trait
	
	if traits.has(trait_name):
		traits.erase(trait_name)


func set_ambition(ambition_):
	if ambition:
		for t in ambition.ambition_traits:
			remove_trait(t)
	ambition = ambition_
	for t in ambition.ambition_traits:
		add_trait(t)
	ambition_changed.emit(ambition)

static func translate_from_enum(stat):
	Logging.debug('try to translate a enum property')
	return PROPERTIES.to_str(stat)