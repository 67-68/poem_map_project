@tool
class_name ImaginaryLevelRewardOperator extends BaseOperator

## 从 context 中读取的关键字key，例如 "feihualing_chosen_word"
@export var context_key: String = ""

## L3 名望奖励
@export var l3_fame: int = 50
## L2 名望奖励
@export var l2_fame: int = 20
## L1 名望奖励
@export var l1_fame: int = 0

## L3 时额外赠送的稀有意象 UUID（可选）
@export var l3_imaginary_uuid: String = ""

## L3 醉意变化
@export var l3_drunk: int = 0
## L2 醉意变化
@export var l2_drunk: int = 5
## L1 醉意变化
@export var l1_drunk: int = 10

## 运行时解析出来的意象 UUID
var _resolved_imaginary_uuid: String = ""


func init(_context: Dictionary) -> Dictionary:
	if context_key.is_empty():
		Logging.err("ImaginaryLevelRewardOperator: context_key is empty")
		return _context

	var uuid = _context.get(context_key)
	if uuid == null:
		Logging.err("ImaginaryLevelRewardOperator: context key '%s' not found" % context_key)
		return _context

	_resolved_imaginary_uuid = str(uuid)
	Logging.info("ImaginaryLevelRewardOperator: resolved imaginary UUID '%s' from context[%s]" % [_resolved_imaginary_uuid, context_key])
	return _context


func operate():
	if _resolved_imaginary_uuid.is_empty():
		Logging.err("ImaginaryLevelRewardOperator: no resolved imaginary UUID, skipping")
		return

	var imaginary = Database.imaginaries.get(_resolved_imaginary_uuid) as ImaginaryTag
	if imaginary == null:
		Logging.err("ImaginaryLevelRewardOperator: imaginary '%s' not found in Database" % _resolved_imaginary_uuid)
		return

	var level = imaginary.current_level
	Logging.info("ImaginaryLevelRewardOperator: imaginary '%s' has level %d" % [_resolved_imaginary_uuid, level])

	match level:
		3:
			PlayerState.append_stat("literary_fame", l3_fame)
			PlayerState.append_stat("drunk", l3_drunk)
			if not l3_imaginary_uuid.is_empty():
				_grant_imaginary(l3_imaginary_uuid)
			Logging.info("ImaginaryLevelRewardOperator: L3 reward applied: fame=%d, drunk=%d, imaginary=%s" % [l3_fame, l3_drunk, l3_imaginary_uuid])
		2:
			PlayerState.append_stat("literary_fame", l2_fame)
			PlayerState.append_stat("drunk", l2_drunk)
			Logging.info("ImaginaryLevelRewardOperator: L2 reward applied: fame=%d, drunk=%d" % [l2_fame, l2_drunk])
		1:
			PlayerState.append_stat("literary_fame", l1_fame)
			PlayerState.append_stat("drunk", l1_drunk)
			Logging.info("ImaginaryLevelRewardOperator: L1 reward applied: fame=%d, drunk=%d" % [l1_fame, l1_drunk])
		_:
			Logging.warn("ImaginaryLevelRewardOperator: unknown level %d, no reward applied" % level)


func _grant_imaginary(imaginary_uuid: String):
	"""向玩家发放一个意象：添加到 ImaginaryTag 的 basic_imaginaries 中"""
	var imaginary = Database.imaginaries.get(imaginary_uuid) as ImaginaryTag
	if imaginary == null:
		Logging.err("ImaginaryLevelRewardOperator: target imaginary '%s' not found for granting" % imaginary_uuid)
		return

	# 创建一个虚拟的意象条目（模拟事件产生的意象）
	var entry = {
		"blueprint_id": imaginary_uuid,
		"contexts": ["feihualing_reward"]
	}
	imaginary.basic_imaginaries.append(entry)

	# 更新等级
	if imaginary.basic_imaginaries.size() > imaginary.l3_threshold:
		imaginary.current_level = 3
	elif imaginary.basic_imaginaries.size() >= ImaginaryTag.new().l2_threshold:
		imaginary.current_level = 2
	else:
		imaginary.current_level = 1

	EventBus.imaginary_changed.emit()
	Logging.info("ImaginaryLevelRewardOperator: granted imaginary '%s', now has %d entries, level=%d" % [
		imaginary_uuid, imaginary.basic_imaginaries.size(), imaginary.current_level])