class_name SurvivalManager extends Node
# 专门管理玩家的生活费丧失
# 计划扫描当前trait获取需要扣除什么
# 计划有一个月和一个旬的扣除费用
# 但太复杂了先不做，目前只有旬的扣除费用，trait 扫描扣除也没做

const HEARTBEAT_HEALTH_THRESHOLD: int = 20

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
		health_max = 59,       # ≤59（即 <60）
		ap_cap = 8,
		trait_enum = ENUMS.TRAITS.EXHAUSTION_INITIAL,
		hint_text = "每旬仅 8 天可用（疲态初显）",
		hint_color = "#ccaa66",
	},
]
const DEFAULT_AP_CAP: int = 10

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
	#breakpoint
	if PlayerState.has_trait(ENUMS.TRAITS.WANDERING_WITHOUT_LIVING_PLACE):
		PlayerState.append_stat(ENUMS.PROPS.MONEY, -2)
		if PlayerState.get_stat_val(ENUMS.PROPS.MONEY) < 0:
			OperatorFactory.create_event_operator('event_money_lower_0_wandering').operate()
		var cap: int = get_current_ap_cap()
		Logging.info('[SurvivalManager] _cost_survival: wandering, refreshing _time to %d' % cap)
		var ok: bool = PlayerState.set_stat_val("_time", cap)
		if not ok:
			Logging.err('[SurvivalManager] _cost_survival: set_stat_val("_time", %d) failed (wandering)' % cap)
		return
	var money_ok: bool = PlayerState.append_stat(ENUMS.PROPS.MONEY, -5)
	if not money_ok:
		Logging.err('[SurvivalManager] _cost_survival: append_stat MONEY failed')
	if PlayerState.get_stat_val(ENUMS.PROPS.MONEY) < 0:
		OperatorFactory.create_event_operator('event_money_lower_0').operate()
	var cap: int = get_current_ap_cap()
	Logging.info('[SurvivalManager] _cost_survival: refreshing _time to %d' % cap)
	var ok: bool = PlayerState.set_stat_val("_time", cap)
	if not ok:
		Logging.err('[SurvivalManager] _cost_survival: set_stat_val("_time", %d) failed' % cap)

# ─── 健康→AP 查询接口（静态，供外部消费方调用） ──────────────

## 返回当前健康对应的 AP 上限
static func get_current_ap_cap() -> int:
	var health: int = int(PlayerState.get_stat_val(ENUMS.PROPS.HEALTH))
	for tier in HEALTH_AP_TIERS:
		if health <= tier.health_max:
			Logging.info('[SurvivalManager] get_current_ap_cap: health=%d ≤ %d → ap_cap=%d' % [health, tier.health_max, tier.ap_cap])
			return tier.ap_cap
	Logging.info('[SurvivalManager] get_current_ap_cap: health=%d → default=%d' % [health, DEFAULT_AP_CAP])
	return DEFAULT_AP_CAP

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

const TEMP_DEBUFF_DURATION_XUN: int = 2
const TEMP_DEBUFFS: Array[String] = ["poisoned", "sprained_ankle"]

func aggregate_trait_effect():
	for t in PlayerState.get_traits():
		var trait_ = Database.get_trait(t)
		if not trait_:
			Logging.warn('为什么player state中存在的triat在database没有？？')
			continue
		trait_.lasting_xun += 1
		trait_.operate_continuous_effect()
		
		# 疾病进展检查：如果 trait 是 Disease 且有 progression_target
		if trait_ is Disease and not trait_.progression_target.is_empty():
			if trait_.lasting_xun >= trait_.progression_xun:
				Logging.info('[SurvivalManager] Disease progression: ' + t + ' → ' + trait_.progression_target)
				PlayerState.remove_trait(t)
				PlayerState.add_trait(trait_.progression_target)
		
		# 临时 debuff 2 旬到期自动移除（硬编码阶段，未来抽象为 Trait max_duration 钩子）
		if t in TEMP_DEBUFFS and trait_.lasting_xun >= TEMP_DEBUFF_DURATION_XUN:
			Logging.info('[SurvivalManager] Temp debuff expired: %s (lasting_xun=%d)' % [t, trait_.lasting_xun])
			PlayerState.remove_trait(t)

func operate_state_transistors():
	for s in Database.get_state_transistors_all():
		var trans = Database.get_state_transistors_all()[s]
		trans.transition()
	
	var prog = PlayerState.get_stat_val(ENUMS.PROPS.PROGRESS)
	if prog >= 100:
		if PlayerState.has_trait(ENUMS.TRAITS.KUANGDA_FENGYING): EventBus.request_event_key.emit("kuangda_2_to_3")
		else: EventBus.request_event_key.emit("kuangda_1_to_2")
	elif prog <= 0:
		if PlayerState.has_trait(ENUMS.TRAITS.KUANGDA_KUANGKE): EventBus.request_event_key.emit("kuangda_3_to_2")
		else: EventBus.request_event_key.emit("kuangda_2_to_1")

# 核心结算管线（上帝视角的暴政：顺序绝对不可更改！）
func _process_single_xun_settlement():
	#breakpoint
	# 第一阶段：跨状态感染 (Cross-Pollination)
	# 在任何增减发生之前，先让状态之间互相发生化学反应。
	# 状态自身存在的持续负面衍生
	# 让属性自己不变，影响其他属性和operator之类的
	aggregate_trait_effect()
	
	# 1.5: 健康→AP 阶梯同步（必须在 aggregate 之后，确保 trait 持续效果已生效）
	_sync_health_ap_traits()
	
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
	operate_state_transistors()
	
	# 4.5: Lock/Block 到期清理
	ActionManager.process_xun_tick()
	
	# 5. 通知 UI 刷新
	EventBus.emit_signal("xun_settlement_completed")
	
	# 6. 延期扣除生活费（快照之后执行，确保计入下月 delta）
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

func _post_xun_money_deduct():
	PlayerState.append_stat(ENUMS.PROPS.MONEY, -30)
	Logging.info('[SurvivalManager] 旬末扣除 30 money（快照之后执行，计入下月 delta）')
	if PlayerState.get_stat_val(ENUMS.PROPS.MONEY) < 0:
		Logging.info('[SurvivalManager] 旬末结算后 money<0，触发流落街头事件')
		OperatorFactory.create_event_operator('event_money_lower_0_innkeeper').operate()

func _ready():
	TimeService.on_xun_tick.connect(_process_single_xun_settlement)
