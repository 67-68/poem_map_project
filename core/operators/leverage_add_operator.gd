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
static var _label_map: Dictionary = {
	# 9 大基础身份
	"TARGET_IDENTITY_QINGLIU_OWNER":      "清流主人",
	"TARGET_IDENTITY_QINGLIU_OFFICIAL":   "清流官",
	"TARGET_IDENTITY_ZHUOLIU_OFFICIAL":   "浊流官",
	"TARGET_IDENTITY_QUANGUI":            "权贵",
	"TARGET_IDENTITY_QINGKE":             "清客",
	"TARGET_IDENTITY_MENZI":              "门子",
	"TARGET_IDENTITY_COUNTY_SHERIFF":     "县尉",
	"TARGET_IDENTITY_VENDOR":             "商贩",
	"TARGET_IDENTITY_POOR":               "穷人",
	# NPC
	"TARGET_NPC_LIBAI":      "李白",
	"TARGET_NPC_WANGWEI":    "王维",
	"TARGET_NPC_GAOSHI":     "高适",
	"TARGET_NPC_ZHENGQIAN":  "郑虔",
	"TARGET_NPC_LILINFU":    "李灵甫",
	"TARGET_NPC_DUFU":       "杜甫",
}

## 解析 target_tag 为可读中文标签
static func _resolve_label(tag: String) -> String:
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
		var msg = "获得了关于「%s」的把柄" % [label]
		EventBus.request_toast.emit("[系统提示]：" + msg, 1)
