shader_type canvas_item;
#include "res://shaders/map_shaders/height_logic.gdshaderinc"

void vertex() {
	vec3 v3 = vec3(VERTEX.x, VERTEX.y, 0.0);
	calculate_vertex_height(v3, UV);
	VERTEX = v3.xy;
}

void fragment() {
	vec4 skin_color = texture(TEXTURE,UV); // 获取texture的颜色

	float h = texture(height_map,UV).r; // 原本的高度
	float h_right = texture(height_map,UV + vec2(0.01,0.0)).r; // 稍微偏上一点的影子高度

	// 做一个差值
	float slope = clamp((h - h_right) * 5.0, 0.0, 1.0);
	COLOR = mix(skin_color,vec4(0.0, 0.0, 0.0, 1.0), slope * 0.3);
}