shader_type spatial;

render_mode unshaded, cull_front;

uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float thickness = 0.1;

void vertex() {
	VERTEX = VERTEX + NORMAL * thickness;
}

void fragment() {
	ALBEDO = color.rgb;
}
