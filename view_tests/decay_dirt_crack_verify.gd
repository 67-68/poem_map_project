extends Control
## decay_dirt_crack_verify.gd — 验证 shader 的极简脚本
## 在 _ready 中动态创建两类 NoiseTexture2D 并注入到 ShaderMaterial
##
## 纹理资源由项目方自行创建 .tres 文件后替换为本脚本的 noise 创建逻辑

const VERIFY_SIZE := Vector2(400, 400)

@onready var _texture_rect: TextureRect = $TextureRect
@onready var _material: ShaderMaterial = _texture_rect.material as ShaderMaterial


func _ready() -> void:
	# 1. 确保 TextureRect 有纹理可采样（否则 shader 全透明）
	if _texture_rect.texture == null:
		# 纯白 placeholder：让脏污和裂纹在白色底上可见
		var placeholder := PlaceholderTexture2D.new()
		placeholder.size = VERIFY_SIZE
		_texture_rect.texture = placeholder

	# 2. 创建脏污噪声纹理（Cellular, Euclid Distance）
	var dirt_noise_tex := _make_noise(
		0.025,  # frequency
		3,      # fractal_octaves
		2.0,    # fractal_lacunarity
		false   # distance2 (Euclidean)
	)

	# 3. 创建裂纹噪声纹理（Cellular, Distance2 → 更长、更线性的裂缝）
	var crack_noise_tex := _make_noise(
		0.015,
		2,
		2.5,
		true   # distance2 (Manhattan-like → 锐利线条感)
	)

	# 4. 注入到 ShaderMaterial
	_material.set_shader_parameter("dirt_noise", dirt_noise_tex)
	_material.set_shader_parameter("crack_noise", crack_noise_tex)


func _make_noise(freq: float, octaves: int, lacunarity: float, use_distance2: bool) -> NoiseTexture2D:
	var fast_noise := FastNoiseLite.new()
	fast_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	fast_noise.frequency = freq
	fast_noise.fractal_octaves = octaves
	fast_noise.fractal_lacunarity = lacunarity
	fast_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	if use_distance2:
		fast_noise.cellular_distance_function = FastNoiseLite.DISTANCE_MANHATTAN
	else:
		fast_noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN

	var tex := NoiseTexture2D.new()
	tex.noise = fast_noise
	tex.seamless = true
	tex.width = 512
	tex.height = 512
	return tex
