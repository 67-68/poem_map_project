class_name Poem extends Trait
## V10: 删除 secular_value / literary_value — 诗词价值不再创作时固化
## 改由 PoemRewardOperator 在消费时根据 mode 动态产出

## 诗词数据模型 — 继承 Trait，复用 topic="POEM" + specific_topic=POEM_TYPE 体系
## 由 PoemCraftingCalculator 在创作成功后动态创建

## 诗词配方所需的 Fragment 列表，FragmentMatcher 用于校验意象组合
@export var required_fragments: Array[String] = []

@export var level: int = 1 # 1,2,3


func _init(p_topic: String = "POEM", p_specific: String = ""):
	topic = p_topic
	specific_topic = p_specific
