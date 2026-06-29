@tool
class_name ImaginaryLevelRequirement extends BaseRequirements

## context 中存储意象 UUID 的 key，例如 "feihualing_chosen_word"
@export var context_key: String = ""

## 需要的最低等级（>= 此值）
@export var min_level: int = 1

## 存在性检查模式：不检查特定意象，而是检查玩家是否有任意意象 >= min_level
@export var check_any: bool = false

## 运行时从 context 解析出来的意象 UUID
var _resolved_imaginary_uuid: String = ""


func init(context: Dictionary) -> Dictionary:
	if check_any:
		Logging.info("ImaginaryLevelRequirement: check_any mode, skipping context resolution")
		return context

	if context_key.is_empty():
		Logging.err("ImaginaryLevelRequirement: context_key is empty")
		return context

	var uuid = context.get(context_key)
	if uuid == null:
		Logging.err("ImaginaryLevelRequirement: context key '%s' not found" % context_key)
		return context

	_resolved_imaginary_uuid = str(uuid)
	Logging.info("ImaginaryLevelRequirement: resolved imaginary UUID '%s' from context[%s]" % [_resolved_imaginary_uuid, context_key])
	return context


func compare(player_state: PlayerState) -> bool:
	if check_any:
		return _check_any_imaginary()

	if _resolved_imaginary_uuid.is_empty():
		Logging.warn("ImaginaryLevelRequirement: no resolved imaginary UUID, requirement fails")
		return false

	var imaginary = Database.get_imaginary(_resolved_imaginary_uuid) as ImaginaryConcept
	if imaginary == null:
		Logging.warn("ImaginaryLevelRequirement: imaginary '%s' not found in Database, requirement fails" % _resolved_imaginary_uuid)
		return false

	var level = imaginary.current_level
	var met = level >= min_level
	Logging.info("ImaginaryLevelRequirement: imaginary '%s' level=%d >= min=%d ? %s" % [_resolved_imaginary_uuid, level, min_level, str(met)])
	return met


## 存在性检查：遍历所有意象，只要有任意一个意象等级 >= min_level 就返回 true
func _check_any_imaginary() -> bool:
	for uuid in Database.get_imaginaries_all():
		var imaginary = Database.get_imaginary(uuid) as ImaginaryConcept
		if not imaginary:
			continue
		if imaginary.current_level >= min_level:
			Logging.info("ImaginaryLevelRequirement: found imaginary '%s' with level=%d >= %d, requirement met" % [uuid, imaginary.current_level, min_level])
			return true

	Logging.info("ImaginaryLevelRequirement: no imaginary with level >= %d found, requirement fails" % min_level)
	return false
