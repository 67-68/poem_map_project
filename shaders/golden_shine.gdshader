shader_type canvas_item;

// ============================================================
// golden_shine.gdshader — 呼吸脉动金光 Shader
//
// 用途: 为 UI 元素（按钮、标题）添加类似心跳的呼吸金光
//      以 sin 波驱动，暗金 ↔ 亮金之间柔和脉动
// ============================================================

// 呼吸频率 (Hz，值越大脉动越快)
uniform float speed : hint_range(0.0, 5.0) = 1.2;

// 脉动强度 (0.0 = 无效果, 1.0 = 闪瞎)
uniform float intensity : hint_range(0.0, 1.0) = 0.35;

// 暗金色基调 (脉动低谷)
uniform vec4 gold_color : source_color = vec4(1.0, 0.843, 0.0, 1.0);

// 高光金色 (脉动峰值)
uniform vec4 highlight_color : source_color = vec4(1.0, 0.95, 0.6, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float alpha = base.a;

	// ---- 呼吸脉动 ----
	// sin 映射到 [0, 1]，周期由 speed 控制
	float breathe = sin(TIME * speed * 3.14159) * 0.5 + 0.5;

	// 用强度缩放脉动幅度
	float shine = breathe * intensity;

	// ---- 颜色混合 ----
	// 基础金色调色: 始终混入一点点 gold_color 做底色
	vec3 gold_tinted = mix(base.rgb, gold_color.rgb, 0.15);

	// 呼吸高光: 低谷→gold_color，峰值→highlight_color
	vec3 final_rgb = mix(gold_tinted, highlight_color.rgb, shine);

	COLOR = vec4(final_rgb, alpha);
}
