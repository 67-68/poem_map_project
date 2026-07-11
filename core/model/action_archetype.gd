class_name ActionArchetype extends Resource
const MicroDSLParser = preload("res://parser/micro_dsl_parser.gd")

## UUID 唯一标识（同时也是文件名）
@export var uuid: String = ""
## 显示名
@export var name: String = ""
## 父 archetype（保留字段）
@export var parent: String = ""
## 条件 DSL（保留字段）
@export var universal_requirement: String = ""
## 结果 DSL
@export var universal_result: String = ""
## 时代限制
@export var era: String = ""
## 对应行动 UUID
@export var action_uuid: String = ""
## 状态："" / "success" / "failure"
@export var state: String = ""
## 失败叙事提示（保留）
@export var failed_hints: Dictionary = {}

## 预解析的 BaseOperator 列表（从 universal_result DSL 解析而来）
var operators: Array = []

## 类型标签：cost / success / failure / defer
var subtype: String = ""

## 工厂方法：创建 ActionArchetype 并预解析 DSL
static func create(arch_key: String, name_str: String, act_uuid: String, arch_state: String, dsl: String, subtype_str: String) -> ActionArchetype:
	var arch := ActionArchetype.new()
	arch.uuid = arch_key
	arch.name = name_str
	arch.parent = ""
	arch.universal_requirement = ""
	arch.universal_result = dsl
	arch.era = ""
	arch.action_uuid = act_uuid
	arch.state = arch_state
	arch.subtype = subtype_str
	
	# 预解析 universal_result DSL → 保留所有有效的 BaseOperator
	var dsl_clean: String = dsl.strip_edges()
	if not dsl_clean.is_empty():
		var parsed = MicroDSLParser.parse_consequence_operators(dsl_clean)
		for op in parsed:
			if op == null:
				continue
			arch.operators.append(op)
	
	return arch
