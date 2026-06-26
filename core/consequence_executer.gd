extends Node
const _ChoiceResult = preload("res://model/choice_result.gd")

func execute_result(result: ChoiceResult):
    if not result:
        Logging.debug('receive a empty result')
        return
    result.operate()
