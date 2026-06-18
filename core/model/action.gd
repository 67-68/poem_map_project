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
