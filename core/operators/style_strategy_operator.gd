@tool
class_name StyleStrategyOperator extends BaseOperator

## 视觉风格策略切换 Operator
##
## 通过 export enum + 硬编码 class_name 来定位目标控件，
## 调用 StyleManager.switch_strategy() 切换视觉策略。
##
## DSL 语法 (预留): style_strategy(target="narrative_tape_container", strategy="frost")
##
## [param target_control] 硬编码的目标控件类型:
##   - NARRATIVE_TAPE_CONTAINER → NarrativeOverlay 的 tape_container (PanelContainer)
##   - AMBITION_HUD             → AmbitionHUD (Control)
## [param strategy_name] 要切换到的策略名称 (与 bind() 时的 strategy_name 对应)
##   传空串 → 回滚到默认状态

enum TARGET_CONTROL {
	NARRATIVE_TAPE_CONTAINER,
	AMBITION_HUD,
}

## 目标控件类型 — 硬编码枚举
@export var target_control: TARGET_CONTROL = TARGET_CONTROL.NARRATIVE_TAPE_CONTAINER

## 要切换到的策略名称，空串回滚到默认
@export var strategy_name: String = ""


func operate() -> void:
	if strategy_name.is_empty():
		Logging.warn("StyleStrategyOperator.operate: strategy_name 为空，将回滚到默认状态")

	var control := _resolve_target()
	if not control:
		Logging.err("StyleStrategyOperator.operate: 无法解析目标控件, target_control=%d" % target_control)
		return

	if not StyleManager:
		Logging.err("StyleStrategyOperator.operate: StyleManager autoload 不可用")
		return

	Logging.info("StyleStrategyOperator.operate: 切换控件 %s → 策略 '%s'" % [control.name, strategy_name if not strategy_name.is_empty() else "(default)"])
	StyleManager.switch_strategy(control, strategy_name)


func describe_preview() -> String:
	var target_label := _enum_to_label()
	var strat_label := strategy_name if not strategy_name.is_empty() else tr("CODE_STYLE_STRATEGY_OPERATOR_0EF211C6E3")
	return tr("CODE_STYLE_STRATEGY_OPERATOR_F7CD302E68") % [target_label, strat_label]


# ============================================================
# 内部 — 枚举 → 场景节点硬编码映射
# ============================================================

func _resolve_target() -> Control:
	var tree := Engine.get_main_loop()
	if not tree:
		Logging.err("StyleStrategyOperator._resolve_target: 无法获取主循环")
		return null
	var root := tree.root as Node
	if not root:
		Logging.err("StyleStrategyOperator._resolve_target: 无法获取场景树根节点")
		return null

	match target_control:
		TARGET_CONTROL.NARRATIVE_TAPE_CONTAINER:
			# 按 class_name 查找 NarrativeOverlay，取其 tape_container
			var nodes := root.find_children("", "NarrativeOverlay", true, false)
			if nodes.size() == 0:
				Logging.err("StyleStrategyOperator._resolve_target: 场景树中未找到 NarrativeOverlay")
				return null
			var narr := nodes[0] as NarrativeOverlay
			if not narr:
				Logging.err("StyleStrategyOperator._resolve_target: 找到的节点不是 NarrativeOverlay 类型")
				return null
			if not narr.tape_container:
				Logging.err("StyleStrategyOperator._resolve_target: NarrativeOverlay.tape_container 为 null")
				return null
			Logging.debug("StyleStrategyOperator._resolve_target: 已定位到 NarrativeOverlay.tape_container")
			return narr.tape_container

		TARGET_CONTROL.AMBITION_HUD:
			var nodes := root.find_children("", "AmbitionHUD", true, false)
			if nodes.size() == 0:
				Logging.err("StyleStrategyOperator._resolve_target: 场景树中未找到 AmbitionHUD")
				return null
			var hud := nodes[0] as AmbitionHUD
			if not hud:
				Logging.err("StyleStrategyOperator._resolve_target: 找到的节点不是 AmbitionHUD 类型")
				return null
			Logging.debug("StyleStrategyOperator._resolve_target: 已定位到 AmbitionHUD")
			return hud

		_:
			Logging.err("StyleStrategyOperator._resolve_target: 未知的 target_control 枚举值 %d" % target_control)
			return null


func _enum_to_label() -> String:
	match target_control:
		TARGET_CONTROL.NARRATIVE_TAPE_CONTAINER:
			return "NarrativeOverlay.tape_container"
		TARGET_CONTROL.AMBITION_HUD:
			return "AmbitionHUD"
		_:
			return tr("CODE_STYLE_STRATEGY_OPERATOR_A12A874BF6")
