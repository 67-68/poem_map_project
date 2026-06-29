@tool
class_name ImaginarySetLevelOperator extends BaseOperator
## 设置两段意象等级操作符 — 由 imaginary_set_level DSL 解析生成。
##
## 直接设置指定意象的 current_level（0-2）。
## 不同于 ImaginaryOperator 的 upgrade_1/downgrade_1（+1/-1），
## 此操作符将等级直接设置为目标值。
##
## DSL 语法: imaginary_set_level(name=emotion:ambition, level=2)

## 两段意象名称（如 emotion:ambition）
@export var imaginary_name: String
## 目标等级（0-2）
@export var target_level: int = 0


func operate():
	Logging.info("ImaginarySetLevelOperator.operate: 开始执行，imaginary_name='%s', target_level=%d" % [imaginary_name, target_level])

	if imaginary_name.is_empty():
		Logging.err("ImaginarySetLevelOperator.operate: imaginary_name 为空，跳过")
		return

	if target_level < 0 or target_level > 2:
		Logging.err("ImaginarySetLevelOperator.operate: target_level=%d 超出范围 [0, 2]，跳过" % target_level)
		return

	var ima = Database.get_imaginary(imaginary_name) as ImaginaryConcept
	if not ima:
		Logging.err("ImaginarySetLevelOperator.operate: 在 Database.imaginaries 中未找到意象 '%s'" % imaginary_name)
		return

	var old_level = ima.current_level
	ima.current_level = target_level
	Logging.info("ImaginarySetLevelOperator.operate: 意象 '%s' 等级从 %d 设置为 %d" % [imaginary_name, old_level, target_level])

	if target_level != old_level:
		Logging.info("ImaginarySetLevelOperator.operate: 等级变化，发射 imaginary_changed 信号")
		EventBus.imaginary_changed.emit()
