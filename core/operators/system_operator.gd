class_name SystemOperator extends BaseOperator

@export var command: String # 例如 "game_over", "return_main"
@export var death_hint: String

func operate() -> void:
    match command:
        "game_over", "game over":
            # 1. 冻结时间流逝
            TimeService.pause()
            # 2. 唤起那个极简的、只有诗词和墓志铭的结算 UI 覆盖层
            if not death_hint:
                Logging.err('can not find death hint')
                return
            Global.show_tombstone_screen.emit(death_hint)
        "return_main":
            # 卸载当前场景，回到主菜单
            Logging.err('dont implement return to main yet')
            # get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
        _:
            Logging.err('wha the hell is ' + command)