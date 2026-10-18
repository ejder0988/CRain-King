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
uniform float wind : hint_range(-1.0, 1.0) = -0.4;
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

group_uniforms collision_ground;
uniform sampler2D ground_height_texture : filter_linear, repeat_disable;
uniform bool use_collision_height = true;
uniform float collision_bounce_intensity : hint_range(0.0, 3.0) = 1.35;
group_uniforms;

group_uniforms storm_sweep;
uniform float right_to_left_progress : hint_range(0.0, 1.0) = 1.0;
uniform float coverage_feather : hint_range(0.01, 0.5) = 0.20;
group_uniforms;

float get_ground_y(float uv_x) {
	if (use_collision_height) {
		float h = texture(ground_height_texture, vec2(clamp(uv_x, 0.0, 1.0), 0.5)).r;
		if (h > 0.02 && h < 0.99) {
			return h;
		}
	}
	return splash_y;
}

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

// High-detail rain splash system:
// - Upward ballistic spray droplets bouncing into the air and arcing with gravity & wind
// - Expanding elliptical ripples propagating on the ground plane
// - Initial impact burst crowns and sparkles at drop contact points
// - Multi-layer dense distribution with boundary neighbor checking (no grid clipping)
// - Ground impact mist veil hovering over the rail/ground surface
vec2 splash_layer(vec2 p, float t) {
	float local_ground_y = get_ground_y(clamp(p.x / aspect, 0.0, 1.0));
	float y_min = local_ground_y - splash_depth * 1.5;
	float y_max = local_ground_y + splash_depth * 0.8;
	if (p.y < y_min || p.y > y_max || splash_amount <= 0.001) {
		return vec2(0.0);
	}

	float acc_drops = 0.0;
	float acc_crown = 0.0;
	float acc_ripples = 0.0;
	float acc_micro = 0.0;

	float s_scale = splash_depth / 0.06;

	// LAYER 1: Primary droplet splashes & ground ripples (foreground)
	float cols1 = 52.0;
	float cell_x1 = p.x * cols1;
	float col_idx1 = floor(cell_x1);

	for (int i = -1; i <= 1; i++) {
		float c_idx = col_idx1 + float(i);
		vec2 seed_vec = vec2(c_idx, seed * 19.17);
		float h_active = hash12(seed_vec + vec2(1.23, 4.56));
		if (h_active > splash_amount) {
			continue;
		}

		float h_spd = hash12(seed_vec + vec2(7.89, 2.34));
		float h_phase = hash12(seed_vec + vec2(3.45, 8.91));
		float freq = 2.8 + 2.4 * h_spd;
		float age = fract(t * freq + h_phase);

		float h_pos_x = hash12(seed_vec + vec2(9.12, 6.78));
		float h_pos_y = hash12(seed_vec + vec2(5.67, 1.23));
		float center_x = (c_idx + 0.15 + 0.70 * h_pos_x) / cols1;
		float col_uv_x = clamp(center_x / aspect, 0.0, 1.0);
		float center_ground_y = get_ground_y(col_uv_x);
		float center_y = center_ground_y + (h_pos_y - 0.5) * (splash_depth * 0.18);
		vec2 impact_pt = vec2(center_x, center_y);
		vec2 d = p - impact_pt;

		// 1. Initial Impact Crown / Flash (age < 0.20)
		if (age < 0.20) {
			float crown_age = age / 0.20;
			float crown_dist = length(d * vec2(1.0, 1.8));
			float crown_rad = (0.0025 + 0.006 * crown_age) * s_scale;
			float crown = (1.0 - smoothstep(crown_rad * 0.25, crown_rad, crown_dist)) * (1.0 - crown_age);
			acc_crown += crown;
		}

		// 2. Ballistic Bouncing Droplets (upward flight & arc with gravity/wind)
		if (age < 0.65) {
			float t_d = age;
			float vx1 = -0.016 * (0.8 + 0.4 * hash12(seed_vec + vec2(2.1, 9.4)));
			float vy1 = 0.075 * (0.85 + 0.3 * hash12(seed_vec + vec2(4.3, 7.6))) * s_scale;

			float vx2 = 0.016 * (0.8 + 0.4 * hash12(seed_vec + vec2(6.5, 3.2)));
			float vy2 = 0.070 * (0.85 + 0.3 * hash12(seed_vec + vec2(8.7, 1.8))) * s_scale;

			float vx3 = 0.005 * (hash12(seed_vec + vec2(1.9, 5.1)) - 0.5);
			float vy3 = 0.092 * (0.85 + 0.3 * hash12(seed_vec + vec2(3.8, 4.2))) * s_scale;

			float grav = 0.22 * s_scale;
			float wind_drift = wind * 0.035 * t_d;

			vec2 p_drop1 = impact_pt + vec2(vx1 * t_d + wind_drift, -vy1 * t_d + 0.5 * grav * t_d * t_d);
			vec2 p_drop2 = impact_pt + vec2(vx2 * t_d + wind_drift, -vy2 * t_d + 0.5 * grav * t_d * t_d);
			vec2 p_drop3 = impact_pt + vec2(vx3 * t_d + wind_drift, -vy3 * t_d + 0.5 * grav * t_d * t_d);

			float r_drop = 0.0019 * s_scale;
			float drop_life = smoothstep(0.0, 0.04, t_d) * (1.0 - smoothstep(0.35, 0.65, t_d));

			float d1 = length(p - p_drop1);
			float d2 = length(p - p_drop2);
			float d3 = length(p - p_drop3);

			float b1 = (1.0 - smoothstep(r_drop * 0.25, r_drop + 0.0006, d1)) * drop_life;
			float b2 = (1.0 - smoothstep(r_drop * 0.25, r_drop + 0.0006, d2)) * drop_life;
			float b3 = (1.0 - smoothstep(r_drop * 0.25, r_drop + 0.0006, d3)) * drop_life * 0.9;

			acc_drops += (b1 + b2 + b3);
		}

		// 3. Ground Ripples (squashed horizontal ellipses on rail/ground)
		if (p.y >= center_y - 0.004) {
			vec2 rip_d = d * vec2(1.0, 4.0);
			float rip_dist = length(rip_d);
			float rip_rad = (0.003 + age * 0.026) * s_scale;
			float rip_width = 0.0022 * (1.0 - age * 0.4);
			float rip_val = (1.0 - smoothstep(0.0, rip_width, abs(rip_dist - rip_rad)));
			rip_val *= (1.0 - age) * smoothstep(0.02, 0.12, age);
			acc_ripples += rip_val;
		}
	}

	// LAYER 2: Ambient High-Density Micro-Splashes (background)
	float cols2 = 76.0;
	float cell_x2 = p.x * cols2;
	float col_idx2 = floor(cell_x2);

	for (int j = -1; j <= 1; j++) {
		float c_idx2 = col_idx2 + float(j);
		vec2 seed_vec2 = vec2(c_idx2, seed * 31.41 + 17.0);
		float h_act2 = hash12(seed_vec2 + vec2(5.5, 6.6));
		if (h_act2 > splash_amount * 0.85) {
			continue;
		}

		float h_spd2 = hash12(seed_vec2 + vec2(1.1, 7.7));
		float h_ph2 = hash12(seed_vec2 + vec2(8.8, 3.3));
		float age2 = fract(t * (3.5 + 3.0 * h_spd2) + h_ph2);

		float h_x2 = hash12(seed_vec2 + vec2(2.2, 9.9));
		float h_y2 = hash12(seed_vec2 + vec2(4.4, 1.1));
		float cx2 = (c_idx2 + 0.1 + 0.8 * h_x2) / cols2;
		float col2_uv_x = clamp(cx2 / aspect, 0.0, 1.0);
		float cy2 = get_ground_y(col2_uv_x) + (h_y2 - 0.5) * (splash_depth * 0.15);
		vec2 pt2 = vec2(cx2, cy2);

		// Quick micro-pop
		if (age2 < 0.5) {
			vec2 p_micro = pt2 + vec2(wind * 0.025 * age2, -0.048 * age2 * s_scale + 0.12 * age2 * age2 * s_scale);
			float dm = length(p - p_micro);
			float m_drop = (1.0 - smoothstep(0.0006, 0.0016 * s_scale, dm)) * (1.0 - age2 * 2.0) * smoothstep(0.0, 0.04, age2);
			acc_micro += m_drop;
		}

		// Small micro-ripple
		if (p.y >= cy2 - 0.003) {
			float dm_rip = length((p - pt2) * vec2(1.0, 4.0));
			float m_rip = (1.0 - smoothstep(0.0, 0.0016, abs(dm_rip - age2 * 0.016 * s_scale))) * (1.0 - age2) * smoothstep(0.01, 0.08, age2);
			acc_micro += m_rip * 0.55;
		}
	}

	// 4. Ground impact mist along the collision plane
	float mist_band = (1.0 - smoothstep(local_ground_y, local_ground_y + splash_depth * 0.35, p.y)) * smoothstep(local_ground_y - splash_depth * 0.75, local_ground_y, p.y);
	float mist_drift = (p.x - p.y * wind * 0.4) * 8.0 - t * 0.6;
	float g_mist = vnoise(vec2(mist_drift, p.y * 35.0)) * vnoise(vec2(p.x * 20.0 + t * 0.3, p.y * 20.0));
	float ground_mist = mist_band * g_mist * 0.28 * splash_amount;

	float splash_alpha = clamp(acc_drops * 1.35 + acc_crown * 1.6 + acc_ripples * 0.9 + acc_micro * 0.8 + ground_mist, 0.0, 1.0);
	float splash_spec = clamp(acc_crown * 0.85 + acc_drops * 0.65 + acc_micro * 0.4, 0.0, 1.0);

	return vec2(splash_alpha, splash_spec);
}

void fragment() {
	float t = TIME * speed + time_offset;
	vec2 p = UV * vec2(aspect, 1.0);
	float local_ground_y = get_ground_y(UV.x);
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
	// Raindrop streaks stop at the collision surface (cannot fall through the ground)
	float ground_cut = 1.0 - smoothstep(local_ground_y - 0.010, local_ground_y + 0.003, UV.y);
	float rain_a = clamp(acc * rain_color.a * 0.8 * ground_cut, 0.0, 1.0);

	// mist veil: low-frequency streaky noise sliding with the rain
	vec2 mp = vec2((p.x - p.y * wind * 0.5) * 2.5, p.y * 1.2 - t * 0.35);
	float m = vnoise(mp) * 0.6 + vnoise(mp * 2.3 + 5.0) * 0.4;
	float mist_cut = 1.0 - smoothstep(local_ground_y - 0.01, local_ground_y + 0.04, UV.y);
	float mist_a = mist * (0.35 + 0.65 * m) * (0.4 + 0.6 * p.y) * intensity * mist_color.a * mist_cut;

	vec2 sp = splash_layer(p, t);
	float sp_a = clamp(sp.x * 1.25 * collision_bounce_intensity, 0.0, 1.0);
	float a_rain = 1.0 - (1.0 - rain_a) * (1.0 - sp_a);
	float a_all = 1.0 - (1.0 - a_rain) * (1.0 - mist_a);

	// Crisp specular highlight on water droplet heads and crowns
	vec3 splash_hl = mix(rain_color.rgb, vec3(0.96, 0.98, 1.0), sp.y);
	vec3 rain_and_splash_col = mix(rain_color.rgb, splash_hl, clamp(sp_a * 0.85, 0.0, 1.0));

	vec3 col = (rain_and_splash_col * a_rain + mist_color.rgb * mist_a * (1.0 - a_rain)) / max(a_rain + mist_a * (1.0 - a_rain), 0.0001);
	float coverage = 1.0;
	if (right_to_left_progress < 1.0) {
		float current_cutoff = mix(1.0 + coverage_feather, -coverage_feather - 0.05, right_to_left_progress);
		float edge_noise = (vnoise(vec2(UV.y * 3.0, TIME * 0.2)) - 0.5) * 0.06;
		coverage = smoothstep(current_cutoff + edge_noise, current_cutoff + edge_noise + coverage_feather, UV.x);
	}
	COLOR = vec4(col, clamp(a_all * alpha_mult * coverage, 0.0, 1.0));
}
