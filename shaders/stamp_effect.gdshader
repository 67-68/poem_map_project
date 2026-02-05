shader_type canvas_item;

void fragment() {
	float noise = fract(sin(dot(UV + TIME * 0.01, vec2(12.9898, 78.233))) * 43758.5453);
COLOR.a *= 0.95 + 0.05 * noise;
}
