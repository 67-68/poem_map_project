class_name Trait extends GameEntity

# name use parent
@export var buffer_to_prop: DictMultiplyOperator
@export var buffer_to_region: DictMultiplyOperator
@export var display_char: String = ""  # 阳刻印章展示字，为空时取 name[0]
# 人物关系状态（RELATION）已废弃，迁移至 RelationFlagManager person_state str flag；
# _relate_to 字段保留但仅用于非 RELATION trait 的 NPC 关联
@export_enum(
	'POEM', 'MAIN_ROUTE', 'DISEASE', 'MENTAL_ILLNESS'
) var topic: String

# 诗词类型复用此字段；HEARD/GOOD/CORE/HATE 已随 RELATION topic 废弃
@export_enum(
	'GAN_YE', 'YING_ZHI', 'DENG_GAO', 'HUAI_GU', 'JI_LV', 'SHAN_SHUI',
	'ACUTE', 'CHRONIC', 'DEPRESSION', 'MANIA'
) var specific_topic: String

@export var _relate_to: ENUMS.RELATION_TARGET = -1
var relate_to: String:
	get: return ENUMS.to_relation_str(_relate_to)
@export var lasting_xun: int # 这个不是说可以last多少，而是当前last了多少

# 内生的效果：自己进化和持续的影响
@export var trait_effect_operations: Array[PropertyOperator] = []

## 此 trait 对每次行动附加的额外天数惩罚（全局，所有行动生效）。
## 推荐改用 conditional_time_penalties + add_to_all=true 替代此字段。
## 运行时由 PlayerState.get_active_time_penalties() 聚合所有活跃 trait 的惩罚。
@export var time_penalty: int = 0

# ─── 🆕 数据驱动字段（替代原硬编码到期/惩罚/叙事逻辑） ──────────

## 到期旬数。> 0 时 lasting_xun 达到此值自动移除/替换。0 = 永不过期。
## 替代原 TEMP_DEBUFFS / SEVERE_INJURY_DURATION_XUN / Disease.progression_xun 硬编码。
@export var duration_xun: int = 0

## 到期后替换为此 trait（UUID）。空字符串 = 到期直接删除，不替换。
## 替代原 TEMP_DEBUFFS 到期移除 / Disease.progression_target / severe_injury 到期移除。
@export var expiry_trait: String = ""

## 条件化时间惩罚列表。get_action_day_cost() 遍历匹配 action_tag。
## 替代原 severe_injury 远游+5AP 硬编码。
@export var conditional_time_penalties: Array[ConditionalTimePenalty] = []

## 永久 AP 上限削减。运行时由 get_current_ap_cap() 聚合。
## 替代原 disease_ouxinlixue 硬编码 AP-2。
@export var ap_penalty: int = 0

## 潜意识碎碎念文本（杜甫口吻）。_subconscious_murmur() 遍历所有 trait 取之。
## 替代原 if has_trait("poisoned")/("sprained_ankle") 硬编码。
@export var narrative_murmur: String = ""

@export var hover_narrative: String = ""

func operate_continuous_effect():
	for op in trait_effect_operations:
		op.operate()
