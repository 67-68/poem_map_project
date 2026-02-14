class_name MessagerData extends WorldEvent

var source_id: String
var target_id: String
var popup_text: String
var color: Color
var msger_uuid: String # msg本人的uuid, 留坑
# 可以和name不一样

var msger_type: int = 0
var speed: int

# 触发时间就直接用year

func _init(data: Dictionary):
	super._init(data)
	# 强制统一接口，别搞 properties 和 property 的二义性！
	var props = data.get("properties", {}) 
	
	if not props:
		props = data.get('property',{})
		Logging.err('哪里又在用property作为key')

	source_id = data.get('source_id', props.get('source_id', ''))
	target_id = data.get('target_id', props.get('target_id', ''))
	
	# 💀 加上你遗漏的这俩货！
	popup_text = data.get('popup_text', props.get('popup_text', ''))
	speed = data.get('speed', props.get('speed', 100)) # 默认给个基础速度
	
	color = Color.from_string(data.get('color', props.get('color', 'white')), Color.WHITE)
	msger_uuid = data.get('msger_uuid', props.get('msger_uuid', ''))
	msger_type = data.get('msger_type', props.get('msger_type', 0))

	# 优秀的架构师从不吝啬 Log 🤓☝️
	if source_id == "" or target_id == "":
		push_error("[MessagerData] 致命错误：数据缺少 source_id 或 target_id！Data: " + str(data))