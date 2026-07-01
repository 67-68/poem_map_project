@tool
class_name PoemRequirement extends BaseRequirements

## V6: 诗词需求检查 — poem_level 已删除，仅按 poem_type 过滤
## 可接受的诗词类型列表（空 = 接受所有 POEM 类型）
@export var accepted_poem_types: Array[ENUMS.POEM_TYPE] = []


func get_referenced_traits() -> Array:
	# 动态匹配，无法静态枚举具体的 trait UUID
	return []


func compare(player_state) -> bool:
	for t in player_state.get_traits():
		var trait_data = Database.get_trait(t)
		if not trait_data:
			Logging.warn("PoemRequirement: trait '%s' not found in Database" % str(t))
			continue
		if not (trait_data is Poem):
			continue

		Logging.debug("PoemRequirement: checking trait '%s' topic=%s specific=%s" % [
			trait_data.uuid, trait_data.topic, trait_data.specific_topic
		])

		# 类型过滤：空数组 = 接受所有 POEM 类型
		if accepted_poem_types.is_empty():
			Logging.debug("PoemRequirement: trait '%s' accepted (no type filter)" % trait_data.uuid)
			return true

		var trait_type_str = trait_data.specific_topic
		for accepted in accepted_poem_types:
			var type_name = ENUMS.POEM_TYPE.keys()[accepted]
			if trait_type_str == type_name:
				Logging.debug("PoemRequirement: trait '%s' accepted (type=%s)" % [
					trait_data.uuid, type_name
				])
				return true

	Logging.debug("PoemRequirement: no matching poem trait found (types=%s)" % str(accepted_poem_types))
	return false
