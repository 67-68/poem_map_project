class_name ActionArchetype extends Resource
const MicroDSLParser = preload("res://parser/micro_dsl_parser.gd")

var name: String = ""
var parent: String = ""
var universal_requirement: String = ""
var universal_result: String = ""
var era: String = ""
var failed_hints: Dictionary = {}

## 预解析的 PropertyOperator 列表（从 universal_result DSL 解析而来）
var operators: Array = []

## 工厂方法：从 JSON entry 创建 ActionArchetype 并预解析 DSL
static func from_json(data: Dictionary) -> ActionArchetype:
	var arch := ActionArchetype.new()
	arch.name = data.get("name", "")
	arch.parent = data.get("parent", "")
	arch.universal_requirement = data.get("universal_requirement", "")
	arch.universal_result = data.get("universal_result", "")
	arch.era = data.get("era", "")
	var hints = data.get("failed_hints", {})
	if hints is Dictionary:
		arch.failed_hints = hints.duplicate()
	
	# 预解析 universal_result DSL
	var dsl: String = arch.universal_result
	if not dsl.is_empty():
		var parsed = MicroDSLParser.parse_consequence_operators(dsl)
		for op in parsed:
			if op is PropertyOperator:
				arch.operators.append(op)
	
	return arch
