class_name BaseOption extends Resource

@export var description := ''
func init(_context: Dictionary) -> Dictionary:
	# 子类可以重写这个方法来初始化选项逻辑
	return _context
