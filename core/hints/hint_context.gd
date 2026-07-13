extends RefCounted
## 行动提示构建的轻量上下文容器
##
## 由调用方（action_button.gd / main_action_button.gd / picker_tape_attachment.gd）
## 从 VolatileState 和 autoload 预组装后传入 ActionHintFormatter。
##
## 核心意图：切断 ActionHintFormatter 对 PlayerState / ActionManager / SurvivalManager
## 的直接 autoload 依赖，让 hint 构建成为纯函数。
##
## ActionHintFormatter 拿到 HintContext 后，禁止再调用 PlayerState 或 ActionManager
## 的任何状态读取方法。纯计算函数（format_time_detail / effective_day_consumed 等）
## 可以保留直接调用。

const _NamedDSLParser = preload("res://parser/named_dsl_parser.gd")


# ════════════════════════════════════════════════════════════════
# 字段
# ════════════════════════════════════════════════════════════════

## 当前行动是否为重复行动
var is_repeated: bool = false

## AP 削减提示文本（空字符串 = 无削减）
var ap_hint: String = ""

## AP 削减提示颜色 hex
var ap_hint_color: String = ""

## NamedDSLParser 的命名数值查询缓存（避免每次调用 _load_named_amounts）
var named_amounts: Dictionary = {}

## Defer 状态缓存 { uuid: { is_deferring, remaining, is_failing } }
var defer_states: Dictionary = {}

## 当前时间（PlayerState.get_stat_val("time")）
var current_time: int = 0

## 当前所在地（PlayerState.stay_place）
var stay_place: String = ""


# ════════════════════════════════════════════════════════════════
# 构建方法 — 由调用方在使用前调用
# ════════════════════════════════════════════════════════════════

## 从当前运行时状态填充 HintContext 字段。
## @param action: 目标 Action（可选，用于预填充 defer_states）
## @return HintContext 自身（链式调用）
func populate(action = null):
	# 重复行动检测结果由调用方显式设置（is_action_repeated 依赖 action_tags 上下文）
	# 这里填入默认值 false；调用方可在 populate 后覆盖 is_repeated
	
	# AP hint
	ap_hint = SurvivalManager.get_active_ap_hint()
	ap_hint_color = SurvivalManager.get_active_ap_hint_color()
	Logging.info("HintContext.populate: ap_hint='%s' ap_hint_color='%s'" % [ap_hint, ap_hint_color])
	
	# Named amounts
	named_amounts = _NamedDSLParser._load_named_amounts()
	Logging.info("HintContext.populate: named_amounts loaded (%d entries)" % named_amounts.size())
	
	# 当前时间
	current_time = int(PlayerState.get_stat_val("time"))
	
	# 当前所在地
	stay_place = PlayerState.stay_place
	Logging.info("HintContext.populate: time=%d, stay_place='%s'" % [current_time, stay_place])
	
	# Defer states（先清空再填充）
	defer_states.clear()
	if action:
		_collect_defer_states(action)
	
	return self


## 收集 action 树中所有可 defer 的子行动的 defer 状态。
## 供 populate 内部调用，也可由调用方手动追加额外 action 的 defer 状态。
func collect_defer_states_for(action) -> void:
	_collect_defer_states(action)


func _collect_defer_states(action) -> void:
	# 检查自身
	if action.defer_config and not action.defer_config.xun_defered.is_empty():
		var a_id = action.uuid
		defer_states[a_id] = {
			is_deferring = ActionManager.is_deferring(a_id),
			remaining = ActionManager.get_defer_remaining(a_id),
			is_failing = ActionManager.is_defer_failing(a_id),
		}
		Logging.info("HintContext._collect_defer_states: action '%s' defer_state=%s" % [action.name, str(defer_states[a_id])])
	
	# 检查子行动
	for sub_uuid in action.sub_actions:
		if sub_uuid.is_empty():
			continue
		var sub = Database.get_action(sub_uuid) as Action
		if sub and sub.defer_config and not sub.defer_config.xun_defered.is_empty():
			defer_states[sub_uuid] = {
				is_deferring = ActionManager.is_deferring(sub_uuid),
				remaining = ActionManager.get_defer_remaining(sub_uuid),
				is_failing = ActionManager.is_defer_failing(sub_uuid),
			}
			Logging.info("HintContext._collect_defer_states: sub_action '%s' defer_state=%s" % [sub.name, str(defer_states[sub_uuid])])


## 获取一个 action uuid 的 defer 状态，不存在时返回空字典
func get_defer_state(uuid: String) -> Dictionary:
	return defer_states.get(uuid, {})
