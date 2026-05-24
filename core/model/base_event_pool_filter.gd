class_name BaseEventPoolFilter extends GDScript

static func filter(events: Array[EventTicket], _context: Dictionary) -> Array[EventTicket]:
    return events