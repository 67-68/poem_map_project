shader_type canvas_item;

// 【核心修改】通过 hint 强制禁用过滤和重复，这比在 UI 里找半天有效得多
uniform sampler2D index_map : hint_default_black, filter_nearest, repeat_disable;
uniform sampler2D paper_index : source_color, filter_linear, repeat_enable; // 宣纸可以模糊点
uniform vec4 selected_id_color; // CPU传过来的州颜色
uniform float highligh_strength: hint_range(0.0,1,0) = 0.3;

uniform sampler2D height_map;
uniform float height_scale;

void vertex() {
    float h = texture(height_map, UV).r;
    VERTEX.y -= h * height_scale;
}

void fragment() {
	vec4 base_color = texture(TEXTURE, UV);
	
	vec4 paper = texture(paper_index, UV);

	vec4 current_id = texture(index_map,UV);

	vec3 diff = abs(current_id.rgb - selected_id_color.rgb);
    float threshold = 0.01; // 稍微放宽一点，别那么死板 😡
    
    float is_selected = 0.0;
    if (diff.r < threshold && diff.g < threshold && diff.b < threshold) {
        is_selected = 1.0;
    }

	vec4 final_output = mix(paper,base_color, 0.8);
	vec4 highlight_tint = vec4(0.8,0.6,0.2,1.0);
	final_output = mix(final_output, highlight_tint, is_selected * highligh_strength);
	COLOR = final_output;
}