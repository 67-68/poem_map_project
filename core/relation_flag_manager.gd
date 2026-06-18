@tool
class_name RelationFlagManager extends RefCounted

# ═══════════════════════════════════════════════════════════
# RelationFlagManager — 泛型关系标志管理器
#
# 负责管理玩家与 NPC / 社会身份 之间的泛型关系状态。
# 底层基于 PlayerState 的 virtual flag 机制，flag_id 按约定规则自动推导。
#
# ── 命名约定 ──
#
#   flag:  flag_gen_{category}_{TARGET_TAG}
#   event: event_{verb}_{TARGET_TAG}
#
# 其中 TARGET_TAG 来自五维宪法 tag_dictioinary.md 的 TARGET 维度，
# 例如 TARGET_NPC_LIBAI、TARGET_IDENTITY_QINGLIU_OFFICIAL 等。
#
# flag_gen_ 前缀标识此 flag 为代码动态生成（virtual flag），
# 不在 _flags.csv 中预定义，首次使用由 _ensure_virtual_flag() 自动注册。
#
# ── 支持的关系类型 ──
#
#   leverage (把柄/威胁):
#     玩家掌握了某个目标（NPC/身份）的把柄/黑料。
#     存储为 JSON 编码的 str flag：'["quangui_corruption","quangui_treason"]'
#     flag_gen_leverage_{TARGET_TAG}
#     event_threaten_{TARGET_TAG} (通用) / event_threaten_{key} (具体)
#
#   help (帮助/交好):
#     玩家帮助过某个目标（NPC/身份）。
#     flag_gen_help_{TARGET_TAG}
#     event_help_{TARGET_TAG}
#
#   favor (好感度):
#     玩家与某个目标（NPC/身份/势力）的好感度数值。
#     存储为 int flag，默认值 30（中性起点）。
#     懒初始化：首次 get_favor() 时若 flag 不存在则自动注册并设为默认值。
#     flag_gen_favor_{TARGET_TAG}
#
# ── 使用示例 ──
#
#   # 添加把柄
#   RelationFlagManager.add_leverage("TARGET_IDENTITY_QUANGUI", "quangui_corruption")
#
#   # 查询所有把柄 key
#   var keys = RelationFlagManager.get_leverage_keys("TARGET_IDENTITY_QUANGUI")
#
#   # 使用把柄（LIFO）
#   var result = RelationFlagManager.try_use_leverage("TARGET_IDENTITY_QUANGUI")
#   # → {consumed: true, leverage_key: "quangui_corruption", event_id: "event_threaten_quangui_corruption"}
#
# ═══════════════════════════════════════════════════════════

# ── 常量：flag_id 前缀 ──
const FLAG_PREFIX_LEVERAGE: String = "flag_gen_leverage_"
const FLAG_PREFIX_HELP:      String = "flag_gen_help_"
const FLAG_PREFIX_FAVOR:     String = "flag_gen_favor_"

# ── 常量：event_id 前缀 ──
const EVENT_PREFIX_THREATEN: String = "event_threaten_"
const EVENT_PREFIX_HELP:     String = "event_help_"

# ── 注册的 flag 类型 ──
# leverage 使用 str 类型（JSON 数组编码）
# help 使用 int 类型（累加计数器）
# favor 使用 int 类型（好感度数）
const VIRTUAL_FLAG_TYPE_LEVERAGE: String = "str"
const VIRTUAL_FLAG_TYPE_HELP:     String = "int"
const VIRTUAL_FLAG_TYPE_FAVOR:    String = "int"

## 好感度默认值（中性起点）
const DEFAULT_FAVOR: int = 30


# ═══════════════════════════════════════════════════════════
# 底层通用工具
# ═══════════════════════════════════════════════════════════

## 构建 flag_id：flag_gen_{category}_{target_tag}
static func _build_flag_id(category_prefix: String, target_tag: String) -> String:
	return category_prefix + target_tag

## 构建 event_id：event_{verb}_{target_tag}
static func _build_event_id(verb_prefix: String, target_tag: String) -> String:
	return verb_prefix + target_tag

## 确保虚拟 flag 已注册到 PlayerState
static func _ensure_virtual_flag(flag_id: String, flag_type: String = VIRTUAL_FLAG_TYPE_HELP) -> void:
	if not Engine.is_editor_hint():
		if PlayerState and PlayerState.has_method("register_virtual_flag"):
			PlayerState.register_virtual_flag(flag_id, flag_type)
		else:
			Logging.warn("RelationFlagManager: PlayerState 不可用，跳过虚拟 flag 注册: %s" % flag_id)
	else:
		Logging.info("RelationFlagManager: @tool 模式，跳过虚拟 flag 注册: %s" % flag_id)


# ═══════════════════════════════════════════════════════════
# 把柄 / 威胁 (Leverage) — list[str] JSON 编码存储
# ═══════════════════════════════════════════════════════════

## 内部：从 PlayerState 读取 leverage list
static func _get_leverage_list(target_tag: String) -> Array:
	var flag_id = _build_flag_id(FLAG_PREFIX_LEVERAGE, target_tag)
	if PlayerState.has_flag(flag_id):
		var raw = PlayerState.get_flag(flag_id)
		if raw is String and not raw.is_empty():
			var parsed = JSON.parse_string(raw)
			if parsed is Array:
				return parsed
		else:
			Logging.err("RelationFlagManager: _get_leverage_list 读取到非 str 类型数据，flag=%s, raw=%s" % [flag_id, str(raw)])
	return []

## 内部：将 leverage list 写入 PlayerState
static func _set_leverage_list(target_tag: String, list: Array) -> void:
	var flag_id = _build_flag_id(FLAG_PREFIX_LEVERAGE, target_tag)
	_ensure_virtual_flag(flag_id, VIRTUAL_FLAG_TYPE_LEVERAGE)
	var json_str = JSON.stringify(list)
	PlayerState.set_flag(flag_id, json_str, VIRTUAL_FLAG_TYPE_LEVERAGE)
	Logging.info("RelationFlagManager: leverage list set for %s (flag=%s) -> %s" % [target_tag, flag_id, json_str])

## 为目标追加一条把柄 key
static func add_leverage(target_tag: String, leverage_key: String) -> void:
	var list = _get_leverage_list(target_tag)
	if leverage_key in list:
		Logging.info("RelationFlagManager: leverage key '%s' already exists for %s, skip duplicate" % [leverage_key, target_tag])
		return
	list.append(leverage_key)
	_set_leverage_list(target_tag, list)
	Logging.info("RelationFlagManager: leverage +'%s' for %s (flag=flag_gen_leverage_%s)" % [leverage_key, target_tag, target_tag])

## 获取目标当前的所有把柄 key
static func get_leverage_keys(target_tag: String) -> Array:
	return _get_leverage_list(target_tag)

## 检查目标是否有把柄
static func has_leverage(target_tag: String) -> bool:
	var list = _get_leverage_list(target_tag)
	return not list.is_empty()

## 按 key 精确匹配并移除一条把柄
## 返回 true 表示成功消费，false 表示未找到
static func consume_leverage(target_tag: String, leverage_key: String) -> bool:
	var list = _get_leverage_list(target_tag)
	if list.is_empty():
		Logging.info("RelationFlagManager: consume_leverage failed — no leverage for %s" % target_tag)
		return false
	
	var idx = list.find(leverage_key)
	if idx == -1:
		Logging.info("RelationFlagManager: consume_leverage failed — key '%s' not found in %s" % [leverage_key, target_tag])
		return false
	
	list.remove_at(idx)
	_set_leverage_list(target_tag, list)
	Logging.info("RelationFlagManager: consume_leverage '%s' from %s, remaining=%d" % [leverage_key, target_tag, list.size()])
	return true

## 尝试使用把柄（LIFO: pop_back 弹出最近一条）
## 返回: {consumed: bool, leverage_key: String, event_id: String}
##   event_id 优先尝试 event_threaten_{key}（具体事件），不存在则降级到 event_threaten_{target_tag}（通用事件）
static func try_use_leverage(target_tag: String) -> Dictionary:
	var list = _get_leverage_list(target_tag)
	if list.is_empty():
		Logging.info("RelationFlagManager: try_use_leverage — no leverage for %s" % target_tag)
		return {consumed = false, leverage_key = "", event_id = ""}
	
	var key: String = list.pop_back()
	_set_leverage_list(target_tag, list)
	
	# 优先查找具体事件: event_threaten_{key}
	var specific_event_id = _build_event_id(EVENT_PREFIX_THREATEN, key)
	var event_id: String = ""
	
	if Database.get_all_events_iterator().has(specific_event_id):
		event_id = specific_event_id
		Logging.info("RelationFlagManager: try_use_leverage — specific event found: %s" % specific_event_id)
	else:
		# 降级到通用事件: event_threaten_{target_tag}
		event_id = _build_event_id(EVENT_PREFIX_THREATEN, target_tag)
		Logging.info("RelationFlagManager: try_use_leverage — specific event not found (%s), fallback to generic: %s" % [specific_event_id, event_id])
	
	Logging.info("RelationFlagManager: try_use_leverage consumed '%s' from %s, remaining=%d" % [key, target_tag, list.size()])
	return {consumed = true, leverage_key = key, event_id = event_id}

## 清除目标的所有把柄
static func clear_leverage(target_tag: String) -> void:
	_set_leverage_list(target_tag, [])
	Logging.info("RelationFlagManager: leverage cleared for %s" % target_tag)

## 获取威胁事件的约定 event_id（通用降级事件）
##
## 结果遵循命名约定：event_threaten_{TARGET_TAG}
## 此 event_id 对应 data/1_core_rules/relations/ 下的威胁事件文件。
static func get_threaten_event_id(target_tag: String) -> String:
	return _build_event_id(EVENT_PREFIX_THREATEN, target_tag)


# ═══════════════════════════════════════════════════════════
# 帮助 / 交好 (Help) — int 计数器
# ═══════════════════════════════════════════════════════════

## 为目标添加 N 次帮助
static func add_help(target_tag: String, amount: int = 1) -> void:
	var flag_id = _build_flag_id(FLAG_PREFIX_HELP, target_tag)
	_ensure_virtual_flag(flag_id, VIRTUAL_FLAG_TYPE_HELP)
	PlayerState.append_flag(flag_id, amount)
	Logging.info("RelationFlagManager: help ++%d for %s (flag=%s)" % [amount, target_tag, flag_id])

## 获取目标当前的帮助次数
static func get_help(target_tag: String) -> int:
	var flag_id = _build_flag_id(FLAG_PREFIX_HELP, target_tag)
	if PlayerState.has_flag(flag_id):
		return int(PlayerState.get_flag(flag_id))
	return 0

## 检查目标是否有帮助记录
static func has_help(target_tag: String) -> bool:
	var flag_id = _build_flag_id(FLAG_PREFIX_HELP, target_tag)
	return PlayerState.has_flag(flag_id) and int(PlayerState.get_flag(flag_id)) > 0

## 清除目标的所有帮助记录
static func clear_help(target_tag: String) -> void:
	var flag_id = _build_flag_id(FLAG_PREFIX_HELP, target_tag)
	PlayerState.set_flag(flag_id, 0, VIRTUAL_FLAG_TYPE_HELP)
	Logging.info("RelationFlagManager: help cleared for %s (flag=%s)" % [target_tag, flag_id])

## 获取交好事件的约定 event_id
##
## 结果遵循命名约定：event_help_{TARGET_TAG}
## 此 event_id 对应 data/1_core_rules/relations/ 下的帮助/交好事件文件。
static func get_help_event_id(target_tag: String) -> String:
	return _build_event_id(EVENT_PREFIX_HELP, target_tag)


# ═══════════════════════════════════════════════════════════
# 好感度 (Favor) — int 标量，懒初始化默认 30
# ═══════════════════════════════════════════════════════════

## 内部：获取或初始化 favor flag
##
## 若 flag 已存在 → 直接返回其 int 值
## 若 flag 不存在 → 注册虚拟 flag 并写入 DEFAULT_FAVOR
static func _get_or_init_favor(target_tag: String) -> int:
	var flag_id = _build_flag_id(FLAG_PREFIX_FAVOR, target_tag)
	if PlayerState.has_flag(flag_id):
		return int(PlayerState.get_flag(flag_id))
	# 懒初始化：注册并写入默认值
	_ensure_virtual_flag(flag_id, VIRTUAL_FLAG_TYPE_FAVOR)
	PlayerState.set_flag(flag_id, DEFAULT_FAVOR, VIRTUAL_FLAG_TYPE_FAVOR)
	Logging.info("RelationFlagManager: favor initialized for %s (flag=%s, default=%d)" % [target_tag, flag_id, DEFAULT_FAVOR])
	return DEFAULT_FAVOR

## 获取目标当前的好感度
##
## 若从未访问过该目标，自动初始化为 DEFAULT_FAVOR（30）。
## 返回 int 值，无上下界约束。
static func get_favor(target_tag: String) -> int:
	return _get_or_init_favor(target_tag)

## 显式设置目标的好感度
static func set_favor(target_tag: String, value: int) -> void:
	var flag_id = _build_flag_id(FLAG_PREFIX_FAVOR, target_tag)
	_ensure_virtual_flag(flag_id, VIRTUAL_FLAG_TYPE_FAVOR)
	PlayerState.set_flag(flag_id, value, VIRTUAL_FLAG_TYPE_FAVOR)
	Logging.info("RelationFlagManager: favor set to %d for %s (flag=%s)" % [value, target_tag, flag_id])

## 调整目标的好感度（支持负数减好感）
##
## 内部调用 _get_or_init_favor 保证懒初始化，
## 修改后通过 set_favor 落盘。
static func add_favor(target_tag: String, delta: int) -> void:
	var current = _get_or_init_favor(target_tag)
	var new_val = current + delta
	var flag_id = _build_flag_id(FLAG_PREFIX_FAVOR, target_tag)
	PlayerState.set_flag(flag_id, new_val, VIRTUAL_FLAG_TYPE_FAVOR)
	Logging.info("RelationFlagManager: favor %+d → %d for %s (flag=%s)" % [delta, new_val, target_tag, flag_id])

## 检查目标是否已初始化过好感度 flag（不触发懒初始化）
##
## 返回 true 表示该目标曾被显式设置过或查询过（非首次访问）。
static func has_favor_flag(target_tag: String) -> bool:
	var flag_id = _build_flag_id(FLAG_PREFIX_FAVOR, target_tag)
	return PlayerState.has_flag(flag_id)

## 清除目标的好感度 flag（重置为未初始化状态）
## 下次 get_favor() 将重新懒初始化到 DEFAULT_FAVOR
static func clear_favor(target_tag: String) -> void:
	var flag_id = _build_flag_id(FLAG_PREFIX_FAVOR, target_tag)
	PlayerState.remove_flag(flag_id)
	Logging.info("RelationFlagManager: favor cleared for %s (flag=%s)" % [target_tag, flag_id])


# ═══════════════════════════════════════════════════════════
# 好感度社交倍率系统 — 信号钩子驱动的属性修正
# ═══════════════════════════════════════════════════════════
#
# 架构概要：
#   PlayerState.append_stat() 在属性变更前发射 before_property_change 信号，
#   RelationFlagManager 监听此信号，根据 PlayerState.last_event.target_tag
#   查询当前好感度，计算社交倍率，存入静态变量。
#   append_stat() 在信号返回后读取此倍率，修正属性变化量。
#
# 好属性（玩家希望增加的）：
#   literary_fame, official_prestige, talent, money, health, inspiration
#
# 坏属性（玩家希望减少的）：
#   fatigue, burnout
#
# 倍率规则：
#   高好感度 → 好属性倍率 >1.0（更多收益），坏属性倍率 <1.0（更少代价）
#   低好感度 → 好属性倍率 <1.0（更少收益），坏属性倍率 >1.0（更多代价）
# ═══════════════════════════════════════════════════════════

## 硬编码的"好属性"对照表（key 为 Database.prop 的 uuid/name）
const GOOD_PROPS: Dictionary = {
	"literary_fame": true,
	"official_prestige": true,
	"talent": true,
	"money": true,
	"health": true,
	"inspiration": true,
}

## 硬编码的"坏属性"对照表
const BAD_PROPS: Dictionary = {
	"fatigue": true,
	"burnout": true,
}

## 由信号处理器写入、append_stat 读取并重置的社交倍率
static var _current_favor_multiplier: float = 1.0

## 连接 PlayerState 的 before_property_change 信号
static func connect_to_player_state(player: PlayerState) -> void:
	player.before_property_change.connect(_on_before_property_change)
	Logging.info("RelationFlagManager: connected to PlayerState.before_property_change")

## 信号处理器：在属性即将变更时计算好感度社交倍率
static func _on_before_property_change(prop_name: String, delta: int) -> void:
	var target_tag = PlayerState.last_event.get("target_tag", "")
	if target_tag.is_empty():
		_current_favor_multiplier = 1.0
		return
	
	# 只对已知的好/坏属性施加倍率
	var is_good = GOOD_PROPS.has(prop_name)
	var is_bad = BAD_PROPS.has(prop_name)
	if not is_good and not is_bad:
		_current_favor_multiplier = 1.0
		return
	
	var favor = get_favor(target_tag)
	_current_favor_multiplier = _calculate_favor_multiplier(favor, is_good)
	Logging.info("RelationFlagManager: favor=%d, prop=%s, is_good=%s, multiplier=%.2f" % [favor, prop_name, is_good, _current_favor_multiplier])

## 根据好感度计算社交倍率
##
##   DEFAULT_FAVOR=30 → ratio=1.0（中性）
##   favor=60 → ratio=2.0（高好感，好属性 2x，坏属性 0.5x）
##   favor=10 → ratio≈0.33（低好感，好属性 0.33x，坏属性 3x）
static func _calculate_favor_multiplier(favor: int, is_good: bool) -> float:
	var ratio = float(favor) / float(DEFAULT_FAVOR)
	if is_good:
		return clampf(ratio, 0.2, 3.0)
	else:
		return clampf(1.0 / ratio, 0.2, 3.0)

## 消费者模式：获取当前倍率并重置为 1.0
##
## 由 PlayerState.append_stat() 在 before_property_change 信号发射后调用。
static func get_and_reset_favor_multiplier() -> float:
	var m = _current_favor_multiplier
	_current_favor_multiplier = 1.0
	return m


# ═══════════════════════════════════════════════════════════
# 冷却 (Cooldown) — int 标量，每旬消耗 1 点
# ═══════════════════════════════════════════════════════════
#
# 目标标签命名：flag_gen_cd_{TARGET_TAG}
# 例如 flag_gen_cd_qingliu, flag_gen_cd_wangwei
#
# set_cooldown：设置 cd 值为 xun（冷却持续 N 旬）
# is_on_cooldown：检查 cd 是否存在且 > 0
# tick_all_cooldowns：旬末回调，所有 cd 值 -1，归零清除

const FLAG_PREFIX_COOLDOWN: String = "flag_gen_cd_"

## 构建 cd flag_id
static func _build_cd_flag_id(target_tag: String) -> String:
	return FLAG_PREFIX_COOLDOWN + target_tag

## 设置目标的冷却旬数
static func set_cooldown(target_tag: String, xun: int) -> void:
	var flag_id = _build_cd_flag_id(target_tag)
	_ensure_virtual_flag(flag_id, VIRTUAL_FLAG_TYPE_FAVOR)  # reuse 'int' type
	PlayerState.set_flag(flag_id, xun, VIRTUAL_FLAG_TYPE_FAVOR)
	Logging.info("RelationFlagManager: cooldown set %s → %d xun (flag=%s)" % [target_tag, xun, flag_id])

## 检查目标是否在冷却中（flag 存在且值 > 0）
static func is_on_cooldown(target_tag: String) -> bool:
	var flag_id = _build_cd_flag_id(target_tag)
	if not PlayerState.has_flag(flag_id):
		return false
	var val = PlayerState.get_flag(flag_id)
	if val is int and val > 0:
		Logging.info("RelationFlagManager: cooldown active for %s (flag=%s, remaining=%d)" % [target_tag, flag_id, val])
		return true
	return false

## 获取剩余冷却旬数（0 表示无冷却）
static func get_cooldown_remaining(target_tag: String) -> int:
	var flag_id = _build_cd_flag_id(target_tag)
	if not PlayerState.has_flag(flag_id):
		return 0
	var val = PlayerState.get_flag(flag_id)
	if val is int:
		return val
	return 0

## 旬末回调：遍历所有 flag_gen_cd_* flag，值 -1，归零则删除
static func tick_all_cooldowns() -> void:
	Logging.info("RelationFlagManager: tick_all_cooldowns — scanning for cd flags")
	var flags_to_remove: Array[String] = []
	var flags_to_decrement: Array[String] = []

	# PlayerState 的 flags 是 Dictionary: flag_id → value
	for flag_id in PlayerState.flags.keys():
		if not flag_id.begins_with(FLAG_PREFIX_COOLDOWN):
			continue
		var val = PlayerState.get_flag(flag_id)
		if val is int:
			var new_val = val - 1
			if new_val <= 0:
				flags_to_remove.append(flag_id)
				Logging.info("RelationFlagManager: cooldown expired, removing %s" % flag_id)
			else:
				flags_to_decrement.append(flag_id)
				PlayerState.set_flag(flag_id, new_val, VIRTUAL_FLAG_TYPE_FAVOR)
				Logging.info("RelationFlagManager: cooldown decrement %s → %d" % [flag_id, new_val])

	for flag_id in flags_to_remove:
		PlayerState.remove_flag(flag_id)
