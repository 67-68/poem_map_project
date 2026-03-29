class_name ConditionalOperator extends BaseOperator

@export var condition: BaseRequirements
@export var condition_success_result: Array[BaseOperator]
@export var condition_fail_result: Array[BaseOperator]

func operate():
    if condition.compare(PlayerState):
        for c in condition_success_result:
            c.operate()
    else:
        for c in condition_fail_result:
            c.operate()
