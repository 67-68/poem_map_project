class_name RequirementFilter extends BaseEventPoolFilter

static func filter(tickets: Array[EventTicket], _context: Dictionary) -> Array[EventTicket]:
    var new_events: Array[EventTicket] = []
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
            Logging.err("[RequirementFilter] Event not found: " + ticket.event_uuid)
            continue

        if not e.requirement or e.requirement.compare(PlayerState):
            new_events.append(ticket)
            Logging.info("[EventManager] Event added to pool: " + e.name)
        else:
            Logging.info("[EventManager] Event skipped due to unmet requirements: " + e.name)
    return new_events
