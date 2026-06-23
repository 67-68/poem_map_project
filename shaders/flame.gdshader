shader_type canvas_item;

// --- 架构师的燃料库 ---
// 毁灭进度：0.0为完好，1.0为灰飞烟灭
uniform float burn_progress : hint_range(0.0, 1.0) = 0.0;

// 混沌算子：决定火焰蔓延形状的噪声图 (必须在材质面板里挂载！)
uniform sampler2D noise_texture : repeat_enable;

// 物理反馈：边缘的色彩定义
uniform vec4 ash_color : source_color = vec4(0.08, 0.05, 0.05, 1.0); // 焦黑的纸灰
uniform vec4 fire_color : source_color = vec4(1.0, 0.3, 0.0, 1.0);  // 绝望的暗红/亮橙

// 侵蚀半径：火光和焦炭的厚度
uniform float fire_width : hint_range(0.0, 0.2) = 0.03;
uniform float ash_width : hint_range(0.0, 0.2) = 0.06;

void fragment() {
    // 获取宣纸/UI原本的颜色
    vec4 original_color = texture(TEXTURE, UV);
    
    // 读取噪声图的灰度值 (决定这里容易烧还是难烧)
    float noise_val = texture(noise_texture, UV).r;
    
    // 修正进度：稍微放大进度域，确保 1.0 时连火星都不剩
    float threshold = burn_progress * (1.0 + ash_width + fire_width);
    
    // 核心数学判决：当前像素距离被抹杀的临界点有多远？
    float burn_dist = noise_val - threshold;
    
    // 1. 虚无判定：小于 0 的地方已经被彻底烧穿
    float alpha_mask = step(0.0, burn_dist); 
    
    // 2. 业火判定：距离边缘在 fire_width 以内的地方，正在猛烈燃烧
    float is_fire = step(burn_dist, fire_width) * alpha_mask;
    
    // 3. 焦炭判定：距离边缘在 ash_width 以内、且没在燃烧的地方，变成了黑灰
    float is_ash = step(burn_dist, ash_width) * (1.0 - is_fire) * alpha_mask;
    
    // 注入我们之前学的“上古咒语”，让边缘的火光疯狂闪烁，模拟系统底噪
    float flicker = 0.8 + 0.4 * fract(sin(dot(UV + TIME * 2.0, vec2(12.9898, 78.233))) * 43758.5453);
    
    // --- 色彩重组 ---
    vec4 final_color = original_color;
    // 覆盖焦炭
    final_color = mix(final_color, ash_color, is_ash);
    // 覆盖火光 (火光加上闪烁，并且使用加法混合模拟高亮)
    final_color = mix(final_color, final_color + fire_color * flicker, is_fire);
    
    // 物理裁剪：抹除烧尽区域的透明度，同时保留原本材质的透明度
    final_color.a *= alpha_mask * original_color.a;
    
    COLOR = final_color;
}