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
            Logging.info('poem type choose operator: successfully get the taste')
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
        var trait_ = Database.get_trait(t)
        if not trait_:
            Logging.err('PoemTypeChooseOperator: can not found trait %s' % t)
            continue
        # 🤓☝️ 只展示诗词类 trait（is Poem），排除社交/主线路线等
        if not (trait_ is Poem):
            Logging.debug('PoemTypeChooseOperator: Skipping non-Poem trait %s' % t)
            continue
        Logging.debug('PoemTypeChooseOperator: Found Poem trait %s' % t)
        data.append(trait_)

    # 🏗️ 不再直接 await end_picking，改为推入事件栈顶
    # 这样 Picker 受 _is_active 保护，不会被栈上新事件覆盖
    Logging.debug('PoemTypeChooseOperator: Pushing picker to stack with %d poem traits' % data.size())
    EventBus.push_item_picker.emit(data, _on_trait_picked)


func _on_trait_picked(trait_picked):
    #breakpoint
    if not trait_picked:
        poem_taste.not_entered_result.operate()
        Logging.warn('trait not picked, left blank')
        return
    Logging.debug('PoemTypeChooseOperator: Trait picked - %s' % trait_picked.uuid)

    # V6: poem_level 已删除，仅按 poem_type 匹配
    var trait_topic = trait_picked.topic
    var poem_type = trait_picked.specific_topic
    Logging.debug('PoemTypeChooseOperator: topic=%s, poem_type=%s' % [trait_topic, poem_type])

    if poem_type in poem_taste.accepted_poem_types:
        Logging.debug('PoemTypeChooseOperator: Type %s in accepted_poem_types, executing accepted_result' % poem_type)
        poem_taste.accepted_result.operate()
    else:
        Logging.debug('PoemTypeChooseOperator: Type %s in rejected_poem_type, executing rejected_result' % poem_type)
        poem_taste.rejected_result.operate()
    
    # 🔥 过没过都扣除对应的诗词（但不进入 picker 的不扣）
    PlayerState.remove_trait(trait_picked.uuid)
    Logging.debug('PoemTypeChooseOperator: 诗词已被消耗: %s' % trait_picked.uuid)
