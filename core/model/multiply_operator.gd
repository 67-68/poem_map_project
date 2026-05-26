@tool
class_name MultiplyOperator extends Resource

enum MUL_OPERATOR{
    POSITIVE_ONLY,
    NEGATIVE_ONLY,
    BOTH
}

@export var key := 'default-multiplication-operator-name'
@export var value := 1.0
@export var operator := MUL_OPERATOR.POSITIVE_ONLY

# 🤓☝️ 强制类型签名：输入 int，输出必须是 int！
func multiply(data: int) -> int:
    if data == 0: 
        Logging.warn('a zero data being multiplied, this will have no effect')
        # 必须返回 0！决不能隐式返回 null！
        return 0 
        
    match operator:
        MUL_OPERATOR.POSITIVE_ONLY:
            # 如果不满足条件，说明这个 Buff 没生效，把原值原样退回去！
            if data < 0: return data 
        MUL_OPERATOR.NEGATIVE_ONLY:
            if data > 0: return data
            
    # value 是 float, data 是 int，乘完之后是 float。
    # 为了满足 -> int 的契约，必须做向下取整或显式强转。
    return int(data * value)