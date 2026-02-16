# 那种有立绘的Chat
class_name FocusedChat extends WorldEvent

enum ChatPosition {
	LEFT,
	RIGHT
}

var texture_left: Texture2D
var texture_right: Texture2D
var chats: Dictionary[String,int] # int -> ChatPosition

func _init(data: Dictionary):
	super._init(data)
	var props = data.get("properties", data.get("property", {}))

	var raw_texture_left = data.get('texture_left',props.get('texture_left',Global.DEFAULT_ICON))
	if raw_texture_left is Texture:
		texture_left = raw_texture_left
	elif raw_texture_left is String:
		texture_left = load(raw_texture_left)
	
	var raw_texture_right = data.get('texture_right',props.get('texture_right',Global.DEFAULT_ICON))
	if raw_texture_right is Texture:
		texture_right = raw_texture_right
	elif raw_texture_left is String:
		texture_right = load(raw_texture_right)
	
	var raw_chats = data.get('chats',props.get('chats',{}))
	for c in raw_chats:
		var pos := 0
		if raw_chats[c] is String:
			pos = ChatPosition.get(c,0)
		else: pos = raw_chats[c]
		chats[c] = pos
	