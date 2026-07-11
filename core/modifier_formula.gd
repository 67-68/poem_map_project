class_name ModifierFormula extends RefCounted
## 统一 S 型阻尼公式 — 纯函数，无状态，幂等
##
## 公式 B：渐近式 S 型阻尼模型
##   amplify:  Result = Raw × (1 + Max_limit × Modifier / (Half_point + Modifier))
##   dampen:   Result = Raw / (1 + Max_limit × Modifier / (Half_point + Modifier))
##
## 所有参数均为 int（Modifier = 属性值如 astuteness/talent/composure）
## 返回值始终为 int（向下取整）


## amplify: 正向增益。mod_val 越大倍率越高。
## @param raw:        原始变化量
## @param mod_val:    修饰符属性当前值（如 astuteness）
## @param max_limit:  渐进上限（控制最大倍率天花板）
## @param half_point: 半效点（mod_val == half_point 时倍率为 1+max_limit/2）
## @return int — 修正后的变化量
static func amplify(raw: int, mod_val: int, max_limit: float, half_point: float) -> int:
	if raw == 0 or mod_val <= 0:
		Logging.debug("[ModifierFormula] amplify: raw=%d mod_val=%d → no-op (raw=0 or mod_val≤0)" % [raw, mod_val])
		return raw

	var denominator: float = half_point + float(mod_val)
	if denominator <= 0.0:
		Logging.warn("[ModifierFormula] amplify: denominator=%.1f (half_point=%.1f + mod_val=%d), returning raw=%d" % [denominator, half_point, mod_val, raw])
		return raw

	var multiplier: float = 1.0 + (max_limit * float(mod_val) / denominator)
	var result: int = int(float(raw) * multiplier)

	Logging.info("[ModifierFormula] amplify: raw=%d mod_val=%d max_limit=%.2f half_point=%.1f → multiplier=%.3f → result=%d" % [raw, mod_val, max_limit, half_point, multiplier, result])
	return result


## dampen: 负向阻尼。mod_val 越大削减越多。
## @param raw:        原始变化量（通常为负值如消耗、衰减，或正值如收入）
## @param mod_val:    修饰符属性当前值
## @param max_limit:  渐进上限
## @param half_point: 半效点
## @return int — 修正后的变化量
static func dampen(raw: int, mod_val: int, max_limit: float, half_point: float) -> int:
	if raw == 0 or mod_val <= 0:
		Logging.debug("[ModifierFormula] dampen: raw=%d mod_val=%d → no-op (raw=0 or mod_val≤0)" % [raw, mod_val])
		return raw

	var denominator: float = half_point + float(mod_val)
	if denominator <= 0.0:
		Logging.warn("[ModifierFormula] dampen: denominator=%.1f, returning raw=%d" % [denominator, raw])
		return raw

	var divisor: float = 1.0 + (max_limit * float(mod_val) / denominator)
	if divisor <= 0.0:
		Logging.warn("[ModifierFormula] dampen: divisor=%.3f ≤ 0, returning raw=%d" % [divisor, raw])
		return raw

	# dampen 用于消耗/衰减时：abs(raw) 变小（减免），用于收入时：abs(raw) 变小（打折）
	var result: int = int(float(raw) / divisor)

	Logging.info("[ModifierFormula] dampen: raw=%d mod_val=%d max_limit=%.2f half_point=%.1f → divisor=%.3f → result=%d" % [raw, mod_val, max_limit, half_point, divisor, result])
	return result
