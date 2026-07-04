# ================================================================
# TimeControlPanel.format_time_dots() 纯函数测试
# ================================================================
# 覆盖场景:
#   - 0-10 天全覆盖（11 个用例）
#   - time_val 超限 → 全白圆兜底
#   - 自定义 total_days / total_slots
# ================================================================
extends GutTest

const TimePanelScript = preload("res://world/time_control_panel.gd")


# ════════════════════════════════════════════════════════════
# 0-10 天全覆盖
# ════════════════════════════════════════════════════════════

func test_format_10_days():
	var result = TimePanelScript.format_time_dots(10, 10)
	assert_eq(result, "●●●●●", "10天 → ●●●●●")

func test_format_9_days():
	var result = TimePanelScript.format_time_dots(9, 10)
	assert_eq(result, "●●●●◐", "9天 → ●●●●◐")

func test_format_8_days():
	var result = TimePanelScript.format_time_dots(8, 10)
	assert_eq(result, "●●●●○", "8天 → ●●●●○")

func test_format_7_days():
	var result = TimePanelScript.format_time_dots(7, 10)
	assert_eq(result, "●●●◐○", "7天 → ●●●◐○")

func test_format_6_days():
	var result = TimePanelScript.format_time_dots(6, 10)
	assert_eq(result, "●●●○○", "6天 → ●●●○○")

func test_format_5_days():
	var result = TimePanelScript.format_time_dots(5, 10)
	assert_eq(result, "●●◐○○", "5天 → ●●◐○○")

func test_format_4_days():
	var result = TimePanelScript.format_time_dots(4, 10)
	assert_eq(result, "●●○○○", "4天 → ●●○○○")

func test_format_3_days():
	var result = TimePanelScript.format_time_dots(3, 10)
	assert_eq(result, "●◐○○○", "3天 → ●◐○○○")

func test_format_2_days():
	var result = TimePanelScript.format_time_dots(2, 10)
	assert_eq(result, "●○○○○", "2天 → ●○○○○")

func test_format_1_day():
	var result = TimePanelScript.format_time_dots(1, 10)
	assert_eq(result, "◐○○○○", "1天 → ◐○○○○")

func test_format_0_days():
	var result = TimePanelScript.format_time_dots(0, 10)
	assert_eq(result, "○○○○○", "0天 → ○○○○○")


# ════════════════════════════════════════════════════════════
# time_val 超限 → 全白圆兜底
# ════════════════════════════════════════════════════════════

func test_format_negative_returns_white():
	var result = TimePanelScript.format_time_dots(-1, 10)
	assert_eq(result, "NaN", "-1 → NaN")

func test_format_overflow_returns_white():
	var result = TimePanelScript.format_time_dots(11, 10)
	assert_eq(result, "NaN", "11 > 10 → NaN")

func test_format_overflow_returns_white_15():
	var result = TimePanelScript.format_time_dots(15, 10)
	assert_eq(result, "NaN", "15 → NaN")


# ════════════════════════════════════════════════════════════
# 自定义 total_days / total_slots
# ════════════════════════════════════════════════════════════

func test_format_custom_total_days():
	# total_days=6, slots=3: 3天 → ●◐○
	var result = TimePanelScript.format_time_dots(3, 6, 3)
	assert_eq(result, "●◐○", "6天池 3天剩余 3槽 → ●◐○")

func test_format_custom_total_days_full():
	# total_days=6, slots=3: 6天 → ●●●
	var result = TimePanelScript.format_time_dots(6, 6, 3)
	assert_eq(result, "●●●", "6天池 6天剩余 3槽 → ●●●")

func test_format_custom_total_days_zero():
	# total_days=6, slots=3: 0天 → ○○○
	var result = TimePanelScript.format_time_dots(0, 6, 3)
	assert_eq(result, "○○○", "6天池 0天剩余 3槽 → ○○○")

func test_format_custom_total_days_overflow():
	# total_days=4, slots=2: 5天超限 → ○○
	var result = TimePanelScript.format_time_dots(5, 4, 2)
	assert_eq(result, "○○", "4天池 5天超限 → ○○")
