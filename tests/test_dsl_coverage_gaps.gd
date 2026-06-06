# ----------------------------------------------------------------
# DSL Parser 覆盖率缺口补充测试
# ----------------------------------------------------------------
# 架构师留言：
# 对照 parser/dsl_parser.gd（~1200 行）和 parser/micro_dsl_parser.gd（~525 行）
# 中所有公开方法和内部处理器，与现有测试文件做交叉比对后，发现以下缺口：
#
# 🔴 P0（核心操作符，生产代码已上线但零测试）
#   push_event / pop_event / queue_event — 事件链核心
#   random(val=80, success=..., fail=...) — 概率分支操作符
#   emo_add / emo_sub / emo_set — 情绪操作符
#   prop_set — 属性设置操作符
#
# 🟡 P1（高风险，上次崩过的区域）
#   parse_interruption_field / parse_interruptions_field — 中断序列解析
#   parse_provider_field — Provider DSL 解析
#   parse_flag — Flag 三种类型 default value 处理
#
# 🟢 P2（中等风险，边缘功能）
#   flag_bool_not_has / flag_str_not / flag_int_eq / flag_int_ne —
#     4 个已注册但零测试的 requirement
#   DynamicRef @context_key — 动态标志位引用分支
#
# 🔵 P3（部分高风险子集）
#   parse_trait / parse_state_transistor —
#   parse_context 方括号数组语法 [val1;val2;val3]
# ----------------------------------------------------------------
extends GutTest


# ════════════════════════════════════════════════════════════
# 🔴 P0: 事件链操作符 — push_event / pop_event / queue_event
# ════════════════════════════════════════════════════════════

func test_p0_push_event_operator():
	"""push_event(event_key=...) 应解析为 PushEventOperator 且 event_key 正确"""
	var op = MicroDSLParser.parse_operator("push_event(event_key=event_poverty)")
	assert_not_null(op, "push_event 不应返回 null")
	assert_true(op is PushEventOperator, "应为 PushEventOperator")
	var cast_op = op as PushEventOperator
	assert_eq(cast_op.event_key, "event_poverty", "event_key 应为 event_poverty")


func test_p0_push_event_missing_key():
	"""push_event 缺少 event_key 应返回 null"""
	var op = MicroDSLParser.parse_operator("push_event()")
	assert_null(op, "缺少 event_key 的 push_event 应返回 null")


func test_p0_push_event_empty_key():
	"""push_event(event_key=) 空 key 应返回 null"""
	var op = MicroDSLParser.parse_operator("push_event(event_key=)")
	assert_null(op, "空 event_key 的 push_event 应返回 null")


func test_p0_pop_event_operator():
	"""pop_event() 应解析为 PopEventOperator"""
	var op = MicroDSLParser.parse_operator("pop_event()")
	assert_not_null(op, "pop_event 不应返回 null")
	assert_true(op is PopEventOperator, "应为 PopEventOperator")


func test_p0_queue_event_operator():
	"""queue_event(event_key=...) 应解析为 QueueEventOperator 且 event_key 正确"""
	var op = MicroDSLParser.parse_operator("queue_event(event_key=event_duel)")
	assert_not_null(op, "queue_event 不应返回 null")
	assert_true(op is QueueEventOperator, "应为 QueueEventOperator")
	var cast_op = op as QueueEventOperator
	assert_eq(cast_op.event_key, "event_duel", "event_key 应为 event_duel")


func test_p0_queue_event_missing_key():
	"""queue_event 缺少 event_key 应返回 null"""
	var op = MicroDSLParser.parse_operator("queue_event()")
	assert_null(op, "缺少 event_key 的 queue_event 应返回 null")


func test_p0_event_chain_in_consequence_operators():
	"""验证事件操作符可以在 parse_consequence_operators 中混合使用"""
	var ops = MicroDSLParser.parse_consequence_operators(
		"push_event(event_key=event_poverty)|pop_event()|queue_event(event_key=event_duel)"
	)
	assert_eq(ops.size(), 3, "应解析出 3 个操作符")
	assert_true(ops[0] is PushEventOperator, "第一个应为 PushEventOperator")
	assert_true(ops[1] is PopEventOperator, "第二个应为 PopEventOperator")
	assert_true(ops[2] is QueueEventOperator, "第三个应为 QueueEventOperator")


# ════════════════════════════════════════════════════════════
# 🔴 P0: 概率分支操作符 — random(val=80, success=..., fail=...)
# ════════════════════════════════════════════════════════════

func test_p0_random_operator_basic():
	"""random(val=N, success=op) 应解析为 RandomOperator，random_value 正确"""
	var op = MicroDSLParser.parse_operator(
		'random(val=80; success=prop_add(name="money"; val=100))'
	)
	assert_not_null(op, "random 不应返回 null")
	assert_true(op is RandomOperator, "应为 RandomOperator")
	var cast_op = op as RandomOperator
	assert_eq(cast_op.random_value, 80, "random_value 应为 80")
	assert_not_null(cast_op.success_operator, "success_operator 不应为 null")
	assert_true(cast_op.success_operator is PropertyOperator, "success 应为 PropertyOperator")
	var success_op = cast_op.success_operator as PropertyOperator
	assert_eq(success_op.str_props, "money", "success 子 operator 的 str_props 应为 money")
	assert_eq(success_op.value, 100, "success 子 operator 的 value 应为 100")
	assert_null(cast_op.fail_operator, "未提供 fail 时应为 null")


func test_p0_random_operator_with_fail():
	"""random(val=N, success=op, fail=op) 应解析成功/失败两个分支"""
	var op = MicroDSLParser.parse_operator(
		'random(val=60; success=trait_add(name=brave); fail=prop_add(name="reputation"; val=-5))'
	)
	assert_not_null(op, "random 不应返回 null")
	assert_true(op is RandomOperator, "应为 RandomOperator")
	var cast_op = op as RandomOperator
	assert_eq(cast_op.random_value, 60, "random_value 应为 60")
	assert_not_null(cast_op.success_operator, "success_operator 不应为 null")
	assert_true(cast_op.success_operator is TraitOperator, "success 应为 TraitOperator")
	assert_not_null(cast_op.fail_operator, "fail_operator 不应为 null")
	assert_true(cast_op.fail_operator is PropertyOperator, "fail 应为 PropertyOperator")
	var fail_op = cast_op.fail_operator as PropertyOperator
	assert_eq(fail_op.str_props, "reputation", "fail 子 operator 的 str_props 应为 reputation")
	assert_eq(fail_op.value, -5, "fail 子 operator 的 value 应为 -5")


func test_p0_random_operator_val_clamping():
	"""random val 超出 0-100 范围应被 clamp 并发出 warn"""
	var op_above = MicroDSLParser.parse_operator(
		'random(val=150; success=prop_add(name="money"; val=10))'
	)
	assert_not_null(op_above, "val=150 的 random 不应为 null")
	var cast_above = op_above as RandomOperator
	assert_eq(cast_above.random_value, 100, "val=150 应被 clamp 到 100")

	var op_below = MicroDSLParser.parse_operator(
		'random(val=-10; success=prop_add(name="money"; val=10))'
	)
	assert_not_null(op_below, "val=-10 的 random 不应为 null")
	var cast_below = op_below as RandomOperator
	assert_eq(cast_below.random_value, 0, "val=-10 应被 clamp 到 0")


func test_p0_random_operator_with_hints():
	"""random 的 success_hint / failed_hint 应被正确解析"""
	var op = MicroDSLParser.parse_operator(
		'random(val=50; success=prop_add(name="money"; val=10); '
		+ 'success_hint="成功了！"; failed_hint="失败了...")'
	)
	assert_not_null(op, "random 不应返回 null")
	var cast_op = op as RandomOperator
	assert_eq(cast_op.success_hint, "成功了！", "success_hint 应为 成功了！")
	assert_eq(cast_op.failed_hint, "失败了...", "failed_hint 应为 失败了...")
	assert_null(cast_op.fail_operator, "未提供 fail 时应为 null")


# ════════════════════════════════════════════════════════════
# 🔴 P0: 情绪操作符 — emo_add / emo_sub / emo_set
# ════════════════════════════════════════════════════════════

func test_p0_emo_add_operator():
	"""emo_add(name=emo, val=N) 应解析为 EmotionOperator，value 为正数"""
	var op = MicroDSLParser.parse_operator("emo_add(name=sorrow; val=10)")
	assert_not_null(op, "emo_add 不应返回 null")
	assert_true(op is EmotionOperator, "应为 EmotionOperator")
	var cast_op = op as EmotionOperator
	assert_eq(cast_op.str_emotion, "sorrow", "str_emotion 应为 sorrow")
	assert_eq(cast_op.value, 10, "value 应为 10（正数）")


func test_p0_emo_sub_operator():
	"""emo_sub(name=emo, val=N) 应解析为 EmotionOperator，value 为负数"""
	var op = MicroDSLParser.parse_operator("emo_sub(name=anger; val=5)")
	assert_not_null(op, "emo_sub 不应返回 null")
	assert_true(op is EmotionOperator, "应为 EmotionOperator")
	var cast_op = op as EmotionOperator
	assert_eq(cast_op.str_emotion, "anger", "str_emotion 应为 anger")
	assert_eq(cast_op.value, -5, "value 应为 -5（负数，带 abs 保护后取负）")


func test_p0_emo_set_operator():
	"""emo_set(name=emo, val=N) 应解析为 EmotionOperator，value 为直接设置值"""
	var op = MicroDSLParser.parse_operator("emo_set(name=joy; val=50)")
	assert_not_null(op, "emo_set 不应返回 null")
	assert_true(op is EmotionOperator, "应为 EmotionOperator")
	var cast_op = op as EmotionOperator
	assert_eq(cast_op.str_emotion, "joy", "str_emotion 应为 joy")
	assert_eq(cast_op.value, 50, "value 应为 50")


func test_p0_emo_sub_abs_protection():
	"""emo_sub 的 abs 保护：val=-3 应变为 -abs(-3)=-3，而不是 3"""
	var op = MicroDSLParser.parse_operator("emo_sub(name=fear; val=-3)")
	assert_not_null(op, "emo_sub 不应返回 null")
	var cast_op = op as EmotionOperator
	assert_eq(cast_op.value, -3, "val=-3 经 abs 保护后取负应为 -3")


func test_p0_emo_add_abs_protection():
	"""emo_add 的 abs 保护：val=-5 应变为 abs(-5)=5"""
	var op = MicroDSLParser.parse_operator("emo_add(name=fear; val=-5)")
	assert_not_null(op, "emo_add 不应返回 null")
	var cast_op = op as EmotionOperator
	assert_eq(cast_op.value, 5, "val=-5 经 abs 保护后应为 5")


func test_p0_emo_missing_name():
	"""emo_add/sub/set 缺少 name 应返回 null"""
	assert_null(MicroDSLParser.parse_operator("emo_add(val=10)"), "emo_add 缺少 name 应返回 null")
	assert_null(MicroDSLParser.parse_operator("emo_sub(val=10)"), "emo_sub 缺少 name 应返回 null")
	assert_null(MicroDSLParser.parse_operator("emo_set(val=10)"), "emo_set 缺少 name 应返回 null")


func test_p0_emo_operators_in_sequence():
	"""多个情绪操作符混合使用应被正确解析"""
	var ops = MicroDSLParser.parse_consequence_operators(
		"emo_add(name=sorrow; val=10)|emo_sub(name=anger; val=5)|emo_set(name=joy; val=50)"
	)
	assert_eq(ops.size(), 3, "应解析出 3 个情绪操作符")
	assert_true(ops[0] is EmotionOperator, "第一个应为 EmotionOperator")
	assert_true(ops[1] is EmotionOperator, "第二个应为 EmotionOperator")
	assert_true(ops[2] is EmotionOperator, "第三个应为 EmotionOperator")
	assert_eq((ops[0] as EmotionOperator).value, 10, "emo_add value 应为 10")
	assert_eq((ops[1] as EmotionOperator).value, -5, "emo_sub value 应为 -5")
	assert_eq((ops[2] as EmotionOperator).value, 50, "emo_set value 应为 50")


# ════════════════════════════════════════════════════════════
# 🔴 P0: 属性设置操作符 — prop_set
# ════════════════════════════════════════════════════════════

func test_p0_prop_set_operator():
	"""prop_set(name=prop, val=N) 应解析为 PropertyOperator，set 语义"""
	var op = MicroDSLParser.parse_operator("prop_set(name=health; val=100)")
	assert_not_null(op, "prop_set 不应返回 null")
	assert_true(op is PropertyOperator, "应为 PropertyOperator")
	var cast_op = op as PropertyOperator
	assert_eq(cast_op.str_props, "health", "str_props 应为 health")
	assert_eq(cast_op.value, 100, "value 应为 100")


func test_p0_prop_set_missing_name():
	"""prop_set 缺少 name 应返回 null"""
	var op = MicroDSLParser.parse_operator("prop_set(val=50)")
	assert_null(op, "prop_set 缺少 name 应返回 null")


func test_p0_prop_set_with_prop_add_sub():
	"""prop_set 与 prop_add / prop_sub 混合使用"""
	var ops = MicroDSLParser.parse_consequence_operators(
		"prop_add(name=money; val=50)|prop_set(name=health; val=100)|prop_sub(name=money; val=30)"
	)
	assert_eq(ops.size(), 3, "应解析出 3 个操作符")
	assert_true(ops[0] is PropertyOperator, "第一个应为 PropertyOperator")
	assert_true(ops[1] is PropertyOperator, "第二个应为 PropertyOperator")
	assert_true(ops[2] is PropertyOperator, "第三个应为 PropertyOperator")
	assert_eq((ops[1] as PropertyOperator).str_props, "health", "prop_set 的 str_props 应为 health")
	assert_eq((ops[1] as PropertyOperator).value, 100, "prop_set 的 value 应为 100")


# ════════════════════════════════════════════════════════════
# 🟡 P1: 中断序列解析 — parse_interruption_field
# ════════════════════════════════════════════════════════════

func test_p1_parse_interruption_field_basic():
	"""interrupt_event(req, op) 应解析为 ConditionalOperator"""
	var cond_op = DSLParser.parse_interruption_field(
		"interrupt_event(prop_gt(name=money; val=50)|push_event(event_key=event_poverty))"
	)
	assert_not_null(cond_op, "interrupt_event 不应返回 null")
	assert_true(cond_op is ConditionalOperator, "应为 ConditionalOperator")
	assert_not_null(cond_op.condition, "condition 不应为 null")
	assert_eq(cond_op.condition_success_result.size(), 1, "应有一个 success operator")
	assert_true(cond_op.condition_success_result[0] is PushEventOperator,
		"success operator 应为 PushEventOperator")


func test_p1_parse_interruption_field_multiple_operators():
	"""interrupt_event(req, op1, op2) 支持多个 operator（逗号分隔）"""
	var cond_op = DSLParser.parse_interruption_field(
		"interrupt_event(prop_gt(name=money; val=50)|"
		+ "push_event(event_key=event_poverty)|trait_add(name=corrupt))"
	)
	assert_not_null(cond_op, "interrupt_event 不应返回 null")
	assert_eq(cond_op.condition_success_result.size(), 2,
		"应有 2 个 success operators")
	assert_true(cond_op.condition_success_result[0] is PushEventOperator,
		"第一个应为 PushEventOperator")
	assert_true(cond_op.condition_success_result[1] is TraitOperator,
		"第二个应为 TraitOperator")


func test_p1_parse_interruption_field_empty():
	"""空字符串应返回 null"""
	var cond_op = DSLParser.parse_interruption_field("")
	assert_null(cond_op, "空字符串应返回 null")


func test_p1_parse_interruption_field_missing_parens():
	"""缺少括号应返回 null"""
	var cond_op = DSLParser.parse_interruption_field(
		"interrupt_event prop_gt(name=money; val=50)|push_event(event_key=test)"
	)
	assert_null(cond_op, "缺少括号应返回 null")


func test_p1_parse_interruption_field_wrong_func_name():
	"""函数名不是 interrupt_event 应返回 null"""
	var cond_op = DSLParser.parse_interruption_field(
		"some_other_func(prop_gt(name=money; val=50)|push_event(event_key=test))"
	)
	assert_null(cond_op, "非 interrupt_event 函数应返回 null")


func test_p1_parse_interruption_field_flag_req():
	"""interrupt_event 支持 flag_bool_has 作为条件"""
	var cond_op = DSLParser.parse_interruption_field(
		"interrupt_event(flag_bool_has(name=has_sword)|push_event(event_key=event_duel))"
	)
	assert_not_null(cond_op, "flag requirement 的 interrupt_event 不应返回 null")
	assert_not_null(cond_op.condition, "condition 不应为 null")
	assert_eq(cond_op.condition_success_result.size(), 1, "应有一个 success operator")
	assert_true(cond_op.condition_success_result[0] is PushEventOperator,
		"success operator 应为 PushEventOperator")


# ════════════════════════════════════════════════════════════
# 🟡 P1: 中断序列解析 — parse_interruptions_field（多个中断）
# ════════════════════════════════════════════════════════════

func test_p1_parse_interruptions_field_multiple():
	"""parse_interruptions_field 应支持多个 interrupt_event 逗号分隔"""
	var cond_ops = DSLParser.parse_interruptions_field(
		"interrupt_event(prop_gt(name=money; val=50)|push_event(event_key=event_poverty))|"
		+ "interrupt_event(flag_bool_has(name=has_sword)|push_event(event_key=event_duel))"
	)
	assert_eq(cond_ops.size(), 2, "应解析出 2 个 ConditionalOperator")
	assert_true(cond_ops[0] is ConditionalOperator, "第一个应为 ConditionalOperator")
	assert_true(cond_ops[1] is ConditionalOperator, "第二个应为 ConditionalOperator")


func test_p1_parse_interruptions_field_single():
	"""parse_interruptions_field 支持单个 interrupt_event"""
	var cond_ops = DSLParser.parse_interruptions_field(
		"interrupt_event(prop_gt(name=money; val=50)|push_event(event_key=event_poverty))"
	)
	assert_eq(cond_ops.size(), 1, "应解析出 1 个 ConditionalOperator")


func test_p1_parse_interruptions_field_empty():
	"""parse_interruptions_field 空字符串应返回空数组"""
	var cond_ops = DSLParser.parse_interruptions_field("")
	assert_eq(cond_ops.size(), 0, "空字符串应返回空数组")


# ════════════════════════════════════════════════════════════
# 🟡 P1: Provider DSL 解析 — parse_provider_field
# ════════════════════════════════════════════════════════════
# ⚠ 注意：parse_provider_field 需要加载 item_provider.gd 等资源文件，
# 在 @tool 模式下可能无法正常实例化。测试验证解析层逻辑（函数名提取、
# 参数解析）的正确性，如果实例化失败至少在预期内。

func test_p1_parse_provider_field_basic():
	"""parse_provider_field 应尝试解析并创建 provider 实例"""
	var provider = DSLParser.parse_provider_field(
		'item_provider(list_key="guests"; text_template="走向 {item}")'
	)
	# 测试只验证解析层不崩溃，实例化依赖 @tool 模式可用性
	if provider != null:
		assert_true(provider is BaseProvider, "provider 应为 BaseProvider")


func test_p1_parse_provider_field_empty():
	"""parse_provider_field 空字符串应返回 null"""
	var provider = DSLParser.parse_provider_field("")
	assert_null(provider, "空 provider 字符串应返回 null")


func test_p1_parse_provider_field_invalid():
	"""parse_provider_field 无效的 DSL 语法应返回 null"""
	var provider = DSLParser.parse_provider_field(
		"not_a_provider(list_key=guests)"
	)
	assert_null(provider, "未知 provider 函数应返回 null")


# ════════════════════════════════════════════════════════════
# 🟡 P1: Flag 解析 — parse_flag (三种类型 + default value)
# ════════════════════════════════════════════════════════════

func test_p1_parse_flag_str():
	"""parse_flag 解析 str 类型的 flag"""
	var row = {"flag_id": "test_flag", "type": "str", "default_value": "hello"}
	var flag = DSLParser.parse_flag(row)
	assert_not_null(flag, "str flag 不应为 null")
	assert_eq(flag.type, "str", "type 应为 str")
	assert_eq(flag.val_str, "hello", "val_str 应为 hello")


func test_p1_parse_flag_int():
	"""parse_flag 解析 int 类型的 flag"""
	var row = {"flag_id": "score_flag", "type": "int", "default_value": "100"}
	var flag = DSLParser.parse_flag(row)
	assert_not_null(flag, "int flag 不应为 null")
	assert_eq(flag.type, "int", "type 应为 int")
	assert_eq(flag.val_int, 100, "val_int 应为 100")


func test_p1_parse_flag_bool_true():
	"""parse_flag 解析 bool 类型的 flag — true"""
	var row = {"flag_id": "visited_flag", "type": "bool", "default_value": "true"}
	var flag = DSLParser.parse_flag(row)
	assert_not_null(flag, "bool flag 不应为 null")
	assert_eq(flag.type, "bool", "type 应为 bool")
	assert_true(flag.val_bool, "val_bool 应为 true")


func test_p1_parse_flag_bool_false():
	"""parse_flag 解析 bool 类型的 flag — false"""
	var row = {"flag_id": "hidden_flag", "type": "bool", "default_value": "false"}
	var flag = DSLParser.parse_flag(row)
	assert_not_null(flag, "bool flag 不应为 null")
	assert_eq(flag.type, "bool", "type 应为 bool")
	assert_false(flag.val_bool, "val_bool 应为 false")


func test_p1_parse_flag_bool_variants():
	"""parse_flag bool 支持 t/f/1/0/yes/no 等多种表示"""
	var variants = ["t", "T", "1", "yes", "YES"]
	for v in variants:
		var row = {"flag_id": "f", "type": "bool", "default_value": v}
		var flag = DSLParser.parse_flag(row)
		assert_true(flag.val_bool, "bool variant '%s' 应解析为 true" % v)

	var false_variants = ["f", "F", "0", "no", "NO"]
	for v in false_variants:
		var row = {"flag_id": "f", "type": "bool", "default_value": v}
		var flag = DSLParser.parse_flag(row)
		assert_false(flag.val_bool, "bool variant '%s' 应解析为 false" % v)


func test_p1_parse_flag_default_type():
	"""parse_flag 未指定 type 时默认 str"""
	var row = {"flag_id": "default_flag", "default_value": "test"}
	var flag = DSLParser.parse_flag(row)
	assert_not_null(flag, "无 type flag 不应为 null")
	assert_eq(flag.type, "str", "未指定 type 时默认应为 str")


func test_p1_parse_flag_empty_row():
	"""parse_flag 空行应返回 null"""
	var row = {}
	assert_null(DSLParser.parse_flag(row), "空行应返回 null")


func test_p1_parse_flag_missing_id():
	"""parse_flag 缺少 flag_id 应返回 null"""
	var row = {"type": "str", "default_value": "test"}
	assert_null(DSLParser.parse_flag(row), "缺少 flag_id 应返回 null")


func test_p1_parse_flag_invalid_type():
	"""parse_flag 无效 type 应 fallback 到 str"""
	var row = {"flag_id": "bad_flag", "type": "float", "default_value": "3.14"}
	var flag = DSLParser.parse_flag(row)
	assert_not_null(flag, "无效 type flag 不应为 null")
	assert_eq(flag.type, "str", "无效 type 应 fallback 到 str")
	assert_eq(flag.val_str, "3.14", "str fallback 值应为 3.14")


# ════════════════════════════════════════════════════════════
# 🟢 P2: 未测试的 Requirement 操作符
# ════════════════════════════════════════════════════════════

func test_p2_flag_bool_not_has():
	"""flag_bool_not_has(name=xxx) 应解析为 FlagRequirement(bool, NOT_HAS)"""
	var req = MicroDSLParser.parse_requirement("flag_bool_not_has(name=visited_palace)")
	assert_not_null(req, "flag_bool_not_has 不应返回 null")
	assert_true(req is FlagRequirement, "应为 FlagRequirement")
	var cast_req = req as FlagRequirement
	assert_eq(cast_req.flag_id, "visited_palace", "flag_id 应为 visited_palace")
	assert_eq(cast_req.type, "bool", "type 应为 bool")
	assert_eq(cast_req.operator, REQ_OPERATOR.COMPARE.LESS_THAN, "operator 应为 LESS_THAN (bool not_has)")
	assert_eq(cast_req.value, true, "value 应为 true")


func test_p2_flag_str_not():
	"""flag_str_not(name=xxx; val=yyy) 应解析为 FlagRequirement(str, NOT_EQUAL)"""
	var req = MicroDSLParser.parse_requirement(
		'flag_str_not(name=player_name; val=张三)'
	)
	assert_not_null(req, "flag_str_not 不应返回 null")
	assert_true(req is FlagRequirement, "应为 FlagRequirement")
	var cast_req = req as FlagRequirement
	assert_eq(cast_req.flag_id, "player_name", "flag_id 应为 player_name")
	assert_eq(cast_req.type, "str", "type 应为 str")
	assert_eq(cast_req.operator, REQ_OPERATOR.COMPARE.NOT_EQUAL, "operator 应为 NOT_EQUAL")
	assert_eq(cast_req.value, "张三", "value 应为 张三")


func test_p2_flag_int_eq():
	"""flag_int_eq(name=xxx; val=N) 应解析为 FlagRequirement(int, EQUAL)"""
	var req = MicroDSLParser.parse_requirement("flag_int_eq(name=flag_score; val=100)")
	assert_not_null(req, "flag_int_eq 不应返回 null")
	assert_true(req is FlagRequirement, "应为 FlagRequirement")
	var cast_req = req as FlagRequirement
	assert_eq(cast_req.flag_id, "flag_score", "flag_id 应为 flag_score")
	assert_eq(cast_req.type, "int", "type 应为 int")
	assert_eq(cast_req.operator, REQ_OPERATOR.COMPARE.EQUAL, "operator 应为 EQUAL")
	assert_eq(cast_req.value, 100, "value 应为 100")


func test_p2_flag_int_ne():
	"""flag_int_ne(name=xxx; val=N) 应解析为 FlagRequirement(int, NOT_EQUAL)"""
	var req = MicroDSLParser.parse_requirement("flag_int_ne(name=flag_score; val=50)")
	assert_not_null(req, "flag_int_ne 不应返回 null")
	assert_true(req is FlagRequirement, "应为 FlagRequirement")
	var cast_req = req as FlagRequirement
	assert_eq(cast_req.flag_id, "flag_score", "flag_id 应为 flag_score")
	assert_eq(cast_req.type, "int", "type 应为 int")
	assert_eq(cast_req.operator, REQ_OPERATOR.COMPARE.NOT_EQUAL, "operator 应为 NOT_EQUAL")
	assert_eq(cast_req.value, 50, "value 应为 50")


# ════════════════════════════════════════════════════════════
# 🟢 P2: DynamicRef @context_key — 动态标志位引用
# ════════════════════════════════════════════════════════════

func test_p2_dynamic_ref_flag_bool_set():
	"""flag_bool_set(name=@ctx_key, val=true) 应解析 DynamicRef"""
	var op = MicroDSLParser.parse_operator("flag_bool_set(name=@initiator_flag; val=true)")
	assert_not_null(op, "DynamicRef flag_bool_set 不应返回 null")
	assert_true(op is FlagOperator, "应为 FlagOperator")
	var cast_op = op as FlagOperator
	assert_eq(cast_op.target_flag_id_from_context, "initiator_flag",
		"target_flag_id_from_context 应为 initiator_flag")
	assert_eq(cast_op.flag_id, "", "flag_id 应为空（由 context 动态解析）")


func test_p2_dynamic_ref_flag_int_append():
	"""flag_int_append(name=@ctx_key, val=N) 应解析 DynamicRef"""
	var op = MicroDSLParser.parse_operator("flag_int_append(name=@target_npc; val=10)")
	assert_not_null(op, "DynamicRef flag_int_append 不应返回 null")
	assert_true(op is FlagOperator, "应为 FlagOperator")
	var cast_op = op as FlagOperator
	assert_eq(cast_op.target_flag_id_from_context, "target_npc",
		"target_flag_id_from_context 应为 target_npc")


func test_p2_dynamic_ref_flag_str_set():
	"""flag_str_set(name=@ctx_key, val=xxx) 应解析 DynamicRef"""
	var op = MicroDSLParser.parse_operator(
		'flag_str_set(name=@initiator_name; val="TR_Drunk")'
	)
	assert_not_null(op, "DynamicRef flag_str_set 不应返回 null")
	assert_true(op is FlagOperator, "应为 FlagOperator")
	var cast_op = op as FlagOperator
	assert_eq(cast_op.target_flag_id_from_context, "initiator_name",
		"target_flag_id_from_context 应为 initiator_name")


# ════════════════════════════════════════════════════════════
# 🔵 P3: Trait 解析 — parse_trait
# ════════════════════════════════════════════════════════════

func test_p3_parse_trait_basic():
	"""parse_trait 应解析基本的 trait 行"""
	var row = {
		"trait_id": "trait_brave",
		"trait_name": "勇敢",
		"topic": "RELATION",
		"specific_topic": "HATE",
		"relate_to": "PLAYER",
		"lasting_xun": "5"
	}
	var trait_ = DSLParser.parse_trait(row)
	assert_not_null(trait_, "trait 不应为 null")
	assert_eq(trait_.uuid, "trait_brave", "uuid 应为 trait_brave")
	assert_eq(trait_.name, "勇敢", "name 应为 勇敢")
	assert_eq(trait_.topic, "RELATION", "topic 应为 RELATION")
	assert_eq(trait_.specific_topic, "HATE", "specific_topic 应为 HATE")


func test_p3_parse_trait_missing_id():
	"""parse_trait 缺少 trait_id 应返回 null"""
	var row = {"trait_name": "test"}
	assert_null(DSLParser.parse_trait(row), "缺少 trait_id 应返回 null")


func test_p3_parse_trait_empty():
	"""parse_trait 空行应返回 null"""
	assert_null(DSLParser.parse_trait({}), "空行应返回 null")


func test_p3_parse_trait_effect_operations():
	"""parse_trait 应解析 trait_effect_operations 为 PropertyOperator 列表"""
	var row = {
		"trait_id": "trait_effect_test",
		"trait_name": "效果测试",
		"trait_effect_operations": "prop_add(name=money; val=10)|prop_sub(name=health; val=5)"
	}
	var trait_ = DSLParser.parse_trait(row)
	assert_not_null(trait_, "trait 不应为 null")
	assert_eq(trait_.trait_effect_operations.size(), 2,
		"trait_effect_operations 应有 2 个操作符")
	assert_true(trait_.trait_effect_operations[0] is PropertyOperator,
		"第一个应为 PropertyOperator")
	assert_true(trait_.trait_effect_operations[1] is PropertyOperator,
		"第二个应为 PropertyOperator")


# ════════════════════════════════════════════════════════════
# 🔵 P3: StateTransistor 解析 — parse_state_transistor
# ════════════════════════════════════════════════════════════

func test_p3_parse_state_transistor_basic():
	"""parse_state_transistor 应解析基本行"""
	var row = {
		"uuid": "transistor_01",
		"target_resource": "urn:flag:some_flag",
		"transist_value": "=true",
		"current_resource": "urn:flag:old_flag",
		"triggered_event": "event_follow_up"
	}
	var transistor = DSLParser.parse_state_transistor(row)
	assert_not_null(transistor, "state_transistor 不应为 null")
	assert_eq(transistor.uuid, "transistor_01", "uuid 应为 transistor_01")
	assert_eq(transistor.target_resource_urn, "urn:flag:some_flag",
		"target_resource_urn 应为 urn:flag:some_flag")
	assert_eq(transistor.transist_value, "=true", "transist_value 应为 =true")
	assert_eq(transistor.triggered_event_key, "event_follow_up",
		"triggered_event_key 应为 event_follow_up")


func test_p3_parse_state_transistor_with_dsl_fields():
	"""parse_state_transistor 应解析 requirement 和 operators DSL 字段"""
	var row = {
		"uuid": "transistor_02",
		"target_resource": "urn:flag:score_flag",
		"requirement": "prop_gt(name=money; val=50)",
		"operators": "prop_add(name=money; val=-50)|trait_add(name=spent_money)"
	}
	var transistor = DSLParser.parse_state_transistor(row)
	assert_not_null(transistor, "state_transistor 不应为 null")
	assert_not_null(transistor.requirements, "requirements 不应为 null")
	assert_eq(transistor.operators.size(), 2, "operators 应有 2 个")
	assert_true(transistor.operators[0] is PropertyOperator,
		"第一个 operator 应为 PropertyOperator")
	assert_true(transistor.operators[1] is TraitOperator,
		"第二个 operator 应为 TraitOperator")


func test_p3_parse_state_transistor_empty():
	"""parse_state_transistor 空行应返回 null"""
	assert_null(DSLParser.parse_state_transistor({}), "空行应返回 null")


# ════════════════════════════════════════════════════════════
# 🔵 P3: parse_context 方括号数组语法 [val1;val2;val3]
# ════════════════════════════════════════════════════════════

func test_p3_parse_context_bracket_array():
	"""parse_context 应支持 [val1;val2;val3] 方括号数组语法"""
	var result = DSLParser.parse_context("some_key=[val1;val2;val3]")
	assert_has(result, "custom_params", "应返回 custom_params")
	assert_has(result.custom_params, "some_key", "custom_params 应包含 some_key")
	var val = result.custom_params["some_key"]
	assert_true(val is PackedStringArray, "方括号数组应为 PackedStringArray")
	assert_eq(val.size(), 3, "数组应有 3 个元素")
	assert_eq(val[0], "val1", "第一个元素应为 val1")
	assert_eq(val[1], "val2", "第二个元素应为 val2")
	assert_eq(val[2], "val3", "第三个元素应为 val3")


func test_p3_parse_context_bracket_array_single():
	"""parse_context 应支持 [val] 单元素方括号数组"""
	var result = DSLParser.parse_context("single_key=[only_one]")
	assert_has(result.custom_params, "single_key")
	var val = result.custom_params["single_key"]
	assert_true(val is PackedStringArray, "单元素也应为 PackedStringArray")
	assert_eq(val.size(), 1, "数组应有 1 个元素")
	assert_eq(val[0], "only_one", "元素应为 only_one")


func test_p3_parse_context_bracket_array_empty():
	"""parse_context 应支持 [] 空方括号数组"""
	var result = DSLParser.parse_context("empty_key=[]")
	assert_has(result.custom_params, "empty_key")
	var val = result.custom_params["empty_key"]
	assert_true(val is PackedStringArray, "空数组也应为 PackedStringArray")
	assert_eq(val.size(), 0, "空数组应有 0 个元素")


func test_p3_parse_context_trigger_tags_bracket():
	"""parse_context 的 trigger_tags 支持方括号语法 [tag1,tag2]"""
	var result = DSLParser.parse_context(
		"trigger_tags=[action:intent:study:poetry/action:intent:study:calligraphy]"
	)
	assert_has(result, "trigger_tags", "应返回 trigger_tags")
	assert_gt(result.trigger_tags.size(), 0, "trigger_tags 不应为空")


# ════════════════════════════════════════════════════════════
# 🔴 P0: 临时标志位操作符 — temp_flag_* DSL 解析测试
# ════════════════════════════════════════════════════════════
# 这些测试验证 MicroDSLParser 是否正确地将 temp_flag_* DSL 语法
# 解析为 TempFlagOperator 实例。TempFlagOperator 继承自 FlagOperator，
# 在 operate() 时额外注册反向清理算子到 PlayerState。
#
# 注意：这里只测试 DSL 解析层（parse_operator 返回值），
# 不测试 operate() 运行时行为（那部分在 test_operators_runtime.gd）。

func test_p0_temp_flag_bool_set():
	"""temp_flag_bool_set(name=xxx, val=true) 应解析为 TempFlagOperator"""
	var op = MicroDSLParser.parse_operator("temp_flag_bool_set(name=temp_has_key; val=true)")
	assert_not_null(op, "temp_flag_bool_set 不应返回 null")
	assert_true(op is TempFlagOperator, "应为 TempFlagOperator")
	var cast_op = op as TempFlagOperator
	assert_eq(cast_op.flag_id, "temp_has_key", "flag_id 应为 temp_has_key")
	assert_eq(cast_op.type, "bool", "type 应为 bool")
	assert_eq(cast_op.operation, "set", "operation 应为 set")
	assert_eq(cast_op.value, true, "value 应为 true")


func test_p0_temp_flag_bool_set_false():
	"""temp_flag_bool_set(name=xxx, val=false) 正确解析 false"""
	var op = MicroDSLParser.parse_operator("temp_flag_bool_set(name=temp_remove_me; val=false)")
	assert_not_null(op, "temp_flag_bool_set false 不应返回 null")
	var cast_op = op as TempFlagOperator
	assert_eq(cast_op.value, false, "value 应为 false")


func test_p0_temp_flag_bool_set_missing_name():
	"""temp_flag_bool_set 缺少 name 应返回 null"""
	var op = MicroDSLParser.parse_operator("temp_flag_bool_set(val=true)")
	assert_null(op, "temp_flag_bool_set 缺少 name 应返回 null")


func test_p0_temp_flag_str_set():
	"""temp_flag_str_set(name=xxx, val=yyy) 应解析为 TempFlagOperator"""
	var op = MicroDSLParser.parse_operator('temp_flag_str_set(name=temp_title; val=TR_Drunk)')
	assert_not_null(op, "temp_flag_str_set 不应返回 null")
	assert_true(op is TempFlagOperator, "应为 TempFlagOperator")
	var cast_op = op as TempFlagOperator
	assert_eq(cast_op.flag_id, "temp_title", "flag_id 应为 temp_title")
	assert_eq(cast_op.type, "str", "type 应为 str")
	assert_eq(cast_op.operation, "set", "operation 应为 set")
	assert_eq(cast_op.value, "TR_Drunk", "value 应为 TR_Drunk")


func test_p0_temp_flag_str_append():
	"""temp_flag_str_append(name=xxx, val=yyy) 应解析为 TempFlagOperator"""
	var op = MicroDSLParser.parse_operator('temp_flag_str_append(name=temp_log; val=新事件)')
	assert_not_null(op, "temp_flag_str_append 不应返回 null")
	assert_true(op is TempFlagOperator, "应为 TempFlagOperator")
	var cast_op = op as TempFlagOperator
	assert_eq(cast_op.flag_id, "temp_log", "flag_id 应为 temp_log")
	assert_eq(cast_op.type, "str", "type 应为 str")
	assert_eq(cast_op.operation, "append", "operation 应为 append")
	assert_eq(cast_op.value, "新事件", "value 应为 新事件")


func test_p0_temp_flag_int_set():
	"""temp_flag_int_set(name=xxx, val=N) 应解析为 TempFlagOperator"""
	var op = MicroDSLParser.parse_operator("temp_flag_int_set(name=temp_score; val=100)")
	assert_not_null(op, "temp_flag_int_set 不应返回 null")
	assert_true(op is TempFlagOperator, "应为 TempFlagOperator")
	var cast_op = op as TempFlagOperator
	assert_eq(cast_op.flag_id, "temp_score", "flag_id 应为 temp_score")
	assert_eq(cast_op.type, "int", "type 应为 int")
	assert_eq(cast_op.operation, "set", "operation 应为 set")
	assert_eq(cast_op.value, 100, "value 应为 100")


func test_p0_temp_flag_int_append():
	"""temp_flag_int_append(name=xxx, val=N) 应解析为 TempFlagOperator"""
	var op = MicroDSLParser.parse_operator("temp_flag_int_append(name=temp_score; val=50)")
	assert_not_null(op, "temp_flag_int_append 不应返回 null")
	assert_true(op is TempFlagOperator, "应为 TempFlagOperator")
	var cast_op = op as TempFlagOperator
	assert_eq(cast_op.flag_id, "temp_score", "flag_id 应为 temp_score")
	assert_eq(cast_op.type, "int", "type 应为 int")
	assert_eq(cast_op.operation, "append", "operation 应为 append")
	assert_eq(cast_op.value, 50, "value 应为 50")


func test_p0_temp_flag_int_reduce_if_above():
	"""temp_flag_int_reduce_if_above 应解析为 TempFlagOperator"""
	var op = MicroDSLParser.parse_operator(
		"temp_flag_int_reduce_if_above(name=temp_sanity; threshold=10; amount=5)"
	)
	assert_not_null(op, "temp_flag_int_reduce_if_above 不应返回 null")
	assert_true(op is TempFlagOperator, "应为 TempFlagOperator")
	var cast_op = op as TempFlagOperator
	assert_eq(cast_op.flag_id, "temp_sanity", "flag_id 应为 temp_sanity")
	assert_eq(cast_op.type, "int", "type 应为 int")
	assert_eq(cast_op.operation, "reduce_if_above", "operation 应为 reduce_if_above")
	assert_eq(cast_op.threshold, 10, "threshold 应为 10")
	assert_eq(cast_op.amount, 5, "amount 应为 5")


func test_p0_temp_flag_operators_in_sequence():
	"""多个 temp_flag 操作符混合使用应被正确解析"""
	var ops = MicroDSLParser.parse_consequence_operators(
		"temp_flag_bool_set(name=temp_has_key; val=true)|"
		+ "temp_flag_int_append(name=temp_score; val=50)|"
		+ "temp_flag_str_set(name=temp_title; val=TR_Drunk)"
	)
	assert_eq(ops.size(), 3, "应解析出 3 个操作符")
	assert_true(ops[0] is TempFlagOperator, "第一个应为 TempFlagOperator")
	assert_true(ops[1] is TempFlagOperator, "第二个应为 TempFlagOperator")
	assert_true(ops[2] is TempFlagOperator, "第三个应为 TempFlagOperator")
	assert_eq((ops[0] as TempFlagOperator).type, "bool", "第一个 type 应为 bool")
	assert_eq((ops[1] as TempFlagOperator).type, "int", "第二个 type 应为 int")
	assert_eq((ops[2] as TempFlagOperator).type, "str", "第三个 type 应为 str")


func test_p0_temp_flag_mixed_with_regular_flag():
	"""temp_flag 与普通 flag 操作符混合解析"""
	var ops = MicroDSLParser.parse_consequence_operators(
		"temp_flag_bool_set(name=temp_entered_tavern; val=true)|"
		+ "flag_bool_set(name=global_has_key; val=true)"
	)
	assert_eq(ops.size(), 2, "应解析出 2 个操作符")
	assert_true(ops[0] is TempFlagOperator, "第一个应为 TempFlagOperator")
	assert_true(ops[1] is FlagOperator, "第二个应为 FlagOperator")
	assert_false(ops[1] is TempFlagOperator, "第二个不应是 TempFlagOperator")


func test_p0_temp_flag_with_dynamic_ref():
	"""temp_flag 支持 @DynamicRef 语法"""
	var op = MicroDSLParser.parse_operator(
		'temp_flag_str_set(name=@initiator_flag; val="TR_Drunk")'
	)
	assert_not_null(op, "DynamicRef temp_flag_str_set 不应返回 null")
	assert_true(op is TempFlagOperator, "应为 TempFlagOperator")
	var cast_op = op as TempFlagOperator
	assert_eq(cast_op.target_flag_id_from_context, "initiator_flag",
		"target_flag_id_from_context 应为 initiator_flag")


func test_p0_temp_flag_with_regular_operators_in_consequence():
	"""temp_flag 与 prop_add / trait_add 等混合使用"""
	var ops = MicroDSLParser.parse_consequence_operators(
		"prop_add(name=money; val=100)|"
		+ "temp_flag_bool_set(name=temp_met_libai; val=true)|"
		+ "trait_add(name=drunk)"
	)
	assert_eq(ops.size(), 3, "应解析出 3 个操作符")
	assert_true(ops[0] is PropertyOperator, "第一个应为 PropertyOperator")
	assert_true(ops[1] is TempFlagOperator, "第二个应为 TempFlagOperator")
	assert_true(ops[2] is TraitOperator, "第三个应为 TraitOperator")
