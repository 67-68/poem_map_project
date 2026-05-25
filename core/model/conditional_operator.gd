class_name ConditionalOperator extends BaseOperator

@export var condition: BaseRequirements
@export var condition_success_result: Array[BaseOperator]
@export var condition_fail_result: Array[BaseOperator]

func operate():
    if not condition:
        Logging.err('no condition for condition opeartor!')
        return
    if condition.compare(PlayerState):
        for c in condition_success_result:
            c.operate()
    else:
        if not condition_fail_result: return
        for c in condition_fail_result:
            c.operate()
