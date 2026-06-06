class_name FocusedChatLine extends Resource
enum ChatPosition {
	LEFT,
	RIGHT
}

# name 作为speaker_name
# description: text
@export var name: String
@export var description: String
@export var chat_position: ChatPosition
@export var texture: Texture2D # 不用管上级的icon图标丢失