extends Node

@export var current_event_pool: Array[BaseEvent] = []

func _ready():
    Logging.info("[EventManager] EventManager initialized")
    TimeService.on_xun_tick.connect(scan_events)
    Logging.info("[EventManager] Connected to TimeService.on_xun_tick")

func scan_events():
    Logging.info("[EventManager] Starting event scan")
    # 致命修复 1：每次重新算命前，必须清空上一次的签筒！
    current_event_pool.clear()
    Logging.info("[EventManager] Cleared previous event pool")
    
    # 扫描全局大池子
    Logging.info("[EventManager] Scanning global event pool, total events: " + str(Global.event_data.size()))
    for e in Global.event_data:
        # 如果你未来在事件最外层加了 valid_locations，可以在这里做第一层极简拦截
        # if e.valid_locations.size() > 0 and PlayerState.current_location not in e.valid_locations:
        #     continue

        # 🚨 致命修复 2：允许没有 requirement 的“无条件事件”进入池子
        if not e.requirement or e.requirement.compare():
            current_event_pool.append(e)
            Logging.info("[EventManager] Event added to pool: " + e.name)
        else:
            Logging.info("[EventManager] Event skipped due to unmet requirements: " + e.name)
    
    Logging.info("[EventManager] Event pool populated with " + str(current_event_pool.size()) + " eligible events")
    
    # 开始命运抽奖
    var ev = roll_events()
    if ev: 
        Global.request_event.emit(ev)
        Logging.info("[EventManager] 命运降临: " + ev.name)
    else: 
        Logging.info("[EventManager] 本旬无事发生，岁月静好")
    
func roll_events():
    Logging.info("[EventManager] Starting event roll")
    if current_event_pool.is_empty():
        Logging.info("[EventManager] Event pool is empty, returning null")
        return null

    var total_weight := 0.0
    for e in current_event_pool:
        total_weight += e.weight
        Logging.info("[EventManager] Event '" + e.name + "' weight: " + str(e.weight))
    
    Logging.info("[EventManager] Total event weight: " + str(total_weight))
        
    # 🎲 工业级无事发生算法：
    # 设定一个空转权重。比如定死为 200，或者设为总权重的 50%。
    # 如果总权重是 100，空转是 50，那么触发真实事件的概率就是 66%
    var null_weight = 200.0 # 策划可以在这里调控游戏节奏的快慢
    var final_total = total_weight + null_weight
    Logging.info("[EventManager] Null weight: " + str(null_weight) + ", final total weight: " + str(final_total))

    var roll: float = randf() * final_total
    var current_accumulated := 0.0
    Logging.info("[EventManager] Rolled value: " + str(roll))
    
    for e in current_event_pool:
        current_accumulated += e.weight
        Logging.info("[EventManager] Checking event '" + e.name + "', accumulated weight: " + str(current_accumulated))
        if roll <= current_accumulated:
            Logging.info("[EventManager] Event selected: " + e.name)
            return e
            
    # 如果 roll 出来的数字落在了 null_weight 的区间里，说明抽中了“无事发生”
    Logging.info("[EventManager] Roll fell in null weight range, no event triggered")
    return null
