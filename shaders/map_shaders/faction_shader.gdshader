shader_type canvas_item;
// 势力染色的东西
uniform sampler2D color_to_idx_map: hint_default_black, filter_nearest, repeat_disable;
uniform sampler2D faction_lut: filter_nearest, repeat_disable;
uniform float faction_intensity: hint_range(0.0, 1.0) = 1.0;

#include "res://shaders/map_shaders/height_logic.gdshaderinc"
#include "res://shaders/map_shaders/index_map.gdshaderinc"

void vertex() {
	vec3 v3 = vec3(VERTEX.x, VERTEX.y, 0.0);
	calculate_vertex_height(v3, UV);
	VERTEX = v3.xy;
}

void fragment() {
    // 1. 获取重焙后的索引值 (0.0 - 1.0)
    // 注意：一定要用 filter_nearest，否则州边界会糊掉！😡
    vec4 index_sample = texture(color_to_idx_map, UV);
    float province_index = index_sample.r; 
    
    // 2. 检查这块地方是不是有效的州
    // 如果 index_map 的 Alpha 是 0，说明是背景
    float mask = step(0.001, index_sample.a);
    
    // 3. 直接拿这个 index 去 LUT 里查颜色 (LUT 是 1D 查找表)
    // 为什么可以直接用 province_index？
    // 因为你在 CPU 里存的是 idx/255.0，而 Shader 采样出来也是 0.0-1.0
    // 它们的比例是完美的 1:1 映射。🤓☝️
    vec2 lut_uv = vec2(province_index, 0.5);
    vec4 faction_color = texture(faction_lut, lut_uv);
    
    // 4. 输出颜色
    // 加上你的强度控制参数
    COLOR = vec4(faction_color.rgb, mask * faction_intensity);
}