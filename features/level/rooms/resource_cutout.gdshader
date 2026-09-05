shader_type canvas_item;
// The preserved source has a white matte. Remove that matte while sampling;
// ceramic and sap highlights are chromatic and remain below the key threshold.
varying vec4 instance_tint;
void vertex() { instance_tint = COLOR; }
void fragment() {
 vec4 texel = texture(TEXTURE, UV);
 float matte = min(texel.r, min(texel.g, texel.b));
 float coverage = 1.0 - smoothstep(0.84, 0.95, matte);
 vec3 color = clamp((texel.rgb - vec3(1.0 - coverage)) / max(coverage, 0.001), vec3(0.0), vec3(1.0));
 COLOR = vec4(color, texel.a * coverage) * instance_tint;
}
