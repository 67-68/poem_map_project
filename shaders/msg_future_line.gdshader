shader_type canvas_item;

uniform float progress_ratio: hint_range(0.0, 1.0);
// === [ 暴露出你的参数字典，拒绝 Hardcode 😡 ] ===
// 流光基础颜色 (由于你想要淡淡的，可以在编辑器里把 Alpha 调低)
uniform vec4 glow_color : source_color = vec4(0.0, 0.8, 1.0, 0.8); 
// 运动速度：正数往前跑，负数往回缩
uniform float speed = 1.5; 
// 光束的密集程度（频段）：值越大，同一条线上出现的光段越多
uniform float frequency = 3.0; 
// 尾迹拖尾长度：控制 discard 的范围 (0.0 到 1.0)
uniform float tail_length = 0.5;
// 边缘柔和度：避免 discard 造成狗啃一样的硬边缘
uniform float edge_softness = 0.1;

void fragment() {
	if (UV.x < progress_ratio){
		discard;
	}

    // 1. 计算核心流动逻辑：用 fract 截断出 0~1 的周期性变化
    // 因为是 Stretch 模式，UV.x 就是整条路径的进度 (0 到 1)
    float flow_phase = fract(UV.x * frequency - TIME * speed);
    
    // 2. 荧光的核心审美：中间亮，两边暗
    // UV.y 从 0 到 1 代表线的宽度。我们在 0.5 处制造最亮的中心线
    // 这里的数学模型很简单：1.0 减去偏离中心的距离的绝对值
    float core_intensity = 1.0 - abs(UV.y - 0.5) * 2.0;
    
    // 给发光核心加一点指数衰减，让光聚拢在中心，边缘变“淡淡的”
    core_intensity = pow(core_intensity, 2.0);

    // 3. 构建拖尾与 Discard 逻辑
    // 如果流动相位大于 tail_length，说明是不需要发光的部分
    // 我们用 smoothstep 来代替粗暴的 if/discard，这不仅对 GPU 友好，而且边缘不会出现锯齿 🤓☝️
    float flow_intensity = smoothstep(tail_length + edge_softness, tail_length, flow_phase);

    // 4. 合成最终透明度与颜色
    // COLOR 是 Line2D 节点本身自带的颜色，乘进去保留编辑器的控制权
    float final_alpha = core_intensity * flow_intensity * glow_color.a;
    
    // 建构纠错反馈：如果你非要物理意义上的 discard（为了极致节省 overdraw）
    // 可以在这里加上一句：if (final_alpha < 0.01) { discard; }
    // 但在这个量级，直接输出透明像素足够了，而且更平滑。
    
    vec4 final_color = vec4(glow_color.rgb, final_alpha);
    
    // 混合 Line2D 节点颜色，保持健壮的组件兼容性
    COLOR = final_color * COLOR;
}