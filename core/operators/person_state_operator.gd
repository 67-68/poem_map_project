@tool
class_name PersonStateOperator extends BaseOperator

# ═══════════════════════════════════════════════════════════
# PersonStateOperator — 统一人物状态操作
#
# 两种模式（mode 参数）：
#   set:     显式设置 target 的 person_state 为指定值
#   upgrade: 将 target 的 person_state 升级到下一级
#
# DSL 语法:
#   person_state(mode=set; state=not_meet; target_key=npc_target)
#   person_state(mode=upgrade; target_key=npc_target)
#
# 参数:
#   mode:       必填 — "set" / "upgrade"
#   state:      set 模式必填 — 目标状态（如 "not_meet"）
#   target_key: 必填 — 从 context 读取 target_tag 的 key
# ═══════════════════════════════════════════════════════════

## 操作模式 — "set" / "upgrade"
@export var mode: String = "set"

## set 模式的目标状态值
@export var state: String = ""

## context 中存储 target_tag 的 key
@export var target_key: String = "npc_target"

## init 阶段捕获的 context
var _captured_context: Dictionary = {}


func init(_context: Dictionary) -> Dictionary:
	_captured_context = _context.duplicate()
	return _context


func operate() -> void:
	Logging.info("[DIAG] PersonStateOperator.operate: _captured_context=%s target_key='%s' mode='%s' state='%s'" % [str(_captured_context), target_key, mode, state])
	var target_tag: String = _captured_context.get(target_key, "")
	if target_tag.is_empty():
		var fallback: String = ""
		for tag in PlayerState.current_action_tags:
			if tag.begins_with("actor:npc:"):
				fallback = tag.trim_prefix("actor:npc:")
				break
		if not fallback.is_empty():
			Logging.err("[DIAG] PersonStateOperator: npc_target 从 context 丢失！从 current_action_tags 回退为 '%s'" % fallback)
			target_tag = fallback
		else:
			Logging.err("PersonStateOperator.operate: context[%s] 为空，_captured_context keys=%s，current_action_tags=%s — 无法回退" % [target_key, str(_captured_context.keys()), str(PlayerState.current_action_tags)])
			return

	match mode:
		"set":
			if state.is_empty():
				Logging.err("PersonStateOperator.operate: set 模式但 state 为空")
				return
			RelationFlagManager.set_person_state(target_tag, state)
			Logging.info("PersonStateOperator: set %s → %s" % [target_tag, state])

		"upgrade":
			var upgraded := RelationFlagManager.upgrade_person_state(target_tag)
			if upgraded:
				var new_state = RelationFlagManager.get_person_state(target_tag)
				Logging.info("PersonStateOperator: upgrade %s → %s" % [target_tag, new_state])
			else:
				Logging.info("PersonStateOperator: upgrade %s 已是最高级或状态异常" % target_tag)

		_:
			Logging.err("PersonStateOperator.operate: 未知 mode='%s'" % mode)


func describe_preview() -> String:
	match mode:
		"set":
			return tr("CODE_PERSON_STATE_OPERATOR_3D01BBC36A") % [target_key, state]
		"upgrade":
			return tr("CODE_PERSON_STATE_OPERATOR_27212B01DC") % target_key
	return "person_state(mode=%s)" % mode
