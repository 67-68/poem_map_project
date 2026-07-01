@tool
class_name PoemRequirement extends BaseRequirements

## 可接受的诗词类型列表（空 = 接受所有 POEM 类型）
@export var accepted_poem_types: Array[ENUMS.POEM_TYPE] = []

## 最低诗词等级（0 = 不限制）
@export var lowest_poem_level: int = 0


func get_referenced_traits() -> Array:
	# 动态匹配，无法静态枚举具体的 trait UUID（与 trait_choose_operator 一致）
	return []


func compare(player_state) -> bool:
	for t in player_state.get_traits():
		var trait_data = Database.get_trait(t)
		if not trait_data:
			Logging.warn("PoemRequirement: trait '%s' not found in Database" % str(t))
			continue
		if not (trait_data is Poem):
			continue

		var level: int = trait_data.poem_level
		Logging.debug("PoemRequirement: checking trait '%s' topic=%s specific=%s level=%d" % [
			trait_data.uuid, trait_data.topic, trait_data.specific_topic, level
		])

		if level < lowest_poem_level:
			Logging.debug("PoemRequirement: trait '%s' level %d < min %d, skipped" % [
				trait_data.uuid, level, lowest_poem_level
			])
			continue

		# 类型过滤：空数组 = 接受所有 POEM 类型（只检查等级）
		if accepted_poem_types.is_empty():
			Logging.debug("PoemRequirement: trait '%s' accepted (no type filter, level=%d >= %d)" % [
				trait_data.uuid, level, lowest_poem_level
			])
			return true

		var trait_type_str = trait_data.specific_topic
		for accepted in accepted_poem_types:
			var type_name = ENUMS.POEM_TYPE.keys()[accepted]
			if trait_type_str == type_name:
				Logging.debug("PoemRequirement: trait '%s' accepted (type=%s, level=%d >= %d)" % [
					trait_data.uuid, type_name, level, lowest_poem_level
				])
				return true

	Logging.debug("PoemRequirement: no matching poem trait found (types=%s, min_level=%d)" % [
		str(accepted_poem_types), lowest_poem_level
	])
	return false
