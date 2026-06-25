class_name RespondSummonManager extends GDScript
# 应召管理器

func _ready():
    TimeService.on_xun_tick.connect(respond_summon)
    
func respond_summon():
    breakpoint
    var chance_of_summoned := 0.0
    chance_of_summoned += PlayerState.get_stat_val('literary_fame') * 0.002
    chance_of_summoned += PlayerState.get_stat_val('progress') * 0.002
    if chance_of_summoned > 0.2: chance_of_summoned = 0.2

    # 随机判断是否触发征召
    if randf() < chance_of_summoned:
        var ev = EventOperator.new()
        ev.event_key = 'feng_zhao'
        ev.operate()
        Logging.info('RespondSummon: summon triggered (chance: %.3f)' % chance_of_summoned)
    else:
        Logging.info('RespondSummon: summon not triggered (chance: %.3f)' % chance_of_summoned)


        