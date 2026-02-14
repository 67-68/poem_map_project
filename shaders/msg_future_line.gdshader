shader_type canvas_item;

uniform float progress_ratio: hint_range(0.0, 1.0);

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	if (UV.x < progress_ratio){
		discard;
	}
	
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
