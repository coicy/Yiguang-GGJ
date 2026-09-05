shader_type canvas_item;
render_mode unshaded;

uniform vec4 fog_color : source_color = vec4(0.39, 0.72, 0.12, 0.72);
uniform float density : hint_range(0.0, 2.0) = 1.0;
uniform float flow_speed : hint_range(0.0, 3.0) = 1.0;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

float cloud(vec2 point) {
	float result = 0.0;
	float weight = 0.54;
	for (int octave = 0; octave < 4; octave++) {
		result += noise(point) * weight;
		point = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * point + vec2(3.7, 7.1);
		weight *= 0.48;
	}
	return result;
}

void fragment() {
	float time = TIME * flow_speed;
	vec2 point = UV * vec2(5.4, 2.7);
	vec2 drift = vec2(time * 0.13, time * -0.075);
	vec2 warp = vec2(noise(point + drift), noise(point * 1.3 - drift + 12.8));
	float body = cloud(point + warp * 1.7 - drift);
	float veil = cloud(point * 1.75 - warp + vec2(time * -0.08, time * 0.12));
	float curl = smoothstep(0.37, 0.77, body * 0.72 + veil * 0.48);
	vec2 edge_distance = min(UV, vec2(1.0) - UV);
	float edge = smoothstep(0.0, 0.14, edge_distance.x)
		* smoothstep(0.0, 0.23, edge_distance.y);
	float shaped = edge * (0.14 + curl * 0.77);

	// Sparse spores rise through the cloud; each cell gets its own phase and size.
	vec2 spore_point = UV * vec2(22.0, 11.0) + vec2(time * 0.08, time * 0.35);
	vec2 cell = floor(spore_point);
	float seed = hash(cell);
	vec2 center = vec2(0.25 + seed * 0.5, 0.25 + hash(cell + 8.2) * 0.5);
	float radius = length(fract(spore_point) - center);
	float glint = (1.0 - smoothstep(0.018, 0.075, radius)) * step(0.82, seed);
	glint *= 0.5 + 0.5 * sin(time * 1.4 + seed * 30.0);
	vec3 shadow = fog_color.rgb * vec3(0.28, 0.42, 0.37);
	vec3 lit = min(fog_color.rgb * 1.3 + vec3(0.08, 0.1, 0.01), vec3(1.0));
	vec3 color = mix(shadow, lit, smoothstep(0.24, 0.76, body + veil * 0.2));
	color = mix(color, vec3(0.81, 0.95, 0.36), glint * 0.85);
	float alpha = clamp((shaped + glint * edge * 0.45) * fog_color.a * density, 0.0, 0.94);
	COLOR = vec4(color, alpha);
}
