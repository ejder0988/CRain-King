// fog_layers - Weather FX 2D (atmosphere)
// Drifting multi-layer fog. Up to 4 depth layers drift at different speeds (parallax).
// Usage: ColorRect over the game, assign this shader. Loops on TIME, never repeats visibly.
// Uniforms: intensity = fog density, layers = depth layers (1..4), wind = drift direction/lean,
//           height_bias > 0 thickens fog toward the bottom, softness = how wispy the edges are.
shader_type canvas_item;

uniform float aspect = 1.7778;
uniform float speed : hint_range(0.0, 3.0) = 1.0;
uniform float time_offset = 0.0;
uniform float seed = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.6;
uniform float alpha_mult : hint_range(0.0, 1.0) = 1.0;
uniform float wind : hint_range(-1.0, 1.0) = 0.5;
uniform int layers : hint_range(1, 4) = 3;
uniform float scale : hint_range(0.5, 6.0) = 2.0;
uniform float softness : hint_range(0.05, 1.0) = 0.5;
uniform float height_bias : hint_range(-1.0, 1.0) = 0.3;

group_uniforms colors;
uniform vec4 fog_color : source_color = vec4(0.78, 0.84, 0.9, 1.0);
uniform vec4 shade_color : source_color = vec4(0.5, 0.58, 0.7, 1.0);
group_uniforms;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
			   mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p){
	float a = 0.5; float s = 0.0;
	for (int i = 0; i < 4; i++){ s += a * vnoise(p); p = p * 2.03 + vec2(17.1, 9.2); a *= 0.5; }
	return s / 0.9375;
}

void fragment() {
	vec2 p = UV * vec2(aspect, 1.0);
	float t = (TIME + time_offset) * speed;
	float acc = 0.0;
	float shade = 0.0;
	float dir = (abs(wind) < 0.02) ? 0.2 : wind;
	for (int i = 0; i < 4; i++) {
		if (i >= layers) break;
		float fi = float(i);
		float depth = 1.0 + fi * 0.6;                 // far layers: larger, slower
		vec2 q = p * scale / depth + vec2(seed * 13.7 + fi * 31.4, fi * 7.7);
		q.x -= t * 0.05 * dir * (1.5 - fi * 0.25);
		q.y += sin(t * 0.07 + fi * 2.0) * 0.15;       // slow vertical breathing
		float n = fbm(q + fbm(q * 0.7 + vec2(t * 0.02, 0.0)) * 0.8);
		float lo = 0.62 - intensity * 0.35 - softness * 0.0;
		float d = smoothstep(lo - softness * 0.4, lo + softness * 0.5, n);
		float hb = mix(1.0, smoothstep(0.0, 1.0, UV.y), abs(height_bias));
		if (height_bias < 0.0) hb = mix(1.0, 1.0 - UV.y, abs(height_bias));
		d *= hb;
		acc = acc + d * (1.0 - acc) * (0.55 / (1.0 + fi * 0.25));
		shade += d * (1.0 - n) * 0.8;
	}
	float a = clamp(acc * (0.55 + intensity * 0.6), 0.0, 0.92) * alpha_mult;
	vec3 col = mix(fog_color.rgb, shade_color.rgb, clamp(shade * 0.6, 0.0, 1.0));
	COLOR = vec4(col, a);
}
