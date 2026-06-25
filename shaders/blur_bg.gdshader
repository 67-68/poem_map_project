shader_type canvas_item;

// WebGL 兼容版：去掉 filter_linear_mipmap（WebGL 无 mipmap 链），
// 用手动多点采样 box blur 替代 textureLod 的 mipmap 模糊。
// kernel 扩展到 ±6（13×13 = 169 采样点），blur_amount 有效范围 0~8。
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

uniform float blur_amount : hint_range(0.0, 8.0) = 2.5;
uniform float darken_amount : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	int radius = int(blur_amount);
	float total_weight = 0.0;
	vec4 color = vec4(0.0);

	vec2 texel_size = 1.0 / vec2(textureSize(screen_texture, 0));

	for (int x = -6; x <= 6; x++) {
		for (int y = -6; y <= 6; y++) {
			if (abs(x) > radius || abs(y) > radius) {
				continue;
			}
			vec2 offset = vec2(float(x), float(y)) * texel_size * 2.8;
			color += texture(screen_texture, SCREEN_UV + offset);
			total_weight += 1.0;
		}
	}

	color /= total_weight;

	// 压暗
	color.rgb *= (1.0 - darken_amount);

	COLOR = color;
}
