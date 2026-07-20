@tool
class_name SystemOperator extends BaseOperator

@export var command: String # 例如 "game_over", "return_main"
@export var death_hint: String

func operate() -> void:
    Logging.info('SystemOperator.operate: command="%s", death_hint="%s"' % [command, death_hint])
    
    match command:
        "game_over", "game over":
            # 1. 先检查 death_hint，避免空数据导致软死锁（时间冻结但无 UI 显示）
            #    death_hint 为空时从 GameState.death_reason 兜底（DeathEvent.on_enter 路径）
            if not death_hint:
                if GameState.death_reason:
                    death_hint = GameState.death_reason
                    Logging.info('SystemOperator.operate: death_hint empty, fallback to GameState.death_reason="%s"' % death_hint)
                else:
                    Logging.err('SystemOperator.operate: death_hint is empty and GameState.death_reason is also empty, game over aborted')
                    return
            
            # 2. 设置游戏结束状态锁，阻断后续事件链继续触发
            GameState.is_game_over = true
            Logging.info('SystemOperator.operate: GameState.is_game_over = true')
            
            # 3. 冻结时间流逝（必须放在 death_hint 检查之后）
            TimeService.pause()
            Logging.info('SystemOperator.operate: time paused')
            
            # 4. 唤起墓碑结算 UI
            Logging.info('SystemOperator.operate: emitting show_tombstone_screen signal')
            EventBus.show_tombstone_screen.emit(death_hint)
            
        "return_main":
            # Resource 子类无法直接调用 get_tree()，需要 EventBus 信号中转
            Logging.warn('SystemOperator.operate: return_main triggered, emitting return_to_main_menu signal')
            EventBus.request_return_to_main_menu.emit()
            
        _:
            Logging.err('SystemOperator.operate: unknown command "%s"' % command)
