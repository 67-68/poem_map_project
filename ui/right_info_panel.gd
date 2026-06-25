extends PanelContainer

# ═══════════════════════════════════════════════════════════
# 目标中文名映射（ENUMS.RELATION_TARGET → 游戏内显示名）
# ═══════════════════════════════════════════════════════════
const CN_NAME_MAP: Dictionary = {
	"libai": "李白",
	"hushang": "胡商",
	"lilinfu": "李林甫",
	"jiwen": "纪闻",
	"youxiangfu": "右相府",
	"qingliu": "清流",
	"gaoshi": "高适",
	"wangwei": "王维",
	"zhengqian": "郑虔",
	"waiqi": "外戚",
	"yangguozhong": "杨国忠",
	"guoguofuren": "虢国夫人",
}

@onready var _info_grid: GridContainer = $Panel/V/InfoGrid
@onready var _write_poem_btn: Button = $Panel/V/WritePoemContainer/WritePoemBtn

func _ready() -> void:
	# ── 琢句按钮：点击打开/关闭诗词创建界面 ──
	if _write_poem_btn == null:
		Logging.err("RightInfoPanel: _write_poem_btn is NULL — PackedScene 'action_button.tscn' instantiation may have failed inside right_info_panel.tscn. Skipping WritePoemBtn setup.")
		return
	var title_label: Label = _write_poem_btn.get_node("Panel/HBoxContainer/VBoxContainer/Title")
	var context_label: Label = _write_poem_btn.get_node("Panel/HBoxContainer/VBoxContainer/Outcome")
	var icon_rect: TextureRect = _write_poem_btn.get_node("Panel/HBoxContainer/TextureRect")
	title_label.text = "琢句"
	context_label.text = "铺陈笔墨，直抒胸臆。"
	icon_rect.texture = load("res://assets/stamps/chuangzuo_stamp.png")
	_write_poem_btn.pressed.connect(func(): EventBus.poem_start_clicked.emit())

	# ── 风闻刷新 ──
	_refresh_rumors()
	TimeService.on_month_tick.connect(_refresh_rumors)
	EventBus.request_refresh_action_panel.connect(_refresh_rumors)

## 刷新风闻面板：遍历所有 RELATION_TARGET，查询 RelationFlagManager，
## 只显示有死穴（leverage）或恩义（help）的目标。
##
## 渲染协议：
##   有具体 key → 「死穴：key1」「死穴：key2」
##   leverage_keys.size() > 1 → 末尾追加 死穴：N
##   help > 0 → 「恩义」×N
##   help > 1 → 末尾追加 恩义：N
##   两者都为空 → 该目标不渲染
func _refresh_rumors() -> void:
	# 构建 target 列表（RELATION_TARGET 枚举 → to_lower 字符串）
	var targets: Array[String] = []
	for target_enum in ENUMS.RELATION_TARGET.values():
		var target_tag: String = ENUMS.to_relation_str(target_enum)
		if not target_tag.is_empty():
			targets.append(target_tag)

	if targets.is_empty():
		Logging.warn("RightInfoPanel: RELATION_TARGET 枚举为空，跳过风闻刷新")
		return

	# 批量查询所有关系数据
	var all_relations: Dictionary = RelationFlagManager.get_all_relations(targets)

	# ── 第一遍：收集所有要渲染的 label 文本 ──
	var label_texts: Array[String] = []
	for target_tag in targets:
		var data: Dictionary = all_relations.get(target_tag, {})
		var leverage_keys: Array = data.get("leverage_keys", [])
		var help_count: int = data.get("help", 0)

		if leverage_keys.is_empty() and help_count <= 0:
			continue

		var parts: Array[String] = []
		var cn_name: String = CN_NAME_MAP.get(target_tag, target_tag)

		# ── 死穴 ──
		if not leverage_keys.is_empty():
			for key in leverage_keys:
				parts.append("「死穴：%s」" % key)
			if leverage_keys.size() > 1:
				parts.append("死穴：%d" % leverage_keys.size())

		# ── 恩义 ──
		if help_count > 0:
			parts.append("「恩义」×%d" % help_count)
			if help_count > 1:
				parts.append("恩义：%d" % help_count)

		label_texts.append("%s：%s" % [cn_name, "  ".join(parts)])

	# ── 第二遍：差分更新 UI ──
	var children = _info_grid.get_children()
	var target_count = label_texts.size()
	var current_count = children.size()

	# 1. 更新已有 Label
	for i in range(min(current_count, target_count)):
		children[i].text = label_texts[i]

	# 2. 多余的销毁
	for i in range(target_count, current_count):
		children[i].queue_free()

	# 3. 不足的新建
	for i in range(current_count, target_count):
		var label := Label.new()
		label.theme_type_variation = "DefaultText"
		label.text = label_texts[i]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_grid.add_child(label)

	Logging.info("RightInfoPanel: 风闻刷新完成，已渲染 %d 条" % _info_grid.get_child_count())
