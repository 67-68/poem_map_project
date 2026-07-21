class_name PoemEffectCalculator extends RefCounted

## V11: 诗词发布效果计算器 — 空壳类
##
## 当 PoemCrafter 的「发布」CheckButton 被勾选时调用，
## 根据诗词属性动态计算发布效果。
## 目前所有效果返回空，待后续实现具体逻辑。

## 计算结果结构
class PoemEffectResult:
	var effect_desc: String = ""   ## 效果描述文本（展示给玩家）
	var rewards: Array = []        ## 奖励 PropertyOperator 数组（待实现）


## 纯函数：计算诗词发布效果
## @param poem: 发布的 Poem 对象
## @return PoemEffectResult
static func calculate(poem: Poem) -> PoemEffectResult:
	var result := PoemEffectResult.new()
	if not poem:
		Logging.warn("PoemEffectCalculator.calculate: poem 为 null")
		result.effect_desc = "（诗词效果待实现）"
		return result

	Logging.info("PoemEffectCalculator.calculate: poem=%s, level=%d, lore=%s" % [poem.name, poem.level, poem.lore])

	# Placeholder: 所有效果返回空
	result.effect_desc = "（诗词效果待实现）"
	result.rewards = []

	return result
