@tool
class_name LeverageAddOperator extends BaseOperator

# ═══════════════════════════════════════════════════════════
# LeverageAddOperator — 把柄获取算子
#
# DSL 语法:
#   leverage_add(target_tag="TARGET_IDENTITY_QUANGUI", key="quangui_corruption")
#   leverage_add(target_tag="TARGET_NPC_LIBAI", key="libai_secret", silent=true)
#
# 参数:
#   target_tag:  目标 Tag (TARGET_IDENTITY_* 或 TARGET_NPC_*)
#   key:         把柄唯一标识符
#   silent:      为 true 时跳过 toast 通知
# ═══════════════════════════════════════════════════════════

@export var target_tag: String = ""
@export var leverage_key: String = ""
@export var silent: bool = false

# ── label 映射：TAG → 中文名称 ──
var _label_map: Dictionary = {
	# 9 大基础身份
	"TARGET_IDENTITY_QINGLIU_OWNER":      tr("CODE_LEVERAGE_ADD_OPERATOR_AAAA7D9F19"),
	"TARGET_IDENTITY_QINGLIU_OFFICIAL":   tr("CODE_LEVERAGE_ADD_OPERATOR_D972C462FC"),
	"TARGET_IDENTITY_ZHUOLIU_OFFICIAL":   tr("CODE_LEVERAGE_ADD_OPERATOR_F09988C201"),
	"TARGET_IDENTITY_QUANGUI":            tr("CODE_NPC_TIER_REQUIREMENT_E4CA3EA091"),
	"TARGET_IDENTITY_QINGKE":             tr("CODE_LEVERAGE_ADD_OPERATOR_2D61825931"),
	"TARGET_IDENTITY_MENZI":              tr("CODE_LEVERAGE_ADD_OPERATOR_1E0F945362"),
	"TARGET_IDENTITY_COUNTY_SHERIFF":     tr("CODE_LEVERAGE_ADD_OPERATOR_E3BD042ACC"),
	"TARGET_IDENTITY_VENDOR":             tr("CODE_LEVERAGE_ADD_OPERATOR_6E27E9DA69"),
	"TARGET_IDENTITY_POOR":               tr("CODE_LEVERAGE_ADD_OPERATOR_9CF19D2B90"),
	# NPC
	"TARGET_NPC_LIBAI":      tr("TRES_POET_LIBAI_001_NAME_0"),
	"TARGET_NPC_WANGWEI":    tr("TRES_NPC_DOC_WANGWEI_NAME_0"),
	"TARGET_NPC_GAOSHI":     tr("CODE_RIGHT_INFO_PANEL_5692EF6E24"),
	"TARGET_NPC_ZHENGQIAN":  tr("TRES_NPC_DOC_ZHENGQIAN_NAME_0"),
	"TARGET_NPC_LILINFU":    tr("CODE_LEVERAGE_ADD_OPERATOR_7A4C672055"),
	"TARGET_NPC_DUFU":       tr("TRES_POET_DUFU_002_NAME_0"),
}

## 解析 target_tag 为可读中文标签
func _resolve_label(tag: String) -> String:
	if _label_map.has(tag):
		return _label_map[tag]
	# 降级：返回 tag 本身
	Logging.info("LeverageAddOperator: 未找到标签映射 for '%s', 使用原始 TAG" % tag)
	return tag

func operate():
	if target_tag.is_empty():
		Logging.err("LeverageAddOperator: target_tag 为空，无法添加把柄")
		return
	
	if leverage_key.is_empty():
		Logging.err("LeverageAddOperator: leverage_key 为空，无法添加把柄")
		return
	
	RelationFlagManager.add_leverage(target_tag, leverage_key)
	
	if not silent:
		var label = _resolve_label(target_tag)
		var msg = tr("CODE_LEVERAGE_ADD_OPERATOR_6AEECA1FB4") % [label]
		EventBus.request_toast.emit(tr("CODE_LEVERAGE_ADD_OPERATOR_85A28E77E3") + msg, 1)
