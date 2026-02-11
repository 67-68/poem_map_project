class_name Territory extends WorldEvent

var color: Color
var stability: float
var capital: String
var sub_ids: Array

func _init(data):
	super._init(data)
	var props = data.get("properties", data.get("property", {}))
	color = data.get('color',props.get('color','FFFFFF'))
	stability = data.get('stability',float(props.get('stability',1.0)))
	capital = data.get('capital',props.get('capital','important_city'))
	sub_ids = data.get('sub_ids',props.get('sub_ids',[]))
