extends Node
## PlayerObserver — 资源消耗观测器 (autoload)
##
## 监听 PlayerState.before_property_change 信号，收集负向资源变更（消耗），
## 按 identity（action uuid 或 topic）分桶存储，同时维护 resource → topic 对照表。
##
## 生命周期：
##   push_cost_context(identity) → cost 执行 → pop_cost_context()
##   每调用一次 append_stat 且 delta < 0 时，自动记录到对应桶。
##
## 数据结构：
##   consumption_by_identity: { identity: { prop: abs_delta } }
##     - "action_fangshi":     { money: 200, health: 50 }
##     - "social":             { money: 100 }   ← topic 路径
##     - "action_jiaoyou_li_bai": { money: 50 }
##
##   resource_to_topic: { prop: { topic: abs_delta } }
##     - money:    { "social": 100, "poem": 50 }
##     - prestige: { "social": 30 }
##
## 查阅方：依赖 PlayerState.get_current_cost_context() 读取当前活跃身份。

## ── 消耗数据：按身份分桶 ──
## Key: identity (String) — action uuid 或 topic ("social"/"poem"/"baiye")
## Value: Dictionary[String, int] — { prop_name: total_consumed }
var consumption_by_identity: Dictionary = {}

## ── 资源 → topic 对照表 ──
## Key: 资源名 (String) — "money", "health", etc.
## Value: Dictionary[String, int] — { topic: total_consumed }
var resource_to_topic: Dictionary = {}

## 活跃的 topic 枚举集合（用于快速判定 identity 是否为 topic）
const TOPIC_VALUES: Array[String] = ["social", "poem", "baiye"]


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# 延迟连接信号，确保 PlayerState 已就绪
	call_deferred("_connect_signals")
	Logging.info("[PlayerObserver] _ready: autoload 已就绪")


func _connect_signals() -> void:
	if not PlayerState.before_property_change.is_connected(_on_before_property_change):
		PlayerState.before_property_change.connect(_on_before_property_change)
		Logging.info("[PlayerObserver] 已连接 PlayerState.before_property_change 信号")
	else:
		Logging.info("[PlayerObserver] before_property_change 已连接，跳过重复连接")


## ────────────────────────────────────────────────
## 信号处理
## ────────────────────────────────────────────────

## 仅追踪负向变更（消耗）。delta >= 0 时忽略。
## 从 PlayerState.get_current_cost_context() 读当前活跃身份，
## 无活跃身份时忽略（不在 cost scope 内）。
func _on_before_property_change(prop_name: String, delta: int) -> void:
	if delta >= 0:
		Logging.debug("[PlayerObserver] _on_before_property_change: prop=%s delta=%d (非消耗, 跳过)" % [prop_name, delta])
		return

	var identity: String = PlayerState.get_current_cost_context()
	if identity.is_empty():
		Logging.debug("[PlayerObserver] _on_before_property_change: prop=%s delta=%d (无 cost context, 跳过)" % [prop_name, delta])
		return

	var abs_delta: int = -delta
	Logging.info("[PlayerObserver] _on_before_property_change: identity=%s prop=%s consumed=%d" % [identity, prop_name, abs_delta])

	# ── 写入 consumption_by_identity ──
	if not consumption_by_identity.has(identity):
		consumption_by_identity[identity] = {}
	var bucket: Dictionary = consumption_by_identity[identity]
	bucket[prop_name] = bucket.get(prop_name, 0) + abs_delta
	Logging.info("[PlayerObserver] consumption_by_identity[%s][%s] = %d (累计)" % [identity, prop_name, bucket[prop_name]])

	# ── 写入 resource_to_topic（仅当 identity 是 topic）──
	if identity in TOPIC_VALUES:
		if not resource_to_topic.has(prop_name):
			resource_to_topic[prop_name] = {}
		var topic_dict: Dictionary = resource_to_topic[prop_name]
		topic_dict[identity] = topic_dict.get(identity, 0) + abs_delta
		Logging.info("[PlayerObserver] resource_to_topic[%s][%s] = %d (累计)" % [prop_name, identity, topic_dict[identity]])


## ────────────────────────────────────────────────
## 查询接口
## ────────────────────────────────────────────────

## 获取指定 identity 的消耗明细。
## @return Dictionary — { prop_name: int }，无记录时返回空 dict
func get_consumption(identity: String) -> Dictionary:
	if not consumption_by_identity.has(identity):
		return {}
	return consumption_by_identity[identity].duplicate()


## 获取所有消耗记录（浅拷贝）。
func get_all_consumption() -> Dictionary:
	return consumption_by_identity.duplicate(true)


## 获取指定资源的 topic 消耗明细。
## @return Dictionary — { topic: int }，无记录时返回空 dict
func get_resource_topics(prop_name: String) -> Dictionary:
	if not resource_to_topic.has(prop_name):
		return {}
	return resource_to_topic[prop_name].duplicate()


## 获取完整 resource_to_topic 表（深拷贝）。
func get_all_resource_topics() -> Dictionary:
	return resource_to_topic.duplicate(true)


## ────────────────────────────────────────────────
## 生命周期管理
## ────────────────────────────────────────────────

## 清空所有观察数据（例如新的一旬开始时调用）。
func clear() -> void:
	consumption_by_identity.clear()
	resource_to_topic.clear()
	Logging.info("[PlayerObserver] clear: 已清空所有消耗记录")


## 清空指定 identity 的消耗记录。
func clear_identity(identity: String) -> void:
	if consumption_by_identity.erase(identity):
		Logging.info("[PlayerObserver] clear_identity: 已清除 identity='%s'" % identity)
	else:
		Logging.info("[PlayerObserver] clear_identity: identity='%s' 不存在，无需清除" % identity)

func get_time_action_rank():
	pass

func get_specific_resource(drained_resource_type: String):
	pass

func get_midware_product():
	pass
	
