class_name ActionHint extends RefCounted
## Action hint 完整结构化输出
##
## 用法（consumer）：
##   var hint = ActionHintFormatter.build_action_hint(action, is_locked, ctx)
##   HoverPopupManager.register(self, {"narrative": hint.narrative, "vector": hint.vector}, ...)
##
## 新 consumer 可直接访问 hint.cost.lines / hint.output.title 等结构化字段。

const _ActionHintModule = preload("res://core/model/action_hint_module.gd")

var narrative: String = ""
var feasibility
var cost
var output
var risk
var other

## 供 SIMPLE profile 使用的标签文本字典（由 ActionHintFormatter 填充）
## 键: "feasibility", "cost", "output", "risk"
var simple_labels: Dictionary = {}

var _vector: String = ""
var _vector_dirty: bool = true

func _init():
	feasibility = _ActionHintModule.new("")
	cost = _ActionHintModule.new("")
	output = _ActionHintModule.new("")
	risk = _ActionHintModule.new("")
	other = _ActionHintModule.new("")

## 标记 vector 为脏态，下次访问时重建
func mark_dirty() -> void:
	_vector_dirty = true

## vector 懒拼接：按模块顺序拼接非空模块
var vector: String:
	get:
		if _vector_dirty:
			_vector = _build_vector()
			_vector_dirty = false
		return _vector

func _build_vector() -> String:
	var parts: Array[String] = []
	var mods := [feasibility, cost, output, risk, other]
	for mod in mods:
		var bb = mod.to_bbcode()
		if not bb.is_empty():
			parts.append(bb)
	return "\n".join(parts)

## 构建兼容 Dictionary（用于旧 consumer 过渡）
func to_dict() -> Dictionary:
	return { "narrative": narrative, "vector": vector }
