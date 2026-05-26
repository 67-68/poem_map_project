@tool
class_name PoemTypeChooseOperator extends BaseOperator

@export var _accepted_poem_types: Array[ENUMS.POEM_TYPE] # e.g. ["yan_ye", "ying_zhi"]
var accepted_poem_types: Array[String]:
    get():
        return _accepted_poem_types.map(func(t: ENUMS.POEM_TYPE) -> String: return ENUMS.POEM_TYPE.keys()[t])
@export var lowest_poem_level := 0
@export var accpeted_result: ChoiceResult = ChoiceResult.new()
@export var rejected_result: ChoiceResult = ChoiceResult.new()
@export var not_entered_result: ChoiceResult = ChoiceResult.new()

func operate():
    Logging.debug('PoemTypeChooseOperator: Starting operate()')
    var data = [] 
    for t in PlayerState.get_traits():
        var trait_ = Database.traits.get(t)
        if not trait_:
            Logging.err('PoemTypeChooseOperator: can not found trait %s' % t)
            continue
        Logging.debug('PoemTypeChooseOperator: Found trait %s' % t)
        data.append(trait_)

    Logging.debug('PoemTypeChooseOperator: Emitting start_picker with %d traits' % data.size())
    EventBus.start_picker.emit(data,null)
    var trait_picked = await EventBus.end_picking
    if not trait_picked:
        not_entered_result.operate()
        Logging.warn('trait not picked, left blank')
        return
    Logging.debug('PoemTypeChooseOperator: Trait picked - %s' % trait_picked.uuid)

    var type = trait_picked.uuid.split(':')[1] # poem:gan_ye:defaultName:1
    var level = trait_picked.uuid.split(':')[3]
    Logging.debug('PoemTypeChooseOperator: Extracted type=%s, level=%s' % [type, level])

    if level < lowest_poem_level:
        Logging.debug('PoemTypeChooseOperator: Level %s below threshold %s, executing rejected_result' % [level, lowest_poem_level])
        rejected_result.operate()
        return
        
    if type in accepted_poem_types:
        Logging.debug('PoemTypeChooseOperator: Type %s in accepted_poem_types, executing accpeted_result' % type)
        accpeted_result.operate()
    else:
        Logging.debug('PoemTypeChooseOperator: Type %s in rejected_poem_type, executing rejected_result' % type)
        rejected_result.operate()
