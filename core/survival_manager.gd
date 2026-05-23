class_name SurvivalManager extends Node
# 专门管理玩家的生活费丧失
# 计划扫描当前trait获取需要扣除什么
# 计划有一个月和一个旬的扣除费用
# 但太复杂了先不做，目前只有旬的扣除费用，trait 扫描扣除也没做



func cost_survival():
    #breakpoint
    if PlayerState.has_trait(ENUMS.TRAITS.WANDERING_WITHOUT_LIVING_PLACE):
        PlayerState.change_stat(ENUMS.PROPS.MONEY, -2)
        if PlayerState.get_stat_val(ENUMS.PROPS.MONEY) < 0:
            OperatorFactory.create_event_operator('event_money_lower_0_wandering').operate()
        return
    PlayerState.change_stat(ENUMS.PROPS.MONEY, -5)
    if PlayerState.get_stat_val(ENUMS.PROPS.MONEY) < 0:
        OperatorFactory.create_event_operator('event_money_lower_0').operate()

func death_judgement():
    """
    这里放死亡/结束游戏的条件
    """
    #breakpoint
    if PlayerState.get_stat_val(ENUMS.PROPS.HEALTH) < 0:
        # ✅ 这里已经是四段式标签，无需标准化
        PlayerState.current_action_tags.append('actor:health:death:general')
        EventManager.scan_death_events()

func _ready():
    TimeService.on_xun_tick.connect(cost_survival)
    TimeService.on_xun_tick.connect(death_judgement)
