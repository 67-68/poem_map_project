@tool
class_name PoemType extends GameEntity

@export var composition: Array[String] = [] # 狂放，隐逸和功名三个类型组成的size = 3 的列表
## V14: 从 Array[BuffOperator] 放宽为 Array[BaseOperator]，
## 支持 PropertyOperator（主导元素属性奖励）和 BuffOperator 混用。
@export var publication_effects: Array[BaseOperator] = []

## 返回展平后的效果文本，每个 BaseOperator.describe_preview() 用换行连接
func get_effects_text() -> String:
	var texts: Array[String] = []
	for op in publication_effects:
		if op and op.has_method("describe_preview"):
			var desc = op.describe_preview()
			if not desc.is_empty():
				texts.append(desc)
	return "\n".join(texts)