class_name ActionTagFilter extends BaseEventPoolFilter

static func filter(tickets: Array[EventTicket]) -> Array[EventTicket]:
    var new_events = {}
    var current_tags = PlayerState.current_action_tags
    
    for ticket in tickets:
        var e = Global.random_events.get(ticket.event_uuid)
        if not e:
            e = Global.end_random_events.get(ticket.event_uuid)
        if not e: 
            e = Global.find_triggerable_item(ticket.event_uuid)
        if not e:             
            Logging.err("[ActionTagFilter] Event not found: " + ticket.event_uuid)
            continue

        # 1. 天地法则：没有标签的全局事件，永远放行！
        if not e.target_tags or e.target_tags.is_empty():
            new_events[ticket.event_uuid] = ticket
            continue

        # 2. 专属拦截：玩家现在闲着（无tag），那带有专属标签的事件直接略过！
        if not current_tags or current_tags.is_empty():
            Logging.warn("检查自己是不是又忘记给玩家加current tags了！！！又筛选掉了")
            continue

        # 3. 对暗号与权重狂欢
        for tag in current_tags:
            if e.target_tags.has(tag):
                if new_events.has(ticket.event_uuid):
                    # 多个 tag 命中，继续追加原始权重
                    new_events[ticket.event_uuid].weight += ticket.original_weight
                else:
                    new_events[ticket.event_uuid] = ticket
                    # 首次命中，权重起飞！(你的乘3倍逻辑非常好)
                    new_events[ticket.event_uuid].weight *= 3
                    
    # 将字典的值强转回 Array[EventTicket]
    var result: Array[EventTicket] = []
    result.assign(new_events.values())
    PlayerState.current_action_tags.clear()
    return result
