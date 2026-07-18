class_name PoemCraftingCalculator extends RefCounted

## 诗词评分引擎 V11 — 纯函数，无状态，幂等
##
## V11 变更:
##   - 才华 (talent) 属性通过 S 型阻尼公式 amplify 最终 score
##
## V10 变更:
##   - 删除 PoemCraftingResult.secular_value / literary_value 及 MODE_VALUE_MAP
##   - 诗词价值不再创作时固化，改由 PoemRewardOperator 消费时动态产出
##   - _calculate_upgrade_probability 改为公开静态方法 calculate_upgrade_probability
##   - 新增 calculate_level_upgrade_probability(level) 供 PoemRewardOperator 复用

const _ModifierFormula = preload("res://core/modifier_formula.gd")

## 才华→诗词评分增益 S 型阻尼参数
const TALENT_SCORE_MAX_LIMIT: float = 0.4
const TALENT_SCORE_HALF_POINT: float = 35.0

## 等级阈值
const LEVEL_1_THRESHOLD := 25   ## 平庸 < 25
const LEVEL_2_THRESHOLD := 50   ## 佳作 ≥ 25, < 50
## 绝唱 ≥ 50

## 每题等级基础分步长
const LEVEL_SCORE_STEP := 25

## 超出 max_manageable 时每个溢出的惩罚分
const OVERFLOW_PENALTY := -5

## Imaginary.level → 评分倍率
const LEVEL_SCORE_MAP := {
	1: 5,
	2: 10,
	3: 15,
}

var POEM_LEVEL_NAMES := {
	1: tr("CODE_POEM_CRAFTING_CALCULATOR_CE57606FBB"),
	2: tr("CODE_POEM_CRAFTING_CALCULATOR_2EA731CCE3"),
	3: tr("CODE_POEM_CRAFTING_CALCULATOR_C335175F07"),
}

## level → 段位中位分数（用于消费时升级概率计算）
const LEVEL_MEDIAN_SCORE := {
	1: 12,
	2: 37,
	3: -1,  # 绝唱无升级空间
}


## ──────────────────────────────────────────────
## 诗词创作结果 V10
## ──────────────────────────────────────────────

class PoemCraftingResult:
	var passed: bool = false          ## false = 错误（如意象不足）
	var fail_reason: String = ""      ## "insufficient" | ""
	var score: int = 0                ## 原始分数（可负）
	var base_level: int = 1           ## 基础等级 (1-3)
	var upgrade_probability: float = 0.0  ## 升级概率 [0.0, 1.0)，纯计算结果
	var matched_recipe: Poem = null   ## V12: 精确 Set 匹配到的诗词配方（null = 无匹配）


## ──────────────────────────────────────────────
## 主入口：纯函数诗词评分引擎 V10
##
## @param imaginaries:  所有参与计算的 Imaginary 数组
## @param mode:         "gan_ye" | "deng_gao"（仅用于提示，不再产出 value）
## @param max_manageable: 意象管理上限，由调用方从 PlayerState.max_imaginary_managable 读取后传入
## @return PoemCraftingResult
## ──────────────────────────────────────────────

func calculate_poem_grade(
	imaginaries: Array,
	mode: String,
	max_manageable: int = 3
) -> PoemCraftingResult:
	var result := PoemCraftingResult.new()
	
	# ── 1. 前置校验：意象数量不足 ──
	if imaginaries.size() < max_manageable:
		result.passed = false
		result.fail_reason = "insufficient"
		Logging.warn("PoemCraftingCalculator(V10): 意象不足 — 当前 %d, 需要至少 %d" % [imaginaries.size(), max_manageable])
		return result
	
	# ── 2. 评分计算 ──
	var score := 0
	var within_limit_count := 0
	var overflow_count := 0
	
	for i in range(imaginaries.size()):
		var imag = imaginaries[i]
		if not imag is Imaginary:
			Logging.warn("PoemCraftingCalculator(V10): 跳过非 Imaginary 元素 at index %d" % i)
			continue
		
		if i < max_manageable:
			var level_bonus := _get_level_score(imag.level)
			score += level_bonus
			within_limit_count += 1
			Logging.debug("PoemCraftingCalculator(V10): index=%d uuid=%s level=%d → +%d" % [i, imag.uuid, imag.level, level_bonus])
		else:
			score += OVERFLOW_PENALTY
			overflow_count += 1
			Logging.debug("PoemCraftingCalculator(V10): index=%d uuid=%s level=%d → %d (溢出惩罚)" % [i, imag.uuid, imag.level, OVERFLOW_PENALTY])
	
	result.score = score
	Logging.info("PoemCraftingCalculator(V11): 评分完成 — raw_score=%d, within=%d, overflow=%d, total=%d" % [score, within_limit_count, overflow_count, imaginaries.size()])

	# 🆕 V11: 才华 S 型阻尼增益诗词评分
	var talent_val: int = PlayerState.get_stat_val("talent")
	if talent_val > 0:
		var amplified_score: int = _ModifierFormula.amplify(score, talent_val, TALENT_SCORE_MAX_LIMIT, TALENT_SCORE_HALF_POINT)
		Logging.info("PoemCraftingCalculator(V11): talent=%d → raw_score=%d → amplified=%d" % [talent_val, score, amplified_score])
		score = amplified_score
		result.score = score
	
	# ── 3. 确定基础等级 ──
	result.base_level = _score_to_base_level(score)
	Logging.info("PoemCraftingCalculator(V11): base_level=%d (%s)" % [result.base_level, POEM_LEVEL_NAMES.get(result.base_level, "未知")])
	
	# ── 4. 计算升级概率 ──
	result.upgrade_probability = calculate_upgrade_probability(score, result.base_level)
	Logging.info("PoemCraftingCalculator(V11): upgrade_probability=%.3f" % result.upgrade_probability)
	
	# ── 5. V12: 配方匹配 — 前 max_manageable 个意象 uuid 精确 Set 匹配 recipe_index ──
	result.matched_recipe = _match_recipe(imaginaries, max_manageable)
	if result.matched_recipe:
		Logging.info("PoemCraftingCalculator(V12): 配方匹配成功 — recipe=%s (%s)" % [result.matched_recipe.name, result.matched_recipe.uuid])
	else:
		Logging.info("PoemCraftingCalculator(V12): 配方匹配失败，将使用通用诗名")
	
	result.passed = true
	return result


## ──────────────────────────────────────────────
## 纯函数：score → base_level
## ──────────────────────────────────────────────

static func _score_to_base_level(score: int) -> int:
	if score >= LEVEL_2_THRESHOLD:
		return 3   # 绝唱
	elif score >= LEVEL_1_THRESHOLD:
		return 2   # 佳作
	else:
		return 1   # 平庸


## ──────────────────────────────────────────────
## 公开纯函数：计算升级概率 [0.0, 1.0)
##
## 仅在 base_level < 3 时计算：
##   upgrade_probability = (score - current_threshold) / (next_threshold - current_threshold)
##
## @param score:      诗词评分
## @param base_level: 基础等级 (1-3)
## @return 升级概率 [0.0, 1.0)
##
## 边界：
##   - score >= LEVEL_2_THRESHOLD (已是绝唱) → 0.0
##   - score < 0 → 钳制 base_level=1, upgrade_probability=0.0
##   - 公式结果钳制在 [0.0, 1.0)
##
## 同时供 PoemCraftingCalculator（创作时）和 PoemRewardOperator（消费时）复用。
## ──────────────────────────────────────────────

static func calculate_upgrade_probability(score: int, base_level: int) -> float:
	if base_level >= 3:
		# 已是绝唱，无升级空间
		return 0.0
	
	if score <= 0:
		# 分数 ≤ 0 时钳制
		return 0.0
	
	var current_threshold: int = (base_level - 1) * LEVEL_SCORE_STEP  # 0 或 25
	var next_threshold: int = base_level * LEVEL_SCORE_STEP            # 25 或 50
	var threshold_range: int = next_threshold - current_threshold      # 25
	
	if threshold_range <= 0:
		Logging.err("PoemCraftingCalculator(V10): calculate_upgrade_probability 除零 — base_level=%d, current=%d, next=%d" % [base_level, current_threshold, next_threshold])
		return 0.0
	
	var progress: float = float(score - current_threshold) / float(threshold_range)
	progress = clampf(progress, 0.0, 0.999)  # [0.0, 1.0)，永远不为 1.0
	
	Logging.debug("PoemCraftingCalculator(V10): progress=(%d-%d)/%d=%.3f" % [score, current_threshold, threshold_range, progress])
	return progress


## ──────────────────────────────────────────────
## 纯函数：Poem.level → 升级概率 [0.0, 1.0)
##
## 使用该等级的段位中位分数插值计算升级概率。
## 供 PoemRewardOperator 在消费诗词时调用。
##
## @param level: Poem 等级 (1-3)
## @return 升级概率 [0.0, 1.0)
## ──────────────────────────────────────────────

static func calculate_level_upgrade_probability(level: int) -> float:
	var median_score: int = LEVEL_MEDIAN_SCORE.get(level, -1)
	if median_score < 0:
		Logging.debug("PoemCraftingCalculator(V10): calculate_level_upgrade_probability — level=%d 无升级空间" % level)
		return 0.0
	Logging.debug("PoemCraftingCalculator(V10): calculate_level_upgrade_probability — level=%d, median_score=%d" % [level, median_score])
	return calculate_upgrade_probability(median_score, level)


## ──────────────────────────────────────────────
## V12: 配方匹配 — 前 max_manageable 个 Imaginary uuid 精确 Set 匹配 Database.recipe_index
##
## 提取前 max_manageable 个意象的 uuid，通过 FragmentMatcher.build_key 查 recipe_index。
## 返回匹配到的 Poem 配方，无匹配返回 null。
## ──────────────────────────────────────────────

static func _match_recipe(imaginaries: Array, max_manageable: int) -> Poem:
	var uuids: Array[String] = []
	for i in range(mini(imaginaries.size(), max_manageable)):
		var imag = imaginaries[i]
		if imag is Imaginary:
			uuids.append(imag.uuid)
	Logging.info("PoemCraftingCalculator(V12): _match_recipe — 前%d个意象 uuids=%s" % [uuids.size(), str(uuids)])
	
	if uuids.size() < max_manageable:
		Logging.info("PoemCraftingCalculator(V12): _match_recipe — 意象数量不足 max_manageable，跳过匹配")
		return null
	
	var key := FragmentMatcher.build_key(uuids)
	Logging.info("PoemCraftingCalculator(V12): _match_recipe — build_key=%s" % key)
	
	var recipe_index: Dictionary = Database.recipe_index
	if recipe_index.is_empty():
		Logging.warn("PoemCraftingCalculator(V12): _match_recipe — Database.recipe_index 为空")
		return null
	
	var recipe = recipe_index.get(key)
	if recipe and recipe is Poem:
		Logging.info("PoemCraftingCalculator(V12): _match_recipe — 命中配方: %s" % recipe.name)
		return recipe
	
	Logging.info("PoemCraftingCalculator(V12): _match_recipe — key '%s' 未命中任何配方" % key)
	return null


## ──────────────────────────────────────────────
## 纯函数：Imaginary.level → 评分值
## ──────────────────────────────────────────────

static func _get_level_score(level: int) -> int:
	return LEVEL_SCORE_MAP.get(level, 5)


## ──────────────────────────────────────────────
## 工具：base_level → 显示名称
## ──────────────────────────────────────────────

func get_level_display_name(level: int) -> String:
	return POEM_LEVEL_NAMES.get(level, tr("CODE_POEM_CRAFTING_CALCULATOR_4D8C1C5B42"))


## ──────────────────────────────────────────────
## 工具：base_level → EventBase uuid
## ──────────────────────────────────────────────

static func get_event_base_for_level(level: int) -> String:
	return "poem_level_%d" % level


## ──────────────────────────────────────────────
## 纯函数：score → 创作代价 operators (V9.2)
##
## @param score: 诗词评分
## @return Array — TimeOperator(天数) + PropertyOperator(健康消耗, 仅 health_cost > 0 时)
##
## 公式：
##   days       = max(1, floor(score / 5))
##   health_cost = floor(score * 2 / 3)，仅 health_cost > 0 时创建 PropertyOperator
##
## 纯函数契约：仅创建 operator 对象，不执行 operate()。
## 调用方负责通过 ActionHintBuilder 展示预览，并在确认创作后执行 operator.operate()。
## ──────────────────────────────────────────────

const COST_DAYS_DIVISOR := 5        ## score / 5 = 天数
const COST_DAYS_MINIMUM := 1        ## 最低保底 1 天
const COST_HEALTH_NUMERATOR := 2    ## 健康消耗分子
const COST_HEALTH_DENOMINATOR := 3  ## 健康消耗分母

static func calculate_crafting_cost(score: int) -> Array:
	var operators: Array = []
	
	# ── 1. 时间代价：floor(score / 5) 天，最低保底 1 天 ──
	var days: int = maxi(COST_DAYS_MINIMUM, floori(float(score) / float(COST_DAYS_DIVISOR)))
	Logging.info("PoemCraftingCalculator(V9.2): calculate_crafting_cost — score=%d → days=%d" % [score, days])
	
	var time_op := TimeOperator.new()
	time_op.day = float(days)
	time_op.refresh_time = false
	operators.append(time_op)
	
	# ── 2. 健康代价：floor(score * 2/3)，仅 >0 时创建 ──
	var health_cost: int = floori(float(score) * float(COST_HEALTH_NUMERATOR) / float(COST_HEALTH_DENOMINATOR))
	Logging.info("PoemCraftingCalculator(V9.2): calculate_crafting_cost — score=%d → health_cost=%d" % [score, health_cost])
	
	if health_cost > 0:
		var health_op := PropertyOperator.new()
		health_op.property = "health"
		health_op.value = -health_cost
		operators.append(health_op)
		Logging.info("PoemCraftingCalculator(V9.2): calculate_crafting_cost — 健康消耗 %d, 已创建 PropertyOperator" % health_cost)
	else:
		Logging.info("PoemCraftingCalculator(V9.2): calculate_crafting_cost — health_cost <= 0, 跳过健康消耗")
	
	Logging.info("PoemCraftingCalculator(V9.2): calculate_crafting_cost — 返回 %d 个 operators" % operators.size())
	return operators
