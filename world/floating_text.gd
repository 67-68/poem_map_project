class_name FloatingText extends Control

signal recycle_requested(text_instance)

@onready var label: RichTextLabel = $Label

# ── 预设配置常量 ─────────────────────────────────────
const CONFIG_GAIN := {  # 属性增加（绿色）
	"color": Color(0.6, 1.0, 0.6, 1.0),
	"start_scale": Vector2(0.4, 0.4),
	"end_scale": 0.7,
	"rise_distance": 50.0,
	"duration": 1.5,
}
const CONFIG_LOSS := {  # 属性减少（红色）
	"color": Color(1.0, 0.4, 0.4, 1.0),
	"start_scale": Vector2(0.4, 0.4),
	"end_scale": 0.7,
	"rise_distance": 50.0,
	"duration": 1.5,
}
const CONFIG_ITEM := {  # 物品/意象获得（金色）
	"color": Color(1.0, 0.84, 0.0, 1.0),
	"start_scale": Vector2(0.3, 0.3),
	"end_scale": 0.8,
	"rise_distance": 70.0,
	"duration": 2.0,
}

func _ready() -> void:
	modulate.a = 0
	# 锚点和偏移已在 .tscn 中配置（顶部居中，offset_top=80）

func play(content: String, config: Dictionary = {}) -> void:
	Logging.debug("FloatingText.play: content='%s', config=%s" % [content, config])
	scale = config.get("start_scale", CONFIG_GAIN.start_scale)
	modulate = config.get("color", CONFIG_GAIN.color)
	modulate.a = 1
	show()

	label.text = content

	var rise_distance = config.get("rise_distance", CONFIG_GAIN.rise_distance)
	var duration = config.get("duration", CONFIG_GAIN.duration)
	var end_scale = config.get("end_scale", CONFIG_GAIN.end_scale)

	# 🤓☝️ 丢掉你那愚蠢的 offset_top，直接对 position 下手！
	# 记录当前 Y 坐标，将初始位置下压 rise_distance
	var target_y = position.y
	position.y = target_y + rise_distance

	var tw = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 😡 替换掉 "offset_top"，改为缓动 "position:y"
	tw.tween_property(self, "position:y", target_y, duration)
	
	tw.parallel()
	tw.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(max(duration - 0.5, 0.0))
	tw.tween_callback(on_finished)

func on_finished():
	recycle_requested.emit(self)
