class_name Imaginary extends Trait
## 意象实体 — 玩家通过事件获取的具体意象（V9: 继承 Trait，统一到期/效果系统）
## uuid: 简单标识名，如 "snow", "drunk"
## name: 展示名，如 "孤雪"
## duration_xun: 统一 2 旬（继承自 Trait），到期后直接删除

@export var level: int = 1 # 1,2,3

## 获取时的外部描写提示，自包含，不依赖上下文。
## eg. "一件粗麻布衣，缝补痕迹历历可见"
@export var get_hint: String = ""