extends Node
## PlayerObserver — 资源消耗观测器 + 里程碑追踪器 (autoload)
##
## 三层架构：
##   Layer 1 — 信号输入：5 个分散的信号监听入口
##   Layer 2 — 统一累加器 + 分桶：unified_accumulators / consumption_by_identity / resource_to_topic
##   Layer 3 — 里程碑配方轮询：对 milestones_config.json 逐条检测阈值
##
## 信号源矩阵：
##   before_property_change → 消耗追踪 + 属性累加 (health/money/time)
##   on_person_state_changed → 结交朋友计数 (know_about)
##   poems_created           → 诗词创作计数
##   idea_upgraded           → 理念获取计数
##   on_xun_tick             → 每旬+1 存活旬数
##
## 数据结构：
##   unified_accumulators: { accumulator_name: int }
##   consumption_by_identity: { identity: { prop: abs_delta } }
##   resource_to_topic: { prop: { topic: abs_delta } }
##   achieved_milestones: { milestone_key: { "achieved_at_day": int } }

# ════════════════════════════════════════════════════════════════
# Layer 1: 信号入口
# ════════════════════════════════════════════════════════════════

## ── 消耗数据：按身份分桶（需 cost context）──
var consumption_by_identity: Dictionary = {}

## ── 资源 → topic 对照表（仅 topic 路径写入）──
var resource_to_topic: Dictionary = {}

const TOPIC_VALUES: Array[String] = ["social", "poem", "baiye"]

## ── Layer 2: 统一累加器 ──
var unified_accumulators: Dictionary = {}

## ── Layer 3: 已达成里程碑 ──
var achieved_milestones: Dictionary = {}

## ── 里程碑配置缓存（从 milestones_config.json 加载）──
var _milestones_config: Array = []

## 需要累加到 unified_accumulators 的属性映射
## before_property_change 中 prop_name → accumulator_key
const PROP_ACCUMULATOR_MAP: Dictionary = {
	"health": "health_consumed",
	"money":  "money_consumed",
	"time":   "days_consumed",
}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_load_milestones_config()
	call_deferred("_connect_signals")
	Logging.info("[PlayerObserver] _ready: autoload 已就绪, 加载 %d 条里程碑配方" % _milestones_config.size())


## ────────────────────────────────────────────────
## Layer 1: 信号连接
## ────────────────────────────────────────────────

func _connect_signals() -> void:
	# -- 属性消耗/变更 --
	if not PlayerState.before_property_change.is_connected(_on_before_property_change):
		PlayerState.before_property_change.connect(_on_before_property_change)
		Logging.info("[PlayerObserver] 已连接 PlayerState.before_property_change")

	# -- 社交关系变更 --
	if not EventBus.on_person_state_changed.is_connected(_on_person_state_changed):
		EventBus.on_person_state_changed.connect(_on_person_state_changed)
		Logging.info("[PlayerObserver] 已连接 EventBus.on_person_state_changed")

	# -- 诗词创作 --
	if not EventBus.poems_created.is_connected(_on_poems_created):
		EventBus.poems_created.connect(_on_poems_created)
		Logging.info("[PlayerObserver] 已连接 EventBus.poems_created")

	# -- 理念获取/升级 --
	if not EventBus.idea_upgraded.is_connected(_on_idea_upgraded):
		EventBus.idea_upgraded.connect(_on_idea_upgraded)
		Logging.info("[PlayerObserver] 已连接 EventBus.idea_upgraded")

	# -- 每旬推进 --
	if not TimeService.on_xun_tick.is_connected(_on_xun_tick):
		TimeService.on_xun_tick.connect(_on_xun_tick)
		Logging.info("[PlayerObserver] 已连接 TimeService.on_xun_tick")


## ────────────────────────────────────────────────
## Layer 1: 信号处理器
## ────────────────────────────────────────────────

## before_property_change: 双通道处理
##   Channel A: 有 cost context 时写入 consumption_by_identity + resource_to_topic（消耗分桶）
##   Channel B: 属性名匹配 health/money/time 时累加到 unified_accumulators（里程碑累加）
func _on_before_property_change(prop_name: String, delta: int) -> void:
	# ── Channel A: cost context 分桶（仅消耗）──
	if delta < 0:
		_handle_cost_context_recording(prop_name, delta)
		_handle_property_accumulation(prop_name, delta)

	Logging.debug("[PlayerObserver] _on_before_property_change: prop=%s delta=%d 处理完成" % [prop_name, delta])


## Channel A: cost context 分桶记录
func _handle_cost_context_recording(prop_name: String, delta: int) -> void:
	var identity: String = PlayerState.get_current_cost_context()
	if identity.is_empty():
		Logging.debug("[PlayerObserver] _handle_cost_context_recording: prop=%s delta=%d (无 cost context, 跳过分桶)" % [prop_name, delta])
		return

	var abs_delta: int = -delta
	Logging.info("[PlayerObserver] cost 分桶: identity=%s prop=%s consumed=%d" % [identity, prop_name, abs_delta])

	# -- consumption_by_identity --
	if not consumption_by_identity.has(identity):
		consumption_by_identity[identity] = {}
	var bucket: Dictionary = consumption_by_identity[identity]
	bucket[prop_name] = bucket.get(prop_name, 0) + abs_delta
	Logging.info("[PlayerObserver] consumption_by_identity[%s][%s] = %d (累计)" % [identity, prop_name, bucket[prop_name]])

	# -- resource_to_topic（仅 topic 路经）--
	if identity in TOPIC_VALUES:
		if not resource_to_topic.has(prop_name):
			resource_to_topic[prop_name] = {}
		var topic_dict: Dictionary = resource_to_topic[prop_name]
		topic_dict[identity] = topic_dict.get(identity, 0) + abs_delta
		Logging.info("[PlayerObserver] resource_to_topic[%s][%s] = %d (累计)" % [prop_name, identity, topic_dict[identity]])


## Channel B: 属性累加到 unified_accumulators（无需 cost context）
func _handle_property_accumulation(prop_name: String, delta: int) -> void:
	if delta >= 0:
		return

	var accumulator_key: String = PROP_ACCUMULATOR_MAP.get(prop_name, "")
	if accumulator_key.is_empty():
		return

	var abs_delta: int = -delta
	var old_val: int = unified_accumulators.get(accumulator_key, 0)
	var new_val: int = old_val + abs_delta
	unified_accumulators[accumulator_key] = new_val
	Logging.info("[PlayerObserver] 属性累加: %s +%d → %d (prop=%s delta=%d)" % [accumulator_key, abs_delta, new_val, prop_name, delta])

	_check_milestones_for_accumulator(accumulator_key)


## on_person_state_changed: 结交朋友计数
## 仅当 new_state == "know_about" 时累加 friends_made
func _on_person_state_changed(target_tag: String, new_state: String) -> void:
	if new_state != "know_about":
		Logging.debug("[PlayerObserver] _on_person_state_changed: target=%s new_state=%s (非 know_about, 跳过)" % [target_tag, new_state])
		return

	var old_val: int = unified_accumulators.get("friends_made", 0)
	var new_val: int = old_val + 1
	unified_accumulators["friends_made"] = new_val
	Logging.info("[PlayerObserver] 结交朋友: friends_made +1 → %d (target=%s)" % [new_val, target_tag])

	_check_milestones_for_accumulator("friends_made")


## poems_created: 诗词创作计数
func _on_poems_created(_data: Array = []) -> void:
	var old_val: int = unified_accumulators.get("poems_created", 0)
	var new_val: int = old_val + 1
	unified_accumulators["poems_created"] = new_val
	Logging.info("[PlayerObserver] 诗词创作: poems_created +1 → %d" % new_val)

	_check_milestones_for_accumulator("poems_created")


## idea_upgraded: 理念获取/升级计数（获取+升级都算+1）
func _on_idea_upgraded() -> void:
	var old_val: int = unified_accumulators.get("ideas_accepted", 0)
	var new_val: int = old_val + 1
	unified_accumulators["ideas_accepted"] = new_val
	Logging.info("[PlayerObserver] 理念获取: ideas_accepted +1 → %d" % new_val)

	_check_milestones_for_accumulator("ideas_accepted")


## on_xun_tick: 每旬存活计数
func _on_xun_tick() -> void:
	var old_val: int = unified_accumulators.get("xun_lived", 0)
	var new_val: int = old_val + 1
	unified_accumulators["xun_lived"] = new_val
	Logging.info("[PlayerObserver] 每旬推进: xun_lived +1 → %d" % new_val)

	_check_milestones_for_accumulator("xun_lived")


# ════════════════════════════════════════════════════════════════
# Layer 2: 配置加载
# ════════════════════════════════════════════════════════════════

## 从 core/milestones_config.json 加载里程碑配方
func _load_milestones_config() -> void:
	var file := FileAccess.open("res://core/milestones_config.json", FileAccess.READ)
	if not file:
		Logging.warn("[PlayerObserver] _load_milestones_config: 无法打开 milestones_config.json")
		return
	var content := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(content)
	if parsed == null or not parsed is Dictionary:
		Logging.err("[PlayerObserver] _load_milestones_config: JSON 解析失败")
		return

	_milestones_config = parsed.get("milestones", [])
	if _milestones_config.is_empty():
		Logging.warn("[PlayerObserver] _load_milestones_config: milestones 数组为空")
	else:
		Logging.info("[PlayerObserver] _load_milestones_config: 成功加载 %d 条里程碑配方" % _milestones_config.size())


# ════════════════════════════════════════════════════════════════
# Layer 3: 里程碑轮询
# ════════════════════════════════════════════════════════════════

## 针对某个累加器，检查所有引用该累加器的里程碑是否达成。
## 每次累加器数值变更后调用。
func _check_milestones_for_accumulator(accumulator_key: String) -> void:
	var current_val: int = unified_accumulators.get(accumulator_key, 0)

	for entry in _milestones_config:
		if not entry is Dictionary:
			continue
		var entry_accumulator: String = entry.get("accumulator", "")
		if entry_accumulator != accumulator_key:
			continue

		var key: String = entry.get("key", "")
		if key.is_empty():
			Logging.warn("[PlayerObserver] _check_milestones_for_accumulator: 配方缺少 key，跳过")
			continue

		# 已达成则不再重复触发
		if achieved_milestones.has(key):
			continue

		var threshold: int = int(entry.get("threshold", 0))
		if current_val >= threshold:
			var current_day: int = TimeService._total_days_elapsed
			achieved_milestones[key] = {"achieved_at_day": current_day}
			Logging.info("[PlayerObserver] 里程碑达成: key=%s accumulator=%s current=%d threshold=%d day=%d desc='%s'" % [
				key, entry_accumulator, current_val, threshold, current_day, entry.get("desc", "")
			])
			EventBus.milestone_achieved.emit(key, entry.duplicate())


# ════════════════════════════════════════════════════════════════
# 查询接口 (Layer 2 消费方)
# ════════════════════════════════════════════════════════════════

## 获取指定累加器的当前值
func get_accumulator(key: String) -> int:
	return unified_accumulators.get(key, 0)


## 获取所有累加器（浅拷贝）
func get_all_accumulators() -> Dictionary:
	return unified_accumulators.duplicate()


## 获取指定 identity 的消耗明细
func get_consumption(identity: String) -> Dictionary:
	if not consumption_by_identity.has(identity):
		return {}
	return consumption_by_identity[identity].duplicate()


## 获取所有消耗记录（深拷贝）
func get_all_consumption() -> Dictionary:
	return consumption_by_identity.duplicate(true)


## 获取指定资源的 topic 消耗明细
func get_resource_topics(prop_name: String) -> Dictionary:
	if not resource_to_topic.has(prop_name):
		return {}
	return resource_to_topic[prop_name].duplicate()


## 获取完整 resource_to_topic 表（深拷贝）
func get_all_resource_topics() -> Dictionary:
	return resource_to_topic.duplicate(true)


## 获取所有已达成里程碑
func get_achieved_milestones() -> Dictionary:
	return achieved_milestones.duplicate(true)


## 检查某个里程碑是否已达成
func is_milestone_achieved(key: String) -> bool:
	return achieved_milestones.has(key)


# ════════════════════════════════════════════════════════════════
# 生命周期管理
# ════════════════════════════════════════════════════════════════

## 清空所有观察数据（消耗分桶 + 累加器 + 里程碑），重新加载配方。
func clear() -> void:
	consumption_by_identity.clear()
	resource_to_topic.clear()
	unified_accumulators.clear()
	achieved_milestones.clear()
	Logging.info("[PlayerObserver] clear: 已清空所有记录")


## 清空指定 identity 的消耗记录
func clear_identity(identity: String) -> void:
	if consumption_by_identity.erase(identity):
		Logging.info("[PlayerObserver] clear_identity: 已清除 identity='%s'" % identity)
	else:
		Logging.info("[PlayerObserver] clear_identity: identity='%s' 不存在，无需清除" % identity)
