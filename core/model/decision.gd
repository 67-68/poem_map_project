class_name Decision extends Action

var disabled := false

## 时间窗口：决策可用的起始年份（-1 表示不限制）
@export var available_from: float = -1.0
## 时间窗口：决策可用的截止年份（-1 表示不限制）
@export var available_until: float = -1.0

## 允许点击次数：-1 表示无限制，>=0 表示最多可点次数（仅当前会话生效，不持久化）
@export var allowed_count: int = -1
## 运行时已点击次数（不持久化）
var _times_clicked: int = 0

## 记录一次点击。若已达上限则返回 false（不应再继续执行逻辑）
func record_click() -> bool:
	if allowed_count < 0:
		return true
	_times_clicked += 1
	return _times_clicked <= allowed_count