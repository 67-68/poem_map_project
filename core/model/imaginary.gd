class_name Imaginary extends GameEntity
## 意象实体 — 玩家通过事件获取的具体意象（V7: 扁平化，不再有 concepts 中间层）
## uuid: 简单标识名，如 "snow", "drunk"
## name: 展示名，如 "孤雪"

@export var level: int = 1 # 1,2,3

## 意象获得的累计天数（用于计算持续时间，统一 2 旬=20 天后到期）
## -1 表示未设置（降级兼容旧存档）
@export var created_at_day: int = -1