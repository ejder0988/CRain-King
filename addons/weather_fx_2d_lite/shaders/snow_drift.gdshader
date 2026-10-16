// snow_drift - Weather FX 2D
// Soft round snowflakes falling in up to 4 parallax layers, swaying side to side. Loops on TIME.
// Usage: full-screen ColorRect over the game. Near layers are big, soft and fast; far layers small and slow.
// Uniforms: intensity, wind, sway, layers, speed, fall_speed, flake_size, softness,
//           snow_color, alpha_mult, seed, time_offset.
shader_type canvas_item;

uniform float aspect = 1.7778;
uniform float speed : hint_range(0.0, 3.0) = 1.0;
uniform float time_offset = 0.0;
uniform float seed = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.6;
uniform float alpha_mult : hint_range(0.0, 2.0) = 1.0;
uniform float wind : hint_range(-1.0, 1.0) = 0.15;
uniform int layers : hint_range(1, 4) = 4;

group_uniforms look;
uniform vec4 snow_color : source_color = vec4(0.97, 0.98, 1.0, 1.0);
uniform float fall_speed : hint_range(0.05, 1.5) = 0.28;
uniform float sway : hint_range(0.0, 1.0) = 0.7;
uniform float flake_size : hint_range(0.3, 2.0) = 1.0;
uniform float softness : hint_range(0.05, 1.0) = 0.45;
group_uniforms;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float flake_layer(vec2 p, float scale, float fall, float dens, float t, float sd, float lean, float sz, float soft) {
	p.x -= p.y * lean;
	vec2 q = p * scale + vec2(sd * 7.1, sd * 3.3);
	q.y -= t * fall * scale;
	vec2 id = floor(q);
	vec2 f = fract(q);
	vec2 so = vec2(sd * 13.1, sd * 7.7);
	float h1 = hash12(id + so);
	float h2 = hash12(id + so + vec2(17.3, 5.1));
	float h3 = hash12(id + so + vec2(3.7, 31.9));
	if (h1 >= dens) return 0.0;
	float r = mix(0.08, 0.2, h2) * sz;
	r = min(r, 0.22);
	float amp = (0.5 - r - 0.03);
	float ph = h3 * 6.2831;
	float cx = 0.5 + amp * sway * sin(t * (0.9 + 0.9 * h2) * 1.6 + ph);
	float cy = 0.5 + amp * 0.6 * sin(t * 0.8 + h2 * 40.0);
	float d = length(f - vec2(cx, cy));
	float aa = length(fwidth(q));
	return 1.0 - smoothstep(r * (1.0 - soft), r + aa, d);
}

void fragment() {
	float t = TIME * speed + time_offset;
	vec2 p = UV * vec2(aspect, 1.0);
	float acc = 0.0;
	int n = layers;
	for (int i = 0; i < 4; i++) {
		if (i >= n) break;
		float k = (n > 1) ? float(i) / float(n - 1) : 0.4;
		float scale = mix(6.0, 22.0, k);
		float fall = fall_speed * mix(1.0, 0.45, k);
		float a = mix(0.95, 0.6, k);
		float soft = clamp(softness * mix(1.4, 0.8, k), 0.05, 0.95);
		float l = flake_layer(p, scale, fall, intensity * 0.75, t, seed + float(i) * 6.7, wind * 0.6, flake_size, soft);
		acc = 1.0 - (1.0 - acc) * (1.0 - clamp(l * a, 0.0, 1.0));
	}
	COLOR = vec4(snow_color.rgb, clamp(acc * snow_color.a * alpha_mult, 0.0, 1.0));
}
