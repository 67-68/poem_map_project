@tool
class_name RandomEvent extends BaseEvent
# 那种在事件池随机抽取的

# 🚨 @tool 模式下类继承链可能未完全加载，BaseEvent 上定义的
# `pre_event_interrupter_sequence` 属性可能不可达。
# 直接赋值会触发 Godot ERR_FAIL → abort 调用方函数 💀
#
# 通过 _set()/_get()/_get_property_list() 兜底：
# - 常规属性查找失败时，_set() 将值存入 _interruption_seq_fallback
# - _get() 返回 fallback 值（供 @tool 模式下读取）
# - _get_property_list() 在 fallback 被激活时注册该属性到 property list，
#   确保 .tres 序列化能正确保存 💾
#
# 非 @tool 模式下继承链正常，_set() 不会被触发，无副作用。
var _interruption_seq_fallback: Array = []
var _interruption_seq_fallback_used: bool = false

func _set(property: StringName, value: Variant) -> bool:
    if property == &"pre_event_interrupter_sequence":
        _interruption_seq_fallback = value
        _interruption_seq_fallback_used = true
        return true
    return false

func _get(property: StringName) -> Variant:
    if property == &"pre_event_interrupter_sequence" and _interruption_seq_fallback_used:
        return _interruption_seq_fallback
    return null

func _get_property_list() -> Array:
    # 只在 fallback 被激活时（即 @tool 模式下属性不可达）才注册，
    # 避免与正常继承链注册的 @export 属性冲突
    if _interruption_seq_fallback_used:
        return [{
            "name": &"pre_event_interrupter_sequence",
            "type": TYPE_ARRAY,
            "usage": PROPERTY_USAGE_DEFAULT
        }]
    return []


@export var weight: float = 10.0
# _raw_requirement: .tres 反序列化写入的目标字段。
# 通过 requirement getter 懒合并 archetype universal_requirement 后对外暴露。
var _raw_requirement: BaseRequirements
var _archetype_requirement_merged: bool = false

@export var requirement: BaseRequirements:
    get:
        if _archetype_requirement_merged or archetype_id.is_empty():
            return _raw_requirement
        _merge_archetype_requirement()
        return _raw_requirement
    set(value):
        _raw_requirement = value
        _archetype_requirement_merged = false

# era 字段标记该事件所属的时代（如 "745_ambition"）。
# 空字符串（默认值）表示该事件对所有时代可用。
# 非空时，只有在 GameState.current_era 匹配时才会参与抽取。
@export var era: String = ""

# ── Archetype（事件类型）系统 ──────────────────────────
# archetype_id: 事件类型标识符（如 "baiye"），对应 tools/data/event_archetypes.json 中的 key。
# 空字符串表示该事件无类型标签。
# .tres 中只持久化此标签；universal_requirement/result/era 在运行时从 JSON 动态加载。
@export var archetype_id: String = ""

# on_enter_result（原名 event_result）已提升到 BaseEvent.on_enter_result
# 保留注释以提示迁移，不再在此处 @export

# 从 context DSL 解析出的自定义参数，init 时通过 merge_context 合并入 context
var custom_context_params: Dictionary = {}

# ── Archetype 运行时缓存 ──────────────────────────
# 缓存已翻译的 archetype requirement / result / era，避免每个事件重复调用 DSLParser
# 缓存 key 为事件的 archetype_id（叶子节点），value 包含整条继承链合并后的结果
static var _archetype_req_cache: Dictionary = {}
static var _archetype_result_cache: Dictionary = {}
static var _archetype_era_cache: Dictionary = {}

# ── Archetype 继承链工具 ──────────────────────────
# 从 archetype_id 出发沿 parent 链向上遍历，返回 [id, parent_id, grandparent_id, ...]
# 携带 visited set 防止循环引用。空 parent 或无 parent 字段视为链终止。
static func _get_archetype_chain(archetype_id: String) -> Array[String]:
    if archetype_id.is_empty():
        return [] as Array[String]
    var chain: Array[String] = [archetype_id]
    var visited: Dictionary = {}
    visited[archetype_id] = true
    var current_id: String = archetype_id
    while true:
        var data := DSLParser.load_event_archetype(current_id)
        if data.is_empty():
            break
        var parent_id: String = data.get("parent", "")
        if parent_id.is_empty():
            break
        if visited.has(parent_id):
            Logging.warn("RandomEvent: archetype 循环引用检测: '%s' -> '%s'，继承链截断" % [current_id, parent_id])
            break
        visited[parent_id] = true
        chain.append(parent_id)
        current_id = parent_id
    return chain

func _get_archetype_requirement() -> BaseRequirements:
    if archetype_id.is_empty():
        return null
    if _archetype_req_cache.has(archetype_id):
        return _archetype_req_cache[archetype_id]
    
    var chain := _get_archetype_chain(archetype_id)
    var merged: BaseRequirements = null
    
    for aid in chain:
        var data := DSLParser.load_event_archetype(aid)
        if data.is_empty():
            continue
        var req_str: String = data.get("universal_requirement", "")
        if req_str.is_empty():
            continue
        var req := DSLParser.parse_requirements(req_str)
        if not req:
            continue
        if not merged:
            merged = req
        else:
            var combined := ComplexRequirements.new()
            combined.operators = [merged, req]
            combined.current_operator = REQ_OPERATOR.LOGIC.AND
            merged = combined
    
    _archetype_req_cache[archetype_id] = merged
    if merged:
        Logging.debug("RandomEvent: archetype '%s' requirement (chain: %s) translated (%d top-level operators)" % [archetype_id, ",".join(chain), _operator_count(merged)])
    return merged

func _get_archetype_result() -> ChoiceResult:
    if archetype_id.is_empty():
        return null
    if _archetype_result_cache.has(archetype_id):
        return _archetype_result_cache[archetype_id]
    
    var chain := _get_archetype_chain(archetype_id)
    var merged_result: ChoiceResult = null
    
    for aid in chain:
        var data := DSLParser.load_event_archetype(aid)
        if data.is_empty():
            continue
        var result_str: String = data.get("universal_result", "")
        if result_str.is_empty():
            continue
        var result := DSLParser.parse_choice_result(result_str)
        if not result or result.operators.is_empty():
            continue
        if not merged_result:
            merged_result = ChoiceResult.new()
            merged_result.operators = [] as Array[BaseOperator]
        # 子（chain 前部）在前，父在后；与 on_enter 中 append_array 顺序一致
        merged_result.operators.append_array(result.operators)
    
    _archetype_result_cache[archetype_id] = merged_result
    if merged_result:
        Logging.debug("RandomEvent: archetype '%s' result (chain: %s) translated (%d operators)" % [archetype_id, ",".join(chain), merged_result.operators.size()])
    return merged_result

func _get_archetype_era() -> String:
    if archetype_id.is_empty():
        return ""
    if _archetype_era_cache.has(archetype_id):
        return _archetype_era_cache[archetype_id]
    
    var chain := _get_archetype_chain(archetype_id)
    for aid in chain:
        var data := DSLParser.load_event_archetype(aid)
        if data.is_empty():
            continue
        var era_val: String = data.get("era", "")
        if not era_val.is_empty():
            _archetype_era_cache[archetype_id] = era_val
            Logging.debug("RandomEvent: archetype '%s' era resolved from chain '%s' -> '%s'" % [archetype_id, aid, era_val])
            return era_val
    
    _archetype_era_cache[archetype_id] = ""
    return ""

func _merge_archetype_requirement() -> void:
    if _archetype_requirement_merged:
        return
    _archetype_requirement_merged = true
    
    var archetype_req := _get_archetype_requirement()
    if not archetype_req:
        return
    
    if not _raw_requirement:
        _raw_requirement = archetype_req
        Logging.info("RandomEvent: archetype '%s' requirement set as sole requirement for event '%s'" % [archetype_id, name])
    else:
        var merged := ComplexRequirements.new()
        merged.operators = [_raw_requirement, archetype_req]
        merged.current_operator = REQ_OPERATOR.LOGIC.AND
        _raw_requirement = merged
        Logging.info("RandomEvent: archetype '%s' requirement merged (AND) for event '%s'" % [archetype_id, name])

static func _operator_count(req: BaseRequirements) -> int:
    if req is ComplexRequirements:
        return (req as ComplexRequirements).operators.size()
    return 1 if req else 0

# ──────────────────────────────────────────────
# on_enter — 舞台置景
# ──────────────────────────────────────────────
# 重写 BaseEvent.on_enter()，在事件级结果执行之前先合并自定义参数。
#
# 执行顺序：
#   1. custom_context_params merge → context 注入 CSV/DSL 参数
#   2. archetype 运行时翻译 → 追加 universal_result operators
#   3. super.on_enter() → event_result.init() + event_result.operate()
#
# 这确保 event_result 中的 operator 可以读取到 custom_context_params 注入的字段。
# ──────────────────────────────────────────────
func on_enter(context: Dictionary) -> void:
    # 将 CSV context 中的自定义参数合并进 init context
    # 必须在 event_result 之前执行，因为 operator 可能依赖这些参数
    if not custom_context_params.is_empty():
        Util.merge_context(context, custom_context_params)
    
    # ── Archetype era 兜底：若 event 自身 era 为空则用 archetype era ──
    if not archetype_id.is_empty():
        if era.is_empty():
            var archetype_era := _get_archetype_era()
            if not archetype_era.is_empty():
                era = archetype_era
                Logging.info("RandomEvent.on_enter: archetype '%s' era fallback applied: %s" % [archetype_id, archetype_era])
    
    # 执行事件级结果（舞台置景）
    super.on_enter(context)


func init(context: Dictionary) -> Array:
    # on_enter 已在 super.init() → BaseEvent.init() 中调用，
    # 所有前置逻辑（custom_context_params merge）已在 on_enter 中完成。
    
    # ── 🆕 预初始化 archetype operators（duplicate 后 init）：在 description 渲染之前将 context 字段（如 imaginary_gain_hint）注入 context ──
    # 注意：必须用 duplicate() 避免污染静态缓存 _archetype_result_cache
    var _preinit_ops: Array[BaseOperator] = []
    if not archetype_id.is_empty():
        var archetype_result := _get_archetype_result()
        if archetype_result and not archetype_result.operators.is_empty():
            Logging.info("RandomEvent.init: archetype '%s' pre-init universal_result (%d operators) into context for event '%s'" % [archetype_id, archetype_result.operators.size(), name])
            for op in archetype_result.operators:
                var dup = op.duplicate()
                Logging.info("RandomEvent.init: pre-init operator %s (duplicated)" % dup.get_class())
                dup.init(context)
                _preinit_ops.append(dup)
    
    var all_options = super.init(context)
    
    # ── Archetype 运行时注入：universal_result → per-option choice_result ──
    if not archetype_id.is_empty() and not _preinit_ops.is_empty():
        Logging.info("RandomEvent.init: archetype '%s' universal_result (%d pre-inited operators) injected into each of %d option(s) for event '%s'" % [archetype_id, _preinit_ops.size(), all_options.size(), name])
        for opt in all_options:
            if opt == null:
                continue
            if not "choice_result" in opt:
                continue
            var cr: ChoiceResult = opt.choice_result
            if not cr:
                cr = ChoiceResult.new()
                opt.choice_result = cr
            
            # 追加 pre-inited operators（深拷贝确保 per-option 独立）
            for op in _preinit_ops:
                cr.operators.append(op.duplicate())
            
            cr.init(context)
    
    return all_options

# 会被使用time operator中的source tag匹配. 由于无法集合两个enum那就单独写再集合
var target_tags: Array[String] = []:
    get:
        var result_tags: Array[String] = []
        for tag in _action_tags:
            result_tags.append(ENUMS.to_action_str(tag))
        for tag in _area_tags:
            result_tags.append(ENUMS.to_area_str(tag))
        for tag in _target_tags:
            result_tags.append(tag)
        return result_tags
    set(tags):
        _target_tags = tags

@export var _target_tags: Array[String] = []
# 为了csv数据输入服务，数据输入不是ENUM格式，需要额外地方存

@export var _action_tags: Array[ENUMS.ACTION_TAGS] = []
@export var _area_tags: Array[ENUMS.AREA_TAGS] = []
