@tool
class_name LianjuScoreOperator extends BaseOperator

## V6: 联句评分算子 — 基于 tier 而非已删除的 level
## T2 基础分
@export var t2_base_score: int = 20
## T1 基础分 (等于 0)
@export var t1_base_score: int = 0
@export var emotion_match_percent: int = 150

## 评分完成后 push 到的事件 key，展示评分结果
@export var result_event_key: String = "lianju_result"

var _picked_imaginary: ImaginaryConcept = null
var _final_score: int = 0
var _picked_name: String = ""
var _had_emotion_match: bool = false


func operate():
	Logging.info("LianjuScoreOperator: Starting operate() — opening picker for player's imaginaries (tier-based)")

	var data: Array[ImaginaryConcept] = []
	for uuid in Database.get_imaginaries_all():
		var imaginary = Database.get_imaginary(uuid) as ImaginaryConcept
		if not imaginary:
			continue
		if imaginary.current_tier < 1:
			continue
		data.append(imaginary)

	Logging.info("LianjuScoreOperator: Found %d available imaginaries for player" % data.size())

	if data.is_empty():
		Logging.warn("LianjuScoreOperator: No imaginaries available, score = 0")
		_final_score = 0
		_picked_name = ""
		_apply_score()
		return

	EventBus.push_picker.emit(data, _on_imaginary_picked, null)


func _on_imaginary_picked(imaginary_picked):
	if not imaginary_picked:
		Logging.warn("LianjuScoreOperator: No imaginary picked, score = 0")
		_final_score = 0
		_picked_name = ""
		_apply_score()
		return

	_picked_imaginary = imaginary_picked as ImaginaryConcept
	if not _picked_imaginary:
		Logging.err("LianjuScoreOperator: Picked item is not an ImaginaryConcept!")
		_final_score = 0
		_picked_name = ""
		_apply_score()
		return

	var uuid = _picked_imaginary.uuid
	var tier = _picked_imaginary.current_tier
	_picked_name = _picked_imaginary.name
	Logging.info("LianjuScoreOperator: Player picked imaginary '%s' (name='%s', tier=%d)" % [uuid, _picked_name, tier])

	var base_score: int
	match tier:
		2:
			base_score = t2_base_score
		1:
			base_score = t1_base_score
		_:
			Logging.warn("LianjuScoreOperator: unknown tier %d, using T1 base" % tier)
			base_score = t1_base_score

	Logging.info("LianjuScoreOperator: base score = %d (tier=%d)" % [base_score, tier])

	var multiplier := 100
	var dominant_emotion := _get_dominant_emotion()
	_had_emotion_match = false
	if not dominant_emotion.is_empty():
		Logging.info("LianjuScoreOperator: dominant emotion = '%s'" % dominant_emotion)
		if uuid.contains(dominant_emotion):
			multiplier = emotion_match_percent
			_had_emotion_match = true
			Logging.info("LianjuScoreOperator: emotion match! multiplier = %d%%" % multiplier)
		else:
			Logging.info("LianjuScoreOperator: no emotion match, multiplier = 100%%")
	else:
		Logging.info("LianjuScoreOperator: no dominant emotion found, multiplier = 100%%")

	_final_score = base_score * multiplier / 100
	Logging.info("LianjuScoreOperator: final score = %d * %d%% = %d" % [base_score, multiplier, _final_score])

	_apply_score()


func _get_dominant_emotion() -> String:
	var emotions: Dictionary = PlayerState.emotions
	if emotions.is_empty():
		return ""

	var max_val := 0
	var max_key := ""
	for key in emotions:
		var val = emotions[key] as int
		if val > max_val:
			max_val = val
			max_key = key

	if max_key.is_empty() or max_val <= 0:
		return ""

	return max_key.to_lower()


func _apply_score():
	if _final_score > 0:
		PlayerState.append_stat("literary_fame", _final_score)
		Logging.info("LianjuScoreOperator: applied %d literary_fame reward" % _final_score)

	EventBus.lianju_score_calculated.emit(_final_score)

	# 根据分数计算评语
	var evaluation: String
	if _final_score >= 30:
		evaluation = "妙绝！此句浑然天成，四座皆惊！"
	elif _final_score >= 15:
		evaluation = "佳句！宾客纷纷点头赞许。"
	elif _final_score >= 5:
		evaluation = "尚可，中规中矩。"
	else:
		evaluation = "你的对句平淡无奇…"
	Logging.info("LianjuScoreOperator: evaluation = '%s' (score=%d)" % [evaluation, _final_score])

	var ctx = {
		"lianju_score": _final_score,
		"lianju_picked_name": _picked_name,
		"lianju_emotion_match": _had_emotion_match,
		"lianju_evaluation": evaluation,
	}
	if _picked_imaginary:
		ctx["lianju_picked_tier"] = _picked_imaginary.current_tier

	if not result_event_key.is_empty():
		Logging.info("LianjuScoreOperator: pushing result event '%s'" % result_event_key)
		EventBus.push_event.emit(result_event_key, ctx)
