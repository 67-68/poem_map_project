class_name MultiplyOperator extends GameEntity
# 给出一个值，通过本地的multiplication 返回一个计算factor之后的值

enum MUL_OPERATOR{
    POSITIVE_ONLY,
    NEGATIVE_ONLY,
    BOTH
}

var key := 'default-multiplication-operator-name'
var value := 1.0
var operator := MUL_OPERATOR.POSITIVE_ONLY

func _init(data):
    super._init(data)
    key = PropParser.parse_any(data,true,"key")
    value = PropParser.parse_any(data,true,'value')
    operator = MUL_OPERATOR.get(PropParser.parse_any(data,true,'operator'))

func multiply(data):
    if data == 0: 
        Logging.warn('a zero data being multiplied, this is will have no effect')
        return
    match operator:
        MUL_OPERATOR.POSITIVE_ONLY:
            if data < 0: return
        MUL_OPERATOR.NEGATIVE_ONLY:
            if data > 0: return
    return data * value


