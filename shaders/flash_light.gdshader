shader_type canvas_item;

uniform float speed = 0.5;
uniform float width = 0.1;
uniform vec4 shine_color: source_color = vec4(1.0, 0.8, 0.0, 1.0);

void fragment() {
	float line_pos = fract(TIME * speed);
	float mask = smoothstep(line_pos - width, line_pos, UV.x) - smoothstep(line_pos, line_pos + width, UV.x);
	COLOR.rgb = mix(COLOR.rgb, shine_color.rgb, mask * shine_color.a * COLOR.a);
}
