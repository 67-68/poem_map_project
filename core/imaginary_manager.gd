extends Node

func add_imagenary(ev: BaseEvent):
	#breakpoint
	Logging.info('adding imagenary for event %s' % ev.uuid)
	if not ev is RandomEvent:
		Logging.warn('this event is not a base event, dont process it and add to imaginary basement')
		return

	# 使用emotion_configs进行校验
	if ev.emotion_configs.is_empty():
		Logging.warn('event %s has no emotion_configs, skipping imaginary processing (event will run normally without imaginary effects)' % ev.uuid)
		return

	Logging.info('event %s has %d emotion_configs, evaluating with player state' % [ev.uuid, ev.emotion_configs.size()])
	_process_emotion_configs(ev)

	Logging.info('finished processing event %s, emitting imaginary_changed signal' % ev.uuid)
	EventBus.imaginary_changed.emit()

func _process_emotion_configs(ev: BaseEvent):
	#breakpoint
	var evaluated_results = ImagenaryEvaluator.evaluate_local_configs(ev.emotion_configs, PlayerState)
	Logging.info('event %s evaluation result: %d configs passed validation' % [ev.uuid, evaluated_results.size()])
	
	for result in evaluated_results:
		var ima_blueprint = result.blueprint
		if not ima_blueprint:
			Logging.err('[ima_manager] blue print contain nothing')
			breakpoint
		var contexts = result.context_tags
		Logging.info('processing validated blueprint: %s with contexts: %s' % [ima_blueprint.uuid, str(contexts)])
		
		if not ima_blueprint:
			Logging.err('blueprint is null in evaluated result')
			continue
		
		# 直接使用 blueprint 对象，无需 TagManager.get_imaginary_from_tag()
		var entry = {
			"blueprint_id": ima_blueprint.uuid,
			"contexts": contexts
		}
		_append_tag(ima_blueprint, entry)

func _append_tag(ima: ImaginaryTag, entry: Dictionary):
	# entry 格式: { "blueprint_id": String, "contexts": Array[String] }
	ima.basic_imaginaries.append(entry)
	Logging.info('appended entry to imaginary %s, new size: %d' % [ima.uuid, ima.basic_imaginaries.size()])
		
	if ima.basic_imaginaries.size() > ima.l3_threshold:
		ima.current_level = 3
		Logging.info('imaginary level updated to 3 (size %d > l3_threshold %d)' % [ima.basic_imaginaries.size(), ima.l3_threshold])
	elif ima.basic_imaginaries.size() >= ima.l2_threshold:
		ima.current_level = 2
		Logging.info('imaginary level updated to 2 (size %d >= l2_threshold %d)' % [ima.basic_imaginaries.size(), ima.l2_threshold])
	else:
		ima.current_level = 1
		Logging.info('imaginary level set to 1 (size %d < l2_threshold %d)' % [ima.basic_imaginaries.size(), ima.l2_threshold])
	EventBus.imaginary_changed.emit()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 移除 event_shown 监听，改为在 narrative_overlay 中直接调用
	# EventBus.event_shown.connect(add_imagenary)
	pass
