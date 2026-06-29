// SubViewportContainer üzerinde — viewport texture + Bayer dither + renk quantize.
shader_type canvas_item;
render_mode unshaded;

uniform int color_depth : hint_range(3, 8) = 5;
uniform float dither_strength : hint_range(0.0, 1.0) = 1.0;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float levels = pow(2.0, float(color_depth));

	ivec2 cell = ivec2(int(FRAGCOORD.x), int(FRAGCOORD.y)) % 4;
	float threshold = BAYER[cell.y * 4 + cell.x] / 16.0;

	vec3 rgb = color.rgb;
	rgb += (threshold - 0.5) / levels * dither_strength;
	rgb = clamp(floor(rgb * levels + 0.5) / levels, 0.0, 1.0);

	COLOR = vec4(rgb, color.a);
}
