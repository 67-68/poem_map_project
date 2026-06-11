shader_type canvas_item;

// ============================================================
// golden_shine.gdshader — 金色闪耀流光 Shader
//
// 用途: 为 UI 元素（进度条、边框）添加动态金色流光效果
//      模拟唐风主线任务的金碧辉煌质感 🤓☝️
// ============================================================

// 流光扫过的速度 (越大越快)
uniform float speed : hint_range(0.0, 5.0) = 1.2;

// 闪耀强度 (0.0 = 无效果, 1.0 = 闪瞎狗眼)
uniform float intensity : hint_range(0.0, 1.0) = 0.35;

// 金色基调
uniform vec4 gold_color : source_color = vec4(1.0, 0.843, 0.0, 1.0);

// 高光颜色 (更亮的金色扫光)
uniform vec4 highlight_color : source_color = vec4(1.0, 0.95, 0.6, 1.0);

// 流光宽度 (0.0 ~ 0.5)
uniform float band_width : hint_range(0.01, 0.5) = 0.15;

void fragment() {
	// 原始颜色 + 透明度
	vec4 base = texture(TEXTURE, UV);
	float alpha = base.a;

	// ---- 流光计算 ----
	// 斜向扫描: 用 UV.x + UV.y 制造对角线方向
	float diagonal = UV.x + UV.y;
	// TIME 驱动循环
	float t = diagonal + TIME * speed;
	// 取小数部分做循环
	float scan = fract(t);

	// 两侧 smoothstep 渐入渐出
	float glow = smoothstep(0.0, band_width, scan) * (1.0 - smoothstep(band_width, band_width * 2.0, scan));

	// 将 glow 映射到强度范围
	float shine = glow * intensity;

	// ---- 颜色混合 ----
	// 1. 基础金色调色: 混合 gold_color
	vec3 gold_tinted = mix(base.rgb, gold_color.rgb, 0.15);

	// 2. 高光扫过: 混合 highlight_color
	vec3 final_rgb = mix(gold_tinted, highlight_color.rgb, shine);

	// 3. 保持原始透明度，避免把背景透明像素点亮
	COLOR = vec4(final_rgb, alpha);
}
