extends Node

func execute_result(result: ChoiceResult):
    if not result:
        Logging.debug('receive a empty result')
        return
    result.operate()
