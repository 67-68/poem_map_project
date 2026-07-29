@tool
class_name ImaginaryGrantChance extends Resource
## 意象获取概率条目 — Action.imaginary_grants 的元素。
## 每个条目描述一种意象类型及其独立获取概率。
##
## 多个条目之间通过加权单次 Roll 消歧：
##   grants = [功名:10%, 狂放:10%] → roll 0-100
##   [0,10): 功名; [10,20): 狂放; [20,100): 不触发

## 意象大类中文名："功名" / "隐逸" / "狂放"
@export var imaginary_type: String = ""

## 获取概率 archetype（来自 tools/data/named_amounts.json）
@export_enum(
	"no_success_rate",
	"xxxs_success_rate",
	"xxs_success_rate",
	"xs_success_rate",
	"s_success_rate",
	"ms_success_rate",
	"m_success_rate",
	"l_success_rate"
) var obtain_possibility: String = "xxs_success_rate"


## 解析 obtain_possibility archetype 为 int（0-100）。
func get_possibility_int() -> int:
	var amounts = NamedDSLParser._load_named_amounts()
	if amounts.has(obtain_possibility):
		return amounts[obtain_possibility] as int
	Logging.err("ImaginaryGrantChance: unknown possibility archetype '%s', fallback to 20" % obtain_possibility)
	return 20


## 检查所有 grants 的概率总和是否超过 100%。
## 返回 true 表示合法（≤100%）；false 表示非法（>100%）。
static func validate_probability_sum(grants: Array) -> bool:
	if grants.is_empty():
		return true
	var total: int = 0
	for g in grants:
		if g is ImaginaryGrantChance:
			total += (g as ImaginaryGrantChance).get_possibility_int()
	if total > 100:
		Logging.err("ImaginaryGrantChance.validate_probability_sum: 概率总和 %d > 100%%, 配置非法" % total)
		return false
	Logging.info("ImaginaryGrantChance.validate_probability_sum: 概率总和=%d%% ≤ 100%%, 合法" % total)
	return true
