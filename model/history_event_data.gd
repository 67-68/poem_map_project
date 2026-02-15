class_name HistoryEventData extends WorldEvent
var options: Array[EventOption] = []
# target prov-uuid: parent - location_uuid
var provs_state_after: Dictionary
# audio 也用父类的
# 需要texture; 使用父类的icon
var example: String
# 对于问题介绍，使用Description
# 问题本身使用name
# bg_color 使用父类的color

func _init(data: Dictionary):
	super._init(data)

	var props = data.get("properties", data.get("property", {}))
	var options_list = data.get('options',props.get('options',[]))
	for option_dict in options_list:
		var option = EventOption.new(option_dict)
		if option: options.append(option)
	
	provs_state_after = data.get('provs_state_after',props.get('provs_state_after',{}))
	example = data.get('example',props.get('example',""))
