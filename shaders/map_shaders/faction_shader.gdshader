/*
 * ----------------------------------------------------------------
 * 大唐地理系统 - 诊断用 Shader (The Diagnostic)
 * ----------------------------------------------------------------
 * 模式 0: 显示原始 Index Map 的 Alpha (检查 Mask)
 * 模式 1: 显示重焙后的 ID 值 (检查 Bake 结果)
 * 模式 2: 显示 LUT 的第一行颜色 (检查 Faction 数据)
 * ----------------------------------------------------------------
 */
shader_type canvas_item;

uniform sampler2D color_to_idx_map : filter_nearest;
uniform sampler2D faction_lut : filter_nearest;
uniform int debug_mode : hint_range(0, 2) = 0;

#include "res://shaders/map_shaders/height_logic.gdshaderinc"

void vertex() {
	vec3 v3 = vec3(VERTEX.x, VERTEX.y, 0.0);
	calculate_vertex_height(v3, UV);
	VERTEX = v3.xy;
}

void fragment() {
	vec4 index_sample = texture(color_to_idx_map, UV);
	
	if (debug_mode == 0) {
		// 诊断 Mask：如果有颜色显示白色，背景黑色
		float m = step(0.001, index_sample.a);
		COLOR = vec4(vec3(m), 1.0);
	} 
	else if (debug_mode == 1) {
		// 诊断 ID：如果看到红色渐变，说明 ID 注入成功；如果看到纯白，说明 Bake 匹配失败
		COLOR = vec4(index_sample.rgb, 1.0);
	}
	else if (debug_mode == 2) {
		// 诊断 LUT：直接把 LUT 铺满全图，看看是不是传了一张空贴图进来
		vec4 lut_sample = texture(faction_lut, vec2(UV.x, 0.5));
		COLOR = lut_sample;
	}
}