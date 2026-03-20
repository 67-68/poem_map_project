class_name DictMultiplyOperator extends GameEntity

# data: { name_of_sth: MultiplyOperator }

func _init(data):
    super._init(data)
    for name_ in data:
        self[name_] = MultiplyOperator.new(data[name_])

func match_and_multiply(prop_name:String, prop: int):
    var exist = self.get(prop_name)
    if exist is MultiplyOperator:
        return exist.multiply(prop)
    else:
        Logging.error('somehow the prop name %s match with a sys prop name, change it' % prop_name)
        return