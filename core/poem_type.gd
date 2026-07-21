@tool
class_name PoemType extends GameEntity

@export var composition: Array[String] = [] # 狂放，隐逸和功名三个类型组成的size = 3 的列表
@export var publication_effects: Array[BuffOperator] = []

## 返回展平后的效果文本，每个 BuffOperator.describe_preview() 用换行连接
func get_effects_text() -> String:
	var texts: Array[String] = []
	for op in publication_effects:
		if op and op.has_method("describe_preview"):
			var desc = op.describe_preview()
			if not desc.is_empty():
				texts.append(desc)
	return "\n".join(texts)