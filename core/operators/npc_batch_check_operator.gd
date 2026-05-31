@tool
class_name NpcBatchCheckOperator extends BaseOperator

# ── 配置参数（在 .tres 场景编辑器中设置） ──

## 从 Context 读取 NPC 列表的 Key
## 预期 context[participants_key] 是一个 Array[String]（NPC UUID 列表）
@export var participants_key: String = ""

## 战报写回 Context 的 Key
## 执行完成后，context[target_context_key] 会被赋值为拼接好的战报文本
@export var target_context_key: String = ""

## 要检定的属性名（如 "TALENT"、"HEALTH"）
## 从 NPCDocument.prop[check_prop] 动态获取
@export var check_prop: String = ""

## 话术模板前缀（如 "FEIHUALING"、"DRINK_BATTLE"）
## 翻译 Key 格式："{text_template}_SUCCESS" / "{text_template}_FAIL"
## 翻译文本示例：FEIHUALING_SUCCESS → "{npc_name} 巧妙地用上了【{keyword}】字，惊艳四座！"
##                 FEIHUALING_FAIL    → "{npc_name} 支支吾吾，半天憋不出一个字..."
## format_args 自动注入：npc_name（翻译后的 NPC 名）+ context 中所有字段
@export var text_template: String = ""


# ═══════════════════════════════════════════════════════════════════════
# 契约方法
# ═══════════════════════════════════════════════════════════════════════

func init(ctx: Dictionary) -> Dictionary:
	"""
	前置校验 + 批量检定 + 战报生成，全在 init 阶段完成。
	
	为什么不在 operate()？
	- operate() 不接收 context 参数，而 init() 可以拿到 context
	- 参考 ContextFetchOperators 模式：所有数据操作在 init 完成
	- context 是引用传递，init 中修改的 context 会保留到后续流程
	"""
	# ── 校验参数完整性 ──
	if participants_key.is_empty():
		Logging.err('NpcBatchCheckOperator.init: participants_key is empty — operator will do nothing')
		return ctx

	if target_context_key.is_empty():
		Logging.err('NpcBatchCheckOperator.init: target_context_key is empty — report will be lost')
		return ctx

	if check_prop.is_empty():
		Logging.err('NpcBatchCheckOperator.init: check_prop is empty — cannot determine what to check')
		return ctx

	if text_template.is_empty():
		Logging.err('NpcBatchCheckOperator.init: text_template is empty — translation keys will be malformed')
		return ctx

	# ── 校验 context 数据 ──
	if not ctx.has(participants_key):
		Logging.err('NpcBatchCheckOperator.init: context key "%s" not found — cannot read participants' % participants_key)
		return ctx

	var participants = ctx[participants_key]
	var is_array_type = (participants is Array) or (participants is PackedStringArray)
	if participants == null or not is_array_type:
		Logging.err('NpcBatchCheckOperator.init: context["%s"] is null or not an Array/PackedStringArray (got %s)' % [participants_key, typeof(participants)])
		return ctx

	# ═══════════════════════════════════════════════════════════════════
	# 核心业务逻辑：批量 NPC 检定 + 战报生成
	# ═══════════════════════════════════════════════════════════════════

	# Normalize: PackedStringArray → Array（后续所有操作统一走 Array）
	var npcs: Array = participants if participants is Array else Array(participants)
	if npcs.is_empty():
		Logging.warn('NpcBatchCheckOperator.init: participants list is empty — nothing to check')
		ctx[target_context_key] = ""
		return ctx

	var report_lines: PackedStringArray = []
	var total_npcs := 0
	var success_count := 0

	for npc_id in npcs:
		# 跳过玩家（玩家选项由 Provider 独立处理）
		if npc_id == "player":
			Logging.debug('NpcBatchCheckOperator.init: skipping "player" in batch check')
			continue

		total_npcs += 1

		# ── 1. 动态获取属性值 ──
		var stat_val = Database.query_prop(npc_id, check_prop)
		Logging.debug('NpcBatchCheckOperator.init: npc="%s", prop="%s", raw_val=%d' % [npc_id, check_prop, stat_val])

		# ── 2. 通用检定逻辑 ──
		var is_success = _universal_roll_dice(stat_val)

		# ── 3. 构建格式化字典 ──
		# 把 NPC 的翻译名（如 "libai" → "李白"）和原始 context 揉在一起
		var format_args = ctx.duplicate()
		format_args["npc_name"] = tr("CHAR_NAME_%s" % str(npc_id).to_upper())

		# ── 4. 使用泛用 Key，通过 format 传入具名参数 ──
		# 翻译文本示例：
		#   FEIHUALING_SUCCESS → "{npc_name} 巧妙地用上了【{keyword}】字，惊艳四座！"
		#   FEIHUALING_FAIL    → "{npc_name} 支支吾吾，半天憋不出一个字..."
		if is_success:
			success_count += 1
			var tr_key = "%s_SUCCESS" % text_template
			var line = tr(tr_key).format(format_args)
			report_lines.append(line)
			Logging.debug('NpcBatchCheckOperator.init: ✅ npc="%s" SUCCESS, tr_key="%s", line="%s"' % [npc_id, tr_key, line])
		else:
			var tr_key = "%s_FAIL" % text_template
			var line = tr(tr_key).format(format_args)
			report_lines.append(line)
			Logging.debug('NpcBatchCheckOperator.init: ❌ npc="%s" FAIL, tr_key="%s", line="%s"' % [npc_id, tr_key, line])

	# ── 写回 Context ──
	ctx[target_context_key] = "\n".join(report_lines)
	Logging.info('NpcBatchCheckOperator.init: ✅ done — %d/%d NPCs passed "%s" check, report (%d lines) written to context["%s"]' % [success_count, total_npcs, check_prop, report_lines.size(), target_context_key])

	return ctx


func operate() -> void:
	"""
	所有业务逻辑已在 init() 阶段完成，operate() 无需额外操作。
	
	参考 ContextFetchOperators 的 operate() 模式。
	"""
	pass


# ═══════════════════════════════════════════════════════════════════════
# 工具方法
# ═══════════════════════════════════════════════════════════════════════

func _universal_roll_dice(stat_val: int) -> bool:
	"""
	通用检定逻辑。
	
	以 stat_val 为成功率阈值，骰 0-99。
	stat_val 越高，成功概率越大。
	
	示例：
	  - stat_val=80  → 80% 成功率
	  - stat_val=30  → 30% 成功率
	  - stat_val=0   → 永远失败
	  - stat_val=100 → 永远成功（0-99 范围，100 = 100%）
	"""
	var roll = randi() % 100
	var result = roll < stat_val
	Logging.debug('_universal_roll_dice: roll=%d, threshold=%d -> %s' % [roll, stat_val, "SUCCESS" if result else "FAIL"])
	return result
