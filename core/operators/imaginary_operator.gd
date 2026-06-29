@tool
class_name ImaginaryOperator extends BaseOperator

@export var imaginary_name: String # 两段
@export_enum("upgrade_1", "downgrade_1") var operation: String


func operate():
    var ima = Database.get_imaginary(imaginary_name) as ImaginaryConcept
    if not ima:
        Logging.err('imagery operator: can not found imagery: %s' % imaginary_name)
        return
    
    match operation:
        'upgrade_1':
            if not ima.current_level == 3:
                ima.current_level += 1
                Logging.info('imagery operator: %s upgraded to level %d' % [imaginary_name, ima.current_level])
                EventBus.imaginary_changed.emit()
        'downgrade_1':
            if not ima.current_level == 0:
                ima.current_level -= 1
                Logging.info('imagery operator: %s downgraded to level %d' % [imaginary_name, ima.current_level])
                EventBus.imaginary_changed.emit()
        _:
            Logging.err('imagery operator: unknown operation: %s' % operation)