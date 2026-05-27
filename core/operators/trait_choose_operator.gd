@tool
class_name PoemTypeChooseOperator extends BaseOperator

@export var poem_taste: PoemTaste = PoemTaste.new()
@export var key_to_get_poem_taste: String = ''
@export var property_multiplication: float = 1.0

func init(_context: Dictionary) -> Dictionary:
    if key_to_get_poem_taste and _context.get(key_to_get_poem_taste):
        var taste = _context.get(key_to_get_poem_taste)
        if taste is PoemTaste:
            poem_taste = taste
        else: Logging.err('poem type choose operator: the type of the data in the context is not the type of taste')
    
    # Apply property_multiplication to the context
    if _context.has("property_multiplication"):
        var ctx_val = _context["property_multiplication"]
        if typeof(ctx_val) in [TYPE_FLOAT, TYPE_INT]:
            var new_val = float(ctx_val) * property_multiplication
            Logging.debug("PoemTypeChooseOperator: Multiplying context property_multiplication %.2f by operator's %.2f → %.2f" % [float(ctx_val), property_multiplication, new_val])
            _context["property_multiplication"] = new_val
        else:
            Logging.warn("PoemTypeChooseOperator: context property_multiplication has unexpected type %s, skipping multiplication" % typeof(ctx_val))
    else:
        Logging.debug("PoemTypeChooseOperator: Setting context property_multiplication to operator's value %.2f" % property_multiplication)
        _context["property_multiplication"] = property_multiplication
    
    return _context

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
        poem_taste.not_entered_result.operate()
        Logging.warn('trait not picked, left blank')
        return
    Logging.debug('PoemTypeChooseOperator: Trait picked - %s' % trait_picked.uuid)

    var type = trait_picked.uuid.split(':')[1] # poem:gan_ye:defaultName:1
    var level = trait_picked.uuid.split(':')[3]
    Logging.debug('PoemTypeChooseOperator: Extracted type=%s, level=%s' % [type, level])

    if level < poem_taste.lowest_poem_level:
        Logging.debug('PoemTypeChooseOperator: Level %s below threshold %s, executing rejected_result' % [level, poem_taste.lowest_poem_level])
        poem_taste.rejected_result.operate()
        return

    if type in poem_taste.accepted_poem_types:
        Logging.debug('PoemTypeChooseOperator: Type %s in accepted_poem_types, executing accepted_result' % type)
        poem_taste.accepted_result.operate()
    else:
        Logging.debug('PoemTypeChooseOperator: Type %s in rejected_poem_type, executing rejected_result' % type)
        poem_taste.rejected_result.operate()
