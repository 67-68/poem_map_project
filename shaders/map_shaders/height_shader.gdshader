shader_type canvas_item;
uniform sampler2D height_map;
uniform float height_scale; // 山峰高度，乘以多少的参数
void vertex() {
	float h = texture(height_map,UV).r; // 读取高度图数据，使用UV直接从height_map获取像素点的颜色
	VERTEX.y -= h * height_scale; // 提升
}

void fragment() {
	vec4 skin_color = texture(TEXTURE,UV); // 获取texture的颜色

	float h = texture(height_map,UV).r; // 原本的高度
	float h_right = texture(height_map,UV + vec2(0.01,0.0)).r; // 稍微偏上一点的影子高度

	// 做一个差值
	float slope = clamp((h - h_right) * 5.0, 0.0, 1.0);
	COLOR = mix(skin_color,vec4(0.0, 0.0, 0.0, 1.0), slope * 0.3);
}