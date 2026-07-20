class_name Action extends GameEntity
# 这里就是场景化行动库的datamodel

# icon: use parent
# name: use parent
# description: use parent

## 子行动所需地点（仅 Picker 内校验，主行动按钮不校验）。
## 空字符串 = 无地点要求（任何地点/出游登高均可用）。
## 合法值："xishi" / "pingkangfang" / "huangcheng"。
@export var required_place: String = ""

## required_place 的中文展示名（给 hint / toast / picker 展示用）
func get_required_place_name() -> String:
	match required_place:
		"xishi":
			return tr("CODE_SOCIAL_CONNECTION_PAGE_BE2A911592")
		"pingkangfang":
			return tr("CODE_SOCIAL_CONNECTION_PAGE_06CF4D3D54")
		"huangcheng":
			return tr("CODE_SOCIAL_CONNECTION_PAGE_CD2724EB5A")
		_:
			return ""

@export var _action_tags: Array[ENUMS.ACTION_TAGS] = [] # 这些action tag 用来筛选当前场景下可用的event
var action_tags: Array[String]:
	get:
		var result: Array[String] = []
		for tag in _action_tags:
			result.append(ENUMS.to_action_str(tag))
		return result

@export var _locational_tags: Array[ENUMS.AREA_TAGS] = []
@export var _province_tags: Array[ENUMS.PROVINCES] = []
var area_tags:
	get:
		var result: Array[String] = []
		for tag in _locational_tags:
			result.append(ENUMS.to_area_str(tag))
		for tag in _province_tags:
			result.append(ENUMS.to_province_str(tag))
		return result

@export var action_results: Array[BaseOperator]
@export var aciton_requirements: Array[BaseRequirements]

## 🆕 当前活跃的 generator（由 DeferredLockActionOperator 生成并挂载）
## null = 无活跃 generator；非 null = 每次点击 action 时消费一个 operator
var generator: Generator = null

## 🆕 兜底事件 UUID：当过滤器链全部过滤后池空时触发此事件
## 例如 "event_baiye_cooldown_wall"（拜谒被拒叙事）
@export var fallback_event_uuid: String = ""

## 🆕 运行时标志：true = 完全不显示在行动面板中（硬拦截：era/阻塞）
## 优先级高于 dynamic_failed_hint。每轮调用 clear_failed_hint() 时自动重置。
var _is_hidden: bool = false

## 🆕 运行时动态失败提示文本（每轮重建），用于 UI 灰化按钮的 tooltip 显示。
## A类（需求不满足）和 B类（未中签）的原因会换行拼接在此字段中。
var dynamic_failed_hint: String = ""

## 🆕 运行时成功提示文本（每轮重建）。条件满足时设置，不触发灰化锁定。
## 仅用于 UI 展示精确数值信息，如「时间充足（剩余5天，需要3天）」。
var success_hint: String = ""

## 🆕 静态配置的叙事文本：当 action 在随机抽取中未被选中（B类锁定）时，
## 此文本会被追加到 dynamic_failed_hint 中作为锁定理由。
## 在 .tres 文件中手动填写，如「今日门庭冷落，车马稀疏…」。
@export var lock_narrative: String = ""

## 🆕 行动 Archetype UUID — 指向 tools/data/event_archetypes.json 中的 key。
## 运行时自动合并 archetype.universal_result 的 operators 到 action_results 一起执行。
## 空字符串 = 不合并。
@export var archetype_uuid: String = ""

## 行动消耗天数（替代原 TimeOperator 在 action_results 中的嵌入）。
## 0 = 不消耗时间。子行动若未设置（=0），自动继承父行动的 day_consumed。
@export var day_consumed: float = 0.0

## 🆕 子行动 UUID 列表：每个元素是一个 Action 的 uuid 字符串。
## 运行时通过 Database.get_action(uuid) 解析为 Action 资源。
## 点击带 sub_actions 的 Action 时，先弹出 Picker 让玩家选择子行动，
## 选中后将选中的 uuid 作为 tag 参与 AND 模式事件扫描。
@export var sub_actions: Array[String] = []
## 🆕 中签概率 archetype（来自 tools/data/named_amounts.json）。
## 可选值: s_success_rate=50, m_success_rate=80, l_success_rate=100。
## 使用 get_possibility_int() 获取解析后的 int 值。
@export_enum(
	's_success_rate',
	'ms_success_rate',
	'm_success_rate',
	'l_success_rate'
) var possibility: String = "l_success_rate"

var dynamic_pos_set = false
var dynamic_possibility = 0:
	set(val):
		dynamic_pos_set = true
		dynamic_possibility = val

@export var failed_result: ChoiceResult = ChoiceResult.new()

@export var defer_config: DeferConfig = DeferConfig.new()

@export var override_action: String = ''

## 🆕 解析 possibility archetype 为 int（0-100）。
## 查表 tools/data/named_amounts.json，未知 key 时 fallback 到 100。
func get_possibility_int() -> int:
	var amounts = NamedDSLParser._load_named_amounts()
	if amounts.has(possibility):
		return amounts[possibility] as int
	Logging.err("Action: unknown possibility archetype '%s', fallback to 100" % possibility)
	return 100

## 🆕 追加一段失败提示文本到 dynamic_failed_hint。
## 多条原因用换行分隔。
func append_failed_hint(text: String) -> void:
	if text.is_empty():
		return
	if dynamic_failed_hint.is_empty():
		dynamic_failed_hint = text
	else:
		dynamic_failed_hint += "\n" + text

## 🆕 清空 dynamic_failed_hint、success_hint 并重置 _is_hidden。
## 每轮开始前或重新评估锁定状态前调用。
func clear_failed_hint() -> void:
	dynamic_failed_hint = ""
	success_hint = ""
	_is_hidden = false

## 🆕 获取行动级 cost archetype 的 operators（在投骰前立即执行）。
## 使用 state="cost" 精确查找。
func get_cost_operators() -> Array:
	var arch = Database.get_archetype_by_uuid(uuid, "cost")
	if arch == null or arch.operators.is_empty():
		Logging.info("Action.get_cost_operators: '%s' 无 cost archetype" % uuid)
		return []
	Logging.info("Action.get_cost_operators: '%s' → cost archetype 返回 %d 个 operator" % [uuid, arch.operators.size()])
	return arch.operators.duplicate(true)

## 🆕 获取对应 outcome 的 archetype operators（延迟到事件层注入）。
## outcome: "success" / "failure"。
func get_outcome_archetype_operators(outcome: String) -> Array:
	var arch = Database.get_archetype_by_uuid(uuid, outcome)
	if arch == null or arch.operators.is_empty():
		Logging.info("Action.get_outcome_archetype_operators: '%s' 无 outcome='%s' archetype" % [uuid, outcome])
		return []
	Logging.info("Action.get_outcome_archetype_operators: '%s' → %s archetype 返回 %d 个 operator" % [uuid, outcome, arch.operators.size()])
	return arch.operators.duplicate(true)

## 🆕（兼容旧路径）获取 success archetype 的 operators。
## 如果 action 无 archetype 体系，fallback 到 action_results。
func get_all_action_results() -> Array:
	if archetype_uuid.is_empty():
		Logging.warn("Action.get_all_action_results: '%s' 的 archetype_uuid 为空" % uuid)
		return action_results if action_results else []
	
	# 🆕 先尝试按 uuid + "success" 查找
	var arch = Database.get_archetype_by_uuid(uuid, "success")
	if arch != null and not arch.operators.is_empty():
		Logging.info("Action.get_all_action_results: '%s' → success archetype 返回 %d 个 operator" % [uuid, arch.operators.size()])
		return arch.operators.duplicate(true)
	
	Logging.warn("Action.get_all_action_results: success archetype '%s' 未找到或 operators 为空" % archetype_uuid)
	return action_results if action_results else []

@export_enum(
	"social",
	"poem",
	"baiye",
) var topic: String = ""