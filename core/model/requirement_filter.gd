class_name RequirementFilter extends BaseEventPoolFilter

static func filter(tickets: Array[EventTicket], _context: Dictionary) -> Array[EventTicket]:
    var new_events: Array[EventTicket] = []
    var main_tag = _context.get('main_tag', '')

    # 前缀匹配：用 main_tag 找对应桶（如 action:main:baiye 匹配 action:main:baiye:general）
    var matched_bucket: Dictionary = {}
    if main_tag:
        matched_bucket = Database.get_random_events(main_tag)

    for ticket in tickets:
        var e: BaseEvent

        # 优先使用 context 中的 main_tag 前缀匹配路由到对应桶
        if not matched_bucket.is_empty():
            e = matched_bucket.get(ticket.event_uuid)

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
