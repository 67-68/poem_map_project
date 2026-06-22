shader_type canvas_item;

// ============================================================
// decay_dirt_crack.gdshader — 纸张脏污侵蚀 + 裂纹撕裂着色器
//
// 驱动方式: uniform progress (0.0→完好出城, 1.0→抵达奉先, 彻底毁灭)
// 需要两张 NoiseTexture2D 分别驱动脏污和裂纹
// ============================================================

// --- 脏污噪声纹理：暗区=污渍斑块，亮区=干净区域 ---
uniform sampler2D dirt_noise : repeat_enable;
// --- 裂纹噪声纹理：暗区=裂纹路径 ---
uniform sampler2D crack_noise : repeat_enable;
// --- 唯一驱动力：0.0 (完好) → 1.0 (彻底毁灭) ---
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// --- 脏污颜色 (焦黑/茶渍色) ---
uniform vec4 dirt_color : source_color = vec4(0.12, 0.08, 0.04, 1.0);
// --- 裂纹边缘燃烧色 (纸张烧焦的棕褐) ---
uniform vec4 burn_edge_color : source_color = vec4(0.50, 0.14, 0.02, 0.85);
// --- 裂纹边缘宽度 (值越小边缘越锋利) ---
uniform float crack_edge_width : hint_range(0.0, 0.08) = 0.025;

void fragment() {
	// 1. 采样底图
	vec4 base_tex = texture(TEXTURE, UV);

	// 2. 采样噪点
	float dirt_val = texture(dirt_noise, UV).r;
	float crack_val = texture(crack_noise, UV).r;

	// ==========================================
	// Phase A: 脏污侵蚀 (Dirt Erosion)
	// ==========================================
	// dirt_val: 0=暗斑(脏), 1=亮区(干净)
	// dirt_contribution = 1 - dirt_val: 0=干净, 1=最脏
	// dirt_threshold 从 1.0(progress=0, 无脏污) 滑到 -0.3(progress=1, 全屏脏污)
	float dirt_contribution = 1.0 - dirt_val;
	float dirt_threshold_low = 1.0 - progress * 1.3;
	float dirt_intensity = smoothstep(dirt_threshold_low, dirt_threshold_low + 0.2, dirt_contribution);

	vec4 final_color = mix(base_tex, dirt_color, dirt_intensity);

	// ==========================================
	// Phase B: 物理撕裂 + 边缘焦灼 (Structural Collapse)
	// ==========================================
	// 裂纹阈值：前 20% 进度强制为 0（无裂纹），之后线性爬升
	float crack_threshold = max(0.0, (progress - 0.2) * 1.5);

	if (crack_val < crack_threshold) {
		// 裂纹命中 → 彻底抹除像素
		COLOR.a = 0.0;
	} else {
		// 裂纹边缘焦灼：阈值附近产生棕褐色渐变
		// crack_edge: 0=紧贴裂口, 1=安全区
		float crack_edge = smoothstep(crack_threshold, crack_threshold + crack_edge_width, crack_val);
		float burn_factor = (1.0 - crack_edge) * burn_edge_color.a;

		// 将脏污后的颜色向燃烧色混合（仅限裂纹边缘）
		vec3 burned = mix(final_color.rgb, burn_edge_color.rgb, burn_factor);

		COLOR.rgb = burned;
		COLOR.a = final_color.a * base_tex.a;
	}
}
