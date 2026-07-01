class_name Action extends GameEntity
# 这里就是场景化行动库的datamodel

# icon: use parent
# name: use parent
# description: use parent

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
@export var sub_actions: Dictionary = {} # 子行动的 UUID 列表，key=uuid, value=name
# eg. sub actions = {"actor:libai": "找李白痛饮"}

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
