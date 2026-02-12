shader_type spatial;

void vertex(){
	VERTEX.y = sin(TIME);
	VERTEX.x = 0.2 * VERTEX.y;
	
	float slope = cos(TIME);
	vec3 tangent = vec3(1.0, slope, 0.0);
	vec3 binomical = vec3(0.0,0.0,1.0);
	
	NORMAL = normalize(cross(binomical, tangent));
}


