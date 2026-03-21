class_name PropertyOperator extends StatOperator

@export_enum(
    'literary_fame',
    'official_prestige',
    'talent',
    'money'
) var property := ''


@export var value: int = 0

func operate():
    PlayerState.change_stat(property,value)