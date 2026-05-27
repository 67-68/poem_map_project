shader_type canvas_item;

// --- 笔触控制 ---
uniform float ink_roughness : hint_range(0.0, 5.0) = 1.0;  // 边缘抖动强度
uniform float dry_brush : hint_range(0.0, 1.0) = 0.5;      // 枯笔程度
uniform sampler2D noise_tex : hint_default_white;
uniform float noise_freq = 50.0; 

void fragment() {
	// 1. 修正 UV 采样：为了防止长路径拉伸，采样时应考虑纹理的长宽比
	// 在 Line2D 中，通常直接用 UV 配合较大的 noise_freq 即可
	vec2 noise_uv = UV * noise_freq + TIME * 0.05;
	float n = texture(noise_tex, noise_uv).r;
	
	// 2. 产生抖动效果
	// 我们不再采样 index_map（因为 Line2D 渲染时没有它），
	// 我们利用 Line2D 自身的边缘 (UV.y 是 0.0 和 1.0)
	float edge_dist = abs(UV.y - 0.5) * 2.0; // 0 是中心，1 是边缘
	
	// 用噪声扰动边缘判定
	float edge_noise = (n - 0.5) * 0.2 * ink_roughness;
	// 顺着写 smoothstep (从小到大)，然后用 1.0 去减它来实现反转！
	// 这样你的代码才可以在任何破烂显卡上稳定运行 🤓☝️
	float ink_mask = 1.0 - smoothstep(0.7 + edge_noise, 0.9 + edge_noise, edge_dist);
	
	// 3. 枯笔效果：根据噪声切开内部像素
	float dry_mask = smoothstep(dry_brush, dry_brush + 0.3, n);
	
	// 4. 【关键修复】结合 Gradient 颜色
	// COLOR 变量包含了 Line2D 的 Gradient 颜色和 Width Curve 的透明度影响
	vec4 final_color = COLOR; 
	
	// 应用我们的墨迹遮罩
	final_color.a *= ink_mask * dry_mask;
	
	COLOR = final_color;
}