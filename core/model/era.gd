class_name Era extends GameEntity

## 该时代接受的 ACTION_TYPE 白名单。
## 两层语义：
##   null / [] → 全部允许（不启用白名单限制）
##   [...]     → 仅允许列表中指定的 action
@export var accepted_actions: Array[ENUMS.ACTION_TYPE]

## 该时代拒绝的 ACTION_TYPE 黑名单。
## 两层语义：
##   null / [] → 不拦截（黑名单未启用）
##   [...]     → 拦截列表中指定的所有 action_type
## 优先级：黑名单高于白名单。同时命中时以黑名单为准。
@export var rejected_actions: Array[ENUMS.ACTION_TYPE]