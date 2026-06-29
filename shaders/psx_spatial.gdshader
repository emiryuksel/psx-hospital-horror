// PSX spatial — vertex snap YOK (ince duvarlarda degenerate üçgen üretiyordu).
// Flat shading + düşük çözünürlük + dither present ile PSX hissi verilir.
shader_type spatial;
render_mode unshaded, specular_disabled, cull_back;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float ambient_strength : hint_range(0.0, 1.0) = 0.42;
uniform float light_strength : hint_range(0.0, 1.5) = 0.78;

flat varying float v_face_shade;

void vertex() {
	vec3 world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 light_dir = normalize(vec3(0.35, -0.9, 0.25));
	float ndl = max(dot(world_normal, -light_dir), 0.0);
	v_face_shade = clamp(ambient_strength + ndl * light_strength, 0.28, 0.82);
}

void fragment() {
	ALBEDO = albedo_color.rgb * v_face_shade;
	ALPHA = albedo_color.a;
}
