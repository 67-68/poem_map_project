class_name ActionTagFilter extends BaseEventPoolFilter

static func filter(tickets: Array[EventTicket]) -> Array[EventTicket]:
    var new_events = {}
    if not PlayerState.current_action_tags: return tickets
    for ticket in tickets:
        # 判断是否事件tag和当前活动tag有交集
        var e = Global.random_events.get(ticket.event_name)
        if not e: 
            Logging.error("[ActionTagFilter] Event not found: " + ticket.event_name)
            continue

        if not e.target_tags:
            new_events[ticket.event_name] = ticket
            continue

        for tag in PlayerState.current_action_tags:
            if e.target_tags.has(tag):
                if new_events.has(ticket.event_name):
                    new_events[ticket.event_name].weight += new_events[ticket.event_name].original_weight
                else:
                    new_events[ticket.event_name] = ticket
    return new_events.values()