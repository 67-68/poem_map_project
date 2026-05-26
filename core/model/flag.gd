class_name Flag extends GameEntity

@export var val_bool := false
@export var val_int := 0
@export var val_str := ''
@export_enum(
    'str',
    'int',
    'bool'
) var type := ''

func append(val):
    Logging.debug('flag append called, type=%s, val=%s' % [type, val])
    if not type == 'int':
        Logging.err('type of flag is not int, can not append')
        return
    val_int += val
    Logging.debug('flag append success, new val_int=%s' % val_int)
    
func set_to(val):
    Logging.debug('flag set_to called, type=%s, val=%s' % [type, val])
    match type:
        'str':
            val_str = val
            Logging.debug('flag set_to str success, val_str=%s' % val_str)
        'int':
            val_int = val
            Logging.debug('flag set_to int success, val_int=%s' % val_int)
        'bool':
            val_bool = val
            Logging.debug('flag set_to bool success, val_bool=%s' % val_bool)
        _: Logging.err('what the hell is this type %s' % val)
    

# 先不管trait的效果，内生进化什么的就算了