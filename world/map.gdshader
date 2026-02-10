shader_type canvas_item;

// --- 变量输入 ---
uniform sampler2D index_map;      // 这里必须拖入那张五颜六色的索引图！
uniform float line_width = 1.0;
uniform float ink_roughness = 0.5; // 墨迹粗糙度

void fragment() {
    vec2 uv = UV;
    vec2 ps = TEXTURE_PIXEL_SIZE;
    
    // 采样中心和四周的颜色
    vec4 c = texture(index_map, uv);
    vec4 r = texture(index_map, uv + vec2(ps.x * line_width, 0.0));
    vec4 d = texture(index_map, uv + vec2(0.0, ps.y * line_width));
    
    // 如果颜色不同，说明是边界
    float edge = 0.0;
    if (distance(c, r) > 0.1 || distance(c, d) > 0.1) {
        edge = 1.0;
    }
    
    // 加入噪声让线条看起来像毛笔画的
    float noise = texture(TEXTURE, uv * 5.0 + TIME * 0.1).r;
    edge *= (0.8 + noise * ink_roughness);
    
    // 最终颜色输出：原有颜色 + 黑色墨线
    vec4 base_color = texture(TEXTURE, uv);
    COLOR = mix(base_color, vec4(0.1, 0.1, 0.1, 1.0), edge);
}