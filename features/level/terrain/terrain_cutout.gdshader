shader_type canvas_item;
// Default CanvasItem lighting preserves PointLight2D and shadow response.
uniform float alpha_clip : hint_range(0.0, 1.0) = 0.85;
varying vec4 item_tint;
void vertex() {
	item_tint = COLOR;
}
void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	if (sample_color.a < alpha_clip) { discard; }
	COLOR = vec4(sample_color.rgb, 1.0) * item_tint;
}
