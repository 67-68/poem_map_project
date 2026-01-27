shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

uniform float speed = 0.5;
uniform float width = 0.1;

void fragment() {
	float line_pos = fract(TIME * speed);
	float mask = smoothstep(line_pos - width, line_pos, UV.x) - smoothstep(line_pos, line_pos + width, UV.x);
	COLOR.rgb += mask;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
