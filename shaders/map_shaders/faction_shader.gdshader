shader_type canvas_item;
uniform sampler2D color_to_idx_map : filter_nearest;

#include "res://shaders/map_shaders/height_logic.gdshaderinc"

void vertex() {
    vec3 v3 = vec3(VERTEX.x, VERTEX.y, 0.0);
    calculate_vertex_height(v3, UV);
    VERTEX = v3.xy;
}

void fragment() {
    vec4 data = texture(color_to_idx_map, UV);
    
    // 如果采样到了 ID (Alpha > 0)，直接涂成亮紫色！
    // 如果采样不到，涂成半透明黄色。
    if (data.a > 0.1) {
        COLOR = vec4(1.0, 0.0, 1.0, 1.0); // 亮紫色
    } else {
        COLOR = vec4(1.0, 1.0, 0.0, 0.2); // 半透明黄（代表 Mesh 本身在，但没数据）
    }
}