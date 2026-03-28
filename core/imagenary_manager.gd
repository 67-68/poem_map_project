extends Node


func add_imagenary(ev: BaseEvent):
	if not ev is RandomEvent:
		Logging.warn('this event is not a base event, dont process it and add to imaginary basement')
		return
	for tag in ev.target_tags:
		var child_class = tag.split(':',true,1)[1] # eg. social:wealth:merchat -> wealth:merchant
		if child_class:
			var ima = Global.imaginaries.get(child_class)
			if not ima:
				Logging.err('can not found child class to create imanaginary for tag %s, that is to say lack of data for' % [tag,child_class]) 
				continue
			ima.basic_imaginaries.append(tag)
			
			if ima.basic_imaginaries.size() > ima.l3_threshold:
				ima.current_level = 3
			elif ima.basic_imaginaries.size() > ima.l2_threshold:
				ima.current_level = 2
			else:
				ima.current_level = 1


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.event_shown.connect(add_imagenary)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
