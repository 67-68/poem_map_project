extends Node

func execute_result(result: ChoiceResult):
    if not result:
        Logging.debug('receive a empty result')
        return

    match result.action_type:
        "add_event": _add_event(result)
        "trait", "property":
            if result.stat_operator:
                result.stat_operator.operate()
            else:
                Logging.err('No stat operator found for action type: %s' % result.action_type)
        
        
func _add_event(result: ChoiceResult):
    var next_item = Global.find_triggerable_item(result.target_uuid)
    if next_item:
        if next_item is FocusedChat or ChatBubble:
            Global.request_add_event.emit(next_item)
        else:
            Logging.warn('what is this item? Check if the uuid mess up. Same uuid for different field data')
            Logging.warn('target: %s next: %s' % [result.target_uuid,next_item.uuid])
    else:
        Logging.warn('can not find a valid uuid for a triggerable item in data: %s' % result.target_uuid)

