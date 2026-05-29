@tool
class_name BaseProvider extends Resource

@export var requirement: BaseRequirements

func init(_context: Dictionary) -> Dictionary:
	return _context

func provide(_context) -> Array: # event option, 只读context
	return []