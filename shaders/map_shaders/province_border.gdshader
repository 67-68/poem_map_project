shader_type canvas_item;

uniform sampler2D index_map;
uniform sampler2D height_map;
uniform float height_scale;
uniform float line_width : hint_range(0.0, 5.0) = 1.0;
uniform float ink_roughness : hint_range(0.0, 1.0) = 0.5;
uniform float line_lower_limit : hint_range(0.0, 1.0) = 0.8;

// 建议在 Inspector 传入一个专门的 NoiseTexture2D
uniform sampler2D noise_tex : hint_default_white; 

void vertex() {
    // 保持位移同步
    float h = texture(height_map, UV).r;
    VERTEX.y -= h * height_scale;
}

void fragment() {
    vec2 uv = UV;
    vec2 ps = TEXTURE_PIXEL_SIZE;
    
    // 1. 边缘检测
    vec4 c = texture(index_map, uv);
    vec4 r = texture(index_map, uv + vec2(ps.x * line_width, 0.0));
    vec4 d = texture(index_map, uv + vec2(0.0, ps.y * line_width));
    
    float edge = 0.0;
    // 增加一点点容差
    if (distance(c, r) > 0.05 || distance(c, d) > 0.05) {
        edge = 1.0;
    }
    
    // 2. 噪声扰动 (使用专门的 noise_tex)
    float noise = texture(noise_tex, uv * 2.0 + TIME * 0.05).r;
    float final_edge = edge * (line_lower_limit + noise * ink_roughness);
    
    // 3. 核心修正：只输出墨色和透明度
    // 我们不需要 mix，我们要的是：如果是边，就有颜色；如果不是，就透明。
    vec3 ink_rgb = vec3(0.1, 0.1, 0.1); // 浓墨色
    
    // COLOR 的 alpha 值直接由 final_edge 决定
    COLOR = vec4(ink_rgb, final_edge);
}
