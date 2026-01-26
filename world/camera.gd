extends Camera2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# 建议的参数
@export var speed: float = 500.0
@export var friction: float = 0.1 # 摩擦力/平滑度

var velocity: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	# 1. 这种写法允许斜向移动，且逻辑清晰
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("left_move", "right_move")
	input_dir.y = Input.get_axis("up_move", "down_move")
	
	# 2. 计算目标速度
	var target_velocity = input_dir.normalized() * speed
	a
	# 3. 使用 lerp 平滑速度（产生惯性效果）
	# 这样松开按键后，相机会滑行一小段，手感极佳
	velocity = velocity.lerp(target_velocity, friction)
	
	# 4. 最终应用位置
	position += velocity * delta