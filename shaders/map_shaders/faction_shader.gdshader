/*
 * ----------------------------------------------------------------
 * 大唐地理系统 - 势力染色层 (Faction Overlay V3.0)
 * ----------------------------------------------------------------
 * 资深架构师评价：一旦解开了 Modulate 的封印，
 * 你的版图将如同开元盛世一般，正式降临在三维大地之上。
 * ----------------------------------------------------------------
 */
shader_type canvas_item;

// 引入我们的高度图“锦囊”
#include "res://shaders/map_shaders/height_logic.gdshaderinc"

// 经过 MapRebaker 洗过的索引图 (R通道存 ID)
uniform sampler2D color_to_idx_map : hint_default_black, filter_nearest, repeat_disable;
// 512x1 的势力调色板
uniform sampler2D faction_lut : filter_nearest, repeat_disable;

uniform float faction_alpha : hint_range(0.0, 1.0) = 0.6;
uniform float faction_intensity : hint_range(0.0, 2.0) = 1.0; // 控制色彩饱和度

void vertex() {
	// 确保这一层完美契合地形
	vec3 v3 = vec3(VERTEX.x, VERTEX.y, 0.0);
	calculate_vertex_height(v3, UV);
	VERTEX = v3.xy;
}

void fragment() {
	// 1. 采样重焙后的索引
	vec4 index_sample = texture(color_to_idx_map, UV);
	float province_index = index_sample.r;
	
	// 2. 判定有效区域 (Alpha 必须由 MapRebaker 设为 1.0)
	float mask = step(0.001, index_sample.a);
	
	// 3. 查表：核心寻址逻辑
	// 既然重焙时存的是 (id / 512.0)，这里直接用 R 值作为 X 采样坐标
	vec4 faction_color = texture(faction_lut, vec2(province_index, 0.5));
	
	// 4. 调试输出：如果看到白块，说明是重焙失败的像素；如果看到颜色，说明 LUT 运作正常
	vec3 final_rgb = faction_color.rgb * faction_intensity;
	
	// 5. 最终合成
	// 使用 mask 控制哪里显示，使用 faction_alpha 控制整体透明度
	COLOR = vec4(final_rgb, mask * faction_alpha);
}