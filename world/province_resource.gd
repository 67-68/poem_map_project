class_name ProvinceResource extends WorldEvent

var color: Color
var stability: float
var capital: String

func _init(data):
	super._init(data)
	var props = data.get("properties", data.get("property", {}))
	color = data.get('color',props.get('color','FFFFFF'))
	stability = data.get('stability',props.get('stability',1.0))
	capital = data.get('capital',props.get('capital','important_city'))