shader_type canvas_item;

// ── 赛博雕版：动态二值化 Shader ──────────────────
// 将任意彩图降维为单色版画：
//   1. 提取灰度 (BT.601 Luminance)
//   2. step 斩首：暗→墨色，亮→透明
//   3. 透出下层 PaperContainer 的麻纸底色
//
// self_modulate.a 可叠加控制全局透明度，与 shader 解耦

uniform float threshold : hint_range(0.0, 1.0) = 0.5;
uniform vec4 ink_color : source_color = vec4(0.0, 0.0, 0.0, 0.85);
uniform vec4 paper_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);

void fragment() {
	// Step 1: 采样纹理并提取灰度 (BT.601)
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));

	// Step 2: 阶跃斩首 — 灰度 > threshold → 留白(0.0), 否则 → 墨色(1.0)
	float mask = 1.0 - step(threshold, lum);

	// Step 3: mix 输出 — 暗部染 ink_color，亮部 paper_color
	COLOR = mix(paper_color, ink_color, mask);
}
