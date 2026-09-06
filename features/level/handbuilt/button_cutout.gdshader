shader_type canvas_item;

// The supplied originals have an opaque white background.
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float background = smoothstep(0.94, 0.99, min(texel.r, min(texel.g, texel.b)));
	COLOR *= vec4(texel.rgb, texel.a * (1.0 - background));
}
