class_name KuangdaState extends RefCounted
## 旷达状态统一查询门面
## 消除 survival_manager / tier_determiner / social_action_resolver 中重复的 KUANGDA_* 判断。
## 三态顺位：狂客 > 钻营 > 逢迎（按优先级降序）

const STATE_MAP: Dictionary = {
	ENUMS.TRAITS.KUANGDA_KUANGKE: "kuangke",
	ENUMS.TRAITS.KUANGDA_FENGYING: "fengying",
	ENUMS.TRAITS.KUANGDA_ZUANYING: "zuanying",
}

## 返回当前旷达状态字符串："" / "kuangke" / "fengying" / "zuanying"
static func current() -> String:
	for trait_enum in STATE_MAP:
		if PlayerState.has_trait(trait_enum):
			return STATE_MAP[trait_enum]
	return ""

## 返回 true 表示玩家处于三种旷达状态的任一中
static func is_active() -> bool:
	return not current().is_empty()
