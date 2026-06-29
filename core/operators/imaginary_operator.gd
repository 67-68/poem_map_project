@tool
class_name ImaginaryOperator extends BaseOperator

@export var imaginary_name: String # 两段
@export_enum("upgrade_1", "downgrade_1") var operation: String


func operate():
    var ima = Database.get_imaginary(imaginary_name) as ImaginaryTag
    if not ima:
        Logging.err('imagery operator: can not found imagery: %s' % imaginary_name)
        return
    
    match operation:
        'upgrade_1':
            if not ima.current_level == 3:
                ima.current_level += 1
                # 播放意象升级音效（AudioManager 统一管理 0.4s 防重叠间隔）
                AudioManager.play_imaginary_sound(ima.current_level)
        'downgrade_1':
            if not ima.current_level == 0: ima.current_level -= 1
        _:
            Logging.err('imagery operator: unknown operation: %s' % operation)