shader_type canvas_item;

// ============================================================
// image_shatter.gdshader — Voronoi 网格解体着色器
//
// 用途: 将图片切割为网格碎片，每块碎片独立随机方向散开并淡出
//       模拟「粉碎/解体」视觉效果
//
// 驱动方式: Tween 驱动 uniform progress (0.0→完整, 1.0→完全消散)
// ============================================================

// 解体进度 (0.0 = 完整图片, 1.0 = 彻底粉碎)
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// 碎片网格大小 (像素单位, 越小碎片越多越细碎)
uniform float cell_size : hint_range(4.0, 128.0) = 32.0;

// 碎片散开强度 (0.0 = 不散开, 1.0 = 剧烈散开)
uniform float scatter_strength : hint_range(0.0, 1.0) = 0.3;

// 从多少 progress 开始 Alpha 淡化 (0.0~1.0)
uniform float alpha_fade_start : hint_range(0.0, 1.0) = 0.5;

// 碎片自旋速度 (弧度, 0.0 = 不旋转, 3.14 = 半圈)
uniform float rotation_amount : hint_range(0.0, 6.28) = 0.8;

// ── 伪随机哈希函数 ────────────────────────────────────────
// 输入: vec2 坐标
// 输出: vec2 伪随机值 (0.0~1.0)
vec2 hash22(vec2 p) {
	p = vec2(
		dot(p, vec2(127.1, 311.7)),
		dot(p, vec2(269.5, 183.3))
	);
	return fract(sin(p) * 43758.5453123);
}

// ── 主片段函数 ──────────────────────────────────────────
void fragment() {
	// 1. 计算网格密度
	float grid_density = 1.0 / max(cell_size, 4.0); // 最小 4px，防止除零

	// 2. 计算当前像素所在网格索引 + 网格内局部 UV
	vec2 cell_idx = floor(UV * grid_density);
	vec2 cell_uv = fract(UV * grid_density);

	// 3. 为该网格生成随机值
	vec2 rand = hash22(cell_idx);
	vec2 scatter_dir = rand * 2.0 - 1.0; // -1..1 随机方向
	float rotation = (rand.x - 0.5) * rotation_amount; // -rotation/2 ~ +rotation/2
	float scatter_scale = 0.5 + rand.y * 0.5; // 0.5~1.0 随机缩放

	// 4. 计算散开偏移 (ease-out 曲线: 先慢后快)
	float eased_progress = 1.0 - pow(1.0 - progress, 2.0);
	vec2 displacement = scatter_dir * cell_size * scatter_strength * scatter_scale * eased_progress;

	// 5. 计算碎片内局部旋转变换
	//    以碎片中心 (0.5, 0.5) 为旋转原点
	vec2 centered_uv = cell_uv - 0.5;
	float cos_r = cos(rotation * eased_progress);
	float sin_r = sin(rotation * eased_progress);
	vec2 rotated_uv = vec2(
		centered_uv.x * cos_r - centered_uv.y * sin_r,
		centered_uv.x * sin_r + centered_uv.y * cos_r
	) + 0.5;

	// 6. 计算采样 UV = 原始网格位置偏移
	vec2 sample_uv = (cell_idx + rotated_uv) / grid_density + displacement;

	// 7. Alpha 淡化
	float alpha = 1.0;
	if (progress > alpha_fade_start) {
		float fade_range = 1.0 - alpha_fade_start;
		if (fade_range > 0.001) {
			alpha = 1.0 - (progress - alpha_fade_start) / fade_range;
		} else {
			alpha = 0.0;
		}
		alpha = max(0.0, alpha);
	}

	// 8. 采样纹理 (使用 clamp 防止边缘拉伸)
	vec4 color = texture(TEXTURE, sample_uv);
	color.a *= alpha;

	COLOR = color;
}
