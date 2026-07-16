class_name ModifierRegistry extends RefCounted
## ModifierRegistry — 统一修饰器注册表查询门面
##
## 所有执行管线模块通过本类查询 GameSave.data.active_modifiers 注册表，
## 获取理念 buff + 修饰符属性（城府/才华/定力 S 型阻尼）的修正效果。
## 不直接读写注册表（由 BuffOperator / ModifierPropRegistrar 负责）。
##
## 查询方法命名规范：
##   get_<type>_<target>() — 返回给定上下文下的修饰值
##
## 约定：
##   - pct 类（efficiency/action_specific/cap_boost/relation_speed_pct）：
##     返回 float 倍率（0.2 = +20%），调用方乘到 delta 上
##   - abs 类（per_xun_passive/relation_speed_abs/npc_trade_tier）：
##     返回 int 绝对值，调用方直接加/减

const _NamedDSLParser = preload("res://parser/named_dsl_parser.gd")
const _ModifierFormula = preload("res://core/modifier_formula.gd")
const _ModifierConfig = preload("res://core/modifier_config.gd")


# ════════════════════════════════════════════════════════════════
# efficiency — 属性获取效率百分比加成
# ════════════════════════════════════════════════════════════════

## 返回指定属性的 efficiency 倍率总和。
## 例如 +20% 效率 = 返回 0.2。调用方在 append_stat 中将 delta ← delta × (1 + 总和)
static func get_efficiency_multiplier(prop_name: String) -> float:
	var total := 0.0
	for entry in GameSave.data.active_modifiers:
		if entry.get("type") != "efficiency":
			continue
		if not _condition_passes(entry):
			continue
		# efficiency 当前没有 prop 过滤（全局到所有 property）
		# 如果未来需要按 prop 过滤，添加 entry["target_prop"] 字段
		var pct_val: int = entry.get("value", 0)
		if pct_val > 0:
			total += float(pct_val) / 100.0
			Logging.info("ModifierRegistry.efficiency: source='%s' → +%.2f (累计 %.2f)" % [entry.get("source", "?"), float(pct_val) / 100.0, total])

	if total != 0.0:
		Logging.info("ModifierRegistry.efficiency: prop='%s' → 总倍率 %.2f" % [prop_name, total])
	return total


# ════════════════════════════════════════════════════════════════
# per_xun_passive — 每旬被动增长
# ════════════════════════════════════════════════════════════════

## 返回所有每旬被动增量的列表（每个条目: {prop_key, delta}）。
## prop_key 从 named_amount_key 中推断（如 "s_inspiration_gain" → "inspiration"）。
static func get_per_xun_passives() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for entry in GameSave.data.active_modifiers:
		if entry.get("type") != "per_xun_passive":
			continue
		if not _condition_passes(entry):
			continue

		var named_key: String = entry.get("named_key", "")
		var raw_val: int = entry.get("value", 0)
		if raw_val == 0:
			continue

		# 从 named_key 推断目标属性（约定: {size}_{prop}_{action}）
		var prop_key := _infer_prop_from_named_key(named_key)
		if prop_key.is_empty():
			Logging.warn("ModifierRegistry.per_xun_passive: 无法从 named_key='%s' 推断属性，跳过" % named_key)
			continue

		results.append({"prop": prop_key, "delta": raw_val})
		Logging.info("ModifierRegistry.per_xun_passive: source='%s' → %s %+d" % [entry.get("source", "?"), prop_key, raw_val])

	if not results.is_empty():
		Logging.info("ModifierRegistry.per_xun_passive: 共 %d 条每旬被动" % results.size())
	return results


# ════════════════════════════════════════════════════════════════
# action_specific — 特定行动的属性加成百分比
# ════════════════════════════════════════════════════════════════

## 返回当前 action 下指定属性的特定行动倍率总和。
## condition 为 ActionMatchRequirement 时才生效。
static func get_action_specific_multiplier(action_id: String, prop_name: String) -> float:
	var total := 0.0
	for entry in GameSave.data.active_modifiers:
		if entry.get("type") != "action_specific":
			continue
		if not _condition_passes_for_action(entry, action_id):
			continue
		var pct_val: int = entry.get("value", 0)
		if pct_val > 0:
			total += float(pct_val) / 100.0
			Logging.info("ModifierRegistry.action_specific: source='%s' action='%s' → +%.2f (累计 %.2f)" % [entry.get("source", "?"), action_id, float(pct_val) / 100.0, total])

	if total != 0.0:
		Logging.info("ModifierRegistry.action_specific: action='%s', prop='%s' → 总倍率 %.2f" % [action_id, prop_name, total])
	return total


# ════════════════════════════════════════════════════════════════
# cap_boost — 属性上限百分比加成
# ════════════════════════════════════════════════════════════════

## 返回指定属性的 cap_boost 倍率总和。
## 调用方（Property）将 hard_max ← int(hard_max × (1 + 总和))
static func get_cap_boost(prop_name: String) -> float:
	var total := 0.0
	for entry in GameSave.data.active_modifiers:
		if entry.get("type") != "cap_boost":
			continue
		if not _condition_passes(entry):
			continue
		var pct_val: int = entry.get("value", 0)
		if pct_val > 0:
			total += float(pct_val) / 100.0
			Logging.info("ModifierRegistry.cap_boost: source='%s' → +%.2f (累计 %.2f)" % [entry.get("source", "?"), float(pct_val) / 100.0, total])

	if total != 0.0:
		Logging.info("ModifierRegistry.cap_boost: prop='%s' → 总倍率 %.2f" % [prop_name, total])
	return total


# ════════════════════════════════════════════════════════════════
# relation_speed — NPC 关系升级速度修正
# ════════════════════════════════════════════════════════════════

## 返回关系速度的修正值。
## relation_speed_pct: 返回倍率（0.5 = 需求减半），调用方乘到需求上
## relation_speed_abs: 返回绝对旬数减少，调用方从需求中减去
##
## @param target_tag: NPC 的 target_tag
## @return {pct: float, abs: int} — 两种类型的修正值
static func get_relation_speed(target_tag: String) -> Dictionary:
	var result := {"pct": 0.0, "abs": 0}
	for entry in GameSave.data.active_modifiers:
		var mod_type: String = entry.get("type", "")
		if mod_type not in ["relation_speed_pct", "relation_speed_abs"]:
			continue
		if not _condition_passes_for_npc(entry, target_tag):
			continue
		var raw_val: int = entry.get("value", 0)
		if raw_val == 0:
			continue

		if mod_type == "relation_speed_pct":
			result.pct += float(raw_val) / 100.0
			Logging.info("ModifierRegistry.relation_speed: source='%s' pct → -%.2f" % [entry.get("source", "?"), float(raw_val) / 100.0])
		elif mod_type == "relation_speed_abs":
			result.abs += raw_val
			Logging.info("ModifierRegistry.relation_speed: source='%s' abs → -%d" % [entry.get("source", "?"), raw_val])

	if result.pct != 0.0 or result.abs != 0:
		Logging.info("ModifierRegistry.relation_speed: target='%s' → pct=%.2f, abs=%d" % [target_tag, result.pct, result.abs])
	return result


# ════════════════════════════════════════════════════════════════
# npc_trade_tier — NPC 交易档次提升（TODO 集成点）
# ════════════════════════════════════════════════════════════════

## 🚧 TODO: NPC 交易系统尚未实现。
## 返回指定 faction 的交易档次提升数（步进值）。
## 待交易系统实现后，调用方在计算 NPC 提供的内容档次时加上此值。
static func get_npc_trade_tier_boost(faction: String) -> int:
	var total := 0
	for entry in GameSave.data.active_modifiers:
		if entry.get("type") != "npc_trade_tier":
			continue
		if not _condition_passes_for_faction(entry, faction):
			continue
		total += entry.get("value", 0)
		Logging.info("ModifierRegistry.npc_trade_tier: source='%s' faction='%s' → +%d档 (累计 %d)" % [entry.get("source", "?"), faction, entry.get("value", 0), total])

	if total != 0:
		Logging.info("ModifierRegistry.npc_trade_tier: faction='%s' → 总档位提升 %d" % [faction, total])
	return total


# ════════════════════════════════════════════════════════════════
# modifier_prop_effect — 修饰符属性 S 型阻尼（城府/才华/定力）
# ════════════════════════════════════════════════════════════════

## 🆕 从 active_modifiers 查询 type="modifier_prop_effect" 的条目，
## 对给定属性的 raw_delta 应用链式 amplify/dampen 修正。
##
## 替代了旧 ModifierConfig.apply_all_matching_effects()，
## 统一走注册表查询入口。
##
## @param stat_name: 属性名（如 "prestige"）
## @param raw_delta: 当前累积的变化量
## @return int — 修正后的变化量
static func get_modifier_prop_adjusted_delta(stat_name: String, raw_delta: int) -> int:
	if raw_delta == 0:
		Logging.debug("[ModifierRegistry] get_modifier_prop_adjusted_delta: raw_delta=0 → no-op")
		return 0

	var adjusted: int = raw_delta
	var delta_is_positive: bool = raw_delta > 0
	var delta_is_negative: bool = raw_delta < 0

	# 🆕 faction 上下文懒加载（仅在有 faction_filter 条目时解析）
	var faction: int = -1
	var faction_str: String = ""

	var entry_count := 0
	for entry in GameSave.data.active_modifiers:
		if entry.get("type") != "modifier_prop_effect":
			continue

		var target_prop: String = entry.get("target_prop", "")
		var delta_sign: String = entry.get("delta_sign", "")
		var faction_filter: String = entry.get("faction_filter", "")
		var direction: String = entry.get("direction", "")
		var mod_val: int = entry.get("mod_val", 0)
		var max_limit: float = entry.get("max_limit", 0.0)
		var half_point: float = entry.get("half_point", 0.0)

		# ── 1. target_prop 过滤 ──
		if not target_prop.is_empty() and target_prop != stat_name:
			Logging.debug("[ModifierRegistry] get_modifier_prop_adjusted_delta: entry source='%s' target_prop='%s' ≠ stat='%s' → skip" % [entry.get("source", "?"), target_prop, stat_name])
			continue

		# ── 2. delta_sign 过滤 ──
		if delta_sign == "positive" and not delta_is_positive:
			Logging.debug("[ModifierRegistry] get_modifier_prop_adjusted_delta: entry source='%s' delta_sign=positive but raw_delta=%d → skip" % [entry.get("source", "?"), raw_delta])
			continue
		if delta_sign == "negative" and not delta_is_negative:
			Logging.debug("[ModifierRegistry] get_modifier_prop_adjusted_delta: entry source='%s' delta_sign=negative but raw_delta=%d → skip" % [entry.get("source", "?"), raw_delta])
			continue

		# ── 3. faction_filter 过滤 ──
		if not faction_filter.is_empty():
			if faction == -1:
				faction = _ModifierConfig.get_faction_from_context()
				faction_str = _ModifierConfig.faction_to_filter(faction)
			if faction_str != faction_filter:
				Logging.debug("[ModifierRegistry] get_modifier_prop_adjusted_delta: entry source='%s' faction_filter=%s but current=%s → skip" % [entry.get("source", "?"), faction_filter, faction_str])
				continue

		# ── 4. mod_val ≤ 0 跳过 ──
		if mod_val <= 0:
			Logging.debug("[ModifierRegistry] get_modifier_prop_adjusted_delta: entry source='%s' mod_val=%d ≤ 0 → skip" % [entry.get("source", "?"), mod_val])
			continue

		# ── 5. 应用公式 ──
		entry_count += 1
		if direction == "amplify":
			adjusted = _ModifierFormula.amplify(adjusted, mod_val, max_limit, half_point)
		else:
			adjusted = _ModifierFormula.dampen(adjusted, mod_val, max_limit, half_point)

		Logging.info("[ModifierRegistry] get_modifier_prop_adjusted_delta: entry source='%s' target='%s' dir=%s mod_val=%d → raw=%d adjusted=%d" % [entry.get("source", "?"), target_prop, direction, mod_val, raw_delta, adjusted])

	if entry_count == 0:
		Logging.debug("[ModifierRegistry] get_modifier_prop_adjusted_delta: stat='%s' raw_delta=%d → no matching modifier_prop_effect entries found" % [stat_name, raw_delta])
	elif adjusted != raw_delta:
		Logging.info("[ModifierRegistry] get_modifier_prop_adjusted_delta: stat='%s' raw_delta=%d → final=%d (%d entries applied)" % [stat_name, raw_delta, adjusted, entry_count])

	return adjusted


# ════════════════════════════════════════════════════════════════
# 内部工具
# ════════════════════════════════════════════════════════════════

## 检查 entry 的 condition（无条件/全局条件）
static func _condition_passes(entry: Dictionary) -> bool:
	var cond = entry.get("condition")
	if cond == null:
		return true  # 无条件 = 全局生效
	if cond is BaseRequirements:
		var passes = cond.compare()
		Logging.debug("ModifierRegistry._condition_passes: cond=%s → %s" % [cond.describe_requirement(), passes])
		return passes
	# condition 保存为 Dictionary 时（反序列化后），无条件通过（兜底）
	return true


## 检查 entry 的 condition 是否匹配指定 action_id
static func _condition_passes_for_action(entry: Dictionary, action_id: String) -> bool:
	var cond = entry.get("condition")
	if cond == null:
		return true
	if cond is ActionMatchRequirement:
		var passes = cond.action_id == action_id
		Logging.debug("ModifierRegistry._condition_passes_for_action: cond=ActionMatchRequirement(%s) action='%s' → %s" % [cond.action_id, action_id, passes])
		return passes
	if cond is BaseRequirements:
		return cond.compare()
	return true


## 检查 entry 的 condition 是否匹配指定 NPC target_tag
static func _condition_passes_for_npc(entry: Dictionary, target_tag: String) -> bool:
	var cond = entry.get("condition")
	if cond == null:
		return true
	# relation_speed 的 condition 通常是 NPCFactionRequirement 或 NPCTierRequirement
	if cond is BaseRequirements:
		var passes = cond.compare()
		Logging.debug("ModifierRegistry._condition_passes_for_npc: target='%s' cond='%s' → %s" % [target_tag, cond.describe_requirement(), passes])
		return passes
	return true


## 检查 entry 的 condition 是否匹配指定 faction
static func _condition_passes_for_faction(entry: Dictionary, faction: String) -> bool:
	var cond = entry.get("condition")
	if cond == null:
		return true
	if cond is NPCFactionRequirement:
		return cond.faction == faction
	if cond is BaseRequirements:
		return cond.compare()
	return true


## 从 named_amount_key 推断目标属性名。
## 约定: {size}_{prop}_{action} 或 {size}_{prop}_{kind}
## 例如 "s_inspiration_gain" → "inspiration", "s_talent_gain" → "talent"
static func _infer_prop_from_named_key(key: String) -> String:
	var known_props := ["prestige", "inspiration", "talent", "momentum", "composure", "astuteness", "money", "health", "progress"]
	var lower := key.to_lower()
	for prop in known_props:
		if prop in lower:
			return prop
	return ""
