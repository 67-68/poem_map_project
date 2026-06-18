class_name CooldownFilter extends BaseEventPoolFilter

# ═══════════════════════════════════════════════════════════
# CooldownFilter — EventManager 过滤器链第三级
#
# 职责：
#  从 context.main_tag 推导 CD 目标标签，检查 RelationFlagManager
#  中是否存在活跃的冷却 flag（flag_gen_cd_{target_tag}）。
#  若目标在冷却中 → 返回空数组（整个池被清空）→ 触发 fallback 兜底。
#
# 非社交行动（如独酌）没有 CD 目标 → 原样返回 tickets，不做过滤。
# ═══════════════════════════════════════════════════════════

## 行动前缀 → CD 目标标签映射表
## key: main_tag 前缀（小写）
## value: CD 目标标签（对应 RelationFlagManager 的 flag_gen_cd_{target}）
const ACTION_TO_CD_TARGET: Dictionary = {
	"action:main:baiye":   "qingliu",
	"action:main:jiaoyou": "jiaoyou",
	"action:main:denggao": "denggao",
	"action:main:fangshi": "fangshi",
	"action:main:duzhuo":  "",     # 独酌无社交对象，跳过 CD
	"action:main:fengzhao": "fengzhao",
}


## 过滤入口：返回经过 CD 检查后剩余的有效 tickets
static func filter(tickets: Array[EventTicket], _context: Dictionary) -> Array[EventTicket]:
	var main_tag: String = _context.get('main_tag', '')
	if main_tag.is_empty():
		return tickets

	# 1. 从 main_tag 推导 CD 目标
	var target_tag := _derive_cooldown_target(main_tag)
	if target_tag.is_empty():
		# 推导不出 CD 目标 → 该行动不受 CD 约束，原样放行
		Logging.info("[CooldownFilter] main_tag '%s' 无对应 CD 目标，跳过 CD 检查" % main_tag)
		return tickets

	# 2. 检查目标是否在冷却中
	if RelationFlagManager.is_on_cooldown(target_tag):
		Logging.info("[CooldownFilter] 🚫 %s 在冷却中（tag=%s），池空触发 fallback" % [main_tag, target_tag])
		return []  # 返回空数组 → roll_events 走 fallback 分支

	Logging.info("[CooldownFilter] ✅ %s 无冷却（tag=%s），正常放行" % [main_tag, target_tag])
	return tickets


## 推导 CD 目标标签
##
## 优先级：
##   1. 硬编码 ACTION_TO_CD_TARGET 前缀匹配
##   2. RELATION_TARGET 枚举值前缀匹配（复用 SocialActionResolver 推导逻辑）
static func _derive_cooldown_target(main_tag: String) -> String:
	var tag_lower := main_tag.to_lower()

	# 优先级 1: 硬编码的行动前缀映射
	for prefix in ACTION_TO_CD_TARGET:
		if tag_lower.begins_with(prefix):
			var target = ACTION_TO_CD_TARGET[prefix]
			if not target.is_empty():
				return target
			# target 为空字符串表示"无 CD 目标"，继续检查后续规则

	# 优先级 2: RELATION_TARGET 枚举前缀匹配（如 libai, wangwei, qingliu...）
	# 复用 SocialActionResolver._derive_relation_target 逻辑
	for target_enum_value in ENUMS.RELATION_TARGET.values():
		var candidate := ENUMS.to_relation_str(target_enum_value)
		if tag_lower.begins_with(candidate):
			return candidate

	# 优先级 3: 检查 main_tag 本身是否就是 RELATION_TARGET 值
	# （例如 bamboo_slip 直接传 trait_uuid 作为 main_tag）
	if ENUMS.RELATION_TARGET.keys().map(func(k): return k.to_lower()).has(tag_lower):
		return tag_lower

	# 兜底：无法推导
	Logging.info("[CooldownFilter] 无法从 main_tag '%s' 推导 CD 目标" % main_tag)
	return ""
