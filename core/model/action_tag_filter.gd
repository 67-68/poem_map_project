class_name ActionTagFilter extends BaseEventPoolFilter

static func filter(tickets: Array[EventTicket], _context: Dictionary) -> Array[EventTicket]:
    var new_events = {}
    var current_tags = PlayerState.current_action_tags

    # 🔍 检查输入标签是否为三段式（向后兼容检查）
    for tag in current_tags:
        if tag.split(':').size() <= 3:
            push_error("🚨 [ActionTagFilter] 发现三段式标签注入: %s，应该在注入时通过 TagManager.normalize_3part_depreciated_tag() 标准化为四段式" % tag)
    
    var maintag = _context.get('main_tag')
    if not maintag: 
        Logging.info('action tag filter: does not found main tag')

    for ticket in tickets:
        #breakpoint
        var e = Database.random_events.get(ticket.event_uuid)
        if not e:
            e = Database.end_random_events.get(ticket.event_uuid)
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

        # 2.5 拦截没有main tag的事件
        if maintag:
            var found = false
            for tag in e.target_tags:
                if tag == maintag:
                    found = true
                    break
            if not found:
                Logging.info("拦截没有main tag的事件: " + ticket.event_uuid)
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
    if not result:
        Logging.warn('filter 把所有事件都干掉了，很可能出问题了')
        breakpoint
    return result
