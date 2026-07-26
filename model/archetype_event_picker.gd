class_name ArchetypeEventPicker extends BaseEventPicker
## 通用 Archetype 事件选择器。
##
## 职责：
##   1. 从 _archetypes 列表中均分概率随机选取一个 archetype key
##   2. 在 _fallback_map 中查找该 archetype 对应的 fallback event uuid
##   3. 向 ctx 注入 archetype_base 和 outcome，供 RandomEvent.init() 运行时注入 operators
##
## 子类在 _init() 中填充 _archetypes 和 _fallback_map 即可。
## 不负责：事件推送（由调用方 ActionManager 完成）、Database 查询。


## 候选 archetype key 列表（对应 Database.action_archetypes 中的 key）。
## 子类 _init() 填充。pick() 中 rand_i % size() 均分概率选取。
var _archetypes: Array[String] = []

## archetype key → fallback event uuid 映射。
## 子类 _init() 填充。key 必须覆盖 _archetypes 中的每一项。
var _fallback_map: Dictionary = {}

## 注入到 ctx 的 outcome 值，默认 "success"。
## 子类可覆写为 "failure" 等。
var _outcome: String = "success"


## 核心选取逻辑。
## 输入 ctx 会被原地修改（注入 archetype_base + outcome），
## 返回选中的 fallback event uuid（空字符串表示未命中）。
func pick(ctx: Dictionary) -> String:
	Logging.info("[ArchetypeEventPicker] pick() called, ctx keys=%s, _archetypes=%s" % [str(ctx.keys()), str(_archetypes)])

	if _archetypes.is_empty():
		Logging.err("[ArchetypeEventPicker] _archetypes 为空，无法选取 archetype")
		return ""

	# ── 1. 均分概率随机选取 archetype ──
	var arch: String = _select_archetype()
	if arch.is_empty():
		Logging.err("[ArchetypeEventPicker] _select_archetype() 返回空")
		return ""

	# ── 2. 查找 fallback event uuid ──
	var fallback: String = _resolve_fallback(arch)
	if fallback.is_empty():
		Logging.warn("[ArchetypeEventPicker] archetype '%s' 在 _fallback_map 中无映射，返回空" % arch)
		return ""

	# ── 3. 向 ctx 注入 archetype 信息 ──
	_inject_archetype(ctx, arch)

	Logging.info("[ArchetypeEventPicker] 选中 archetype='%s' → fallback='%s', outcome='%s'" % [arch, fallback, _outcome])
	return fallback


## 均分概率随机选取一个 archetype key。
## 子类可覆写以支持加权选取。
func _select_archetype() -> String:
	var idx: int = randi() % _archetypes.size()
	Logging.info("[ArchetypeEventPicker] _select_archetype: idx=%d/%d → '%s'" % [idx, _archetypes.size(), _archetypes[idx]])
	return _archetypes[idx]


## 从 _fallback_map 查找 archetype 对应的 fallback event uuid。
## 子类可覆写以支持 Database 查找等复杂解析。
func _resolve_fallback(arch_key: String) -> String:
	if _fallback_map.has(arch_key):
		var fb: String = _fallback_map[arch_key]
		Logging.info("[ArchetypeEventPicker] _resolve_fallback: '%s' → '%s'" % [arch_key, fb])
		return fb
	Logging.warn("[ArchetypeEventPicker] _resolve_fallback: '%s' 未在 _fallback_map 中找到" % arch_key)
	return ""


## 向 ctx 注入 archetype_base 和 outcome。
## RandomEvent.init() 会读取这两个 key 并调用 Database.get_archetype_by_uuid() 注入 operators。
func _inject_archetype(ctx: Dictionary, arch_key: String) -> void:
	ctx["archetype_base"] = arch_key
	ctx["outcome"] = _outcome
	Logging.info("[ArchetypeEventPicker] _inject_archetype: ctx['archetype_base']='%s', ctx['outcome']='%s'" % [arch_key, _outcome])
