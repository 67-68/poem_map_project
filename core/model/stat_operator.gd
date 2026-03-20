class_name StatOperator extends GameEntity

var key := 'default-stat-name'
var value
var operator := '+'

func _init(data):
    super._init(data)
    key = PropParser.parse_any(data,true,"key")
    value = PropParser.parse_any(data,true,'value')
    operator = PropParser.parse_any(data,true,'operator')

func operate():
    """
    执行这个operator, 根据具体的value类型，例如str/int
    执行添加trait/property的操作
    """
    Logging.warn('someone call the super method of stat operator, which is mean to be rewrite from child class')
