@tool
class_name BuffOperator extends BaseOperator
## BuffOperator — 理念 Buff 操作器（注册表模式）
##
## 不再直接操作属性值。改为在 GameSave.data.active_modifiers 中
## 注册/注销修饰器条目，由各执行管线模块查询注册表来产生实际效果。
##
## modifier_type 取值：
##   efficiency         — 属性获取效率百分比加成 (pct)
##   per_xun_passive    — 每旬被动增长 (abs)
##   action_specific    — 特定行动的属性加成百分比 (pct)
##   cap_boost          — 属性上限百分比加成 (pct)
##   relation_speed_pct — NPC 关系需求百分比减免 (pct)
##   relation_speed_abs — NPC 关系需求绝对旬数减少 (abs)
##   npc_trade_tier     — NPC 交易档次步进 (abs) — TODO 集成点
##   damage_reduction   — 属性扣除百分比减免 (pct，对负 delta 生效)
##
## condition 是 nullable 的 BaseRequirements，用于运行时条件匹配。
## 例如 ActionMatchRequirement(action="denggao_shaolingyuan") 要求
## 当前 action_id 匹配时才生效。

@export var named_amount_key: String = ""       # named_amounts.json 的 key
@export var modifier_type: String = ""           # efficiency|per_xun_passive|action_specific|cap_boost|relation_speed_pct|relation_speed_abs|npc_trade_tier|damage_reduction
@export var condition: BaseRequirements = null   # nullable — DSL requirement 条件

## 🆕 目标属性过滤（空字符串=全局生效）。efficiency/damage_reduction 类型可用。
@export var target_prop: String = ""

## 🆕 最大使用次数（>0 启用，每次 append_stat 触发后 ModifierRegistry.consume_max_uses 递减）
## 减至 0 时自动移除该 modifier 条目和对应 trait。
@export var max_uses: int = 0

## 运行时由 Idea.increase_idea_level() 注入，标识此 buff 的来源理念 UUID
var source_uuid: String = ""


func operate():
	if named_amount_key.is_empty():
		Logging.err("BuffOperator.operate: named_amount_key 为空，跳过执行")
		return
	if modifier_type.is_empty():
		Logging.err("BuffOperator.operate: modifier_type 为空，跳过执行")
		return
	if source_uuid.is_empty():
		Logging.err("BuffOperator.operate: source_uuid 为空（Idea 未注入），跳过执行")
		return

	var amounts: Dictionary = NamedDSLParser._load_named_amounts()
	if not amounts.has(named_amount_key):
		Logging.err("BuffOperator.operate: named_amount_key='%s' 在 named_amounts.json 中不存在，跳过" % named_amount_key)
		return

	var entry := {
		"source": source_uuid,
		"type": modifier_type,
		"named_key": named_amount_key,
		"value": amounts[named_amount_key],
		"condition": condition.duplicate() if condition else null,
		"target_prop": target_prop,
		"max_uses": max_uses,
		"uses_remaining": max_uses,
	}

	GameSave.data.active_modifiers.append(entry)
	Logging.info("BuffOperator.operate: 注册修饰器 — source='%s', type='%s', named_key='%s', value=%s" % [source_uuid, modifier_type, named_amount_key, str(amounts[named_amount_key])])


func on_exit(_context: Dictionary) -> Dictionary:
	if source_uuid.is_empty():
		Logging.warn("BuffOperator.on_exit: source_uuid 为空，无法精确删除，按 modifier_type + named_key 模糊删除")
		_remove_by_type_key(modifier_type, named_amount_key)
		return _context

	var removed := 0
	var remaining: Array[Dictionary] = []
	for entry in GameSave.data.active_modifiers:
		if entry.get("source") == source_uuid and entry.get("type") == modifier_type and entry.get("named_key") == named_amount_key:
			removed += 1
			Logging.info("BuffOperator.on_exit: 注销修饰器 — source='%s', type='%s', named_key='%s'" % [source_uuid, modifier_type, named_amount_key])
		else:
			remaining.append(entry)

	# 如果没有精确匹配，尝试模糊删除
	if removed == 0:
		Logging.warn("BuffOperator.on_exit: 未找到精确匹配条目 (source='%s', type='%s', named_key='%s')，尝试模糊删除" % [source_uuid, modifier_type, named_amount_key])
		_remove_by_type_key(modifier_type, named_amount_key)
	else:
		GameSave.data.active_modifiers = remaining

	Logging.info("BuffOperator.on_exit: 清理完成，移除了 %d 个条目，剩余 %d 个" % [removed, GameSave.data.active_modifiers.size()])
	return _context


func _remove_by_type_key(mod_type: String, named_key: String) -> void:
	var remaining: Array[Dictionary] = []
	var removed := 0
	for entry in GameSave.data.active_modifiers:
		if entry.get("type") == mod_type and entry.get("named_key") == named_key:
			removed += 1
		else:
			remaining.append(entry)
	if removed > 0:
		GameSave.data.active_modifiers = remaining
		Logging.info("BuffOperator._remove_by_type_key: 模糊删除了 %d 个条目 (type='%s', named_key='%s')" % [removed, mod_type, named_key])


func init(_context: Dictionary) -> Dictionary:
	if named_amount_key.is_empty():
		Logging.warn("BuffOperator.init: named_amount_key 为空，跳过验证")
		return _context

	var amounts = NamedDSLParser._load_named_amounts()
	if not amounts.has(named_amount_key):
		Logging.err("BuffOperator.init: named_amount_key='%s' 在 named_amounts.json 中不存在，buff 可能在运行时失效" % named_amount_key)
	else:
		Logging.debug("BuffOperator.init: named_amount_key='%s' 验证通过 (value=%s)" % [named_amount_key, str(amounts[named_amount_key])])
	return _context


func describe_preview() -> String:
	if named_amount_key.is_empty() or modifier_type.is_empty():
		return ""

	var amounts: Dictionary = NamedDSLParser._load_named_amounts()
	var raw_val = amounts.get(named_amount_key, 0)

	var type_cn := ""
	var display_val := ""
	match modifier_type:
		"efficiency":
			type_cn = tr("CODE_BUFF_OPERATOR_0A676BE9DE")
			display_val = "+%d%%" % raw_val
		"per_xun_passive":
			type_cn = tr("CODE_BUFF_OPERATOR_27D874C137")
			display_val = "%+d" % raw_val
		"action_specific":
			type_cn = tr("CODE_BUFF_OPERATOR_2D602CA4EF")
			display_val = "+%d%%" % raw_val
		"cap_boost":
			type_cn = tr("CODE_BUFF_OPERATOR_8E7DDBEEE3")
			display_val = "+%d%%" % raw_val
		"relation_speed_pct":
			type_cn = tr("CODE_BUFF_OPERATOR_1DD5A83A65")
			display_val = "-%d%%" % raw_val
		"relation_speed_abs":
			type_cn = tr("CODE_BUFF_OPERATOR_33564A7B86")
			display_val = tr("CODE_BUFF_OPERATOR_0B15CFDD12") % raw_val
		"npc_trade_tier":
			type_cn = tr("CODE_BUFF_OPERATOR_A22B5ACD70")
			display_val = tr("CODE_BUFF_OPERATOR_66D1B869F2") % raw_val
		"damage_reduction":
			type_cn = "伤害减免"
			display_val = "-%d%%" % raw_val
		_:
			return "%s %s=%s" % [modifier_type, named_amount_key, str(raw_val)]

	# 如果有 condition，附加条件描述
	var cond_text := ""
	if condition:
		cond_text = " (" + condition.describe_requirement() + ")"

	return "%s %s%s" % [type_cn, display_val, cond_text]


func get_referenced_props() -> Array:
	return []


func get_demanded_props() -> Array:
	return []
