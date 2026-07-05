class_name Poem extends Trait
## V7: ImaginaryConcept 已删除；required_fragments 存储 imaginary uuid 列表

## 诗词数据模型 — 继承 Trait，复用 topic="POEM" + specific_topic=POEM_TYPE 体系
## 由 PoemCraftingCalculator 在创作成功后动态创建

## 世俗变现值（金钱/功名），来自收益公式
@export var secular_value: float = 0.0

## 千古不朽值（文学声望），来自收益公式
@export var literary_value: float = 0.0

## 诗词配方所需的 Fragment 列表，FragmentMatcher 用于校验意象组合
@export var required_fragments: Array[String] = []

@export var level: int = 1 # 1,2,3


func _init(p_topic: String = "POEM", p_specific: String = "", p_secular: float = 0.0, p_literary: float = 0.0):
	topic = p_topic
	specific_topic = p_specific
	secular_value = p_secular
	literary_value = p_literary
