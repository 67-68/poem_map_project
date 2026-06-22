@tool
class_name OverlayAnimationOperator extends BaseOperator

## 驱动 NarrativeOverlay 执行动画 — 策略驱动
##
## DSL 语法: overlay_anim(strategy="slide_out_and_back", duration=0.5)
##
## [param strategy] 动画策略枚举:
##   - "slide_out_and_back": 纸带向下滑出视口再滑回原位
## [param duration] 动画总时长 (秒)，平分给下滑与回弹两段

@export var strategy: String = "slide_out_and_back"
@export var duration: float = 0.5


func operate() -> void:
	Logging.info("OverlayAnimationOperator.operate: strategy='%s', duration=%.2f" % [strategy, duration])

	if strategy.is_empty():
		Logging.err("OverlayAnimationOperator.operate: strategy 为空，跳过")
		return

	var params := {
		"duration": duration
	}

	EventBus.request_overlay_animation.emit(strategy, params)
	Logging.info("OverlayAnimationOperator.operate: 信号已发射 → strategy='%s'" % strategy)


func describe_preview() -> String:
	return "OverlayAnimation: %s (%.1fs)" % [strategy, duration]
