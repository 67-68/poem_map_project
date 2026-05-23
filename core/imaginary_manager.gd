extends Node

func add_imagenary(ev: BaseEvent):
	#breakpoint
	Logging.info('adding imagenary for event %s' % ev.uuid)
	if not ev is RandomEvent:
		Logging.warn('this event is not a base event, dont process it and add to imaginary basement')
		return
	Logging.info('event %s is a RandomEvent, processing %d target tags' % [ev.uuid, ev.target_tags.size()])
	for tag in ev.target_tags:
		Logging.info('processing tag: %s' % tag)
		var ima = TagManager.get_imaginary_from_tag(tag)
		if not ima:
			Logging.err('can not found imanaginary for tag %s' % tag) 
			Logging.info('skipping tag %s due to missing imaginary' % tag)
			continue
		Logging.info('found imaginary for tag %s, appending tag' % tag)
		_append_tag(ima,tag)
		
	Logging.info('finished processing all tags for event %s, emitting imaginary_changed signal' % ev.uuid)
	EventBus.imaginary_changed.emit()

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
