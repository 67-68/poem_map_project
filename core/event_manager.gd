extends Node

@export var current_event_pool: Array[EventTicket] = []
var filters: Array[Callable] = [RequirementFilter.filter,ActionTagFilter.filter]

func _ready():
    Logging.info("[EventManager] EventManager initialized")
    TimeService.on_xun_tick.connect(scan_events)
    Logging.info("[EventManager] Connected to TimeService.on_xun_tick")

func _create_ticket(event: BaseEvent) -> EventTicket:
    var ticket = EventTicket.new()
    ticket.event_uuid = event.uuid
    ticket.weight = event.weight
    ticket.original_weight = event.weight
    return ticket

func scan_events(nothing_multiplication_weight = 10.0, context: Dictionary = {}):
    """
    扫描事件池，根据权重进行事件抽取

    参数:
        nothing_multiplication_weight: 无事发生的权重倍数，默认为10
        context: 上下文字典，包含main_tag等信息
    """
    #breakpoint
    Logging.info("[EventManager] Starting event scan")

    var initial_tickets: Array[EventTicket] = []
    var main_tag = context.get('main_tag', '')
    var events_to_scan = Database.get_random_events(main_tag)

    for e in events_to_scan.values():
        initial_tickets.append(_create_ticket(e))
    scan_events_from_tickets(initial_tickets, nothing_multiplication_weight, '', context)

func scan_poem_events(imaginaries: Array[ImaginaryTag]):
    #breakpoint
    var imas = {}
    for i in imaginaries:
        imas[i.uuid] = i

    for p in Database.legendary_poems.values():
        if not Database.legendary_poems: 
            Logging.err('the legendary poems is somehow contain nothing! this will cause error!!')
        var created = true
        for d in p.imagenary_demand:
            if not (d.imagenary_name in imas and imas[d.imagenary_name].current_level >= d.level):
                created = false
                break
        if created:
            return p
        
    var tags = []
    for i in imaginaries:
        for entry in i.basic_imaginaries:
            var blueprint_id = entry.get("blueprint_id", "")
            if not blueprint_id.is_empty():
                tags.append(blueprint_id)
    
    # create tickets
    var tickets: Array[EventTicket] = []
    for t in tags:
        for e in Database.normal_poem_events.values():
            for target_tag in e.target_tags:
                # 🚀 革新匹配：前缀匹配（短 tag 做前缀，匹配长 tag）
                if TagManager.prefix_match(target_tag, t):
                    tickets.append(_create_ticket(e))
    #breakpoint
    scan_events_from_tickets(tickets, 0.0, 'da_you_shi', {})


func scan_death_events():
    """
    在结局之后使用，扫描死亡/失败/结束事件
    """
    Logging.info("[EventManager] Starting death event scan")
    var initial_tickets: Array[EventTicket] = []
    for e in Database.end_random_events.values():
        initial_tickets.append(_create_ticket(e))
    #breakpoint
    scan_events_from_tickets(initial_tickets, 0.0, '', {})

func scan_events_from_tickets(initial_tickets: Array[EventTicket], nothing_multiplication_weight = 10.0, fallback_event_uuid: String = "", context: Dictionary = {}):
    """
    从给定的事件票据池中扫描事件的核心逻辑

    参数:
        initial_tickets: 初始事件票据数组
        nothing_multiplication_weight: 无事发生的权重倍数，默认为10
        fallback_event_uuid: 当无事发生时使用的事件UUID，可选
        context: 上下文字典，包含main_tag等信息
    """
    Logging.info("[EventManager] Starting event scan from " + str(initial_tickets.size()) + " initial tickets")
    # 致命修复 1：每次重新算命前，必须清空上一次的签筒！
    current_event_pool.clear()
    Logging.info("[EventManager] Cleared previous event pool")

    current_event_pool.assign(initial_tickets)

    #breakpoint
    for f in filters:
        current_event_pool = f.call(current_event_pool, context) as Array[EventTicket]

    Logging.info("[EventManager] Event pool populated with " + str(current_event_pool.size()) + " eligible events")
    
    # 开始命运抽奖
    var ev_name = roll_events(nothing_multiplication_weight, fallback_event_uuid)
    if ev_name:
        EventBus.request_event_key.emit(ev_name, context)
        Logging.info("[EventManager] 命运降临: " + ev_name)
    else: 
        Logging.info("[EventManager] 这次抽取事件，岁月静好")
    

func roll_events(nothing_multiplication_weight = 10.0, fallback_event_uuid: String = ""):
    Logging.info("[EventManager] Starting event roll")
    if current_event_pool.is_empty():
        Logging.info("[EventManager] Event pool is empty, returning null")
        return null

    var total_weight := 0.0
    for ticket in current_event_pool:
        total_weight += ticket.weight
        Logging.info("[EventManager] Event '" + ticket.event_uuid + "' weight: " + str(ticket.weight))
    
    Logging.info("[EventManager] Total event weight: " + str(total_weight))
        
    # 🎲 工业级无事发生算法：
    # 设定一个空转权重。比如定死为 200，或者设为总权重的 50%。
    # 如果总权重是 100，空转是 50，那么触发真实事件的概率就是 66%
    var null_weight = total_weight * nothing_multiplication_weight
    var final_total = total_weight + null_weight
    Logging.info("[EventManager] Null weight: " + str(null_weight) + ", final total weight: " + str(final_total))

    var roll: float = randf() * final_total
    var current_accumulated := 0.0
    Logging.info("[EventManager] Rolled value: " + str(roll))
    
    for ticket in current_event_pool:
        current_accumulated += ticket.weight
        Logging.info("[EventManager] Checking event '" + ticket.event_uuid + "', accumulated weight: " + str(current_accumulated))
        if roll <= current_accumulated:
            Logging.info("[EventManager] Event selected: " + ticket.event_uuid)
            return ticket.event_uuid
            
    # 如果 roll 出来的数字落在了 null_weight 的区间里，说明抽中了“无事发生”
    if fallback_event_uuid != "":
        Logging.info("[EventManager] Roll fell in null weight range, using fallback event: " + fallback_event_uuid)
        return fallback_event_uuid
    else:
        Logging.info("[EventManager] Roll fell in null weight range, no event triggered")
        return null
