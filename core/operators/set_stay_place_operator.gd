@tool
class_name SetStayPlaceOperator extends BaseOperator

## SetStayPlaceOperator — 设置驻留地点操作符
### 通过 archetype DSL 调用: set_stay_place(place=xishi)
### 将 PlayerState.stay_place 设为对应字符串，触发 UI 刷新

## DSL: set_stay_place(place=xishi)
## place 可选值: xishi / pingkangfang / huangcheng
@export var place: String = "xishi"

# 中文名映射
const PLACE_CN_MAP: Dictionary = {
	"xishi": "西市",
	"pingkangfang": "平康坊",
	"huangcheng": "皇城",
}

func describe_preview() -> String:
	var cn = PLACE_CN_MAP.get(place, place)
	return "驻留 → %s" % cn

func operate() -> void:
	if place.is_empty():
		Logging.err("SetStayPlaceOperator: place 为空，跳过执行")
		return
	PlayerState.stay_place = place
	Logging.info("SetStayPlaceOperator: 设置驻留地点为 '%s'(%s)" % [place, PLACE_CN_MAP.get(place, "?")])

func get_referenced_flags() -> Array:
	return []

func get_provided_flags() -> Array:
	return []
