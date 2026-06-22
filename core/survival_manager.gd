class_name SurvivalManager extends Node
# 专门管理玩家的生活费丧失
# 计划扫描当前trait获取需要扣除什么
# 计划有一个月和一个旬的扣除费用
# 但太复杂了先不做，目前只有旬的扣除费用，trait 扫描扣除也没做

const HEARTBEAT_HEALTH_THRESHOLD: int = 20

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
        return
    PlayerState.append_stat(ENUMS.PROPS.MONEY, -5)
    if PlayerState.get_stat_val(ENUMS.PROPS.MONEY) < 0:
        OperatorFactory.create_event_operator('event_money_lower_0').operate()

func decay(prop_enum, threshold, decay_val):
    var current_val = get_prop(prop_enum)
    # 如果当前值高于阈值，扣除固定的衰减量；否则直接清零
    if current_val > threshold: 
        append_prop(prop_enum, -decay_val)
    else:
        append_prop(prop_enum, -current_val)

func _decay_volatile_emotions():
    # 使用各属性自身的 decay_threshold，不再硬编码
    decay(ENUMS.PROPS.DRUNK, _get_decay_threshold(ENUMS.PROPS.DRUNK), _get_decay_threshold(ENUMS.PROPS.DRUNK))
    decay(ENUMS.PROPS.INSPIRATION, _get_decay_threshold(ENUMS.PROPS.INSPIRATION), _get_decay_threshold(ENUMS.PROPS.INSPIRATION))
    decay(ENUMS.PROPS.FATIGUE, _get_decay_threshold(ENUMS.PROPS.FATIGUE), _get_decay_threshold(ENUMS.PROPS.FATIGUE))

func _process_fatigue_accumulation():
    # 使用 soft_max 替换魔法数字 100，溢出后复位到 soft_max - 1
    var drunk_soft = _get_soft_max(ENUMS.PROPS.DRUNK)
    var fatigue_soft = _get_soft_max(ENUMS.PROPS.FATIGUE)
    var burnout_soft = _get_soft_max(ENUMS.PROPS.BURNOUT)

    if get_prop(ENUMS.PROPS.DRUNK) >= drunk_soft:
        append_prop(ENUMS.PROPS.FATIGUE, 20)
        set_prop(ENUMS.PROPS.DRUNK, drunk_soft - 1)
    if get_prop(ENUMS.PROPS.FATIGUE) >= fatigue_soft:
        append_prop(ENUMS.PROPS.BURNOUT, 10)
        set_prop(ENUMS.PROPS.FATIGUE, fatigue_soft - 1)
    if get_prop(ENUMS.PROPS.BURNOUT) >= burnout_soft:
        append_prop(ENUMS.PROPS.HEALTH,-20)
        set_prop(ENUMS.PROPS.BURNOUT, burnout_soft - 1)

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

func operate_state_transistors():
    for s in Database.get_state_transistors_all():
        var trans = Database.get_state_transistors_all()[s]
        trans.transition()

# 核心结算管线（上帝视角的暴政：顺序绝对不可更改！）
func _process_single_xun_settlement():
    #breakpoint
    # 第一阶段：跨状态感染 (Cross-Pollination)
    # 在任何增减发生之前，先让状态之间互相发生化学反应。
    # 状态自身存在的持续负面衍生
    # 让属性自己不变，影响其他属性和operator之类的
    _process_health_checks()
    aggregate_trait_effect()
    
    # 第二阶段：生存基础扣除 (Upkeep & Economy)
    # 外部环境对玩家的无情压迫。
    _cost_survival()
    
    # 第三阶段：溢出清算与异化 (Threshold Detonation) —— 你最关注的一步
    # 结算所有的长期代价，进行不可逆的惩罚。
    # 让属性 < 100
    _process_fatigue_accumulation()
    
    # 3.5: 濒危警告音效
    _update_heartbeat_sfx()
    
    death_judgement()
    
    # 第四阶段：衰减与重置 (Decay, Reset & GC)
    # 打完巴掌给个甜枣，系统内存回收。
    # 属性 90 -> 50
    _decay_volatile_emotions()
    #breakpoint
    operate_state_transistors()
    
    # 4.5: Lock/Block 到期清理
    ActionManager.process_xun_tick()
    
    # 5. 通知 UI 刷新
    EventBus.emit_signal("xun_settlement_completed")

func _process_health_checks():
    if get_prop(ENUMS.PROPS.DRUNK) > 50:
        append_prop(ENUMS.PROPS.FATIGUE, -20)
    if get_prop(ENUMS.PROPS.BURNOUT) > 30:
        append_prop(ENUMS.PROPS.SICK, 5)
    if get_prop(ENUMS.PROPS.SICK) > 0:
        append_prop(ENUMS.PROPS.HEALTH, -10)

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
        var count: int = PlayerState.get_flag("flag_near_death_count") as int
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

func _ready():
    TimeService.on_xun_tick.connect(_process_single_xun_settlement)
