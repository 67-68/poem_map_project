@tool
extends Node

# ═══════════════════════════════════════════════════════
# create_fengxian_events.gd — 奉先村事件链一键创建脚本
#
# 使用方式: godot --headless --script parser/create_fengxian_events.gd
#
# 创建 5 个事件 + 完整链 + 所有 operators/requirements。
# 无 DSL，直接 Resource API，一步到位。
# ═══════════════════════════════════════════════════════

# ─── preload 依赖（--script 模式兼容） ───
const BaseEvent = preload("res://model/event.gd")
const EventOption = preload("res://model/event/event_option.gd")
const ChoiceResult = preload("res://model/choice_result.gd")
const PushEventOperator = preload("res://core/operators/push_event_operator.gd")
const PopEventOperator = preload("res://core/operators/pop_event_operator.gd")
const FlagRequirement = preload("res://core/requirements/flag_requirement.gd")
const FlagOperator = preload("res://core/operators/flag_operator.gd")
const InfoDemoOperator = preload("res://core/operators/info_demo_operator.gd")
const ComplexRequirements = preload("res://core/model/multiple_requiremenets.gd")

const SAVE_DIR := "res://data/5_story_arcs/755_backhome/"

# ─── Flag 命名常量 ───
const FLAG_FAMILIAR_PATH_DONE   := "flag_fengxian_familiar_path_done"
const FLAG_ASK_LIZHENG_DONE     := "flag_fengxian_ask_lizheng_done"
const FLAG_OLD_HOME_DONE        := "flag_fengxian_old_home_done"

# Once-flag 前缀 (由 chain_flag_generator 约定)
const ONCE_PREFIX := "flag_once_"
const EVENT1_KEY  := "fengxian_village_entrance"
const FLAG_ONCE_E1_OPT1 := ONCE_PREFIX + EVENT1_KEY + "_opt_go_familiar_path"
const FLAG_ONCE_E1_OPT2 := ONCE_PREFIX + EVENT1_KEY + "_opt_ask_lizheng"
const FLAG_ONCE_E1_OPT3 := ONCE_PREFIX + EVENT1_KEY + "_opt_find_old_home"


func _ready() -> void:
	print("[FengxianCreator] ========== 开始创建奉先村事件链 ==========")

	_create_event_2()
	_create_event_3()
	_create_event_4()
	_create_event_1()
	_create_event_5()

	print("[FengxianCreator] ========== 全部完成 ==========")
	print("[FengxianCreator] 三个 Flag 名称（用于手动 interruptor）:")
	print("  - %s" % FLAG_FAMILIAR_PATH_DONE)
	print("  - %s" % FLAG_ASK_LIZHENG_DONE)
	print("  - %s" % FLAG_OLD_HOME_DONE)
	get_tree().quit(0)


# ─── 事件 2: 沿熟悉路径找家 ───
func _create_event_2() -> void:
	var event = BaseEvent.new()
	event.uuid = "fengxian_familiar_path"
	event.name = "熟悉的路径"
	event.description = "你凭着十年前的记忆在这片田野里摸索。路早就被荒草吞没了大半，但方向还在骨头里。风从奉先县城那边吹过来，夹着一股柴烟味。"

	# 唯一的选项: 返回村口
	var opt = EventOption.new()
	opt.uuid = "opt_return_village"
	opt.description = "折返回村口"

	# Pop 回 Event 1
	var pop_op = PopEventOperator.new()

	# Flag 标记：已完成
	var flag_op = FlagOperator.new()
	flag_op.flag_id = FLAG_FAMILIAR_PATH_DONE
	flag_op.type = "bool"
	flag_op.operation = "set"
	flag_op.value = true

	# 不详预感 InfoDemo
	var info_op = InfoDemoOperator.new()
	info_op.info = "远处的茅草屋里传来婴儿断断续续的啼哭，像是在硬撑。"

	var cr = ChoiceResult.new()
	cr.operators.append(pop_op)
	cr.operators.append(flag_op)
	cr.operators.append(info_op)
	opt.choice_result = cr

	event.options.append(opt)

	var path = SAVE_DIR + "fengxian_familiar_path.tres"
	_save(event, path)


# ─── 事件 3: 折返问里正 ───
func _create_event_3() -> void:
	var event = BaseEvent.new()
	event.uuid = "fengxian_ask_lizheng"
	event.name = "村口的里正"
	event.description = "里正还坐在那张磨得发亮的木凳上，像是从未挪过。你走过去的时候，他正闭着眼晒太阳——不，也许只是在打盹。冬天的太阳没有温度，照在他脸上像一层薄灰。"

	# 唯一的选项: 返回村口
	var opt = EventOption.new()
	opt.uuid = "opt_return_village"
	opt.description = "转身离开"

	var pop_op = PopEventOperator.new()

	var flag_op = FlagOperator.new()
	flag_op.flag_id = FLAG_ASK_LIZHENG_DONE
	flag_op.type = "bool"
	flag_op.operation = "set"
	flag_op.value = true

	var info_op = InfoDemoOperator.new()
	info_op.info = "里正闭着眼，指了一个你根本不认识的方向。风里…听不到哭声了。"

	var cr = ChoiceResult.new()
	cr.operators.append(pop_op)
	cr.operators.append(flag_op)
	cr.operators.append(info_op)
	opt.choice_result = cr

	event.options.append(opt)

	var path = SAVE_DIR + "fengxian_ask_lizheng.tres"
	_save(event, path)


# ─── 事件 4: 旧家·干尸 ───
func _create_event_4() -> void:
	var event = BaseEvent.new()
	event.uuid = "fengxian_old_home_corpse"
	event.name = "旧居"
	event.description = "门虚掩着。你推开门，屋里的霉味混着一股甜腻的腐烂气息迎面扑来。地上趴着一具干尸——骨节粗大，肩宽，不像女人，更不是孩子。你蹲下来翻看尸体的手，指节上有老茧，是握锄头的痕迹。"

	# 唯一的选项: 返回村口
	var opt = EventOption.new()
	opt.uuid = "opt_return_village"
	opt.description = "退出门外"

	var pop_op = PopEventOperator.new()

	var flag_op = FlagOperator.new()
	flag_op.flag_id = FLAG_OLD_HOME_DONE
	flag_op.type = "bool"
	flag_op.operation = "set"
	flag_op.value = true

	var info_op = InfoDemoOperator.new()
	info_op.info = "你急疯了，在泥水里跌跌撞撞。那阵哭声变得极其微弱，几乎要被风声盖过。"

	var cr = ChoiceResult.new()
	cr.operators.append(pop_op)
	cr.operators.append(flag_op)
	cr.operators.append(info_op)
	opt.choice_result = cr

	event.options.append(opt)

	var path = SAVE_DIR + "fengxian_old_home_corpse.tres"
	_save(event, path)


# ─── 事件 1: 奉先村村头（入口） ───
func _create_event_1() -> void:
	var event = BaseEvent.new()
	event.uuid = EVENT1_KEY
	event.name = "奉先村村头"
	event.description = "你站在奉先村的村口，风从骊山方向灌过来，把衣摆吹得猎猎作响。十年前的记忆在脑子里乱撞，每条巷子都像，又都不像。村口的老槐树还在，但树下的石凳上坐着陌生的人。"

	# ─── 选项 1: 沿熟悉路径找家 [ONCE] → Push E2 ───
	var opt1 = EventOption.new()
	opt1.uuid = "opt_go_familiar_path"
	opt1.description = "沿着记忆中的小径，去找十年前住过的那间屋"
	# Once requirement: flag_bool_not_has
	opt1.requirement = _make_bool_not_has_req(FLAG_ONCE_E1_OPT1)
	# Operators: Push + Set Flag
	var cr1 = ChoiceResult.new()
	cr1.operators.append(_make_push_op("fengxian_familiar_path"))
	cr1.operators.append(_make_flag_set_op(FLAG_ONCE_E1_OPT1))
	opt1.choice_result = cr1
	event.options.append(opt1)

	# ─── 选项 2: 折返问里正 [ONCE] → Push E3 ───
	var opt2 = EventOption.new()
	opt2.uuid = "opt_ask_lizheng"
	opt2.description = "回头去找村口的里正，他应该知道这些年发生了什么"
	opt2.requirement = _make_bool_not_has_req(FLAG_ONCE_E1_OPT2)
	var cr2 = ChoiceResult.new()
	cr2.operators.append(_make_push_op("fengxian_ask_lizheng"))
	cr2.operators.append(_make_flag_set_op(FLAG_ONCE_E1_OPT2))
	opt2.choice_result = cr2
	event.options.append(opt2)

	# ─── 选项 3: 直接找旧家 [ONCE + REQUIRE: E2已完成 flag_bool_has] → Push E4 ───
	var opt3 = EventOption.new()
	opt3.uuid = "opt_find_old_home"
	opt3.description = "不去问人，直接凭着直觉去找那间漏雨的老屋"
	# ComplexRequirements: AND(Once + E2 done)
	var multi_req = ComplexRequirements.new()
	multi_req.current_operator = 0  # LOGIC.AND
	multi_req.operators.append(_make_bool_not_has_req(FLAG_ONCE_E1_OPT3))
	multi_req.operators.append(_make_bool_has_req(FLAG_FAMILIAR_PATH_DONE, "你不知道家在哪里"))
	opt3.requirement = multi_req

	var cr3 = ChoiceResult.new()
	cr3.operators.append(_make_push_op("fengxian_old_home_corpse"))
	cr3.operators.append(_make_flag_set_op(FLAG_ONCE_E1_OPT3))
	opt3.choice_result = cr3
	event.options.append(opt3)

	var path = SAVE_DIR + "fengxian_village_entrance.tres"
	_save(event, path)


# ─── 事件 5: 重回村头（锁死选项 1-3，新增选项 4） ───
func _create_event_5() -> void:
	var event = BaseEvent.new()
	event.uuid = "fengxian_village_entrance_revisit"
	event.name = "奉先村村头"
	event.description = "你又站在了村口。风还是从骊山方向来，但现在你知道有些东西已经不一样了。里正死了，那片你住过的区域已经换了模样——他们似乎搬迁到了你不熟悉的地方。你不常回来，也没钱，这些年村子对你来说，已经成了一个陌生的地方。"

	var locked_hint = "你知道那里不对，里正死了，他们似乎搬迁到了你不熟悉的地方"

	# ─── 选项 1: 锁死 ───
	var opt1 = EventOption.new()
	opt1.uuid = "opt_go_familiar_path_locked"
	opt1.description = "沿着记忆中的小径，去找十年前住过的那间屋"
	opt1.requirement = _make_never_unlock_req(locked_hint)
	event.options.append(opt1)

	# ─── 选项 2: 锁死 ───
	var opt2 = EventOption.new()
	opt2.uuid = "opt_ask_lizheng_locked"
	opt2.description = "回头去找村口的里正，他应该知道这些年发生了什么"
	opt2.requirement = _make_never_unlock_req(locked_hint)
	event.options.append(opt2)

	# ─── 选项 3: 锁死 ───
	var opt3 = EventOption.new()
	opt3.uuid = "opt_find_old_home_locked"
	opt3.description = "不去问人，直接凭着直觉去找那间漏雨的老屋"
	opt3.requirement = _make_never_unlock_req(locked_hint)
	event.options.append(opt3)

	# ─── 选项 4: 向小木屋走去（新选项，你后续手动链接） ───
	var opt4 = EventOption.new()
	opt4.uuid = "opt_walk_to_cabin"
	opt4.description = "向小木屋走去"
	# 空 choice_result，你后续手动注入 PushEventOperator
	event.options.append(opt4)

	var path = SAVE_DIR + "fengxian_village_entrance_revisit.tres"
	_save(event, path)


# ═══════════════════════════════════════════════════════
# 便捷工厂方法
# ═══════════════════════════════════════════════════════

# flag_bool_not_has: COMPARE.LESS_THAN (0) value=true → flag value < true = flag not set
func _make_bool_not_has_req(flag_id: String) -> FlagRequirement:
	var req = FlagRequirement.new()
	req.flag_id = flag_id
	req.type = "bool"
	req.operator = 0  # COMPARE.LESS_THAN
	req.value = true
	return req


# flag_bool_has: COMPARE.GREATER_THAN (1) value=false → flag value > false = flag is true
func _make_bool_has_req(flag_id: String, failed_hint: String = "") -> FlagRequirement:
	var req = FlagRequirement.new()
	req.flag_id = flag_id
	req.type = "bool"
	req.operator = 1  # COMPARE.GREATER_THAN
	req.value = false
	if not failed_hint.is_empty():
		req.failed_hint = failed_hint
	return req


# flag_bool_has(name=__never_unlock): COMPARE.GREATER_THAN (1) value=false
func _make_never_unlock_req(failed_hint: String) -> FlagRequirement:
	var req = FlagRequirement.new()
	req.flag_id = "__never_unlock"
	req.type = "bool"
	req.operator = 1  # COMPARE.GREATER_THAN
	req.value = false
	req.failed_hint = failed_hint
	return req


func _make_push_op(event_key: String) -> PushEventOperator:
	var op = PushEventOperator.new()
	op.event_key = event_key
	return op


func _make_flag_set_op(flag_id: String) -> FlagOperator:
	var op = FlagOperator.new()
	op.flag_id = flag_id
	op.type = "bool"
	op.operation = "set"
	op.value = true
	return op


func _save(resource: Resource, path: String) -> void:
	var result = ResourceSaver.save(resource, path)
	if result == OK:
		print("[FengxianCreator] ✓ 已保存: %s" % path)
	else:
		print("[FengxianCreator] ✗ 保存失败 (code=%d): %s" % [result, path])
