@tool
class_name ModifierPropRegistrar extends RefCounted
## ModifierPropRegistrar — 修饰符属性注册器
##
## 监听城府/才华/定力（astuteness/talent/composure）的属性变化，
## 自动将 8 条 S 型阻尼效果注册到 GameSave.data.active_modifiers。
##
## 注册条目 type = "modifier_prop_effect"，与 BuffOperator 的理念 buff
## （type = "efficiency" / "per_xun_passive" 等）共享同一个注册表。
##
## 查询侧由 ModifierRegistry.get_modifier_prop_adjusted_delta() 统一入口。

const _ModifierConfig = preload("res://core/modifier_config.gd")

const MODIFIER_PROPS: Array[String] = ["astuteness", "talent", "composure"]
const SOURCE_PREFIX := "modifier_prop:"
const ENTRY_TYPE := "modifier_prop_effect"

static var _initialized := false


## 初始化：连接 PlayerState.player_stat_changed 信号，并注册当前初始值。
## 应在 PlayerState 就绪后、首次 append_stat 之前调用。
static func initialize() -> void:
	if _initialized:
		Logging.warn("[ModifierPropRegistrar] initialize: already initialized, skipping")
		return
	_initialized = true

	if not PlayerState.player_stat_changed.is_connected(_on_stat_changed):
		PlayerState.player_stat_changed.connect(_on_stat_changed)
		Logging.info("[ModifierPropRegistrar] initialize: connected to PlayerState.player_stat_changed")
	else:
		Logging.info("[ModifierPropRegistrar] initialize: signal already connected (reload scenario)")

	# 🆕 初始注册：为三条修饰符属性注册当前值对应的效果
	for prop in MODIFIER_PROPS:
		_sync_prop(prop)

	Logging.info("[ModifierPropRegistrar] initialize: complete — %s initial entries registered" % str(MODIFIER_PROPS))


# ════════════════════════════════════════════════════════════════
# 信号处理
# ════════════════════════════════════════════════════════════════

static func _on_stat_changed(prop_name: String) -> void:
	if prop_name not in MODIFIER_PROPS:
		return
	Logging.info("[ModifierPropRegistrar] _on_stat_changed: prop='%s' changed, syncing..." % prop_name)
	_sync_prop(prop_name)


# ════════════════════════════════════════════════════════════════
# 注册/注销
# ════════════════════════════════════════════════════════════════

## 同步单条修饰符属性：先删旧，再按新值注册
static func _sync_prop(prop_name: String) -> void:
	Logging.info("[ModifierPropRegistrar] _sync_prop: start for '%s'" % prop_name)

	# 1. 删除旧条目
	_unregister_prop(prop_name)

	# 2. 获取当前值
	var mod_val: int = PlayerState.get_stat_val(prop_name) as int
	# 🆕 即使值为0也注册（pct=0%），让 UI hint 能展示效果清单

	# 3. 遍历 MODIFIER_EFFECTS，注册匹配的效果
	var registered := 0
	for effect in _ModifierConfig.MODIFIER_EFFECTS:
		if effect.source_prop != prop_name:
			continue

		var entry := {
			"source": SOURCE_PREFIX + prop_name,
			"type": ENTRY_TYPE,
			"source_prop": prop_name,
			"target_prop": effect.target_prop,
			"direction": effect.direction,
			"delta_sign": effect.delta_sign,
			"faction_filter": effect.faction_filter,
			"mod_val": mod_val,
			"max_limit": effect.max_limit,
			"half_point": effect.half_point,
			"hint_text": effect.hint_text,
		}
		GameSave.data.active_modifiers.append(entry)
		registered += 1
		Logging.info("[ModifierPropRegistrar] _sync_prop: registered entry — source='%s%s' target='%s' dir=%s sign=%s faction='%s' mod_val=%d max=%.1f half=%.1f" % [SOURCE_PREFIX, prop_name, effect.target_prop, effect.direction, effect.delta_sign, effect.faction_filter, mod_val, effect.max_limit, effect.half_point])

	Logging.info("[ModifierPropRegistrar] _sync_prop: '%s' complete — %d effects registered (mod_val=%d)" % [prop_name, registered, mod_val])


## 删除所有 source 匹配 "modifier_prop:{prop_name}" 且 type="modifier_prop_effect" 的条目
static func _unregister_prop(prop_name: String) -> void:
	var source_key := SOURCE_PREFIX + prop_name
	var remaining: Array[Dictionary] = []
	var removed := 0

	for entry in GameSave.data.active_modifiers:
		if entry.get("source") == source_key and entry.get("type") == ENTRY_TYPE:
			removed += 1
		else:
			remaining.append(entry)

	if removed > 0:
		GameSave.data.active_modifiers = remaining
		Logging.info("[ModifierPropRegistrar] _unregister_prop: removed %d entries for source='%s'" % [removed, source_key])
	else:
		Logging.info("[ModifierPropRegistrar] _unregister_prop: no entries to remove for source='%s'" % source_key)
