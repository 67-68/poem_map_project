class_name PoemCraftingCalculator extends Node

static func cost_is_high(imas: Array[ImaginaryTag]):
    for i in imas:
        if i.current_level == 2:
            return true
    return false

static func calculate(imas: Array[ImaginaryTag]) -> Array[BaseOperator]:
    """
    calculate poem cost
    """
    var operators:Array[BaseOperator] = []
    # 最简单的形态：仅扣除健康
    var level_factor = 0.5 if PoemCraftingCalculator.cost_is_high(imas) else 0.2
    var base_health = 0
    for i in imas:
        base_health += i.current_level * level_factor + 0.5 * i.l3_threshold
    operators.append(OperatorFactory.create_property_operator("health", -base_health))
    
    if cost_is_high(imas):
        var talent_cost = 0
        for i in imas:
            if i.current_level == 2:
                talent_cost += i.current_level * 1.5
        operators.append(OperatorFactory.create_property_operator("talent", -talent_cost))
    return operators

static func translate(ops: Array[BaseOperator]):
    var base_text = ''
    for op in ops:
        if op is PropertyOperator:
            base_text += op.property + ':' + str(op.value) + '\n'
    return base_text