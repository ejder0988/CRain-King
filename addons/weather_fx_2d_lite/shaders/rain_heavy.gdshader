// rain_heavy - Weather FX 2D
// Dense storm rain: 4 parallax layers of fast streaks, a drifting mist veil and
// optional splash rings near the bottom of the rect. Loops on TIME.
// Usage: full-screen ColorRect over the game. Set splash_amount > 0 to enable splashes;
//        splash_y is the ground line (0..1 of rect height), splash_depth the band below it.
// Uniforms: intensity, wind, layers, speed, fall_speed, mist, splash_amount, splash_y,
//           splash_depth, rain_color, alpha_mult, seed, time_offset.
shader_type canvas_item;

uniform float aspect = 1.7778;
uniform float speed : hint_range(0.0, 3.0) = 1.0;
uniform float time_offset = 0.0;
uniform float seed = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.8;
uniform float alpha_mult : hint_range(0.0, 2.0) = 1.0;
uniform float wind : hint_range(-1.0, 1.0) = 0.4;
uniform int layers : hint_range(1, 4) = 4;

group_uniforms look;
uniform vec4 rain_color : source_color = vec4(0.72, 0.8, 0.9, 1.0);
uniform vec4 mist_color : source_color = vec4(0.55, 0.62, 0.7, 1.0);
uniform float fall_speed : hint_range(0.5, 6.0) = 3.2;
uniform float streak_length : hint_range(0.1, 0.95) = 0.75;
uniform float streak_width : hint_range(0.03, 0.4) = 0.16;
uniform float mist : hint_range(0.0, 1.0) = 0.25;
group_uniforms;

group_uniforms splashes;
uniform float splash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float splash_y : hint_range(0.0, 1.0) = 0.93;
uniform float splash_depth : hint_range(0.01, 0.3) = 0.06;
group_uniforms;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float rain_layer(vec2 p, float cols, float spd, float dens, float t, float sd, float lean) {
	float rows = cols * 0.2;
	p.x -= p.y * lean;
	vec2 q = vec2(p.x * cols, p.y * rows);
	float cx = floor(q.x);
	float colrnd = hash12(vec2(cx, sd));
	q.y -= t * spd * rows * (0.85 + 0.3 * colrnd);
	vec2 id = vec2(cx, floor(q.y));
	vec2 f = fract(q);
	vec2 so = vec2(sd * 13.1, sd * 7.7);
	float h1 = hash12(id + so);
	float h2 = hash12(id + so + vec2(17.3, 5.1));
	float h3 = hash12(id + so + vec2(3.7, 31.9));
	if (h1 >= dens) return 0.0;
	float len = streak_length;
	float y0 = len + (1.0 - len) * h3;
	float xc = 0.2 + 0.6 * h2;
	float d = f.y - y0;
	float aa = length(fwidth(q));
	float tail = smoothstep(-len, 0.0, d);
	tail *= tail;
	float head = 1.0 - smoothstep(-0.03, 0.03, d);
	float dx = abs(f.x - xc);
	float w = streak_width * (0.75 + 0.25 * tail);
	float side = 1.0 - smoothstep(w * 0.25, w + aa, dx);
	return tail * head * side * (0.6 + 0.4 * h1 / max(dens, 0.001));
}

float splash_layer(vec2 p, float t) {
	float band = (p.y - splash_y) / splash_depth;
	if (band < 0.0 || band > 3.0 || splash_amount <= 0.0) return 0.0;
	float cols = 32.0;
	vec2 q = vec2(p.x * cols, band);
	vec2 id = floor(q);
	vec2 f = fract(q);
	vec2 so = vec2(seed * 9.1, seed * 4.3);
	float h1 = hash12(id + so + vec2(1.3, 2.9));
	float h2 = hash12(id + so + vec2(8.1, 6.2));
	float h3 = hash12(id + so + vec2(4.4, 12.7));
	if (h1 > splash_amount) return 0.0;
	float age = fract(t * (0.9 + 0.8 * h2) + h3);
	vec2 c = vec2(0.5 + 0.3 * (h2 - 0.5), 0.5);
	// squashed ring so it reads as a ripple on a ground plane
	float cell_ratio = splash_depth / 3.0 * cols; // cell height / cell width
	vec2 d = (f - c) * vec2(1.0, cell_ratio);
	float r = length(d * vec2(1.0, 2.6));
	float ring_r = 0.08 + age * 0.38;
	float ring = 1.0 - smoothstep(0.02, 0.09, abs(r - ring_r));
	// small upward tick at the start of the splash
	float tick = (1.0 - smoothstep(0.0, 0.05, abs(f.x - c.x))) * step(f.y, c.y) * step(c.y - 0.5 * (1.0 - age) / cell_ratio, f.y) * step(age, 0.3);
	return (ring * (1.0 - age) + tick * 0.7) * (1.0 - age);
}

void fragment() {
	float t = TIME * speed + time_offset;
	vec2 p = UV * vec2(aspect, 1.0);
	float acc = 0.0;
	int n = layers;
	for (int i = 0; i < 4; i++) {
		if (i >= n) break;
		float k = (n > 1) ? float(i) / float(n - 1) : 0.4;
		float cols = mix(26.0, 75.0, k);
		float spd = fall_speed * mix(1.0, 0.6, k);
		float a = mix(1.0, 0.5, k);
		float dens = intensity * 0.6 * mix(0.8, 1.2, k);
		float l = rain_layer(p, cols, spd, dens, t, seed + float(i) * 5.31, wind * 0.9);
		acc = 1.0 - (1.0 - acc) * (1.0 - clamp(l * a, 0.0, 1.0));
	}
	float rain_a = clamp(acc * rain_color.a * 0.8, 0.0, 1.0);
	// mist veil: low-frequency streaky noise sliding with the rain
	vec2 mp = vec2((p.x - p.y * wind * 0.5) * 2.5, p.y * 1.2 - t * 0.35);
	float m = vnoise(mp) * 0.6 + vnoise(mp * 2.3 + 5.0) * 0.4;
	float mist_a = mist * (0.35 + 0.65 * m) * (0.4 + 0.6 * p.y) * intensity * mist_color.a;
	float s = splash_layer(p, t);
	float sp_a = clamp(s * 1.2, 0.0, 1.0);
	float a_rain = 1.0 - (1.0 - rain_a) * (1.0 - sp_a);
	float a_all = 1.0 - (1.0 - a_rain) * (1.0 - mist_a);
	vec3 col = (rain_color.rgb * a_rain + mist_color.rgb * mist_a * (1.0 - a_rain)) / max(a_rain + mist_a * (1.0 - a_rain), 0.0001);
	COLOR = vec4(col, clamp(a_all * alpha_mult, 0.0, 1.0));
}
