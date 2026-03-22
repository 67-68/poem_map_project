extends Node

@export var current_event_pool: Array[EventTicket] = []
@export var filters: Array[BaseEventPoolFilter] = [RequirementFilter,ActionTagFilter]

func _ready():
    Logging.info("[EventManager] EventManager initialized")
    TimeService.on_xun_tick.connect(scan_events)
    Logging.info("[EventManager] Connected to TimeService.on_xun_tick")

func create_ticket(event: BaseEvent) -> EventTicket:
    var ticket = EventTicket.new()
    ticket.event_name = event.name
    ticket.possibility = event.weight
    return ticket

func scan_events():
    Logging.info("[EventManager] Starting event scan")
    # 致命修复 1：每次重新算命前，必须清空上一次的签筒！
    current_event_pool.clear()
    Logging.info("[EventManager] Cleared previous event pool")


    current_event_pool = Global.random_events.values().map(func(e): return create_ticket(e))

    for f in filters:
        current_event_pool = f.filter(current_event_pool)
        
    Logging.info("[EventManager] Event pool populated with " + str(current_event_pool.size()) + " eligible events")
    
    # 开始命运抽奖
    var ev_name = roll_events()
    if ev_name: 
        Global.request_event_key.emit(ev_name)
        Logging.info("[EventManager] 命运降临: " + ev_name)
    else: 
        Logging.info("[EventManager] 本旬无事发生，岁月静好")

func roll_events():
    Logging.info("[EventManager] Starting event roll")
    if current_event_pool.is_empty():
        Logging.info("[EventManager] Event pool is empty, returning null")
        return null

    var total_weight := 0.0
    for ticket in current_event_pool:
        total_weight += ticket.weight
        Logging.info("[EventManager] Event '" + ticket.event_name + "' weight: " + str(ticket.weight))
    
    Logging.info("[EventManager] Total event weight: " + str(total_weight))
        
    # 🎲 工业级无事发生算法：
    # 设定一个空转权重。比如定死为 200，或者设为总权重的 50%。
    # 如果总权重是 100，空转是 50，那么触发真实事件的概率就是 66%
    var null_weight = total_weight * 10
    var final_total = total_weight + null_weight
    Logging.info("[EventManager] Null weight: " + str(null_weight) + ", final total weight: " + str(final_total))

    var roll: float = randf() * final_total
    var current_accumulated := 0.0
    Logging.info("[EventManager] Rolled value: " + str(roll))
    
    for ticket in current_event_pool:
        current_accumulated += ticket.weight
        Logging.info("[EventManager] Checking event '" + ticket.event_name + "', accumulated weight: " + str(current_accumulated))
        if roll <= current_accumulated:
            Logging.info("[EventManager] Event selected: " + ticket.event_name)
            return ticket.event_name
            
    # 如果 roll 出来的数字落在了 null_weight 的区间里，说明抽中了“无事发生”
    Logging.info("[EventManager] Roll fell in null weight range, no event triggered")
    return null
