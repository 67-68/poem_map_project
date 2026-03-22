class_name RequirementFilter extends BaseEventPoolFilter

static func filter(tickets: Array[EventTicket]) -> Array[EventTicket]:
    var new_events = []
    for ticket in tickets:
        var e = Global.random_events.get(ticket.event_name)
        if not e:
            Logging.error("[RequirementFilter] Event not found: " + ticket.event_name)
            continue

        if not e.requirement or e.requirement.compare(PlayerState):
            new_events.append(ticket)
            Logging.info("[EventManager] Event added to pool: " + e.name)
        else:
            Logging.info("[EventManager] Event skipped due to unmet requirements: " + e.name)
    return new_events