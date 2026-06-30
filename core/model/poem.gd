class_name Poem extends Trait

## 诗词数据模型 — 继承 Trait，复用 topic="POEM" + specific_topic=POEM_TYPE 体系
## 由 PoemCraftingCalculator 在创作成功后动态创建

## 世俗变现值（金钱/功名），来自 10.4 收益公式
@export var secular_value: float = 0.0

## 千古不朽值（文学声望），来自 10.4 收益公式
@export var literary_value: float = 0.0

## 诗词等级（0-2），对应创作时意象的最低 level
@export var poem_level: int = 0

## 诗词配方所需的 Fragment 四段式列表，FragmentMatcher 用于校验意象组合
@export var required_fragments: Array[String] = []

## 诗词背景类型（旧 PoemData.Poem_BG，迁移至此）
enum PoemBG {
	BOOK,
	NIGHT
}

## 诗词稀缺度等级（旧 PoemData.Poem_Grade，迁移至此）
enum PoemGrade {
	SHIYI,      ## 拾遗
	YASONG,     ## 雅颂
	GUIYI,      ## 瑰意
	JUECHANG    ## 绝唱
}

## Grade → 中文显示名
static func get_poem_grade_str(grade: PoemGrade) -> String:
	match grade:
		PoemGrade.JUECHANG: return "绝唱"
		PoemGrade.GUIYI: return "瑰意"
		PoemGrade.YASONG: return "雅颂"
		_: return "拾遗"


func _init(p_topic: String = "POEM", p_specific: String = "", p_level: int = 0, p_secular: float = 0.0, p_literary: float = 0.0):
	topic = p_topic
	specific_topic = p_specific
	poem_level = p_level
	secular_value = p_secular
	literary_value = p_literary
