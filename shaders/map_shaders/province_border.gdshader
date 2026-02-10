shader_type canvas_item;

uniform sampler2D index_map;
uniform sampler2D height_map;
uniform float height_scale;

// --- 笔触控制 ---
uniform float line_width : hint_range(0.0, 10.0) = 2.5;     // 调高它！建议 2.5 - 4.0
uniform float ink_roughness : hint_range(0.0, 2.0) = 1.0;  // 抖动强度
uniform float dry_brush : hint_range(0.0, 1.0) = 0.5;      // 枯笔程度 (越高越虚)

// --- 噪声控制 ---
uniform sampler2D noise_tex : hint_default_white;
uniform float noise_freq = 100.0;                          // 频率！必须高，建议 50-150

void vertex() {
    float h = texture(height_map, UV).r;
    VERTEX.y -= h * height_scale;
}

void fragment() {
    // 1. 高频噪声采样 (重点：UV 缩放要大)
    vec2 noise_uv = UV * noise_freq + TIME * 0.01;
    float n = texture(noise_tex, noise_uv).r;
    
    // 2. 核心：坐标扰动 (UV Jitter)
    // 用噪声偏置 UV，让采样点“变歪”，从而产生毛刺边
    vec2 ps = TEXTURE_PIXEL_SIZE;
    vec2 jitter = (vec2(n) - 0.5) * ps * ink_roughness * 10.0;
    vec2 uv = UV + jitter;
    
    // 3. 增强型边缘检测 (4 向采样以加粗线条)
    vec4 c = texture(index_map, uv);
    vec4 r = texture(index_map, uv + vec2(ps.x * line_width, 0.0));
    vec4 l = texture(index_map, uv - vec2(ps.x * line_width, 0.0));
    vec4 u = texture(index_map, uv - vec2(0.0, ps.y * line_width));
    vec4 d = texture(index_map, uv + vec2(0.0, ps.y * line_width));
    
    float edge = 0.0;
    // 只要周围任一方向颜色不同，判定为边
    if (distance(c, r) > 0.1 || distance(c, l) > 0.1 || distance(c, u) > 0.1 || distance(c, d) > 0.1) {
        edge = 1.0;
    }
    
    // 4. 枯笔效果 (使用 step/smoothstep 让噪声真正“切开”线条)
    // 线条透明度不再是线性加法，而是根据噪声阈值决定“留白”
    float alpha_mask = smoothstep(dry_brush, dry_brush + 0.2, n);
    float final_alpha = edge * alpha_mask;
    
    // 浓墨色
    vec3 ink_rgb = vec3(0.05, 0.05, 0.05); 
    COLOR = vec4(ink_rgb, final_alpha);
}