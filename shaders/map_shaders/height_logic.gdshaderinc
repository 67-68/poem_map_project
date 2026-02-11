uniform sampler2D height_map;
uniform float height_scale; // 山峰高度，乘以多少的参数
uniform float vertical_offset : hint_range(-1.0, 1.0) = 0.001; // 用于防止 Z-Fighting

void calculate_vertex_height(inout vec3 vertex, vec2 uv) {
	float h = texture(height_map,uv).r; // 读取高度图数据，使用UV直接从height_map获取像素点的颜色
	vertex.y -= h * height_scale; // 提升
	vertex.y -= vertical_offset;
}