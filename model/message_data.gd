class_name MessagerData extends WorldEvent

var source_id: String
var target_id: String
var popup_text: String
var color: Color
var msger_uuid: String # msg本人的uuid, 留坑
# 可以和name不一样

var msger_type: int
var speed: int

# 触发时间就直接用year

func _init(data: Dictionary):
	super._init(data)
	var props = data.get("properties", data.get("property", {}))
	source_id = data.get('source_id', props.get('source_id', ''))
	target_id = data.get('target_id', props.get('target_id', ''))
	color = Color.from_string(data.get('color',props.get('color','white')),Color.WHITE)
	msger_uuid = data.get('msger_uuid',props.get('msger_uuid',''))
	msger_type = data.get('msger_type',props.get('msger_type',0))
