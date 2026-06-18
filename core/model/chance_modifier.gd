@tool
class_name ChanceModifier extends Resource

## 条件随机概率修正器
## 当玩家拥有指定 trait 时，对 base_chance 进行 delta 修正

@export var trait_key: String = ""       # 判定的 trait
@export var delta: int = 0               # 概率修正值（正数增加，负数减少）
@export var label: String = ""           # 可读标签，用于日志
