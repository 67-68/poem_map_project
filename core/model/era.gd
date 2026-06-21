class_name Era extends GameEntity

## 该时代接受的 ACTION_TYPE 白名单。
## 三层语义：
##   null（未设置）→ 全部允许
##   []（显式空数组）→ 全部禁止
##   [...] → 仅允许列表中指定的 action
@export var accepted_actions: Array[ENUMS.ACTION_TYPE]