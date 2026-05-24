extends Node

func add_imagenary(ev: BaseEvent):
	#breakpoint
	Logging.info('adding imagenary for event %s' % ev.uuid)
	if not ev is RandomEvent:
		Logging.warn('this event is not a base event, dont process it and add to imaginary basement')
		return
	
	# 使用emotion_configs进行校验
	if ev.emotion_configs.is_empty():
		Logging.warn('event %s has no emotion_configs, falling back to target_tags' % ev.uuid)
		_process_target_tags(ev)
	else:
		Logging.info('event %s has %d emotion_configs, evaluating with player state' % [ev.uuid, ev.emotion_configs.size()])
		_process_emotion_configs(ev)
	
	Logging.info('finished processing event %s, emitting imaginary_changed signal' % ev.uuid)
	EventBus.imaginary_changed.emit()

func _process_target_tags(ev: BaseEvent):
	Logging.info('event %s processing %d target tags (fallback mode)' % [ev.uuid, ev.target_tags.size()])
	for tag in ev.target_tags:
		Logging.info('processing tag: %s' % tag)
		var ima = TagManager.get_imaginary_from_tag(tag)
		if not ima:
			Logging.err('can not found imanaginary for tag %s' % tag) 
			Logging.info('skipping tag %s due to missing imaginary' % tag)
			continue
		Logging.info('found imaginary for tag %s, appending tag' % tag)
		_append_tag(ima,tag)

func _process_emotion_configs(ev: BaseEvent):
	var evaluated_uids = ImagenaryEvaluator.evaluate_local_configs(ev.emotion_configs, PlayerState)
	Logging.info('event %s evaluation result: %d uids passed validation' % [ev.uuid, evaluated_uids.size()])
	
	for uid in evaluated_uids:
		Logging.info('processing validated uid: %s' % uid)
		var ima = TagManager.get_imaginary_from_tag(uid)
		if not ima:
			Logging.err('can not find imaginary for uid %s' % uid)
			Logging.info('skipping uid %s due to missing imaginary' % uid)
			continue
		
		Logging.info('found imaginary for uid %s, appending tag' % uid)
		_append_tag(ima, uid)

func add_tag_to_imaginary(tag: String):
	
	var ima = TagManager.get_imaginary_from_tag(tag)
	if not ima:
		Logging.err('can not found imaginary for tag' + tag)
		return
	_append_tag(ima,tag)

func _append_tag(ima: ImaginaryTag, tag: String):
	ima.basic_imaginaries.append(tag)
	Logging.info('appended tag %s to imaginary, new size: %d' % [tag, ima.basic_imaginaries.size()])
		
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
	EventBus.event_shown.connect(add_imagenary)
	EventBus.request_add_imaginary.connect(add_tag_to_imaginary)
