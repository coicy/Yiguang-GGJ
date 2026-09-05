shader_type canvas_item;
render_mode unshaded;
// ImageGen source retained verbatim. Remove only its pale neutral matte at draw time.
varying vec4 item_tint;
void vertex() {
    item_tint = COLOR;
}
void fragment() {
    vec4 texel = texture(TEXTURE, UV);
    float low = min(texel.r, min(texel.g, texel.b));
    float high = max(texel.r, max(texel.g, texel.b));
    float neutral = 1.0 - smoothstep(0.07, 0.17, high - low);
    float matte = smoothstep(0.68, 0.88, low) * neutral;
    COLOR = vec4(texel.rgb, texel.a * (1.0 - matte)) * item_tint;
}
