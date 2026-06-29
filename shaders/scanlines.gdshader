shader_type canvas_item;

uniform float line_opacity : hint_range(0.0, 1.0) = 0.12;
uniform float line_spacing : hint_range(1.0, 8.0) = 2.0;

void fragment() {
	float line = mod(FRAGCOORD.y, line_spacing);
	float mask = step(line, 1.0);
	COLOR = vec4(0.0, 0.0, 0.0, mask * line_opacity);
}
