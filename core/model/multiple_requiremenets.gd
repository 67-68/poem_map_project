class_name ComplexRequirements extends BasePropertyOperator

@export var operators: Array[BasePropertyOperator] = []
@export var current_operator: REQ_OPERATOR.ENUM

func compare(data):
    # 分别调用下级的operator, 根据and 或者or分别判断
    if operators.is_empty():
        Logging.warn('ComplexRequirements: No operators defined, returning true by default')
        return true
    
    var results = []
    for i in range(operators.size()):
        var operator = operators[i]
        if not operator:
            Logging.err('ComplexRequirements: Operator at index %d is null' % i)
            return false
        var result = operator.compare(data)
        results.append(result)
    
    if current_operator == 0:  # REQ_OPERATOR.AND
        # AND逻辑：所有条件都必须满足
        for i in range(results.size()):
            if not results[i]:
                Logging.err('ComplexRequirements: AND operation failed at operator index %d' % i)
                return false
        return true
    elif current_operator == 1:  # REQ_OPERATOR.OR
        # OR逻辑：至少一个条件满足
        for i in range(results.size()):
            if results[i]:
                return true
        Logging.err('ComplexRequirements: OR operation failed, none of %d operators satisfied' % results.size())
        return false
    else:
        Logging.err('ComplexRequirements: Unknown current_operator value: %d' % current_operator)
        return false

func _init(data):
    if not data:
        Logging.err('ComplexRequirements: Initialization data is null or empty')
        return
    
    var operators_ = PropParser.parse_any(data,true,'operators')
    if not operators_ is Array: 
        Logging.err('ComplexRequirements: operators field is not an array, got: %s' % str(typeof(operators_)))
        return
    
    if operators_.is_empty():
        Logging.warn('ComplexRequirements: operators array is empty')
    
    for i in range(operators_.size()):
        var op = operators_[i]
        if not op:
            Logging.err('ComplexRequirements: Operator at index %d is null' % i)
            return
            
        if not op.has('type'): 
            Logging.err('ComplexRequirements: Operator at index %d missing type field, data: %s' % [i, str(op)])
            return
            
        var operator_type = op['type']
        
        if operator_type == 'ComplexRequirements':
            var complex_req = PropParser.parse_and_create_cls(ComplexRequirements,op,true,'data')
            if complex_req:
                operators.append(complex_req)
            else:
                Logging.err('ComplexRequirements: Failed to create ComplexRequirements at index %d' % i)
                return
        elif operator_type == 'PropertyRequirement':
            var prop_req = PropParser.parse_and_create_cls(PropertyRequirement,op,true,'data')
            if prop_req:
                operators.append(prop_req)
            else:
                Logging.err('ComplexRequirements: Failed to create PropertyRequirement at index %d' % i)
                return
        else:
            Logging.err('ComplexRequirements: Unknown operator type at index %d: %s' % [i, operator_type])
            return
    var current_operator_ = PropParser.parse_any(data,true,'current_operator')
    if not current_operator_:
        print('what is hell is the fucking bug that can not let me parse a single int??? fuck you')
        current_operator_ = 0
    current_operator = current_operator_
    if not current_operator: 
        Logging.err('ComplexRequirements: Missing or invalid current_operator field in data: %s' % str(data))
        return
    
    if current_operator != 0 and current_operator != 1:
        Logging.err('ComplexRequirements: Invalid current_operator value: %d, expected 0 (AND) or 1 (OR)' % current_operator)
        return
    
    Logging.info('ComplexRequirements: Successfully initialized with %d operators and operator type %d' % [operators.size(), current_operator])
