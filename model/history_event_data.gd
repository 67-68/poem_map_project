class_name HistoryEventData extends WorldEvent
var options: Array[EventOption] = []
# target prov-uuid: parent - location_uuid
var prov_state_after: PROV_STATE
# audio 也用父类的

func _init(data: Dictionary):
	super._init(data)

	var props = data.get("properties", data.get("property", {}))
	var options_list = data.get('options',props.get('options',[]))
	for option_dict in options_list:
		var option = EventOption.new(option_dict)
		if option: options.append(option)
	
	prov_state_after = data.get('prov_state_after',props.get('prov_state_after',0))