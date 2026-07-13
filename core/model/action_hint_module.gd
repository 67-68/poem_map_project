class_name ActionHintModule extends RefCounted
## 向量层的一个结构化模块
##
## title: 模块标题（如 "━━━ 可行性 ━━━"），空字符串表示无标题
## lines: 模块内的文本行

var title: String
var lines: Array[String] = []

func _init(p_title: String = ""):
	title = p_title

## 追加一行
func append(line: String) -> void:
	lines.append(line)

## 追加多行
func append_array(arr: Array[String]) -> void:
	lines.append_array(arr)

## 是否为空
func is_empty() -> bool:
	return lines.is_empty()

## 转 BBCode 字符串（仅 lines 不为空时输出 title + lines）
func to_bbcode() -> String:
	if lines.is_empty():
		return ""
	var parts: Array[String] = []
	if not title.is_empty():
		parts.append(title)
	parts.append_array(lines)
	return "\n".join(parts)
