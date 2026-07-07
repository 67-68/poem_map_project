class_name ConditionalTimePenalty extends Resource
## 条件时间惩罚 — trait 对特定行动追加额外天数。
## 由 Trait.conditional_time_penalties 持有，get_action_day_cost() 遍历匹配。

## action_tag 匹配模式（contains 语义），add_to_all=true 时忽略此字段。
@export var action_tag_match: String = ""

## 匹配时追加的天数。
@export var penalty_days: int = 0

## 是否对所有行动生效（覆盖 action_tag_match）。
@export var add_to_all: bool = false

## UI 展示用描述，如 "重伤远游"。
@export var description: String = ""
