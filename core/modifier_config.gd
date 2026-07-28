class_name ModifierConfig extends RefCounted
## 修饰符属性效果配置表 + NPC 派系映射
##
## 三条修饰符属性：
##   ASTUTENESS (城府) — 克制外部消耗，稳中求利
##   TALENT     (才华) — 放大声望/诗词产出，减免清流成本
##   COMPOSURE  (定力) — 克制情绪波动和身体损耗
##
## 8 条效果全部在此配置，无硬编码 if。


# ════════════════════════════════════════════════════════════════
# NPC 派系映射（target_tag → faction）
# ════════════════════════════════════════════════════════════════

enum Faction {
	QINGLIU,   # 清流
	ZHUOLIU,   # 浊流
	NEUTRAL,   # 中立（市井/商贩/平民，无党派效果）
}

## NPC target_tag（ENUMS.to_relation_str() 的小写结果）→ Faction
const NPC_FACTION_MAP: Dictionary = {
	"libai":       Faction.QINGLIU,
	"gaoshi":      Faction.QINGLIU,
	"wangwei":     Faction.QINGLIU,
	"zhengqian":   Faction.QINGLIU,
	"qingliu":     Faction.QINGLIU,
	"hushang":     Faction.NEUTRAL,
	"lilinfu":     Faction.ZHUOLIU,
	"jiwen":       Faction.ZHUOLIU,
	"youxiangfu":  Faction.ZHUOLIU,
	"yangguozhong":Faction.ZHUOLIU,
	"guoguofuren": Faction.ZHUOLIU,
	"waiqi":       Faction.ZHUOLIU,
}


# ════════════════════════════════════════════════════════════════
# 修饰符效果配置表
#
# 结构: Array[Dictionary] — 每条效果定义:
#   source_prop:    修改符属性名（如 "astuteness"）
#   target_prop:    受影响属性名（"" = 任意/不限定）
#   direction:      "amplify" | "dampen"
#   delta_sign:     "positive" | "negative" | "any" — 仅对应符号的 delta 触发
#   faction_filter: "" | "qingliu" | "zhuoliu" — 空=无 faction 要求
#   max_limit:      float — 公式渐进上限
#   half_point:     float — 公式半效点
#   hint_text:      String — UI 展示文本模板（{mod_val} 替换为实际值）
# ════════════════════════════════════════════════════════════════

static var MODIFIER_EFFECTS: Array[Dictionary] = [
	# ── 城府 ASTUTENESS ──
	{
		source_prop = "astuteness",
		target_prop = "momentum",
		direction = "dampen",
		delta_sign = "negative",
		faction_filter = "",
		max_limit = 0.8,
		half_point = 20.0,
		hint_text = "CODE_MODIFIER_CONFIG_79A843720B",
	},
	{
		source_prop = "astuteness",
		target_prop = "prestige",
		direction = "dampen",
		delta_sign = "positive",
		faction_filter = "",
		max_limit = 0.5,
		half_point = 25.0,
		hint_text = "CODE_MODIFIER_CONFIG_78ACB44470",
	},
	{
		source_prop = "astuteness",
		target_prop = "",
		direction = "dampen",
		delta_sign = "negative",
		faction_filter = "zhuoliu",
		max_limit = 0.5,
		half_point = 25.0,
		hint_text = "CODE_MODIFIER_CONFIG_27F59B3B2C",
	},
	{
		source_prop = "astuteness",
		target_prop = "money",
		direction = "amplify",
		delta_sign = "positive",
		faction_filter = "",
		max_limit = 0.3,
		half_point = 30.0,
		hint_text = "CODE_MODIFIER_CONFIG_5A9DF0C8BE",
	},

	# ── 才华 TALENT ──
	{
		source_prop = "talent",
		target_prop = "prestige",
		direction = "amplify",
		delta_sign = "positive",
		faction_filter = "",
		max_limit = 0.5,
		half_point = 25.0,
		hint_text = "CODE_MODIFIER_CONFIG_6437EEB330",
	},
	{
		source_prop = "talent",
		target_prop = "",
		direction = "dampen",
		delta_sign = "negative",
		faction_filter = "qingliu",
		max_limit = 0.5,
		half_point = 25.0,
		hint_text = "CODE_MODIFIER_CONFIG_0B0EC74089",
	},

	# ── 定力 COMPOSURE ──
	{
		source_prop = "composure",
		target_prop = "inspiration",
		direction = "dampen",
		delta_sign = "positive",
		faction_filter = "",
		max_limit = 0.5,
		half_point = 25.0,
		hint_text = "CODE_MODIFIER_CONFIG_BCACFF08CC",
	},
	{
		source_prop = "composure",
		target_prop = "health",
		direction = "dampen",
		delta_sign = "negative",
		faction_filter = "",
		max_limit = 0.6,
		half_point = 20.0,
		hint_text = "CODE_MODIFIER_CONFIG_6A9F4227A3",
	},
]


# ════════════════════════════════════════════════════════════════
# 公开 API
# ════════════════════════════════════════════════════════════════

## 从当前上下文解析当前交互 NPC 的派系。
## 优先级: last_event.target_tag > current_action_tags 中的 actor:npc:* 标签
## @return Faction enum 值，无匹配时返回 Faction.NEUTRAL
static func get_faction_from_context() -> int:
	# 1. 从 last_event 取 target_tag
	var target_tag: String = PlayerState.last_event.get("target_tag", "")
	if not target_tag.is_empty():
		var faction := _tag_to_faction(target_tag)
		if faction != Faction.NEUTRAL:
			Logging.info("[ModifierConfig] get_faction_from_context: last_event.target_tag='%s' → faction=%d" % [target_tag, faction])
			return faction

	# 2. 从 current_action_tags 中提取 actor:npc:* 标签
	for tag in PlayerState.current_action_tags:
		if tag.begins_with("actor:npc:"):
			var npc_tag := tag.replace("actor:npc:", "")
			var faction := _tag_to_faction(npc_tag)
			Logging.info("[ModifierConfig] get_faction_from_context: current_action_tag='%s' → npc_tag='%s' → faction=%d" % [tag, npc_tag, faction])
			return faction

	Logging.debug("[ModifierConfig] get_faction_from_context: 无 NPC 上下文 → NEUTRAL")
	return Faction.NEUTRAL


## 获取派系的字符串标识（用于配置表匹配）
static func faction_to_filter(faction: int) -> String:
	match faction:
		Faction.QINGLIU: return "qingliu"
		Faction.ZHUOLIU: return "zhuoliu"
		_: return ""


## 获取修饰符属性当前值
static func get_modifier_val(source_prop: String) -> int:
	return PlayerState.get_stat_val(source_prop) as int


## 计算修饰符产生的倍率百分比（用于 UI 展示）
## @return 0.0~1.0 之间的百分比值
static func get_pct_for_display(source_prop: String, max_limit: float, half_point: float) -> float:
	var mod_val := get_modifier_val(source_prop)
	if mod_val <= 0:
		return 0.0
	var pct := max_limit * float(mod_val) / (half_point + float(mod_val))
	return pct


## 🆕 给定属性名和原始 delta，返回 UI 预览注解。
## 每条注解格式: "城府 -8" 或 "才华 +12"
## 用于 ActionHintBuilder 在消耗/收益预览中展示修饰符的影响。
##
## @param prop_name: 属性名（如 "money"）
## @param raw_delta: 原始变化量（如 -40）
## @return Array[String] — 如 ["城府 -8"]，无匹配时返回空数组
func get_preview_annotations(prop_name: String, raw_delta: int) -> Array[String]:
	if raw_delta == 0:
		return []

	var annotations: Array[String] = []
	var delta_is_positive := raw_delta > 0
	var delta_is_negative := raw_delta < 0

	# 先确定当前 NPC 派系
	var faction: int = -1
	var faction_str: String = ""

	# 按 source_prop 聚合每个修饰符的独立贡献
	var per_prop: Dictionary = {}

	for effect in MODIFIER_EFFECTS:
		var target_prop: String = effect.target_prop
		var delta_sign: String = effect.delta_sign
		var faction_filter: String = effect.faction_filter
		var source_prop: String = effect.source_prop

		# ── 过滤 ──
		if not target_prop.is_empty() and target_prop != prop_name:
			continue
		if delta_sign == "positive" and not delta_is_positive:
			continue
		if delta_sign == "negative" and not delta_is_negative:
			continue
		if not faction_filter.is_empty():
			if faction == -1:
				faction = get_faction_from_context()
				faction_str = faction_to_filter(faction)
			if faction_str != faction_filter:
				continue

		# ── 修饰符值 ──
		var mod_val: int = get_modifier_val(source_prop)
		if mod_val <= 0:
			continue

		# ── 独立计算该效果对 raw_delta 的影响 ──
		var adjusted: int
		if effect.direction == "amplify":
			adjusted = ModifierFormula.amplify(raw_delta, mod_val, effect.max_limit, effect.half_point)
		else:
			adjusted = ModifierFormula.dampen(raw_delta, mod_val, effect.max_limit, effect.half_point)

		var diff := adjusted - raw_delta
		if diff == 0:
			continue

		if not per_prop.has(source_prop):
			per_prop[source_prop] = 0
		per_prop[source_prop] += diff

	# ── 构建注解文本 ──
	var display_names := {
		"astuteness": tr("TRES_ASTUTENESS_NAME_0"),
		"talent": tr("CODE_MODIFIER_HINT_FORMATTER_0288A3D9E2"),
		"composure": tr("TRES_COMPOSURE_NAME_0"),
	}

	for sp in per_prop:
		var d: int = per_prop[sp]
		var name = display_names.get(sp, sp)
		var sign = "+" if d > 0 else ""
		annotations.append("%s %s%d" % [name, sign, d])

	return annotations


# ════════════════════════════════════════════════════════════════
# 内部
# ════════════════════════════════════════════════════════════════

static func _tag_to_faction(tag: String) -> int:
	return NPC_FACTION_MAP.get(tag.to_lower(), Faction.NEUTRAL)


## 🆕 根据配置表对单个属性 delta 应用所有匹配的修饰符公式。
## 供 PlayerState._apply_modifier_formula() 和 ActionManager.check_archetype_property_costs() 复用。
##
## @param stat_name: 属性名（如 "prestige"）
## @param raw_delta: 当前累积的变化量
## @return int — 修正后的变化量
func apply_all_matching_effects(stat_name: String, raw_delta: int) -> int:
	if raw_delta == 0:
		Logging.debug("[ModifierConfig] apply_all_matching_effects: raw_delta=0 → no-op")
		return 0

	var adjusted: int = raw_delta
	var delta_is_positive: bool = raw_delta > 0
	var delta_is_negative: bool = raw_delta < 0

	# 先确定当前 NPC 派系（仅在有消耗减免效果需要时懒加载）
	var faction: int = -1
	var faction_str: String = ""

	for effect in MODIFIER_EFFECTS:
		var source_prop: String = effect.source_prop
		var target_prop: String = effect.target_prop
		var direction: String = effect.direction
		var delta_sign: String = effect.delta_sign
		var faction_filter: String = effect.faction_filter

		# ── 1. target_prop 过滤 ──
		if not target_prop.is_empty() and target_prop != stat_name:
			continue

		# ── 2. delta_sign 过滤 ──
		if delta_sign == "positive" and not delta_is_positive:
			continue
		if delta_sign == "negative" and not delta_is_negative:
			continue

		# ── 3. faction_filter 过滤 ──
		if not faction_filter.is_empty():
			if faction == -1:
				faction = get_faction_from_context()
				faction_str = faction_to_filter(faction)
			if faction_str != faction_filter:
				Logging.debug("[ModifierConfig] apply_all_matching_effects: effect '%s→%s' faction_filter=%s but current=%s → skip" % [source_prop, target_prop, faction_filter, faction_str])
				continue

		# ── 4. 获取修饰符值 ──
		var mod_val: int = get_modifier_val(source_prop)
		if mod_val <= 0:
			Logging.debug("[ModifierConfig] apply_all_matching_effects: source_prop '%s' val=%d ≤ 0 → skip" % [source_prop, mod_val])
			continue

		# ── 5. 应用公式 ──
		var max_limit: float = effect.max_limit
		var half_point: float = effect.half_point

		if direction == "amplify":
			adjusted = ModifierFormula.amplify(adjusted, mod_val, max_limit, half_point)
		else:
			adjusted = ModifierFormula.dampen(adjusted, mod_val, max_limit, half_point)

		Logging.info("[ModifierConfig] apply_all_matching_effects: effect '%s→%s' [%s/%s] mod_val=%d raw=%d → adjusted=%d" % [source_prop, target_prop, direction, faction_filter, mod_val, raw_delta, adjusted])

	if adjusted != raw_delta:
		Logging.info("[ModifierConfig] apply_all_matching_effects: stat=%s raw_delta=%d → final=%d" % [stat_name, raw_delta, adjusted])

	return adjusted
