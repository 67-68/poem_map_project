class_name Poem extends Trait
## V11: 删除 intent — stance 改为基于 used_imaginary_types 三大类计数

## 诗词数据模型 — 继承 Trait，复用 topic="POEM" + specific_topic=POEM_TYPE 体系
## 由 PoemCraftingCalculator 在创作成功后动态创建

## 诗词配方所需的 Fragment 列表，FragmentMatcher 用于校验意象组合
@export var required_fragments: Array[String] = []
@export var level: int = 1 # 1,2,3
## 命中配方时设为 true（有典故出处）
@export var lore: bool = false
## V11: 创作此诗时消耗的意象分类计数，如 {"功名": 2, "隐逸": 1}
## 供 TagManager 计算诗风站队
@export var used_imaginary_types: Dictionary = {}

func _init(p_topic: String = "POEM", p_specific: String = ""):
	topic = p_topic
	specific_topic = p_specific