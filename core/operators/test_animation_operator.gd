@tool
class_name TestAnimationOperator extends BaseOperator

## 测试动画操作符 — 手动测试 AnimationObject 体系
##
## DSL 语法: test_animation(type="slide", image_id="juanzhou", duration=2.0)
##
## type 可选: "slide" / "shatter" / "fade_out"
##   slide: 将已展示的图片滑动到 center
##   shatter: 粉碎已展示的图片
##   fade_out: 淡出已展示的图片

@export var animation_type: String = "slide"   # slide / shatter / fade_out
@export var image_id: String = ""
@export var duration: float = 2.0


func operate() -> void:
	Logging.info("TestAnimationOperator.operate: type='%s', id='%s', duration=%.2f" % [animation_type, image_id, duration])

	if image_id.is_empty():
		Logging.err("TestAnimationOperator.operate: image_id 为空，跳过")
		return

	var handle = ImageManager.recall(image_id)
	if handle == null:
		Logging.err("TestAnimationOperator.operate: 图片 '%s' 不在活跃列表中" % image_id)
		return

	var anim: AnimationObject

	match animation_type:
		"slide":
			var target_vec = ImageManager._resolve_pos(ENUMS.IMAGE_POS.CENTER)
			anim = handle.create_slide(target_vec, duration)
			Logging.info("TestAnimationOperator: 创建 SlideAnimation → center, %.2f秒" % duration)
		"shatter":
			anim = handle.create_shatter(duration)
			Logging.info("TestAnimationOperator: 创建 ShatterAnimation, %.2f秒" % duration)
		"fade_out":
			anim = handle.create_fade_out(duration)
			Logging.info("TestAnimationOperator: 创建 FadeOutAnimation, %.2f秒" % duration)
		_:
			Logging.err("TestAnimationOperator: 未知 animation_type '%s'" % animation_type)
			return

	# 通过 EventBus 请求 NarrativeOverlay 追踪此动画
	EventBus.request_track_stage_animation.emit(anim)
	Logging.info("TestAnimationOperator: 已广播 request_track_stage_animation")
