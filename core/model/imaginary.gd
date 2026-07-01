class_name Imaginary extends GameEntity
## 意象实体 — 玩家通过事件获取的具体意象
## uuid: 简单标识名，如 "snow", "drunk"
## name: 展示名，如 "孤雪"
## concepts: 关联的抽象概念 uuid 列表，如 ["environment:snow", "emotion:tranquility"]

@export var concepts: Array[String] = []
