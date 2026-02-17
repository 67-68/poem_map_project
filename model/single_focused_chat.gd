class_name FocusedChatLine extends GameEntity
enum ChatPosition {
	LEFT,
	RIGHT
}

# name 作为speaker_name
# description: text
var chat_position: int
var texture: Texture2D # 不用管上级的icon图标丢失

func _init(data: Dictionary):
	super._init(data)
	var props = data.get("properties", data.get("property", {}))
	var raw_tex = data.get('texture',props.get('texture',Global.DEFAULT_ICON_PATH))
	if raw_tex is Texture:
		texture = raw_tex
	elif raw_tex is String:
		if FileAccess.file_exists(Global.CHARACTER_PATH + raw_tex):
			raw_tex = Global.CHARACTER_PATH + raw_tex
		elif FileAccess.file_exists(Global.ICON_PATH + raw_tex):
			raw_tex = Global.ICON_PATH + raw_tex
		elif FileAccess.file_exists(raw_tex):
			pass
		else:
			raw_tex = Global.DEFAULT_ICON_PATH
		
		texture = load(raw_tex)
	
	var raw_chat_position = data.get('chat_position',props.get('chat_position'))
	if raw_chat_position is int: # enum or int
		chat_position = raw_chat_position
	else:		
		chat_position = ChatPosition[raw_chat_position]
