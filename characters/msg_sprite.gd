extends Sprite2D

func _ready() -> void:
	# 强制替换为 icon.svg 进行测试
	texture = load("res://icon.svg") 
	scale = Vector2(1, 1)
	modulate = Color.RED # 染成红色，显眼包
	z_index = 4096