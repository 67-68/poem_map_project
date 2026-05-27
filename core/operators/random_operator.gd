@tool
class_name RandomOperator extends BaseOperator

@export var random_value: int # 如果是86, 那么就有86的概率触发
@export var success_operator: BaseOperator
@export var fail_operator: BaseOperator
@export var success_hint: String
@export var failed_hint: String
# 随机数范围 0-99

func operate():
    var rand = randi() % 100
    if rand < random_value:
        success_operator.operate()
        if success_hint: show_hint(success_hint)
    else:
        fail_operator.operate()
        if failed_hint: show_hint(failed_hint)

    