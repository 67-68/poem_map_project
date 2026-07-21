class_name Imaginary extends Trait
## 意象实体 — 玩家通过事件获取的具体意象（V11: 三大类意象 + FIFO 顶替 + 5旬到期）
## uuid: 简单标识名，如 "snow", "drunk"
## name: 展示名，如 "孤雪"
## duration_xun: 统一 5 旬（继承自 Trait），到期后直接删除

@export var level: int = 1 # 1,2,3

## 意象大类: "功名" | "隐逸" | "狂放"
@export var imaginary_type: String = ""

## 创建时的 total_days_elapsed，用于 FIFO 顶替（最老的先被替换）
@export var created_at_day: int = 0

## 获取时的外部描写提示，自包含，不依赖上下文。
## eg. "一件粗麻布衣，缝补痕迹历历可见"
@export var get_hint: String = ""