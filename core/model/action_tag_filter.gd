class_name ActionTagFilter extends BaseEventPoolFilter

static func filter(tickets: Array[EventTicket], _context: Dictionary) -> Array[EventTicket]:
    var new_events = {}
    var current_tags = PlayerState.current_action_tags
    
    for ticket in tickets:
        var e: BaseEvent
        var main_tag = _context.get('main_tag', '')

        # 优先使用 context 中的 main_tag 路由到对应桶
        if main_tag and Database.random_events.has(main_tag):
            e = Database.random_events[main_tag].get(ticket.event_uuid)

        # 如果没有 main_tag 或对应桶中没有，尝试从所有事件中查找
        if not e:
            e = Database.find_triggerable_item(ticket.event_uuid)

        if not e:
            Logging.err("[ActionTagFilter] Event not found: " + ticket.event_uuid)
            continue

        # 1. 天地法则：没有标签的全局事件，永远放行！
        if not e.target_tags or e.target_tags.is_empty():
            new_events[ticket.event_uuid] = ticket
            Logging.warn('放行没有标签的全局事件')
            continue

        # 2. 专属拦截：玩家现在闲着（无tag），那带有专属标签的事件直接略过！
        if not current_tags or current_tags.is_empty():
            Logging.warn("检查自己是不是又忘记给玩家加current tags了！！！又筛选掉了")
            continue

        # 3. 🚀 革新匹配：前缀匹配，仅对比前3级，第4级忽略
        for tag in current_tags:
            for target_tag in e.target_tags:
                if TagManager.prefix_match(tag, target_tag, 3):
                    if new_events.has(ticket.event_uuid):
                        # 多个 tag 命中，继续追加原始权重
                        new_events[ticket.event_uuid].weight += ticket.original_weight * 3
                    else:
                        new_events[ticket.event_uuid] = ticket
                        # 首次命中，权重起飞！
                        new_events[ticket.event_uuid].weight *= 9
                    break  # 一个事件匹配一个当前 tag 就够了，跳出 target_tag 内层循环
                    
    # 将字典的值强转回 Array[EventTicket]
    var result: Array[EventTicket] = []
    result.assign(new_events.values())
    PlayerState.current_action_tags.clear()
    if not result:
        Logging.warn('filter 把所有事件都干掉了，很可能出问题了')
        breakpoint
    return result
