class_name Imaginary extends GameEntity

## 详细意象碎片 — 玩家在事件中获取的具体意象实体
## uuid: 碎片的唯一标识，如 "changanleaf"
## name: 展示名，如 "长安落叶"

## 该碎片所属的四段式 Tag 列表
## 例: ["ENV:NATURE:AUTUMN:changanleaf", "VIBE:THEME:MACABRE:changanleaf"]
@export var detail_imaginaries: Array[String] = []

## 每个四段式 Tag 对应的感知描述文本
## key: 四段式 Tag (如 "ENV:NATURE:AUTUMN:changanleaf")
## value: 感知描述 (如 "秋风萧瑟，落叶满长安")
@export var perceptions: Dictionary = {}
