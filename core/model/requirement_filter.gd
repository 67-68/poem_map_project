class_name RequirementFilter extends BaseEventPoolFilter

static func filter(tickets: Array[EventTicket]) -> Array[EventTicket]:
    var new_events: Array[EventTicket] = []
    for ticket in tickets:
        var e = Global.random_events.get(ticket.event_uuid)
        if not e:
            e = Global.find_triggerable_item(ticket.event_uuid)
            if e is not BaseEvent:
                e = null
        if not e:
            Logging.err("[RequirementFilter] Event not found: " + ticket.event_uuid)
            continue

        if not e.requirement or e.requirement.compare(PlayerState):
            new_events.append(ticket)
            Logging.info("[EventManager] Event added to pool: " + e.name)
        else:
            Logging.info("[EventManager] Event skipped due to unmet requirements: " + e.name)
    return new_events
