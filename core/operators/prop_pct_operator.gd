@tool
class_name PropPctOperator extends BaseOperator
## 百分比属性修改器 — 按当前属性值的百分比进行扣除
## 用于 Event 2（韦坚案：扣30%势）等需要百分比操作的场景
##
## 字段:
##   str_props — 目标属性名（如 "momentum"）
##   pct       — 百分比值（如 -30.0 表示扣除当前值的 30%）
##   max_sub   — 最大扣除量上限（防止极端高属性时扣太多，0=无上限）
##
## operate() 逻辑:
##   delta = int(current_val * pct / 100.0)
##   若 pct < 0: clamp(delta, -max_sub, 0)  → PlayerState.append_stat(prop, delta)

@export var str_props: String = ""
@export var pct: float = 0.0
@export var max_sub: int = 0

func init(_context: Dictionary) -> Dictionary:
	Logging.info("[PropPctOperator] init: str_props=%s, pct=%.1f%%, max_sub=%d" % [str_props, pct, max_sub])
	return _context

func operate() -> void:
	if str_props.is_empty():
		Logging.err("[PropPctOperator] operate: str_props is empty, skip")
		return
	if pct == 0.0:
		Logging.info("[PropPctOperator] operate: pct=0, skip")
		return

	var current_val: int = PlayerState.get_stat_val(str_props)
	if current_val <= 0:
		Logging.info("[PropPctOperator] operate: current_val=%d for '%s', nothing to adjust" % [current_val, str_props])
		return

	var delta: int = int(float(current_val) * pct / 100.0)
	Logging.info("[PropPctOperator] operate: current=%d, pct=%.1f%%, raw_delta=%d" % [current_val, pct, delta])

	if pct < 0 and max_sub > 0:
		# 负百分比时，clamp 到 [-max_sub, 0]
		if delta < -max_sub:
			Logging.info("[PropPctOperator] operate: delta=%d clamped to max_sub=%d" % [delta, max_sub])
			delta = -max_sub

	if delta == 0:
		Logging.info("[PropPctOperator] operate: final delta=0, skip")
		return

	PlayerState.append_stat(str_props, delta)
	Logging.info("[PropPctOperator] operate: applied %+d to '%s'" % [delta, str_props])

	# 触发属性变化音效
	AudioManager.play_property_sound(str_props, delta)

func describe_preview() -> String:
	if str_props.is_empty() or pct == 0.0:
		return ""
	var prop = Database.get_property(str_props)
	if not prop:
		return ""
	var cn_name = prop.get_display_name() if not prop.name.is_empty() else str_props
	var arrow = "↓" if pct < 0 else "↑"
	var abs_pct = abs(pct)
	var extra := ""
	if pct < 0 and max_sub > 0:
		extra = tr("CODE_PROP_PCT_OPERATOR_CAP") % str(max_sub)
	return "%s %s：%d%%%s" % [cn_name, arrow, int(abs_pct), extra]

func get_referenced_flags() -> Array:
	return []

func get_referenced_traits() -> Array:
	return []

func get_demanded_flags() -> Array:
	return []

func get_demanded_traits() -> Array:
	return []
