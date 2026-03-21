class_name MultiplyOperator extends Resource
# 给出一个值，通过本地的multiplication 返回一个计算factor之后的值

enum MUL_OPERATOR{
    POSITIVE_ONLY,
    NEGATIVE_ONLY,
    BOTH
}

@export var key := 'default-multiplication-operator-name'
@export var value := 1.0
@export var operator := MUL_OPERATOR.POSITIVE_ONLY

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


