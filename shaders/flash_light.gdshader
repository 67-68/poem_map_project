shader_type canvas_item;

// === [ 架构师参数面板 ] ===
// 当前信使的位置进度 (由 GDScript 每帧投喂)
uniform float current_progress : hint_range(0.0, 1.0) = 0.0;
// 未来的荧光色 (你在编辑器里调这个就行)
uniform vec4 future_color : source_color = vec4(0.0, 0.8, 1.0, 0.3);
// 裁剪边缘柔和度 (稍微给点渐变，别让线段看起来像被狗啃了一样 🐶)
uniform float edge_softness : hint_range(0.0, 0.05) = 0.01;

void fragment() {
    if (current_progress > UV.x) {
		discard;
	}
    float visibility = smoothstep(current_progress, current_progress + edge_softness, UV.x);
    
    // 2. 边缘羽化：保留“淡淡的荧光”质感，中间亮两边暗
    // 还是那个配方：用 UV.y 把线的两边缘变暗
    float core_intensity = 1.0 - abs(UV.y - 0.5) * 2.0;
    core_intensity = pow(core_intensity, 1.5); // 加点指数让发光更聚拢
    
    // 3. 输出合并
    COLOR = future_color;
    COLOR.a *= visibility * core_intensity;
}