@tool
class_name PlaceRequirement extends BaseRequirements
## PlaceRequirement — 检查玩家当前驻留地点是否匹配。
##
## @export place: 期望的地点 key（如 "taishan_base", "taishan_upper"）。

@export var place: String = ""

func compare(_player_state) -> bool:
	if place.is_empty():
		Logging.err("PlaceRequirement.compare: place 为空，返回 false")
		return false
	var current := PlayerState.stay_place
	var result := current == place
	Logging.info("PlaceRequirement.compare: current='%s', expected='%s' → %s" % [current, place, str(result)])
	return result

func describe_requirement() -> String:
	if place.is_empty():
		return ""
	return tr("CODE_PLACE_REQUIREMENT_DESC") % place

func get_failed_hint() -> String:
	if place.is_empty():
		return ""
	return tr("CODE_PLACE_REQUIREMENT_FAILED") % place
