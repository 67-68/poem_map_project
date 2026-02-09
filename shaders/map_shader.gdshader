shader_type canvas_item;

// 控制透视强度的参数
uniform float tilt : hint_range(-1.0, 1.0) = 0.4;      // 倾斜度 (0 为不倾斜)
uniform float fov : hint_range(0.1, 2.0) = 0.8;       // 视野宽度/拉伸感
uniform float zoom : hint_range(0.1, 5.0) = 1.0;      // 缩放倍率

void vertex() {
    // 1. 将顶点坐标归一化到 -1.0 到 1.0 之间
    float x = (UV.x - 0.5) * 2.0;
    float y = (UV.y - 0.5) * 2.0;

    // 2. 计算透视因子 (越往上方 y 越小，x 的缩放比例就越小，形成梯形)
    // 我们利用 y 坐标来模拟深度感
    float perspective = 1.0 + (y * tilt);
    
    // 防止除以 0 或产生极端的形变
    perspective = max(perspective, 0.1);

    // 3. 应用透视变换
    // x 坐标受深度影响缩放，y 坐标受 fov 影响拉伸
    VERTEX.x = x * perspective * fov * (1.0 / zoom) * (1.0 / TEXTURE_PIXEL_SIZE.x / 2.0);
    VERTEX.y = y * (1.0 / zoom) * (1.0 / TEXTURE_PIXEL_SIZE.y / 2.0);
    
    // 将顶点重新映射回 Godot 的像素坐标空间
    VERTEX += (1.0 / TEXTURE_PIXEL_SIZE) * 0.5;
}

void fragment() {
    // 这里保持简单的纹理采样，你未来可以增加“老旧地图”的滤镜效果
    vec4 col = texture(TEXTURE, UV);
    COLOR = col;
}