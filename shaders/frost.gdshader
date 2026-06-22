shader_type canvas_item;

// --- 极简契约 ---
uniform sampler2D frost_noise : repeat_enable;
// 唯一驱动力：0.0 (未结霜) -> 1.0 (彻底冻结)
uniform float freeze_progress : hint_range(0.0, 1.0) = 0.0;
// 惨白色/冰蓝色
uniform vec4 frost_color : source_color = vec4(0.85, 0.9, 0.95, 1.0); 

void fragment() {
    // 1. 采样底图 (你那焦黑的残纸)
    vec4 base_tex = texture(TEXTURE, UV);
    
    // 2. 采样冰晶噪点
    float noise_val = texture(frost_noise, UV).r;
    
    // ==========================================
    // 核心物理运算：自下而上的深渊吞噬 (Bottom-Up Mask)
    // Godot 的 2D UV.y 是上 0 下 1。
    // ==========================================
    // 计算当前冻结线的高度，留一点平滑过渡区间 (0.2)
    float current_freeze_line = 1.0 - freeze_progress; 
    float vertical_mask = smoothstep(current_freeze_line, current_freeze_line + 0.2, UV.y);
    
    // ==========================================
    // 冰晶凝结逻辑 (Crystallization)
    // ==========================================
    // 只有在噪点值符合阈值，且处于冻结线以下的部分，才会结霜
    // 随着进度加深，霜的密度（阈值）越来越大
    float frost_intensity = smoothstep(0.7 - (freeze_progress * 0.5), 0.9, noise_val) * vertical_mask;
    
    // 将底层颜色与白霜颜色混合，模拟冰层的覆盖感
    vec4 final_color = mix(base_tex, frost_color, frost_intensity);
    
    COLOR = final_color;
    COLOR.a *= base_tex.a; // 保留原生 Alpha
}
