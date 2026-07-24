class_name PoemEffectCalculator extends RefCounted

## V14: 诗词发布效果格式化器
##
## 当 PoemCrafter 的「发布」CheckButton 被勾选时调用，
## 从 PoemType.publication_effects（Array[BaseOperator]）提取效果描述文本。
## 保留 PoemEffectResult 结构为未来动态计算留扩展点。

## 计算结果结构
class PoemEffectResult:
	var effect_desc: String = ""   ## 效果描述文本（展示给玩家，注入 ctx.publish_effect）
	var rewards: Array = []        ## 奖励数组（预留，当前从 PoemType.publication_effects 直接执行）


## 纯函数：从 PoemType 格式化发布效果描述
## @param poem_type: 匹配到的 PoemType（null 则返回空效果）
## @return PoemEffectResult
static func calculate(poem_type: PoemType) -> PoemEffectResult:
	var result := PoemEffectResult.new()
	if not poem_type:
		Logging.info("PoemEffectCalculator.calculate: poem_type 为 null，返回空效果")
		result.effect_desc = ""
		return result

	Logging.info("PoemEffectCalculator.calculate(V14): poem_type=%s (%s), effects_count=%d" % [poem_type.name, poem_type.uuid, poem_type.publication_effects.size()])

	result.effect_desc = poem_type.get_effects_text()
	if result.effect_desc.is_empty():
		Logging.info("PoemEffectCalculator.calculate(V14): poem_type=%s 无 publication_effects，effect_desc 为空" % poem_type.name)
	else:
		Logging.info("PoemEffectCalculator.calculate(V14): effect_desc=%s" % result.effect_desc)

	result.rewards = []
	return result
