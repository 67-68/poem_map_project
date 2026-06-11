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
@export var background: Texture2D # 当前句的背景图; null = 延续上一张

## 当前句执行时触发的操作符（动画、属性修改等）
## 在 FocusChatOverlay._show_current_line() 渲染此句后同步执行
@export var operators: Array[BaseOperator] = []

## 执行当前行的所有 operator
## 在 FocusChatOverlay._show_current_line() 中被调用
func execute_operators(context: Dictionary) -> void:
	if operators.is_empty():
		return
	for op in operators:
		if op:
			op.init(context)
			op.operate()
		else:
			Logging.warn("FocusedChatLine.execute_operators: 发现空 operator")