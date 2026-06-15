@tool
class_name EraOperator extends BaseOperator

## 目标时代标识（如 "ambition", "decline"）。
@export var era: String = ""

## 操作模式:
##   - set:   将 GameState.current_era 设为 era 的值
##   - clear: 将 GameState.current_era 清空（空字符串 = 无时代限制）
@export_enum("set", "clear") var mode: String = "set"

func operate():
    # 校验 era 值的合法性（仅 set mode 需要，通过注册表）
    if mode == "set" and not era.is_empty():
        if not ENUMS.is_valid_era(era):
            Logging.err('[EraOperator] invalid era value: "%s" — must be one of: %s' % [era, ", ".join(ENUMS.get_all_eras())])
            return

    match mode:
        "set":
            if era.is_empty():
                Logging.warn("[EraOperator] mode=set but era is empty, clearing current_era")
                GameState.current_era = ""
            else:
                GameState.current_era = era
            Logging.info('[EraOperator] switched current_era to "%s"' % GameState.current_era)
        "clear":
            GameState.current_era = ""
            Logging.info('[EraOperator] cleared current_era')
        _:
            Logging.err('[EraOperator] unknown mode: "%s"' % mode)

## 契约方法：返回该Operator引用的flag ID数组
func get_referenced_flags() -> Array:
    return []

## 契约方法：返回该Operator提供的flag ID数组
## EraOperator 不直接操作 flag，而是操作 GameState.current_era
func get_provided_flags() -> Array:
    return []

func get_demanded_flags() -> Array:
    return []
