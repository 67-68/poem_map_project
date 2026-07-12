class_name NPCAvailabilityManager extends RefCounted

# ═══════════════════════════════════════════════════════════
# NPCAvailabilityManager — NPC 可用性静态工具
#
# 职责:
#   根据 NPCDocument.appear_days 配置 + TimeService.current_day
#   判断 NPC 在当前时间是否可用。
#
# 规则:
#   appear_days 为空数组 → 始终可用（向后兼容）
#   appear_days 非空     → current_day 必须在列表内
# ═══════════════════════════════════════════════════════════

## 判断指定 NPC 在当前旬的第 current_day 天是否可用。
## @param npc_doc: NPCDocument 实例
## @param day: int — TimeService.current_day（值域 0~9，0-based）
## @return bool — true = 可用
## 注意：appear_days 使用 1-based 索引（1-10），内部做 +1 转换。
static func is_available(npc_doc: NPCDocument, day: int) -> bool:
	if npc_doc == null:
		Logging.err("NPCAvailabilityManager.is_available: npc_doc 为 null")
		return false

	# 空数组 = 始终可用
	if npc_doc.appear_days.is_empty():
		return true

	# appear_days 是 1-based（1-10），current_day 是 0-based（0-9），做 +1 转换
	var day_1based: int = day + 1
	if day_1based in npc_doc.appear_days:
		return true

	Logging.debug("NPCAvailabilityManager: NPC '%s' 在 day=%d（1-based=%d）不可用 (appear_days=%s)" % [npc_doc.uuid, day, day_1based, str(npc_doc.appear_days)])
	return false
