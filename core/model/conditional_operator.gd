@tool
class_name ConditionalOperator extends BaseOperator

@export var condition: BaseRequirements
@export var condition_success_result: Array[BaseOperator]
@export var condition_fail_result: Array[BaseOperator]

func get_referenced_flags() -> Array:
    var result = []
    # 从 condition 收集引用的 flag
    if condition and condition.has_method('get_referenced_flags'):
        result.append_array(condition.get_referenced_flags())
    # 从 condition_success_result 收集引用的 flag
    for op in condition_success_result:
        if op and op.has_method('get_referenced_flags'):
            result.append_array(op.get_referenced_flags())
    # 从 condition_fail_result 收集引用的 flag
    for op in condition_fail_result:
        if op and op.has_method('get_referenced_flags'):
            result.append_array(op.get_referenced_flags())
    return result

func get_provided_flags() -> Array:
    var result = []
    # 从 condition_success_result 收集提供的 flag
    for op in condition_success_result:
        if op and op.has_method('get_provided_flags'):
            result.append_array(op.get_provided_flags())
    # 从 condition_fail_result 收集提供的 flag
    for op in condition_fail_result:
        if op and op.has_method('get_provided_flags'):
            result.append_array(op.get_provided_flags())
    return result

func get_referenced_traits() -> Array:
    var result = []
    # 从 condition 收集引用的 trait
    if condition and condition.has_method('get_referenced_traits'):
        result.append_array(condition.get_referenced_traits())
    # 从 condition_success_result 收集引用的 trait
    for op in condition_success_result:
        if op and op.has_method('get_referenced_traits'):
            result.append_array(op.get_referenced_traits())
    # 从 condition_fail_result 收集引用的 trait
    for op in condition_fail_result:
        if op and op.has_method('get_referenced_traits'):
            result.append_array(op.get_referenced_traits())
    return result

func get_provided_traits() -> Array:
    var result = []
    # 从 condition_success_result 收集提供的 trait
    for op in condition_success_result:
        if op and op.has_method('get_provided_traits'):
            result.append_array(op.get_provided_traits())
    # 从 condition_fail_result 收集提供的 trait
    for op in condition_fail_result:
        if op and op.has_method('get_provided_traits'):
            result.append_array(op.get_provided_traits())
    return result

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
