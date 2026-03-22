extends Node

@export var current_event_pool: Array[HistoryEventData] = []

func _ready():
    TimeService.on_xun_tick.connect(scan_events)

func scan_events():
    # 扫描当前事件池中的所有事件
    for e in Global.event_data:
        if e.requirement and e.requirement.compare():
            current_event_pool.append(e)
    
    var ev = roll_events()
    if ev: 
        Global.request_event.emit(ev)
        Logging.log("EventManager", "Rolled event: " + ev.name)
    else: Logging.log("EventManager", "No event rolled out")
    
func roll_events():
    var total := 0.0
    for e in current_event_pool:
        total += e.weight
    # 加入一个随机的无事发生选项
    total += randf() * (total / 2.0)

    var random := randf() * total
    var current := 0.0
    for e in current_event_pool:
        current += e.weight
        if current >= random:
            return e
    return null

