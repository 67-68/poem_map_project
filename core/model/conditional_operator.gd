class_name ConditionalOperator extends BaseOperator

@export var condition: BaseRequirements
@export var condition_success_result: BaseOperator
@export var condition_fail_result: BaseOperator

func operate():
    if condition.is_met():
        condition_success_result.operate()
    else:
        condition_fail_result.operate()