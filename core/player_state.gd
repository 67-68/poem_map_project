extends Node

var stats := {}
var traits := []
var current_ambition := {}

signal ambition_changed(ambition)

func _ready():
	add_stat('official_prestige', 50)
	add_stat('literary_fame',50)
	add_stat('talent',50) # 如果才气不够就写不出春望，需要点各种事件来加才气
	add_trait('offspring_of_du_shen_yan')

func add_stat(stat_name, data):
	if stat_name is int:
		var int_stat = translate_from_enum(stat_name)
		if not int_stat:
			Logging.err('do not find stat %s' % stat_name)
			return
		stat_name = int_stat

	if not stats.has(stat_name):
		stats[stat_name] = 0 # 初始化为 0
	stats[stat_name] += data # 永远执行加法

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

func set_ambition(ambition_):
	current_ambition = ambition_

static func translate_from_enum(stat):
	Logging.debug('try to translate a enum property')
	return PROPERTIES.to_str(stat)