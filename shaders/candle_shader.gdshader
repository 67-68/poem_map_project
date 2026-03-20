shader_type canvas_item;

// 0.0 = 完好无损，1.0 = 烧成灰烬
uniform float raw_burn_progress : hint_range(0.0, 1.0) = 0.0; 

// 边缘羽化程度，拒绝像素锯齿
uniform float edge_softness : hint_range(0.001, 0.1) = 0.02; 

// 燃烧边缘的火星/暗红色（大唐独有的焦虑色）
uniform vec4 ember_color : source_color = vec4(0.8, 0.2, 0.0, 1.0);
// 火星带的宽度
uniform float ember_width : hint_range(0.0, 0.2) = 0.05;

void fragment() {
    // 采样原本的贴图颜色
    vec4 base_color = texture(TEXTURE, UV);
    float burn_progress = raw_burn_progress/2.0; // 原图有一半都是底座
    
    // 假设香是从上往下烧：UV.y 从 0.0 到 1.0
    // smoothstep(min, max, value): value 小于 min 返回 0，大于 max 返回 1，中间平滑插值
    // 这里算出基础的透明遮罩 (0.0 = 被烧掉的，1.0 = 存活的)
    float alpha_mask = smoothstep(burn_progress - edge_softness, burn_progress + edge_softness, UV.y);
    
    // 计算火星边缘带遮罩 (距离燃烧点 ember_width 范围内的区域)
    float glow_mask = smoothstep(burn_progress, burn_progress + ember_width, UV.y);
    
    // 反转 glow_mask 并乘以 alpha_mask，得到只在燃烧边缘高亮的光晕带
    float ember_mix = (1.0 - glow_mask) * alpha_mask;
    
    // 1. 裁剪掉烧毁的像素
    COLOR.a = base_color.a * alpha_mask;
    
    // 2. 在断口处注入火星的颜色 (基于透明度判断，防止把背景透明像素也染红)
    if (COLOR.a > 0.0) {
        COLOR.rgb = mix(base_color.rgb, ember_color.rgb, ember_mix);
    }
}