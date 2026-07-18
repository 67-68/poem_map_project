extends Control
class_name SocialConnectionPage

# ═══════════════════════════════════════════════════════════
# SocialConnectionPage — 社交人脉总览页
#
# 左侧树状图：以地区或阵营维度浏览所有已知 NPC
# 右侧信息面板：展示选中 NPC 的完整 NPCDocument 数据
#
# 数据来源：Database.npc_document → NPCDocument
# 关系层级：RelationFlagManager.RELATION_TARGET_TIER
# ═══════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════
# 常量映射
# ═══════════════════════════════════════════════════════════

var PLACE_CN: Dictionary = {
	"pingkangfang": tr("CODE_SOCIAL_CONNECTION_PAGE_06CF4D3D54"),
	"huangcheng": tr("CODE_SOCIAL_CONNECTION_PAGE_CD2724EB5A"),
	"xishi": tr("CODE_SOCIAL_CONNECTION_PAGE_BE2A911592"),
}

var PERSON_STATE_CN: Dictionary = {
	"not_meet": tr("CODE_SOCIAL_CONNECTION_PAGE_FC09E638F1"),
	"know_about": tr("CODE_SOCIAL_CONNECTION_PAGE_320A6DD958"),
	"inner_circle": tr("CODE_SOCIAL_CONNECTION_PAGE_67B1207A0B"),
	"blood_oath": tr("CODE_SOCIAL_CONNECTION_PAGE_82200B0785"),
}

var TIER_LABELS: Dictionary = {
	1: tr("CODE_SOCIAL_CONNECTION_PAGE_D5617BCA8A"),
	2: tr("CODE_SOCIAL_CONNECTION_PAGE_AF314B7D7E"),
	3: tr("CODE_SOCIAL_CONNECTION_PAGE_76BE7378D6"),
}

var UNKNOWN_TIER_LABEL: String = tr("CODE_SOCIAL_CONNECTION_PAGE_AF4682C8B2")
var UNKNOWN_PLACE_LABEL: String = tr("CODE_SOCIAL_CONNECTION_PAGE_CDC9E0E088")

# ═══════════════════════════════════════════════════════════
# Onready 节点引用
# ═══════════════════════════════════════════════════════════

@onready var _tree: Tree = $PanelContainer/H/V/Tree
@onready var _btn_by_place: Button = $PanelContainer/H/V/Modes/Button
@onready var _btn_by_tier: Button = $PanelContainer/H/V/Modes/Button2
@onready var _btn_close: Button = $PanelContainer/Button  # 右上角 X 关闭按钮

@onready var _info_basic: RichTextLabel = $PanelContainer/H/Info/VBoxContainer/Unit8/RichTextLabel
@onready var _info_relation: RichTextLabel = $PanelContainer/H/Info/VBoxContainer/Unit2/RichTextLabel
@onready var _info_related: RichTextLabel = $PanelContainer/H/Info/VBoxContainer/Unit5/RichTextLabel
@onready var _info_quests: RichTextLabel = $PanelContainer/H/Info/VBoxContainer/Unit6/RichTextLabel
@onready var _info_recipes: RichTextLabel = $PanelContainer/H/Info/VBoxContainer/Unit7/RichTextLabel


# ═══════════════════════════════════════════════════════════
# 页面开关状态 + 动画
# ═══════════════════════════════════════════════════════════

var expand := false
var _page_tween: Tween = null
var _original_offsets: Dictionary = {}


# ═══════════════════════════════════════════════════════════
# 生命周期
# ═══════════════════════════════════════════════════════════

func _ready() -> void:
	Logging.info("[SocialConnectionPage] _ready 开始")

	# 保存原始 offset 供 hide 后恢复
	_original_offsets = {
		"left": offset_left,
		"top": offset_top,
		"right": offset_right,
		"bottom": offset_bottom,
	}

	hide()
	EventBus.social_connection_toggled.connect(func():
		if not expand:
			show_page()
		else:
			hide_page()
	)

	# 🆕 右上角 X 按钮 → 关闭页面
	_btn_close.pressed.connect(hide_page)

	# 连接模式切换信号 —— 两个按钮共用 ButtonGroup，toggled 会在按下和释放时各触发一次
	_btn_by_place.toggled.connect(_on_mode_changed)
	_btn_by_tier.toggled.connect(_on_mode_changed)

	# 连接 Tree 选中信号
	_tree.item_selected.connect(_on_tree_item_selected)

	# 首次构建 —— 默认「按地区分类」（button_pressed = true）
	_rebuild_tree()
	Logging.info("[SocialConnectionPage] _ready 完成")


# ═══════════════════════════════════════════════════════════
# 页面动画 — show / hide（参考 PoemCreationPage）
# ═══════════════════════════════════════════════════════════

func show_page() -> void:
	if expand:
		return
	expand = true
	Logging.info("SocialConnectionPage: show_page 开始 — 全屏模糊 → 面板滑出 → 展示")

	# 🆕 隐藏纸带（引用计数递增）
	EventBus.narrative_tape_hide_requested.emit()

	# 1. 全屏模糊（幕布）
	BlurManager.show_cinematic_blur()
	await get_tree().create_timer(0.5).timeout

	# 2. 左右面板滑出
	var main := get_tree().root.get_node("Main") as Node
	if main and main.has_method("slide_panels_out"):
		main.slide_panels_out()
	else:
		Logging.warn("SocialConnectionPage: Main.slide_panels_out 不可用")
	await get_tree().create_timer(0.65).timeout

	# 3. 取消全屏模糊，切换为地图模糊
	BlurManager.hide_cinematic_blur()
	BlurManager.trigger_event_blur()

	# 4. 展示页面 — 先恢复原始 offset（防止 hide 动画污染）
	if not _original_offsets.is_empty():
		offset_left = _original_offsets.get("left", offset_left)
		offset_top = _original_offsets.get("top", offset_top)
		offset_right = _original_offsets.get("right", offset_right)
		offset_bottom = _original_offsets.get("bottom", offset_bottom)
		Logging.info("SocialConnectionPage: restored original offsets: %s" % _original_offsets)
	_rebuild_tree()
	show()
	_page_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _page_tween.finished

	Logging.info("SocialConnectionPage: show_page 完成")


func hide_page() -> void:
	if not expand:
		return
	expand = false
	Logging.info("SocialConnectionPage: hide_page 开始")

	# 🆕 恢复纸带（引用计数递减）
	EventBus.narrative_tape_show_requested.emit()

	# 1. 取消地图模糊
	BlurManager.return_to_hub()

	# 2. 面板滑回
	var main := get_tree().root.get_node("Main") as Node
	if main and main.has_method("slide_panels_in"):
		main.slide_panels_in()

	# 3. 隐藏页面
	if _page_tween:
		_page_tween.kill()
	_page_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_page_tween.set_parallel(true)
	_page_tween.tween_property(self, "size", Vector2(103, 47), 0.5)
	_page_tween.tween_property(self, "position", Vector2(520, 565), 0.5)
	_page_tween.tween_callback(func():
		hide()
	)

	Logging.info("SocialConnectionPage: hide_page 完成")


# ═══════════════════════════════════════════════════════════
# 模式切换
# ═══════════════════════════════════════════════════════════

func _on_mode_changed(pressed: bool) -> void:
	if not pressed:
		Logging.info("[SocialConnectionPage] 按钮取消按下，忽略此次 toggled")
		return
	Logging.info("[SocialConnectionPage] 模式切换 — 按地区=%s 按阵营=%s" % [_btn_by_place.button_pressed, _btn_by_tier.button_pressed])
	_rebuild_tree()


# ═══════════════════════════════════════════════════════════
# Tree 构建
# ═══════════════════════════════════════════════════════════

func _rebuild_tree() -> void:
	Logging.info("[SocialConnectionPage] _rebuild_tree 开始")
	_tree.clear()

	var all_docs: Dictionary = Database.get_npc_document_all()
	Logging.info("[SocialConnectionPage] Database.npc_document 共 %d 条" % all_docs.size())

	if all_docs.is_empty():
		Logging.warn("[SocialConnectionPage] npc_document 为空，Tree 不构建任何节点")
		_clear_info()
		return

	# 过滤 uncharted —— 玩家完全不知道此人存在，不显示
	var visible_docs: Array[NPCDocument] = []
	for uuid: String in all_docs:
		var doc: NPCDocument = all_docs[uuid]
		if doc.person_state == "uncharted":
			Logging.info("[SocialConnectionPage] 跳过 uncharted NPC — uuid=%s" % doc.uuid)
			continue
		visible_docs.append(doc)

	Logging.info("[SocialConnectionPage] 过滤后可见 NPC 共 %d 条" % visible_docs.size())

	if visible_docs.is_empty():
		Logging.info("[SocialConnectionPage] 所有 NPC 均为 uncharted，Tree 为空")
		_clear_info()
		return

	if _btn_by_tier.button_pressed:
		_build_tree_by_tier(visible_docs)
	else:
		_build_tree_by_place(visible_docs)

	Logging.info("[SocialConnectionPage] _rebuild_tree 完成")


func _build_tree_by_place(docs: Array[NPCDocument]) -> void:
	Logging.info("[SocialConnectionPage] 按地区分组构建 Tree")

	# { place_str: [NPCDocument, ...] }
	var groups: Dictionary = {}
	var no_place_docs: Array[NPCDocument] = []

	for doc: NPCDocument in docs:
		if doc.preferred_places.is_empty():
			Logging.info("[SocialConnectionPage]   NPC %s 无偏好地点，归入「其他地点」" % doc.uuid)
			no_place_docs.append(doc)
			continue

		for place: String in doc.preferred_places:
			if not groups.has(place):
				groups[place] = []
			groups[place].append(doc)

	var root: TreeItem = _tree.create_item()

	# 有地点的分组 —— 按 key 排序保证一致性
	var place_keys: Array[String] = []
	place_keys.assign(groups.keys())
	place_keys.sort()

	for place_key: String in place_keys:
		var cn_name: String = PLACE_CN.get(place_key, place_key)
		var place_item: TreeItem = _tree.create_item(root)
		place_item.set_text(0, cn_name)
		place_item.set_selectable(0, false)
		Logging.info("[SocialConnectionPage]   创建地点节点 — %s (%s), 共 %d 个 NPC" % [cn_name, place_key, groups[place_key].size()])

		for doc: NPCDocument in groups[place_key]:
			_add_npc_item(place_item, doc)

	# 无地点兜底分组
	if not no_place_docs.is_empty():
		var unknown_item: TreeItem = _tree.create_item(root)
		unknown_item.set_text(0, UNKNOWN_PLACE_LABEL)
		unknown_item.set_selectable(0, false)
		Logging.info("[SocialConnectionPage]   创建「其他地点」节点, 共 %d 个 NPC" % no_place_docs.size())
		for doc: NPCDocument in no_place_docs:
			_add_npc_item(unknown_item, doc)


func _build_tree_by_tier(docs: Array[NPCDocument]) -> void:
	Logging.info("[SocialConnectionPage] 按阵营分组构建 Tree")

	# { tier_int: [NPCDocument, ...] }
	var groups: Dictionary = {}
	var unknown_tier_docs: Array[NPCDocument] = []

	for doc: NPCDocument in docs:
		var tier: int = RelationFlagManager.RELATION_TARGET_TIER.get(doc.uuid, 0)
		Logging.info("[SocialConnectionPage]   NPC %s → tier=%d" % [doc.uuid, tier])
		if tier == 0:
			unknown_tier_docs.append(doc)
		else:
			if not groups.has(tier):
				groups[tier] = []
			groups[tier].append(doc)

	var root: TreeItem = _tree.create_item()

	# T1, T2, T3 按数字顺序
	var tier_keys: Array[int] = []
	tier_keys.assign(groups.keys())
	tier_keys.sort()

	for tier: int in tier_keys:
		var cn_name: String = TIER_LABELS.get(tier, "T%d" % tier)
		var tier_item: TreeItem = _tree.create_item(root)
		tier_item.set_text(0, cn_name)
		tier_item.set_selectable(0, false)
		Logging.info("[SocialConnectionPage]   创建阵营节点 — %s (tier=%d), 共 %d 个 NPC" % [cn_name, tier, groups[tier].size()])

		for doc: NPCDocument in groups[tier]:
			_add_npc_item(tier_item, doc)

	# 未知阵营兜底
	if not unknown_tier_docs.is_empty():
		var unknown_item: TreeItem = _tree.create_item(root)
		unknown_item.set_text(0, UNKNOWN_TIER_LABEL)
		unknown_item.set_selectable(0, false)
		Logging.info("[SocialConnectionPage]   创建「未知阵营」节点, 共 %d 个 NPC" % unknown_tier_docs.size())
		for doc: NPCDocument in unknown_tier_docs:
			_add_npc_item(unknown_item, doc)


# ═══════════════════════════════════════════════════════════
# TreeItem 辅助
# ═══════════════════════════════════════════════════════════

## 在 parent 下创建一个 NPC 叶子节点，metadata 存储 uuid 供点击回调查询
func _add_npc_item(parent: TreeItem, doc: NPCDocument) -> void:
	var label: String = _format_npc_label(doc)
	var npc_item: TreeItem = _tree.create_item(parent)
	npc_item.set_text(0, label)
	npc_item.set_metadata(0, doc.uuid)
	Logging.info("[SocialConnectionPage]     添加 NPC 叶子 — %s (uuid=%s)" % [label, doc.uuid])


func _format_npc_label(doc: NPCDocument) -> String:
	var state_cn: String = PERSON_STATE_CN.get(doc.person_state, doc.person_state)
	var display_name: String = doc.name if not doc.name.is_empty() else doc.uuid
	return "%s · %s" % [state_cn, display_name]


func _format_places(doc: NPCDocument) -> String:
	if doc.preferred_places.is_empty():
		return tr("CODE_SOCIAL_CONNECTION_PAGE_CBAC35BFBD")
	var parts: Array[String] = []
	for place: String in doc.preferred_places:
		parts.append(PLACE_CN.get(place, place))
	return "、".join(parts)


# ═══════════════════════════════════════════════════════════
# Tree 选中事件 → 刷新右侧信息面板
# ═══════════════════════════════════════════════════════════

func _on_tree_item_selected() -> void:
	var selected: TreeItem = _tree.get_selected()
	if selected == null:
		Logging.info("[SocialConnectionPage] 无选中项，清空信息面板")
		_clear_info()
		return

	var uuid: String = selected.get_metadata(0)
	if uuid == null or uuid.is_empty():
		Logging.info("[SocialConnectionPage] 选中项为分组节点（无 metadata），清空信息面板")
		_clear_info()
		return

	Logging.info("[SocialConnectionPage] 选中 TreeItem → uuid=%s" % uuid)

	var doc: NPCDocument = Database.get_npc_document(uuid)
	if doc == null:
		Logging.err("[SocialConnectionPage] Database.get_npc_document('%s') 返回 null" % uuid)
		_clear_info()
		return

	_refresh_info_panel(doc)


func _refresh_info_panel(doc: NPCDocument) -> void:
	Logging.info("[SocialConnectionPage] 刷新信息面板 — name=%s uuid=%s" % [doc.name, doc.uuid])

	# ── Unit8: 基本信息 ──
	var state_cn: String = PERSON_STATE_CN.get(doc.person_state, doc.person_state)
	var basic_text: String = tr("CODE_SOCIAL_CONNECTION_PAGE_90D2FA0B75") % [
		doc.name if not doc.name.is_empty() else doc.uuid,
		state_cn,
		_format_places(doc),
	]
	_info_basic.text = basic_text
	Logging.info("[SocialConnectionPage]   基本信息 — state=%s places=%s" % [doc.person_state, str(doc.preferred_places)])

	# ── Unit2: 关系 ──
	var relation_parts: Array[String] = []

	if not doc.leverage_keys.is_empty():
		relation_parts.append(tr("CODE_SOCIAL_CONNECTION_PAGE_02A90CFD1C") % doc.leverage_keys.size())
		for key: String in doc.leverage_keys:
			relation_parts.append("  · %s" % key)

	if not doc.intro_keys.is_empty():
		relation_parts.append(tr("CODE_SOCIAL_CONNECTION_PAGE_1559C9C814") % doc.intro_keys.size())
		for key: String in doc.intro_keys:
			relation_parts.append("  · %s" % key)

	if doc.help_count > 0:
		relation_parts.append(tr("CODE_SOCIAL_CONNECTION_PAGE_272D014D81") % doc.help_count)

	var relation_text: String
	if relation_parts.is_empty():
		relation_text = tr("CODE_SOCIAL_CONNECTION_PAGE_42ED69BD0B")
	else:
		relation_text = "\n".join(relation_parts)
	_info_relation.text = relation_text
	Logging.info("[SocialConnectionPage]   关系 — leverage=%d intro=%d help=%d" % [doc.leverage_keys.size(), doc.intro_keys.size(), doc.help_count])

	# ── Unit5: 相关人物 ──
	var related_text: String
	if doc.relate_to.is_empty():
		related_text = tr("CODE_SOCIAL_CONNECTION_PAGE_A2A09D3198")
	else:
		var names: Array[String] = []
		for target_tag: String in doc.relate_to:
			var rel_doc: NPCDocument = Database.get_npc_document(target_tag)
			if rel_doc != null and not rel_doc.name.is_empty():
				names.append(rel_doc.name)
			else:
				names.append(target_tag)
		related_text = "、".join(names)
	_info_related.text = related_text
	Logging.info("[SocialConnectionPage]   相关人物 — %s" % str(doc.relate_to))

	# ── Unit6: 可用任务（后端未就绪） ──
	_info_quests.text = tr("CODE_SOCIAL_CONNECTION_PAGE_497C85690C")
	Logging.info("[SocialConnectionPage]   可用任务 — 暂无数据")

	# ── Unit7: 资源转换配方（使用 ActionHintBuilder 构建预览） ──
	var recipe_parts: Array[String] = []
	for action_uuid: String in doc.normal_actions:
		var action: Action = Database.get_action(action_uuid) as Action
		if action == null:
			Logging.warn("[SocialConnectionPage] normal_actions 中的 action '%s' 未在 Database 中找到" % action_uuid)
			continue

		# 使用 ActionHintBuilder.new().build_action_hint 获取结构化 hint
		var hint = ActionHintBuilder.new().build_action_hint(action, false)
		if hint == null:
			continue

		# 标题行：行动名称 + 覆盖关系
		if not action.override_action.is_empty():
			var overridden_action: Action = Database.get_action(action.override_action) as Action
			var overridden_name: String = overridden_action.name if overridden_action else action.override_action
			recipe_parts.append(tr("CODE_SOCIAL_CONNECTION_PAGE_73CA9EBD64") % [action.name, overridden_name])
		else:
			recipe_parts.append("[b]%s[/b]" % action.name)

		# 叙事层（描述）
		if not hint.narrative.is_empty():
			recipe_parts.append("  %s" % hint.narrative)

		# 产出模块（output）
		if hint.output and not hint.output.is_empty():
			for line: String in hint.output.lines:
				recipe_parts.append("  %s" % line)

		# 空行分隔
		recipe_parts.append("")

	var recipe_text: String
	if recipe_parts.is_empty():
		recipe_text = tr("CODE_SOCIAL_CONNECTION_PAGE_ECF3D57F6F")
	else:
		recipe_text = "\n".join(recipe_parts).strip_edges()
	_info_recipes.text = recipe_text
	Logging.info("[SocialConnectionPage]   资源转换配方 — %d 条 action" % doc.normal_actions.size())


func _clear_info() -> void:
	Logging.info("[SocialConnectionPage] 清空信息面板全部字段")
	_info_basic.text = tr("CODE_SOCIAL_CONNECTION_PAGE_4F10F59F78")
	_info_relation.text = ""
	_info_related.text = ""
	_info_quests.text = ""
	_info_recipes.text = ""
