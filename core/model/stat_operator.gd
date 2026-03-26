class_name BaseOperator extends Resource

# 让子类自己定义，自己决定叫什么
# 只要方法没问题就行

func operate():
    """
    执行这个operator, 根据具体的value类型，例如str/int
    执行添加trait/property的操作
    """
    Logging.warn('someone call the super method of stat operator, which is mean to be rewrite from child class')