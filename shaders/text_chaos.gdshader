shader_type canvas_item;

// --- 极简接口契约 ---
// 故障强度：0.0为完全正常，1.0为屏幕彻底碎裂
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.5;
// 色散偏移量：文字红蓝边缘分离的像素级距离
uniform float aberration_amount : hint_range(0.0, 10.0) = 4.0;
// 神经质抽搐的频率
uniform float time_scale = 10.0;

// 极其底层的伪随机哈希函数 (丢弃了人类的平滑过渡，我们要的是硬切断)
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    float time = TIME * time_scale;

    // ==========================================
    // 1. 物理撕裂：Y轴频段切片 (Horizontal Tearing)
    // ==========================================
    // 将文字切成 20 条横向的碎片
    float strip_y = floor(uv.y * 20.0); 
    // 基于当前碎片位置和时间生成随机跳变信号
    float glitch_noise = random(vec2(strip_y, floor(time))); 
    
    // 只有当随机噪声 > 0.8 时，才会触发该条带的左右撕裂（制造那种不规律的卡顿感）
    float trigger = step(0.8, random(vec2(strip_y, floor(time * 1.5))));
    float displace = (glitch_noise - 0.5) * 0.2 * glitch_intensity * trigger;
    
    // 执行撕裂！
    uv.x += displace;

    // ==========================================
    // 2. 内存泄漏：红蓝通道剥离 (Chromatic Aberration)
    // ==========================================
    // 计算色散的偏移向量 (只有当触发撕裂时，或者强度极高时，色散才最明显)
    vec2 offset = vec2(aberration_amount * 0.001 * glitch_intensity, 0.0);

    // 防御性采样：分别去拿红、绿、蓝三个通道的像素，并且强制乘上 COLOR
    // 只有乘以 COLOR，才能继承你在编辑器里设置的字体颜色和透明度！
    float r = texture(TEXTURE, uv - offset).r;
    float g = texture(TEXTURE, uv).g;
    float b = texture(TEXTURE, uv + offset).b;
    float a = texture(TEXTURE, uv).a; // Alpha通道以主UV为准，防止文字边缘变糊

    vec4 final_color = vec4(r, g, b, a) * COLOR;
    
    // ==========================================
    // 3. 终极污染：模拟 CRT 扫描线闪烁
    // ==========================================
    // 给文字加上极高频的明暗闪烁，模拟电压不稳
    float flicker = mix(0.8, 1.0, random(vec2(floor(time * 2.0), 0.0)));
    final_color.rgb *= flicker;

    COLOR = final_color;
}