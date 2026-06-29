class_name ActionSelector extends RefCounted
## 抽卡引擎 — 从候选池中按平方权重随机选择，支持预留插队。
##
## 纯逻辑，不持有 ActionManager 的引用，不修改任何外部状态。
## 返回结构化结果供调用方处理提示文本等后续工作。


## 一次抽取结果的数据结构。
## selected_actions: 按序选中的 SceneAction 数组。
## selected_ids: 已中签的 action UUID 字典（key=uuid, val=true）。
## reserved_count: 预留消耗数。
## random_count: 随机抽取消耗数。
class SelectionResult:
	var selected_actions: Array[SceneAction] = []
	var selected_ids: Dictionary = {}
	var reserved_count: int = 0
	var random_count: int = 0


## 从 action_pool 中按规则抽取 pick_count 个 action。
##
## action_pool: 候选项字典 { action_id: weight(1) }
## reserved_action_ids: 本回合应预留的 action ID 列表（优先中签）
## pick_count: 目标抽取数，默认 6
##
## 返回 SelectionResult，包含选中的 actions 和选中 ID 集合。
static func select(
	action_pool: Dictionary,
	reserved_action_ids: Array[String],
	pick_count: int
) -> SelectionResult:
	var result := SelectionResult.new()
	var available_pool = action_pool.duplicate()
	
	# ── Phase 1: 预留插队 ──
	for reserved_id in reserved_action_ids:
		if result.selected_actions.size() >= pick_count:
			break
		if available_pool.has(reserved_id):
			result.selected_actions.append(
				Database.get_action(reserved_id) as SceneAction
			)
			available_pool.erase(reserved_id)
	
	result.reserved_count = result.selected_actions.size()
	
	# ── Phase 2: 平方权重随机抽取（无放回）──
	while result.selected_actions.size() < pick_count and not available_pool.is_empty():
		var total_weight := 0.0
		for action_id in available_pool:
			total_weight += pow(available_pool[action_id], 2)
		
		var roll := randf_range(0.0, total_weight)
		var cursor := 0.0
		
		for action_id in available_pool:
			cursor += pow(available_pool[action_id], 2)
			if roll <= cursor:
				result.selected_actions.append(
					Database.get_action(action_id) as SceneAction
				)
				available_pool.erase(action_id)
				break
	
	result.random_count = result.selected_actions.size() - result.reserved_count
	
	# ── 构建选中 ID 索引 ──
	for sa in result.selected_actions:
		if sa:
			result.selected_ids[sa.uuid] = true
	
	return result
