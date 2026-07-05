class_name PoemCraftingCalculator extends RefCounted

## 诗词评分引擎 V9 — 纯函数，无状态，幂等
##
## V9 变更:
##   - 砍掉 C(N,3) 食谱枚举，替换为基于 Imaginary 数量和等级的线性评分
##   - 纯函数契约：禁止 randf() / Database / PlayerState / Time 调用
##   - max_manageable 由调用方从 PlayerState 读取后显式传入
##   - 随机性（概率升级抽奖）分离到调用方执行
##   - 管道乘数 CHANNEL_MATRIX 砍掉，mode 直接硬赋值 secular/literary

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

## mode → secular/literary 硬赋值
const MODE_VALUE_MAP := {
	"gan_ye":   {"secular": 64.0, "literary": 0.0},
	"deng_gao": {"secular": 0.0,  "literary": 48.0},
}

const POEM_LEVEL_NAMES := {
	1: "平庸",
	2: "佳作",
	3: "绝唱",
}


## ──────────────────────────────────────────────
## 诗词创作结果 V9
## ──────────────────────────────────────────────

class PoemCraftingResult:
	var passed: bool = false          ## false = 错误（如意象不足）
	var fail_reason: String = ""      ## "insufficient" | ""
	var score: int = 0                ## 原始分数（可负）
	var base_level: int = 1           ## 基础等级 (1-3)
	var upgrade_probability: float = 0.0  ## 升级概率 [0.0, 1.0)，纯计算结果
	var secular_value: float = 0.0    ## mode 硬赋值
	var literary_value: float = 0.0   ## mode 硬赋值


## ──────────────────────────────────────────────
## 主入口：纯函数诗词评分引擎 V9
##
## @param imaginaries:  所有参与计算的 Imaginary 数组
## @param mode:         "gan_ye" | "deng_gao"
## @param max_manageable: 意象管理上限，由调用方从 PlayerState.max_imaginary_managable 读取后传入
## @return PoemCraftingResult
## ──────────────────────────────────────────────

static func calculate_poem_grade(
	imaginaries: Array,
	mode: String,
	max_manageable: int = 3
) -> PoemCraftingResult:
	var result := PoemCraftingResult.new()
	
	# ── 1. 前置校验：意象数量不足 ──
	if imaginaries.size() < max_manageable:
		result.passed = false
		result.fail_reason = "insufficient"
		Logging.warn("PoemCraftingCalculator(V9): 意象不足 — 当前 %d, 需要至少 %d" % [imaginaries.size(), max_manageable])
		return result
	
	# ── 2. 评分计算 ──
	var score := 0
	var within_limit_count := 0
	var overflow_count := 0
	
	for i in range(imaginaries.size()):
		var imag = imaginaries[i]
		if not imag is Imaginary:
			Logging.warn("PoemCraftingCalculator(V9): 跳过非 Imaginary 元素 at index %d" % i)
			continue
		
		if i < max_manageable:
			var level_bonus := _get_level_score(imag.level)
			score += level_bonus
			within_limit_count += 1
			Logging.debug("PoemCraftingCalculator(V9): index=%d uuid=%s level=%d → +%d" % [i, imag.uuid, imag.level, level_bonus])
		else:
			score += OVERFLOW_PENALTY
			overflow_count += 1
			Logging.debug("PoemCraftingCalculator(V9): index=%d uuid=%s level=%d → %d (溢出惩罚)" % [i, imag.uuid, imag.level, OVERFLOW_PENALTY])
	
	result.score = score
	Logging.info("PoemCraftingCalculator(V9): 评分完成 — score=%d, within=%d, overflow=%d, total=%d" % [score, within_limit_count, overflow_count, imaginaries.size()])
	
	# ── 3. 确定基础等级 ──
	result.base_level = _score_to_base_level(score)
	Logging.info("PoemCraftingCalculator(V9): base_level=%d (%s)" % [result.base_level, POEM_LEVEL_NAMES.get(result.base_level, "未知")])
	
	# ── 4. 计算升级概率 ──
	result.upgrade_probability = _calculate_upgrade_probability(score, result.base_level)
	Logging.info("PoemCraftingCalculator(V9): upgrade_probability=%.3f" % result.upgrade_probability)
	
	# ── 5. Mode → secular/literary 硬赋值 ──
	var mode_values = MODE_VALUE_MAP.get(mode, {"secular": 0.0, "literary": 0.0})
	result.secular_value = mode_values["secular"]
	result.literary_value = mode_values["literary"]
	Logging.info("PoemCraftingCalculator(V9): mode='%s' → secular=%.1f, literary=%.1f" % [mode, result.secular_value, result.literary_value])
	
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
## 纯函数：计算升级概率 [0.0, 1.0)
##
## 仅在 base_level < 3 时计算：
##   upgrade_probability = (score - current_threshold) / (next_threshold - current_threshold)
##
## 边界：
##   - score >= LEVEL_2_THRESHOLD (已是绝唱) → 0.0
##   - score < 0 → 钳制 base_level=1, upgrade_probability=0.0
##   - 公式结果钳制在 [0.0, 1.0)
## ──────────────────────────────────────────────

static func _calculate_upgrade_probability(score: int, base_level: int) -> float:
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
		Logging.err("PoemCraftingCalculator(V9): _calculate_upgrade_probability 除零 — base_level=%d, current=%d, next=%d" % [base_level, current_threshold, next_threshold])
		return 0.0
	
	var progress: float = float(score - current_threshold) / float(threshold_range)
	progress = clampf(progress, 0.0, 0.999)  # [0.0, 1.0)，永远不为 1.0
	
	Logging.debug("PoemCraftingCalculator(V9): progress=(%d-%d)/%d=%.3f" % [score, current_threshold, threshold_range, progress])
	return progress


## ──────────────────────────────────────────────
## 纯函数：Imaginary.level → 评分值
## ──────────────────────────────────────────────

static func _get_level_score(level: int) -> int:
	return LEVEL_SCORE_MAP.get(level, 5)


## ──────────────────────────────────────────────
## 工具：base_level → 显示名称
## ──────────────────────────────────────────────

static func get_level_display_name(level: int) -> String:
	return POEM_LEVEL_NAMES.get(level, "未知")


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
