@tool
class_name SetStayPlaceOperator extends BaseOperator

## SetStayPlaceOperator — 设置驻留地点操作符
### 通过 archetype DSL 调用: set_stay_place(place=xishi)
### 将 PlayerState.stay_place 设为对应字符串，触发 UI 刷新

## DSL: set_stay_place(place=xishi)
## place 可选值: xishi / pingkangfang / huangcheng
@export var place: String = "xishi"

# 中文名映射
var PLACE_CN_MAP: Dictionary = {
	"xishi": tr("CODE_SOCIAL_CONNECTION_PAGE_BE2A911592"),
	"pingkangfang": tr("CODE_SOCIAL_CONNECTION_PAGE_06CF4D3D54"),
	"huangcheng": tr("CODE_SOCIAL_CONNECTION_PAGE_CD2724EB5A"),
	"taishan_base": tr("TRES_TUT_MEET_TAOIST_NAME_0"),
	"taishan_upper": tr("CODE_SET_STAY_PLACE_OPERATOR_FAD381D3E4"),
	"dongmen_baqiao": tr("PLACE_DONGMEN_BAQIAO"),
	"lishan": tr("PLACE_LISHAN"),
	"frozen_wei_river": tr("PLACE_FROZEN_WEI_RIVER"),
	"fengxian_village": tr("PLACE_FENGXIAN_VILLAGE"),
	"wooden_hut_door": tr("PLACE_WOODEN_HUT_DOOR"),
}

func describe_preview() -> String:
	var cn = PLACE_CN_MAP.get(place, place)
	return tr("CODE_SET_STAY_PLACE_OPERATOR_011D4BC5AA") % cn

func operate() -> void:
	if place.is_empty():
		Logging.err("SetStayPlaceOperator: place 为空，跳过执行")
		return
	Logging.info("SetStayPlaceOperator: [地点DEBUG] operate() ENTER — 即将设置 stay_place: 当前='%s' → 目标='%s'(%s)" % [PlayerState.stay_place, place, PLACE_CN_MAP.get(place, "?")])
	PlayerState.stay_place = place
	Logging.info("SetStayPlaceOperator: [地点DEBUG] operate() DONE — stay_place 已设为 '%s'(%s), 验证 PlayerState.stay_place='%s'" % [place, PLACE_CN_MAP.get(place, "?"), PlayerState.stay_place])

func get_referenced_flags() -> Array:
	return []

func get_provided_flags() -> Array:
	return []
