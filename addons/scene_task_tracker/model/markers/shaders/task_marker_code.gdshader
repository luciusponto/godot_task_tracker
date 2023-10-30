shader_type spatial;

render_mode unshaded, blend_mix;

instance uniform vec4 color : source_color = vec4(1.0);
//uniform float alpha = 0.75;

void fragment() {
	
	//const float sRGB_to_linear = 1.0 / 1.0;
	//ALBEDO = pow(COLOR.rgb, vec3(sRGB_to_linear));
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
