class_name SystemOperator extends BaseOperator

@export var command: String # 例如 "game_over", "return_main"

func operate() -> void:
    match command:
        "game_over":
            # 1. 冻结时间流逝
            TimeService.pause()
            # 2. 唤起那个极简的、只有诗词和墓志铭的结算 UI 覆盖层
            Global.show_tombstone_screen.emit()
        "return_main":
            # 卸载当前场景，回到主菜单
            Logging.err('dont implement return to main yet')
            # get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")