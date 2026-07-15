extends Node
## VolatileState — 跨一整个 action 树的挥发性共享状态
##
## 不可能同时打开两个 action 树，所以用单一实例承载。
## 每次新 action 树启动时覆盖写入，执行完毕后 clear()。
##
## 消费方：
##   MainActionButton → 写入 pending_* + push_sub_action_picker
##   SubActionButton → 写入 selected_sub_action_uuid（Toggle）
##   NpcActionButton → 读取 selected_sub_action_uuid + pending_* → SubActionExecutor.execute()
##   SubActionExecutor → 执行完毕后 clear()

## ── 内部状态容器 ──────────────────────────────
class VolatileActionState:
	var selected_sub_action_uuid: String = ""       ## SubActionButton Toggle 写入
	var selected_entity_place_mismatch: bool = false  ## 选中 entity 是否异地
	var selected_entity_required_place: String = ""   ## 选中 entity 需要的目标地点 key
	var selected_entity_required_place_name: String = ""  ## 选中 entity 需要的目标地点中文名
	var pending_main_tag: String = ""               ## 父 action main_tag
	var pending_fallback: String = ""               ## 父 action fallback_event_uuid
	var pending_tags: Array[String] = []            ## 父 action tags
	var pending_results: Array = []                 ## 父 action_results operators
	var pending_parent_day_consumed: float = 0.0    ## 父 action day_consumed
	var pending_outcome: String = "success"         ## 父 action outcome（success/failure）
	var pending_on_checkbox_toggled: Callable = Callable()  ## Picker CheckBox toggle callback
	var did_auto_enable_remote: bool = false        ## zhu_liu 自动开启「显示异地行动」标记
	var npc_target: String = ""                     ## 从 cost archetype init() 提取的 NPC 标识

	func clear() -> void:
		selected_sub_action_uuid = ""
		selected_entity_place_mismatch = false
		selected_entity_required_place = ""
		selected_entity_required_place_name = ""
		pending_main_tag = ""
		pending_fallback = ""
		pending_tags.clear()
		pending_results.clear()
		pending_parent_day_consumed = 0.0
		pending_outcome = "success"
		pending_on_checkbox_toggled = Callable()
		did_auto_enable_remote = false
		npc_target = ""
		Logging.info("VolatileActionState.clear: 已清理所有 pending 数据")

	func has_pending() -> bool:
		return not pending_main_tag.is_empty() or not pending_tags.is_empty()


## ── 全局单例 ──────────────────────────────────
var action_state: VolatileActionState = VolatileActionState.new()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Logging.info("VolatileState._ready: autoload 已就绪")
