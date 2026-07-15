extends RefCounted
## Simple Profile Operator 预览文本格式化器
##
## 为每个 Operator 类型提供简单版本描述，用于 HintProfile.SIMPLE 模式。
## 不调用 op.describe_preview()，不依赖 ModifierConfig，不展示知觉文本。
##
## Simple 规则：
##   PropertyOperator → 属性名 + 箭头（S/M/L → 1/2/3个），无数字，无知觉文本
##   TimeOperator     → ⏱N天
##   TraitOperator    → 获/失 + trait 名
##   PoemRewardOperator → mode→短标签（卖诗/以诗换名/携诗拜谒）
##   其他 Operator    → 返回 ""（不展示）

const _PropertyOperator = preload("res://core/model/property_operator.gd")


# ════════════════════════════════════════════════════════════════
# 公开接口
# ════════════════════════════════════════════════════════════════

## 将一列 BaseOperator 转为简单版 "{desc}" 字符串数组（无 • 前缀）。
static func build_simple_preview(operators: Array) -> Array[String]:
	var lines: Array[String] = []
	if operators.is_empty():
		return lines

	for op in operators:
		if not op:
			continue
		var desc := _simple_desc_for(op)
		if desc.is_empty():
			continue
		lines.append(desc)

	Logging.info("SimpleOperatorPreviewFormatter.build_simple_preview: %d operators → %d lines" % [operators.size(), lines.size()])
	return lines


# ════════════════════════════════════════════════════════════════
# 内部：按 Operator 类型分发
# ════════════════════════════════════════════════════════════════

static func _simple_desc_for(op) -> String:
	if op is _PropertyOperator:
		return _simple_property(op)
	if op is TimeOperator:
		return _simple_time(op)
	if op is TraitOperator:
		return _simple_trait(op)
	if op is PoemRewardOperator:
		return _simple_poem_reward(op)
	# 其他 Operator 类型在 simple 模式下不展示
	return ""


# ════════════════════════════════════════════════════════════════
# 简单描述实现
# ════════════════════════════════════════════════════════════════

## PropertyOperator: 「健康↑↑↑」— 属性名 + 箭头（复用 _get_arrow_count），无数字无知觉文本
static func _simple_property(pop) -> String:
	if pop.value == 0 or pop.property.is_empty():
		return ""

	var arrow_char = "↑" if pop.value > 0 else "↓"
	var arrow_count = _PropertyOperator._get_arrow_count(pop.property, pop.value)
	var arrows = ""
	for i in arrow_count:
		arrows += arrow_char

	# 直接使用 property 的 display_name（不包含数字和知觉文本）
	var prop = Database.get_property(pop.property)
	var cn_name = prop.get_display_name() if prop and not prop.name.is_empty() else pop.property

	return "%s%s" % [cn_name, arrows]


## TimeOperator: 「⏱5天」
static func _simple_time(top) -> String:
	if top.refresh_time or top.day <= 0:
		return ""
	return "⏱%d天" % int(top.day)


## TraitOperator: 「获 崴脚」/「失 中毒」
static func _simple_trait(top) -> String:
	if top.trait_key.is_empty():
		return ""
	var trait_obj = Database.get_trait(top.trait_key)
	var cn_name = trait_obj.name if trait_obj and not trait_obj.name.is_empty() else top.trait_key

	if top.operator == REQ_OPERATOR.CRUD.ADD:
		return "获 %s" % cn_name
	elif top.operator == REQ_OPERATOR.CRUD.REMOVE:
		return "失 %s" % cn_name
	return ""


## PoemRewardOperator: mode→短标签
static func _simple_poem_reward(pro) -> String:
	match pro.mode:
		"money":
			return "卖诗"
		"fame":
			return "以诗换名"
		"baiye":
			return "携诗拜谒"
		_:
			return "卖诗"