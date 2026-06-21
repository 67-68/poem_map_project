class_name Decision extends Action

var disabled := false

## 时间窗口：决策可用的起始年份（-1 表示不限制）
@export var available_from: float = -1.0
## 时间窗口：决策可用的截止年份（-1 表示不限制）
@export var available_until: float = -1.0