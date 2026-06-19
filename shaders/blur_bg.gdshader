shader_type canvas_item;

// Godot 4 核心魔法：捕获屏幕纹理并开启 mipmap 以支持平滑模糊
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// 暴露出两个变量，方便你在代码里控制
uniform float blur_amount : hint_range(0.0, 5.0) = 2.5;
uniform float darken_amount : hint_range(0.0, 1.0) = 0.5; // 压暗环境，让白字/红字更清晰

void fragment() {
    // 1. 读取屏幕当前像素，并利用 LOD (Level of Detail) 算法实现高斯模糊
    vec4 color = textureLod(screen_texture, SCREEN_UV, blur_amount);
    
    // 2. 暴力压暗亮度，模拟“风雨欲来”的沉重感
    color.rgb *= (1.0 - darken_amount); 
    
    COLOR = color;
}