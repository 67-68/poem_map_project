class_name SurvivalManager extends Node
# 专门管理玩家的生活费丧失
# 计划扫描当前trait获取需要扣除什么
# 计划有一个月和一个旬的扣除费用
# 但太复杂了先不做，目前只有旬的扣除费用，trait 扫描扣除也没做

const _ModifierFormula = preload("res://core/modifier_formula.gd")
const _NamedDSLParser = preload("res://parser/named_dsl_parser.gd")

const HEARTBEAT_HEALTH_THRESHOLD: int = 20

# ─── 每旬自然衰减配置 ────────────────────────────────────────
## 势 (momentum) 每旬基础衰减量（正值表示扣减）
const MOMENTUM_DECAY_PER_XUN: int = 5

# ─── 健康→AP 阶梯配置（唯一真相源） ──────────────────────────
# 按 health_max 升序排列，遍历顺序从最严重到最轻微。
# 外部消费方（action_hint_builder / time_control_panel）通过静态查询接口获取数据，
# 严禁各自硬编码 trait 名或数值。
const HEALTH_AP_TIERS: Array[Dictionary] = [
	{
		health_max = 30,       # ≤30
		ap_cap = 5,
		trait_enum = ENUMS.TRAITS.TERMINAL_ILLNESS,
		hint_text = "每旬仅 5 天可用（病入膏肓）",
		hint_color = "#cc6666",
	},
	{
		health_max = 60,       # ≤60
		ap_cap = 8,
		trait_enum = ENUMS.TRAITS.EXHAUSTION_INITIAL,
		hint_text = "每旬仅 8 天可用（疲态初显）",
		hint_color = "#ccaa66",
	},
]
const DEFAULT_AP_CAP: int = 10

# ─── Imaginary 生命周期常量 ──────────────────────────────────
## 所有等级意象统一保持 2 旬（20 天），已通过 Trait.duration_xun 数据驱动
const IMAGINARY_DURATION_XUN: int = 2

func get_prop(data): return PlayerState.get_stat_val(data)
func append_prop(data,val):PlayerState.append_stat(data,val)
func set_prop(data,val):PlayerState.set_stat_val(data,val)
func force_set_prop(data,val):PlayerState.force_set_stat_val(data,val)

# ─── 属性配置访问 ────────────────────────────────────
func _get_prop_config(prop_enum) -> Property:
	var key = ENUMS.to_prop_str(prop_enum)
	return Database.get_property(key) as Property

func _get_soft_max(prop_enum) -> int:
	var prop = _get_prop_config(prop_enum)
	if prop and prop.soft_max >= 0:
		return prop.soft_max
	# 兜底：默认 100（兼容无 soft_max 的老属性）
	return 100

func _get_decay_threshold(prop_enum) -> int:
	var prop = _get_prop_config(prop_enum)
	if prop and prop.decay_threshold >= 0:
		return prop.decay_threshold
	# 兜底：默认 25
	return 25

func _cost_survival():
	# 🆕 Tutorial 期间跳过每旬扣钱，仅刷新 AP
	#breakpoint
	if TutorialController.is_tutorial_active():
		Logging.info('[SurvivalManager] _cost_survival: tutorial 模式 跳过扣钱')
		return

	var money_ok: bool = PlayerState.append_stat(ENUMS.PROPS.MONEY, -5)
	if not money_ok:
		Logging.err('[SurvivalManager] _cost_survival: append_stat MONEY failed')
	var cap: int = get_current_ap_cap()
	Logging.info('[SurvivalManager] _cost_survival: refreshing _time to %d' % cap)
	var ok: bool = PlayerState.set_stat_val("_time", cap)
	if not ok:
		Logging.err('[SurvivalManager] _cost_survival: set_stat_val("_time", %d) failed' % cap)

# ─── 健康→AP 查询接口（静态，供外部消费方调用） ──────────────

## 返回当前健康对应的 AP 上限（含 Imaginary + 疾病惩罚）
static func get_current_ap_cap() -> int:
	var health: int = int(PlayerState.get_stat_val(ENUMS.PROPS.HEALTH))
	var base_ap: int = DEFAULT_AP_CAP
	for tier in HEALTH_AP_TIERS:
		if health <= tier.health_max:
			base_ap = tier.ap_cap
			Logging.info('[SurvivalManager] get_current_ap_cap: health=%d ≤ %d → ap_cap=%d' % [health, tier.health_max, tier.ap_cap])
			break
		else:
			Logging.info('[SurvivalManager] get_current_ap_cap: health=%d → default=%d' % [health, DEFAULT_AP_CAP])
	
	# 🆕 Lv3 Imaginary 持有期惩罚：每持有 1 个 Lv3 意象，AP 上限 -1
	var lv3_count := _count_active_lv3_imaginaries()
	base_ap -= lv3_count
	if lv3_count > 0:
		Logging.info('[SurvivalManager] get_current_ap_cap: %d 个 Lv3 Imaginary → AP %d' % [lv3_count, base_ap])
	
	# 🆕 trait.ap_penalty 聚合：遍历所有活跃 trait 的 ap_penalty 并扣除
	var ap_penalty_total := 0
	for t_name in PlayerState.traits:
		var t_data = Database.get_trait(t_name)
		if t_data and t_data.ap_penalty != 0:
			ap_penalty_total += t_data.ap_penalty
			Logging.info('[SurvivalManager] get_current_ap_cap: trait "%s" ap_penalty=%d → 累计=%d' % [t_name, t_data.ap_penalty, ap_penalty_total])
	if ap_penalty_total != 0:
		base_ap += ap_penalty_total  # ap_penalty 为负数，直接加 = 扣除
		Logging.info('[SurvivalManager] get_current_ap_cap: 总 ap_penalty=%d → AP=%d' % [ap_penalty_total, base_ap])
	
	#breakpoint
	if TutorialController.is_tutorial_active():
		base_ap = 2
	else:
		base_ap = 10

	
	# 底限钳制：AP 不能降到 1 以下
	var final_ap := maxi(base_ap, 1)
	Logging.info('[SurvivalManager] get_current_ap_cap: 最终 AP = %d' % final_ap)
	return final_ap

## 🆕 统计当前持有中且尚未过期的 Lv3 Imaginary 数量
## 使用 Trait 基类的 lasting_xun/duration_xun 判定是否过期
static func _count_active_lv3_imaginaries() -> int:
	var count := 0
	for uuid in Database.imaginaries_detail:
		var imag = Database.imaginaries_detail[uuid]
		if imag is Imaginary and imag.level == 3:
			if imag.lasting_xun < imag.duration_xun or imag.duration_xun <= 0:
				count += 1
			Logging.info('[SurvivalManager] _count_active_lv3_imaginaries: Imaginary "%s" level=3, lasting_xun=%d, duration_xun=%d → %s' % [uuid, imag.lasting_xun, imag.duration_xun, "活跃" if imag.lasting_xun < imag.duration_xun else "已过期"])
	Logging.info('[SurvivalManager] _count_active_lv3_imaginaries: 当前 %d 个活跃 Lv3 Imaginary' % count)
	return count

## 返回当前激活的 AP 削减提示文本，无削减时返回 ""
static func get_active_ap_hint() -> String:
	var health: int = int(PlayerState.get_stat_val(ENUMS.PROPS.HEALTH))
	for tier in HEALTH_AP_TIERS:
		if health <= tier.health_max:
			return tier.hint_text
	return ""

## 返回当前激活的 AP 削减提示颜色，无削减时返回 ""
static func get_active_ap_hint_color() -> String:
	var health: int = int(PlayerState.get_stat_val(ENUMS.PROPS.HEALTH))
	for tier in HEALTH_AP_TIERS:
		if health <= tier.health_max:
			return tier.hint_color
	return ""

# ─── 健康→Trait 同步 ────────────────────────────────────────

## 根据当前健康值自动增减 HEALTH_AP_TIERS 中配置的 trait。
## 必须在 aggregate_trait_effect() 之后、_cost_survival() 之前调用，
## 确保 trait 持续效果（如中毒扣血）已生效后再判定 AP 等级。
func _sync_health_ap_traits():
	var health: int = int(PlayerState.get_stat_val(ENUMS.PROPS.HEALTH))
	Logging.info('[SurvivalManager] _sync_health_ap_traits: health=%d' % health)
	
	var matched_trait: String = ""
	for tier in HEALTH_AP_TIERS:
		var trait_str := ENUMS.to_traits_str(tier.trait_enum)
		if health <= tier.health_max:
			matched_trait = trait_str
			if not PlayerState.has_trait(trait_str):
				PlayerState.add_trait(trait_str)
				Logging.info('[SurvivalManager] _sync_health_ap_traits: health=%d ≤ %d → add_trait(%s)' % [health, tier.health_max, trait_str])
			else:
				Logging.info('[SurvivalManager] _sync_health_ap_traits: health=%d ≤ %d → trait(%s) already present' % [health, tier.health_max, trait_str])
			break
	
	# 移除所有未匹配的 HEALTH_AP_TIERS trait
	for tier in HEALTH_AP_TIERS:
		var trait_str := ENUMS.to_traits_str(tier.trait_enum)
		if trait_str != matched_trait and PlayerState.has_trait(trait_str):
			PlayerState.remove_trait(trait_str)
			Logging.info('[SurvivalManager] _sync_health_ap_traits: health=%d, no longer match → remove_trait(%s)' % [health, trait_str])

func decay(prop_enum, threshold, decay_val):
	var current_val = get_prop(prop_enum)
	# 如果当前值高于阈值，扣除固定的衰减量；否则直接清零
	if current_val > threshold: 
		append_prop(prop_enum, -decay_val)
	else:
		append_prop(prop_enum, -current_val)

## 🆕 统一到期逻辑：所有 trait 走 duration_xun + expiry_trait。
## 替代原 TEMP_DEBUFFS / SEVERE_INJURY_DURATION_XUN / Disease.progression 三套硬编码。
func aggregate_trait_effect():
	for t in PlayerState.get_traits():
		var trait_ = Database.get_trait(t)
		if not trait_:
			Logging.warn('为什么player state中存在的trait在database没有？？')
			continue
		trait_.lasting_xun += 1
		trait_.operate_continuous_effect()
		
		# 🆕 统一到期逻辑：duration_xun > 0 时自动移除/替换
		if trait_.duration_xun > 0 and trait_.lasting_xun >= trait_.duration_xun:
			Logging.info('[SurvivalManager] Trait expired: %s (lasting_xun=%d, duration_xun=%d)' % [t, trait_.lasting_xun, trait_.duration_xun])
			PlayerState.remove_trait(t)
			if not trait_.expiry_trait.is_empty():
				Logging.info('[SurvivalManager] Trait %s → 替换为 %s' % [t, trait_.expiry_trait])
				PlayerState.add_trait(trait_.expiry_trait)

# ─── Imaginary 生命周期结算 ──────────────────────────────────
## 在 aggregate_trait_effect() 之后、_sync_health_ap_traits() 之前执行。
## V9: Imaginary extends Trait，统一使用 lasting_xun/duration_xun。
## Lv2 扣血走 trait_effect_operations（operate_continuous_effect）。
## 到期统一删除，不再转化 trait（expiry_trait 字段已删除）。
func _process_imaginary_effects() -> void:
	var to_delete: Array[String] = []  # 到期需要删除的 Imaginary UUID
	var has_changed := false
	
	Logging.info('[SurvivalManager] _process_imaginary_effects: 开始扫描 %d 个 Imaginary' % Database.imaginaries_detail.size())
	
	for uuid in Database.imaginaries_detail:
		var imag = Database.imaginaries_detail[uuid]
		if not imag is Imaginary:
			continue
		
		# 递增已持续旬数
		imag.lasting_xun += 1
		Logging.info('[SurvivalManager] _process_imaginary_effects: Imaginary "%s" (Lv%d) lasting_xun=%d, duration_xun=%d' % [uuid, imag.level, imag.lasting_xun, imag.duration_xun])
		
		# Lv2 持有期扣血：走 trait_effect_operations（operate_continuous_effect 继承自 Trait）
		if imag.level == 2:
			imag.operate_continuous_effect()
			has_changed = true
			Logging.info('[SurvivalManager] _process_imaginary_effects: Lv2 Imaginary "%s" → operate_continuous_effect() 执行' % uuid)
		
		# Lv1/Lv3: operate_continuous_effect 为空（无 trait_effect_operations），无副作用
		
		# 🆕 统一到期：lasting_xun >= duration_xun → 直接删除
		if imag.duration_xun > 0 and imag.lasting_xun >= imag.duration_xun:
			Logging.info('[SurvivalManager] _process_imaginary_effects: Imaginary "%s" (Lv%d) 到期（lasting_xun=%d >= duration_xun=%d），删除' % [uuid, imag.level, imag.lasting_xun, imag.duration_xun])
			to_delete.append(uuid)
			has_changed = true
	
	# ── 清理到期的 Imaginary ──
	for del_uuid in to_delete:
		Database.imaginaries_detail.erase(del_uuid)
		Logging.info('[SurvivalManager] _process_imaginary_effects: 已删除 Imaginary "%s"' % del_uuid)
	
	if has_changed:
		EventBus.imaginary_changed.emit()
		Logging.info('[SurvivalManager] _process_imaginary_effects: 结算完成，删除了 %d 个 Imaginary' % to_delete.size())
	else:
		Logging.info('[SurvivalManager] _process_imaginary_effects: 无变化')


func operate_state_transistors():
	for s in Database.get_state_transistors_all():
		var trans = Database.get_state_transistors_all()[s]
		trans.transition()
	
	var prog = PlayerState.get_stat_val(ENUMS.PROPS.PROGRESS)
	if prog >= 100:
		if KuangdaState.current() == "fengying": EventBus.request_event_key.emit("kuangda_2_to_3")
		else: EventBus.request_event_key.emit("kuangda_1_to_2")
	elif prog <= 0:
		if KuangdaState.current() == "kuangke": EventBus.request_event_key.emit("kuangda_3_to_2")
		else: EventBus.request_event_key.emit("kuangda_2_to_1")

# 核心结算管线（上帝视角的暴政：顺序绝对不可更改！）
func _process_single_xun_settlement():
	#breakpoint
	
	# 🆕 批量模式包裹：旬结算期间金钱/时间/健康可能变化多次，
	# ActionManager._on_player_stat_changed 会触发 reevaluate_all_locks，
	# 导致 UI 在结算中期被反复刷新。begin_action_batch 抑制中间刷新，
	# 结算完成后统一执行一次 reevaluate。
	ActionManager.begin_action_batch()
	
	# 第一阶段：跨状态感染 (Cross-Pollination)
	# 在任何增减发生之前，先让状态之间互相发生化学反应。
	# 状态自身存在的持续负面衍生
	# 让属性自己不变，影响其他属性和operator之类的
	aggregate_trait_effect()
	
	# 1.3: Imaginary 生命周期结算（Lv2 每旬扣血 via operate_continuous_effect + 到期删除）
	# 必须在 aggregate 之后、_sync_health_ap_traits 之前（Lv2 扣血后健康可能变化）
	_process_imaginary_effects()
	
	# 1.5: 健康→AP 阶梯同步（必须在 aggregate 之后，确保 trait 持续效果已生效）
	_sync_health_ap_traits()
	
	# 🆕 1.7: 每旬基础兴获取（+3, soft_max=50 溢出减半）
	# 在 NPC 加成之前执行：叙事顺序「自身灵感微发 → 友人激发助兴 → 生存消耗」
	_apply_xun_base_inspiration()
	
	# 🆕 1.8: NPC inner_circle 每旬属性加成
	# 必须在 health sync 之后（健康不影响 NPC 加成）、cost 之前（加成先于扣除）。
	_apply_npc_inner_circle_bonus()
	
	# 🆕 1.9: 理念每旬被动增长（per_xun_passive）
	# 在 NPC 加成之后、生存扣除之前执行：先给甜头再扒皮。
	_apply_idea_per_xun_passives()
	
	# 第二阶段：生存基础扣除 (Upkeep & Economy)
	# 外部环境对玩家的无情压迫。
	_cost_survival()
	
	# 3.5: 濒危警告音效
	_update_heartbeat_sfx()
	death_judgement()
	
	# 第四阶段：衰减与重置 (Decay, Reset & GC)
	# 打完巴掌给个甜枣，系统内存回收。
	# 属性 90 -> 50
	#breakpoint

	# 🆕 4.0: 属性自然衰减（势每旬-5，城府 dampen 减免）
	_apply_prop_decay()

	operate_state_transistors()
	
	# 4.5: Lock/Block 到期清理
	ActionManager.process_xun_tick()
	
	# 🆕 结算完毕，统一执行一次锁定重评估，解除批量模式
	ActionManager.end_action_batch()
	
	# 5. 通知 UI 刷新
	EventBus.emit_signal("xun_settlement_completed")
	
	# 6. 延期扣除生活费（快照之后执行，确保计入下月 delta）
	# ⚠️ 这个 deferred 调用在批量模式结束后才执行，会独立触发一次 reevaluate
	call_deferred("_post_xun_money_deduct")

func _update_heartbeat_sfx() -> void:
	"""根据健康值启动/停止心跳循环音效。"""
	var health: int = PlayerState.get_stat_val(ENUMS.PROPS.HEALTH) as int
	if health <= HEARTBEAT_HEALTH_THRESHOLD and health > 0:
		if not AudioManager.is_sfx_loop_playing():
			AudioManager.play_sfx_loop("heartbeat", 0.05)
	else:
		if AudioManager.is_sfx_loop_playing():
			AudioManager.stop_sfx_loop()


func death_judgement():
	"""
	三层濒死兜底系统：
	- flag_near_death_count < 3：自增计数器 + 强制续命 HEALTH=1
	- flag_near_death_count >= 3：走死亡结算流程
	"""
	if PlayerState.get_stat_val(ENUMS.PROPS.HEALTH) <= 0:
		if GameState.current_era == "755_backhome":
			var count = PlayerState.get_flag("flag_near_death_count")
			breakpoint
			if count < 3:
				breakpoint
				PlayerState.append_flag("flag_near_death_count", 1)
				force_set_prop(ENUMS.PROPS.HEALTH, 1)
				Logging.info('[SurvivalManager] Near-death count=%d, force_set health=1' % (count + 1))
			else:
				# 第三次濒死兜底已耗尽，走向真正的死亡
				AudioManager.stop_sfx_loop()
				PlayerState.current_action_tags.append('actor:health:death:general')
				EventManager.scan_death_events()
		else:
			AudioManager.stop_sfx_loop()
			PlayerState.current_action_tags.append('actor:health:death:general')
			EventManager.scan_death_events()

# ─── 🆕 NPC inner_circle 每旬属性加成 ────────────────────────────
## 遍历所有 person_state == "inner_circle" 的 NPC，累加他们的
## shi/xing/wang 的 upper_limit 和 addition。
##
## 算法（方案A）：
##   1. 累加所有 inner_circle NPC 的 upper_limit → cumulative_upper
##   2. 累加所有 inner_circle NPC 的 addition   → cumulative_add
##   3. stat += cumulative_add
##   4. IF stat > cumulative_upper:
##        overflow = stat - cumulative_upper
##        stat = cumulative_upper + overflow * 0.5
##
## addition / upper_limit 字段存 named_amount key（如 "m_momentum_gain"），
## 通过 NamedDSLParser._load_named_amounts() 解析为整数值。
func _apply_npc_inner_circle_bonus() -> void:
	var amounts: Dictionary = _NamedDSLParser._load_named_amounts()
	
	# 属性元组：[属性枚举, 字段前缀, 属性显示名]
	var prop_configs := [
		[ENUMS.PROPS.MOMENTUM,    "shi", "势"],
		[ENUMS.PROPS.INSPIRATION, "xing", "兴"],
		[ENUMS.PROPS.PRESTIGE,    "wang", "望"],
	]
	
	# 收集所有 inner_circle NPC
	var all_docs: Dictionary = Database.get_npc_document_all()
	var inner_npcs: Array[NPCDocument] = []
	var npc_names: Array[String] = []
	for uuid in all_docs:
		var doc: NPCDocument = all_docs[uuid] as NPCDocument
		if doc and doc.person_state == "inner_circle":
			inner_npcs.append(doc)
			npc_names.append(doc.name if not doc.name.is_empty() else doc.uuid)
	
	if inner_npcs.is_empty():
		Logging.info("[SurvivalManager] _apply_npc_inner_circle_bonus: 无 inner_circle NPC，跳过")
		return
	
	Logging.info("[SurvivalManager] _apply_npc_inner_circle_bonus: 检测到 %d 个 inner_circle NPC: %s" % [inner_npcs.size(), ", ".join(npc_names)])
	
	for cfg in prop_configs:
		var prop_enum: int = cfg[0]
		var prefix: String = cfg[1]
		var cn_name: String = cfg[2]
		
		var cumulative_upper: int = 0
		var cumulative_add: int = 0
		
		for doc in inner_npcs:
			# 读取 upper_limit / addition 的 named_amount key
			# NPCDocument 的 @export 字段始终存在，默认 ""
			var upper_key_field := prefix + "_upper_limit"
			var add_key_field := prefix + "_addition"
			var upper_key: String = doc.get(upper_key_field)
			var add_key: String = doc.get(add_key_field)
			
			if not upper_key.is_empty():
				var val: int = amounts.get(upper_key, 0)
				cumulative_upper += val
				Logging.info('[SurvivalManager]   NPC "%s" %s_upper_limit="%s"→%d' % [doc.name if not doc.name.is_empty() else doc.uuid, prefix, upper_key, val])
			if not add_key.is_empty():
				var val: int = amounts.get(add_key, 0)
				cumulative_add += val
				Logging.info('[SurvivalManager]   NPC "%s" %s_addition="%s"→%d' % [doc.name if not doc.name.is_empty() else doc.uuid, prefix, add_key, val])
		
		# 无加成 → 跳过
		if cumulative_add == 0:
			Logging.info("[SurvivalManager]   %s: 无加成，跳过" % cn_name)
			continue
		
		# 获取当前值
		var prop_str: String = ENUMS.to_prop_str(prop_enum)
		var current_val: int = PlayerState.get_stat_val(prop_enum)
		Logging.info("[SurvivalManager]   %s(%s): current=%d, cumulative_add=%d, cumulative_upper=%d" % [cn_name, prop_str, current_val, cumulative_add, cumulative_upper])
		
		# 累加
		var new_val: int = current_val + cumulative_add
		
		# 动态上限：如果 upper_limit > 0 且超出，溢出减半
		if cumulative_upper > 0 and new_val > cumulative_upper:
			var overflow: int = new_val - cumulative_upper
			var half_overflow: int = overflow / 2
			new_val = cumulative_upper + half_overflow
			Logging.info("[SurvivalManager]   %s: 超出上限 %d (溢出 %d)，减半 → %d" % [cn_name, cumulative_upper, overflow, new_val])
		
		# 应用值（使用 set_stat_val 直接设值，不走 tier multiplier / fatigue）
		PlayerState.set_stat_val(prop_enum, new_val)
		Logging.info("[SurvivalManager]   %s: 设定为 %d" % [cn_name, new_val])
	
	Logging.info("[SurvivalManager] _apply_npc_inner_circle_bonus: 加成完成")


# ─── 🆕 理念每旬被动增长 ──────────────────────────────────────────
## 查询 ModifierRegistry 中的 per_xun_passive 条目，对指定属性执行
## 每旬增量。使用 set_stat_val 直接设值（跳过 append_stat 的倍率修正）。
func _apply_idea_per_xun_passives() -> void:
	var passives: Array[Dictionary] = ModifierRegistry.get_per_xun_passives()
	if passives.is_empty():
		Logging.debug("[SurvivalManager] _apply_idea_per_xun_passives: 无每旬被动，跳过")
		return

	Logging.info("[SurvivalManager] _apply_idea_per_xun_passives: 共 %d 条每旬被动" % passives.size())
	for p in passives:
		var prop_str: String = p.get("prop", "")
		var delta: int = p.get("delta", 0)
		if prop_str.is_empty() or delta == 0:
			continue

		var current_val: int = PlayerState.get_stat_val(prop_str)
		var new_val: int = current_val + delta
		PlayerState.set_stat_val(prop_str, new_val)
		Logging.info("[SurvivalManager]   per_xun_passive: %s %+d (当前=%d, 新值=%d)" % [prop_str, delta, current_val, new_val])

	Logging.info("[SurvivalManager] _apply_idea_per_xun_passives: 完成")


# ─── 🆕 每旬基础兴获取 ─────────────────────────────────────────────
## 每旬 +3 inspiration（s_xing_gain）。
## 无硬上限（hard_max = -1），采用 soft_max=50 溢出减半模型（与 望 对齐）。
## 先从 Database 读取 Property 模板获取 soft_max，使用 append_stat 修正，
## 若超过 soft_max 则溢出部分减半。
func _apply_xun_base_inspiration() -> void:
	var BASE_XING_GAIN: int = 3
	Logging.info("[SurvivalManager] _apply_xun_base_inspiration: 基础兴 +%d" % BASE_XING_GAIN)
	
	var current: int = PlayerState.get_stat_val(ENUMS.PROPS.INSPIRATION)
	var prop_template = Database.get_property("inspiration")
	var soft_max: int = -1
	if prop_template and prop_template.soft_max >= 0:
		soft_max = prop_template.soft_max
		Logging.info("[SurvivalManager]   inspiration soft_max=%d, current=%d" % [soft_max, current])
	
	var new_val: int = current + BASE_XING_GAIN
	
	# soft_max 溢出减半
	if soft_max >= 0 and new_val > soft_max:
		var overflow: int = new_val - soft_max
		var half_overflow: int = overflow / 2
		new_val = soft_max + half_overflow
		Logging.info("[SurvivalManager]   inspiration 超出 soft_max %d (溢出 %d)，减半 → %d" % [soft_max, overflow, new_val])
	
	# 直接 set_stat_val（跳过 append_stat 的 trait buffer / modifier 修正，避免二次叠加）
	PlayerState.set_stat_val(ENUMS.PROPS.INSPIRATION, new_val)
	Logging.info("[SurvivalManager]   inspiration 设定为 %d" % new_val)


# ─── 🆕 属性自然衰减（每旬结算时执行） ────────────────────────────
## 势 (momentum) 每旬衰减 MOMENTUM_DECAY_PER_XUN。
## 城府 (astuteness) 越高，衰减越小（走 append_stat → ModifierFormula dampen）。
func _apply_prop_decay() -> void:
	var current_momentum: int = PlayerState.get_stat_val(ENUMS.PROPS.MOMENTUM)
	if current_momentum <= 0:
		Logging.info("[SurvivalManager] _apply_prop_decay: momentum=0，跳过衰减")
		return

	Logging.info("[SurvivalManager] _apply_prop_decay: momentum=%d → 衰减 %d (经 append_stat 中的城府 dampen 修正)" % [current_momentum, MOMENTUM_DECAY_PER_XUN])
	PlayerState.append_stat(ENUMS.PROPS.MOMENTUM, -MOMENTUM_DECAY_PER_XUN)
	Logging.info("[SurvivalManager] _apply_prop_decay: 衰减后 momentum=%d" % PlayerState.get_stat_val(ENUMS.PROPS.MOMENTUM))


func _post_xun_money_deduct():
	# 🆕 Tutorial 期间跳过
	if TutorialController.is_tutorial_active():
		Logging.info('[SurvivalManager] _post_xun_money_deduct: tutorial 模式，跳过扣钱')
		return
	PlayerState.append_stat(ENUMS.PROPS.MONEY, -30)
	Logging.info('[SurvivalManager] 旬末扣除 30 money（快照之后执行，计入下月 delta）')
	if PlayerState.get_stat_val(ENUMS.PROPS.MONEY) <= 0:
		Logging.info('[SurvivalManager] 旬末结算后 money<0，触发流落街头事件')
		OperatorFactory.create_event_operator('event_money_lower_0_innkeeper').operate()

func _ready():
	TimeService.on_xun_tick.connect(_process_single_xun_settlement)
	# 实时监听健康变化，立即同步 AP trait 并判定死亡（不等下一旬）
	PlayerState.player_stat_changed.connect(func(prop_name: String):
		if prop_name == ENUMS.to_prop_str(ENUMS.PROPS.HEALTH):
			var health: int = int(PlayerState.get_stat_val(ENUMS.PROPS.HEALTH))
			Logging.info('[SurvivalManager] health changed to %d, immediate sync + death check' % health)
			_sync_health_ap_traits()
			death_judgement()
	)
