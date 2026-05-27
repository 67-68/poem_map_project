class_name PropertyOption extends BaseOption

# 用来判断单个属性是否满足条件
# failed_hint直接写在req, 会自动输出

var property_name: String:
    get():
        return ENUMS.to_prop_str(_property_name)
        
@export var _property_name: ENUMS.PROPS
@export var requirements: PropertyRequirement = PropertyRequirement.new()
@export var choice_result: ChoiceResult

