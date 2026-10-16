shader_type canvas_item;
// Lightning Flash - Weather FX 2D (events)
// What: a double flash with a branching bolt silhouette dropping from the top of the rect,
//       plus a brief brightening of the whole screen. Transparent when idle.
// Usage: ColorRect over the game. EVENT: animate `progress` 0 -> 1 (about 0.8-1.2 s with a Tween)
//        to fire one strike. Or set `loop_interval` > 0 (seconds) to strike automatically on TIME.
// Notes: progress = 0 and progress = 1 both draw nothing. With loop_interval the bolt moves to a new
//        place each strike (randomize_position). `intensity` scales both bolt and flash.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float loop_interval : hint_range(0.0, 30.0) = 0.0;
uniform float flash_duration : hint_range(0.3, 3.0) = 1.0;
uniform float time_offset = 0.0;
uniform float aspect = 1.7778;
uniform float seed = 1.0;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float alpha_mult : hint_range(0.0, 1.0) = 1.0;
uniform float wind : hint_range(-1.0, 1.0) = 0.0;

group_uniforms bolt;
uniform bool show_bolt = true;
uniform bool randomize_position = true;
uniform float bolt_x : hint_range(0.0, 1.0) = 0.5;
uniform float bolt_width : hint_range(0.002, 0.05) = 0.010;
uniform float branches : hint_range(0.0, 1.0) = 1.0;
uniform vec4 bolt_color : source_color = vec4(0.93, 0.96, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.45, 0.6, 1.0, 1.0);

group_uniforms flash;
uniform float screen_flash : hint_range(0.0, 1.0) = 0.45;
uniform vec4 flash_color : source_color = vec4(0.8, 0.87, 1.0, 1.0);

float hash11(float x) {
	float p = fract(x * 0.1031 + 0.3);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float vnoise1(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), f);
}

float pulse(float p, float start, float decay) {
	float x = p - start;
	if (x < 0.0) {
		return 0.0;
	}
	return smoothstep(0.0, 0.012, x) * exp(-x / decay);
}

// Bolt vertex i of N (top to bottom). Zigzag offsets are bounded by the vertical step, so every
// segment leans at most ~45-50 degrees from vertical (never near-horizontal), whatever the aspect.
const int SEGS = 12;

vec2 bolt_vertex(int i, float sid, float base) {
	float y = float(i) / float(SEGS);
	float h = hash11(float(i) * 1.91 + sid * 13.7);
	float sgn = hash11(float(i) * 3.37 + sid * 5.1 + 0.5) > 0.5 ? 1.0 : -1.0;
	float amp = 0.5 * 0.85 / float(SEGS) / aspect;
	float x = base + sgn * (0.4 + 0.6 * h) * amp * (i == 0 ? 0.0 : 1.0);
	x += 0.04 * sin(y * 3.4 + sid * 2.0) * y + wind * y * 0.14;
	return vec2(x, y);
}

// distance from point p to segment a-b in aspect-corrected space
float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = (p - a) * vec2(aspect, 1.0);
	vec2 ba = (b - a) * vec2(aspect, 1.0);
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	float p;
	float sid = seed;
	if (loop_interval > 0.0) {
		float t = TIME + time_offset;
		float cyc = floor(t / loop_interval);
		float local = t - cyc * loop_interval;
		p = clamp(local / flash_duration, 0.0, 1.0);
		sid = seed + mod(cyc, 97.0);
	} else {
		p = progress;
	}
	float env = pulse(p, 0.02, 0.07) + 0.75 * pulse(p, 0.21, 0.13);
	env = clamp(env, 0.0, 1.0) * (1.0 - smoothstep(0.75, 1.0, p));

	if (env <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		float base = bolt_x;
		if (randomize_position && loop_interval > 0.0) {
			base = 0.15 + 0.7 * hash11(sid * 3.7);
		}
		vec2 uv = UV;
		float y = uv.y;

		// screen brightening, strongest high up
		float fl = screen_flash * env * (0.4 + 0.6 * (1.0 - y * 0.8));
		float a_flash = clamp(fl * intensity, 0.0, 1.0);

		float bolt_a = 0.0;
		float glow_a = 0.0;
		if (show_bolt) {
			float reach = 0.12 + 0.82 * smoothstep(0.0, 0.07, max(p - 0.02, 0.0));
			float vis = 1.0 - smoothstep(reach - 0.03, reach, y);
			float w = bolt_width * (1.0 - 0.45 * y);

			// main bolt: nearest of the 3 segments around this row
			int si = clamp(int(floor(y * float(SEGS))), 0, SEGS - 1);
			float dm = 1e3;
			for (int k = -1; k <= 1; k++) {
				int sj = clamp(si + k, 0, SEGS - 1);
				dm = min(dm, seg_dist(uv, bolt_vertex(sj, sid, base), bolt_vertex(sj + 1, sid, base)));
			}
			float core = 1.0 - smoothstep(w * 0.4, w * 1.15, dm);
			float glow = exp(-dm / (w * 6.0)) * 0.7;
			float b = (core + glow * 0.8) * vis;
			float g = glow * vis;

			// two downward side branches, each a short 3-segment zigzag leaving a bolt vertex
			for (int k = 0; k < 2; k++) {
				float fk = float(k);
				int kb = 3 + 3 * k + int(hash11(sid + fk * 5.0) * 2.0);
				float side = (bolt_vertex(kb + 1, sid, base).x >= bolt_vertex(kb, sid, base).x) ? -1.0 : 1.0;
				float dy = 0.065;
				vec2 a = bolt_vertex(kb, sid, base);
				float y0 = a.y;
				float db = 1e3;
				for (int j = 0; j < 3; j++) {
					float hj = hash11(sid * 2.3 + fk * 9.1 + float(j) * 4.7);
					float inc = side * (0.55 + 0.4 * hj) * dy / aspect * ((j % 2) == 0 ? 1.0 : 0.45);
					vec2 bb = vec2(a.x + inc, a.y + dy);
					db = min(db, seg_dist(uv, a, bb));
					a = bb;
				}
				float fade = 1.0 - smoothstep(0.0, 1.0, clamp((y - y0) / (3.0 * dy), 0.0, 1.0));
				float wb = w * 0.65;
				float bc = (1.0 - smoothstep(wb * 0.4, wb * 1.15, db)) + exp(-db / (wb * 6.0)) * 0.35;
				float bv = 1.0 - smoothstep(reach - 0.2, reach + 0.02, y);
				b += bc * (0.35 + 0.65 * fade) * bv * 0.85 * branches;
				g += exp(-db / (wb * 6.0)) * 0.3 * fade * bv * branches;
			}
			bolt_a = clamp(b, 0.0, 1.0) * env * intensity;
			glow_a = clamp(g, 0.0, 1.0) * env * intensity;
		}
		float core_mix = smoothstep(0.35, 0.9, bolt_a);
		vec3 bcol = mix(glow_color.rgb, bolt_color.rgb, core_mix);
		float ba = clamp(bolt_a + glow_a * 0.3, 0.0, 1.0);

		float a = a_flash + ba * (1.0 - a_flash);
		vec3 rgb = (flash_color.rgb * a_flash + bcol * ba * (1.0 - a_flash)) / max(a, 0.0001);
		COLOR = vec4(rgb, a * alpha_mult);
	}
}
