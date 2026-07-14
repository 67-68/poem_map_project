@tool
class_name MultiBuffOperator extends BaseOperator
## MultiBuffOperator — 复合 BuffOperator 容器
##
## 当理念的某级包含多个 BuffOperator 时使用。
## operate() 遍历子 buff 注入 source_uuid 并执行。
## on_exit() 遍历子 buff 注入 source_uuid 并执行清理。

@export var buffs: Array[BuffOperator] = []

var source_uuid: String = ""


func operate():
	if buffs.is_empty():
		Logging.warn("MultiBuffOperator.operate: buffs 为空，跳过")
		return
	for buff in buffs:
		if buff:
			buff.source_uuid = source_uuid
			buff.operate()
	Logging.info("MultiBuffOperator.operate: 执行了 %d 个子 buff" % buffs.size())


func on_exit(_context: Dictionary) -> Dictionary:
	if buffs.is_empty():
		Logging.warn("MultiBuffOperator.on_exit: buffs 为空，跳过")
		return _context
	for buff in buffs:
		if buff:
			buff.source_uuid = source_uuid
			buff.on_exit(_context)
	Logging.info("MultiBuffOperator.on_exit: 清理了 %d 个子 buff" % buffs.size())
	return _context


func describe_preview() -> String:
	if buffs.is_empty():
		return ""
	var parts: Array[String] = []
	for buff in buffs:
		if buff:
			var desc := buff.describe_preview()
			if not desc.is_empty():
				parts.append(desc)
	return " | ".join(parts)


func init(_context: Dictionary) -> Dictionary:
	for buff in buffs:
		if buff:
			buff.init(_context)
	return _context
