// PSX-style LIT spatial shader.
// View-space vertex snap — komsu mesh birlesimlerinde clip-space snap titremesini onler.
shader_type spatial;
render_mode specular_disabled, diffuse_lambert;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec3 uv_scale = vec3(1.0, 1.0, 1.0);
uniform float vertex_snap : hint_range(64.0, 1024.0) = 320.0;
uniform bool use_texture = true;

varying vec2 v_uv;

void vertex() {
	v_uv = UV * uv_scale.xy;

	// View-space grid: ayni dunya konumundaki vertex'ler ayni noktaya oturur,
	// komsu yuzeylerin birlesim cizgilerinde titreme olmaz.
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float view_grid = max(0.018, 14.0 / vertex_snap);
	view.xyz = floor(view.xyz / view_grid + 0.5) * view_grid;

	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	vec3 col = albedo_color.rgb;
	if (use_texture) {
		vec4 tex = texture(albedo_texture, v_uv);
		col *= tex.rgb;
		ALPHA = tex.a * albedo_color.a;
	} else {
		ALPHA = albedo_color.a;
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
