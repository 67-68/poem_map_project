class_name SurvivalManager extends Node
# 专门管理玩家的生活费丧失
# 计划扫描当前trait获取需要扣除什么
# 计划有一个月和一个旬的扣除费用
# 但太复杂了先不做，目前只有旬的扣除费用，trait 扫描扣除也没做

func get_prop(data): return PlayerState.get_stat_val(data)
func append_prop(data,val):PlayerState.append_stat(data,val)
func set_prop(data,val):PlayerState.set_stat_val(data,val)

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
    decay(ENUMS.PROPS.DRUNK, 25, 25)
    decay(ENUMS.PROPS.INSPIRATION,25,25)
    decay(ENUMS.PROPS.FATIGUE,90,90) # 只有90以上不能归零

func _process_fatigue_accumulation():
    # 让属性 < 100
    if get_prop(ENUMS.PROPS.DRUNK) >= 100:
        append_prop(ENUMS.PROPS.FATIGUE, 20)
        set_prop(ENUMS.PROPS.DRUNK,99)
    if get_prop(ENUMS.PROPS.FATIGUE) >= 100:
        append_prop(ENUMS.PROPS.BURNOUT, 10)
        set_prop(ENUMS.PROPS.FATIGUE,99)
    if get_prop(ENUMS.PROPS.BURNOUT) >= 100:
        append_prop(ENUMS.PROPS.HEALTH,-20)
        set_prop(ENUMS.PROPS.BURNOUT,99)

func aggregate_trait_effect():
    for t in PlayerState.get_traits():
        var trait_ = Database.traits.get(t)
        if not trait_: 
            Logging.warn('为什么player state中存在的triat在database没有？？')
            continue
        trait_.lasting_xun += 1
        trait_.operate_continuous_effect()

func operate_state_transistors():
    for s in Database.state_transistors:
        var trans = Database.state_transistors[s]
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
    death_judgement()
    
    # 第四阶段：衰减与重置 (Decay, Reset & GC)
    # 打完巴掌给个甜枣，系统内存回收。
    # 属性 90 -> 50
    _decay_volatile_emotions()
    #breakpoint
    operate_state_transistors()
    
    # 5. 通知 UI 刷新
    EventBus.emit_signal("xun_settlement_completed")

func _process_health_checks():
    if get_prop(ENUMS.PROPS.DRUNK) > 50:
        append_prop(ENUMS.PROPS.FATIGUE, -20)
    if get_prop(ENUMS.PROPS.BURNOUT) > 30:
        append_prop(ENUMS.PROPS.SICK, 5)
    if get_prop(ENUMS.PROPS.SICK) > 0:
        append_prop(ENUMS.PROPS.HEALTH, -10)

func death_judgement():
    """
    这里放死亡/结束游戏的条件
    """
    #breakpoint
    if PlayerState.get_stat_val(ENUMS.PROPS.HEALTH) <= 0:
        # ✅ 这里已经是四段式标签，无需标准化
        PlayerState.current_action_tags.append('actor:health:death:general')
        EventManager.scan_death_events()

func _ready():
    TimeService.on_xun_tick.connect(_process_single_xun_settlement)
