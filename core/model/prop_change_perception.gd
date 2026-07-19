class_name PropChangePerceptionData extends Resource

## 变化量下限 (包含)
@export var min_delta: int = 0
## 变化量上限 (包含)
@export var max_delta: int = 999
## 属性增加时显示的文本
@export var gain_text: String = ""
## 属性减少时显示的文本
@export var loss_text: String = ""

func get_text(delta: int) -> String:
	var raw := gain_text if delta > 0 else loss_text
	return tr(raw) if not raw.is_empty() else raw
