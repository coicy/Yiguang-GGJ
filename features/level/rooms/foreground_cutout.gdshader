shader_type canvas_item;
// Unmix the white matte continuously, including enclosed grey leaf gaps.
// Per-art interior highlights can remain opaque; source RGB is not modified.
uniform vec2 highlight_center_px = vec2(0.0);
uniform vec2 highlight_radius_px = vec2(1.0);
uniform float highlight_preservation : hint_range(0.0, 1.0) = 0.0;
uniform float opaque_floor : hint_range(0.05, 0.6) = 0.28;
varying vec4 instance_tint;
void vertex() { instance_tint = COLOR; }
void fragment() {
 vec4 texel = texture(TEXTURE, UV);
 float matte = min(texel.r, min(texel.g, texel.b));
 // RGB = coverage * foreground + (1 - coverage) * white.
 // Dividing the white distance estimates coverage without a binary halo.
 float coverage = clamp((1.0 - matte) / (1.0 - opaque_floor), 0.0, 1.0);
 float radius = length((UV / TEXTURE_PIXEL_SIZE - highlight_center_px) / max(highlight_radius_px, vec2(1.0)));
 float preserve = (1.0 - smoothstep(0.65, 1.0, radius)) * highlight_preservation;
 coverage = mix(coverage, 1.0, preserve);
 coverage *= 1.0 - smoothstep(0.95, 0.99, matte);
 vec3 color = clamp((texel.rgb - vec3(1.0 - coverage)) / max(coverage, 0.001), vec3(0.0), vec3(1.0));
 COLOR = vec4(color, texel.a * coverage) * instance_tint;
}
