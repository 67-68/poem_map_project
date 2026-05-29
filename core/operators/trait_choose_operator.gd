@tool
class_name PoemTypeChooseOperator extends BaseOperator

@export var poem_taste: PoemTaste = PoemTaste.new()
@export var key_to_get_poem_taste: String = 'poem_taste'
@export var property_multiplication: float = 1.0

func init(_context: Dictionary) -> Dictionary:
    #breakpoint
    if key_to_get_poem_taste and _context.get(key_to_get_poem_taste):
        var taste = _context.get(key_to_get_poem_taste)
        
        # 🛡️ 防御：如果 URN 里混入了逗号分隔的额外 kv（DSL 解析 bug 导致的脏数据），只取第一段
        if taste is String and taste.contains(","):
            var parts = taste.split(",")
            taste = parts[0].strip_edges()
            Logging.warn('PoemTypeChooseOperator.init: context["%s"] contains extra params after comma, extracting only the URN part: "%s"' % [key_to_get_poem_taste, taste])
        
        var taste_instance = URN.get_resource_through_urn(taste)
        if taste_instance is PoemTaste:
            poem_taste = taste_instance
            print('poem type choose operator: successfully get the taste')
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
    
    # ✅ 级联初始化三个 ChoiceResult，让内部的 FlagOperator 等能从 context 解析动态引用
    #breakpoint
    poem_taste.accepted_result.init(_context)
    poem_taste.rejected_result.init(_context)
    poem_taste.not_entered_result.init(_context)
    
    return _context

func operate():
    #breakpoint
    Logging.debug('PoemTypeChooseOperator: Starting operate()')
    var data = []
    for t in PlayerState.get_traits():
        var trait_ = Database.traits.get(t)
        if not trait_:
            Logging.err('PoemTypeChooseOperator: can not found trait %s' % t)
            continue
        # 🤓☝️ 只展示诗词类 trait（topic == "POEM"），排除社交/主线路线等
        if trait_.topic != "POEM":
            Logging.debug('PoemTypeChooseOperator: Skipping non-POEM trait %s (topic=%s)' % [t, trait_.topic])
            continue
        Logging.debug('PoemTypeChooseOperator: Found POEM trait %s' % t)
        data.append(trait_)

    Logging.debug('PoemTypeChooseOperator: Emitting start_picker with %d poem traits' % data.size())
    EventBus.start_picker.emit(data)
    var trait_picked = await EventBus.end_picking
    
    #breakpoint
    if not trait_picked:
        poem_taste.not_entered_result.operate()
        Logging.warn('trait not picked, left blank')
        return
    Logging.debug('PoemTypeChooseOperator: Trait picked - %s' % trait_picked.uuid)

    # 使用 trait 的 topic/specific_topic 字段，不再解析 UUID
    var trait_topic = trait_picked.topic
    var poem_type = trait_picked.specific_topic
    # 从 UUID 末尾提取等级（命名约定：poem_gan_ye_1 → 1）
    var level_str = trait_picked.uuid.split('_')[-1]
    var level = level_str.to_int()
    Logging.debug('PoemTypeChooseOperator: topic=%s, poem_type=%s, level=%d' % [trait_topic, poem_type, level])

    if level < poem_taste.lowest_poem_level:
        Logging.debug('PoemTypeChooseOperator: Level %s below threshold %s, executing rejected_result' % [level, poem_taste.lowest_poem_level])
        poem_taste.rejected_result.operate()
        return

    if poem_type in poem_taste.accepted_poem_types:
        Logging.debug('PoemTypeChooseOperator: Type %s in accepted_poem_types, executing accepted_result' % poem_type)
        poem_taste.accepted_result.operate()
    else:
        Logging.debug('PoemTypeChooseOperator: Type %s in rejected_poem_type, executing rejected_result' % poem_type)
        poem_taste.rejected_result.operate()
