shader_type canvas_item;

uniform sampler2D water_mask : filter_linear;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

group_uniforms Ocean_Colors;
uniform vec4 water_color : source_color = vec4(0.04, 0.62, 0.88, 0.82);
uniform vec4 deep_water_color : source_color = vec4(0.01, 0.24, 0.52, 0.94);
uniform vec4 abyss_water_color : source_color = vec4(0.005, 0.08, 0.26, 0.98);

group_uniforms Surface_And_Waves;
uniform float threshold : hint_range(0.1, 2.5, 0.05) = 0.62;
uniform float surface_flatness : hint_range(1.0, 6.0, 0.1) = 3.6;
uniform float wave_speed : hint_range(0.0, 5.0, 0.1) = 1.8;
uniform float wave_amount : hint_range(0.0, 0.08, 0.002) = 0.014;

group_uniforms Sea_Foam;
uniform bool enable_foam = true;
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 0.92);
uniform vec4 foam_edge_color : source_color = vec4(0.70, 0.90, 0.98, 0.65);
uniform float foam_thickness : hint_range(0.02, 0.50, 0.01) = 0.16;
uniform float foam_intensity : hint_range(0.0, 2.0, 0.05) = 1.0;
uniform float foam_scale : hint_range(10.0, 150.0, 1.0) = 45.0;
uniform float foam_speed : hint_range(0.0, 4.0, 0.1) = 1.2;
uniform float foam_bubble_density : hint_range(0.1, 1.0, 0.05) = 0.80;
uniform float foam_transparency : hint_range(0.0, 1.0, 0.05) = 0.90;
uniform float foam_flow_offset = 0.0;
uniform float water_agitation = 0.0;

group_uniforms Caustics_And_Lighting;
uniform float caustic_strength : hint_range(0.0, 0.4, 0.01) = 0.12;
uniform float caustic_scale : hint_range(40.0, 350.0, 10.0) = 160.0;
uniform float sun_ray_strength : hint_range(0.0, 0.4, 0.01) = 0.07;
uniform float refraction_strength : hint_range(0.0, 0.03, 0.001) = 0.006;
uniform float chromatic_split : hint_range(0.0, 0.015, 0.001) = 0.003;

group_uniforms Micro_Bubbles;
uniform bool enable_bubbles = true;
uniform float bubble_amount : hint_range(0.0, 1.0, 0.05) = 0.40;
uniform float bubble_scale : hint_range(80.0, 500.0, 10.0) = 240.0;
uniform float bubble_speed : hint_range(0.1, 3.0, 0.1) = 0.75;

// Multi-octave surface wave
float get_surface_wave(float x, float t) {
	float w1 = sin(x * 35.0 + t * wave_speed) * wave_amount;
	float w2 = cos(x * 75.0 - t * wave_speed * 0.8) * (wave_amount * 0.45);
	float w3 = sin(x * 160.0 + t * wave_speed * 1.7) * (wave_amount * 0.2);
	return w1 + w2 + w3;
}

// Crisp, high-frequency ocean caustics (sunlight web lines)
float get_ocean_caustic(vec2 uv, float t) {
	vec2 p = uv * caustic_scale;
	vec2 v1 = p + vec2(sin(t * 1.4 + p.y * 0.03), cos(t * 1.1 + p.x * 0.03)) * 3.0;
	vec2 v2 = p + vec2(cos(-t * 1.2 + p.y * 0.025), sin(-t * 1.5 + p.x * 0.025)) * 2.5;
	float c1 = sin(v1.x * 0.7 + v1.y * 0.5);
	float c2 = cos(v2.x * 0.6 - v2.y * 0.8);
	float c3 = sin((v1.x + v2.y) * 0.45 + t * 1.8);
	float c = (c1 + c2 + c3) * 0.3333;
	return pow(clamp(c * 0.5 + 0.5, 0.0, 1.0), 3.2);
}

// Procedural micro-bubbles: small, crisp circles rising upward
float get_micro_bubbles(vec2 uv, float t) {
	if (!enable_bubbles || bubble_amount <= 0.0) {
		return 0.0;
	}

	vec2 b_uv = uv * bubble_scale;
	// Rising upward with subtle horizontal wobble
	b_uv.y -= t * 35.0 * bubble_speed;
	b_uv.x += sin(b_uv.y * 0.12 + t * 2.0 * bubble_speed) * 1.2;

	vec2 id = floor(b_uv);
	vec2 f = fract(b_uv);

	// Pseudo-random per cell
	vec2 rnd = fract(sin(vec2(dot(id, vec2(127.1, 311.7)), dot(id, vec2(269.5, 183.3)))) * 43758.5453);

	if (rnd.x > bubble_amount) {
		return 0.0;
	}

	vec2 center = 0.25 + 0.5 * rnd;
	float radius = 0.07 + 0.09 * rnd.y; // Tiny micro-bubble radius

	float dist = length(f - center);
	float body = 1.0 - smoothstep(radius * 0.65, radius, dist);
	float rim = smoothstep(radius * 0.4, radius, dist) * body;
	float glint = smoothstep(0.04, 0.015, length(f - (center + vec2(-0.025, 0.025))));

	return (rim * 0.5 + glint * 0.8) * rnd.y;
}

// Subtle diagonal underwater sun rays (God rays)
float get_sun_rays(vec2 uv, float t, float depth) {
	float ray_coord = (uv.x + uv.y * 0.4) * 32.0;
	float r1 = sin(ray_coord + t * 0.7) * 0.5 + 0.5;
	float r2 = sin(ray_coord * 1.8 - t * 0.5) * 0.5 + 0.5;
	float rays = pow(r1 * 0.65 + r2 * 0.35, 3.0);
	return rays * (1.0 - smoothstep(0.1, 0.85, depth));
}

// Fast hash
vec2 foam_hash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453123);
}

// Crisp, robust Voronoi cellular noise for sea foam bubbles and lace
vec2 voronoi_foam(vec2 uv, float t) {
	vec2 g = floor(uv);
	vec2 f = fract(uv);
	float d1 = 8.0;
	float d2 = 8.0;

	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 lattice = vec2(float(x), float(y));
			vec2 rand_p = foam_hash(g + lattice);
			// Breathing / churning motion of sea bubbles
			vec2 offset = 0.5 + 0.35 * sin(t * 1.6 + 6.28318 * rand_p);
			vec2 r = lattice + offset - f;
			float d = length(r);

			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(d1, d2 - d1);
}

// Wave turbulence for organic froth breakup
float froth_wave(vec2 uv, float t) {
	float w1 = sin(uv.x * 2.2 + uv.y * 1.4 + t * 2.0);
	float w2 = cos(uv.x * 3.6 - uv.y * 2.0 - t * 1.6);
	float w3 = sin((uv.x + uv.y) * 4.2 + t * 2.3);
	return (w1 + w2 + w3) * 0.3333 * 0.5 + 0.5;
}

// Helper to sample water density from water mask
float get_water_density(sampler2D mask, vec2 uv) {
	vec4 s = texture(mask, uv);
	return (s.r + s.g + s.b) * 0.3333 * s.a;
}

void fragment() {
	vec2 tex_size = vec2(textureSize(water_mask, 0));
	vec2 ps = vec2(surface_flatness, 1.25) / max(tex_size, vec2(1.0));

	// 13-point horizontally weighted metaball smoothing
	vec4 m = texture(water_mask, SCREEN_UV) * 0.24;
	m += texture(water_mask, SCREEN_UV + vec2(ps.x, 0.0)) * 0.14;
	m += texture(water_mask, SCREEN_UV - vec2(ps.x, 0.0)) * 0.14;
	m += texture(water_mask, SCREEN_UV + vec2(ps.x * 2.0, 0.0)) * 0.09;
	m += texture(water_mask, SCREEN_UV - vec2(ps.x * 2.0, 0.0)) * 0.09;
	m += texture(water_mask, SCREEN_UV + vec2(0.0, ps.y)) * 0.07;
	m += texture(water_mask, SCREEN_UV - vec2(0.0, ps.y)) * 0.07;
	m += texture(water_mask, SCREEN_UV + vec2(ps.x, ps.y)) * 0.04;
	m += texture(water_mask, SCREEN_UV + vec2(-ps.x, ps.y)) * 0.04;
	m += texture(water_mask, SCREEN_UV + vec2(ps.x, -ps.y)) * 0.04;
	m += texture(water_mask, SCREEN_UV + vec2(-ps.x, -ps.y)) * 0.04;

	float density = (m.r + m.g + m.b) * 0.3333 * m.a;

	// Multi-octave surface wave displacement
	float surface_wave = get_surface_wave(SCREEN_UV.x, TIME);
	float effective_threshold = threshold + surface_wave;

	if (density > effective_threshold) {
		// Anti-aliased fluid edge
		float edge_alpha = smoothstep(effective_threshold, effective_threshold + 0.035, density);

		// Depth factor (0.0 = surface, 1.0 = deep ocean core)
		float depth_factor = clamp((density - effective_threshold) / 0.85, 0.0, 1.0);

		// Optical refraction with chromatic aberration
		vec2 refr_dir = vec2(
			sin(SCREEN_UV.y * 50.0 + TIME * 2.4),
			cos(SCREEN_UV.x * 50.0 + TIME * 2.0)
		) * refraction_strength * clamp(depth_factor + 0.35, 0.0, 1.0);

		vec3 bg_color = vec3(
			texture(SCREEN_TEXTURE, SCREEN_UV + refr_dir * (1.0 + chromatic_split)).r,
			texture(SCREEN_TEXTURE, SCREEN_UV + refr_dir).g,
			texture(SCREEN_TEXTURE, SCREEN_UV + refr_dir * (1.0 - chromatic_split)).b
		);

		// Two-stage ocean depth gradient: Surface Azure -> Deep Navy -> Abyss Blue
		vec4 base_water;
		if (depth_factor < 0.5) {
			base_water = mix(water_color, deep_water_color, depth_factor * 2.0);
		} else {
			base_water = mix(deep_water_color, abyss_water_color, (depth_factor - 0.5) * 2.0);
		}

		// Crisp shimmering caustics (fine sunlight web)
		float caustic = get_ocean_caustic(SCREEN_UV, TIME) * caustic_strength * (1.0 - depth_factor * 0.55);

		// Delicate rising micro-bubbles
		float bubbles = get_micro_bubbles(SCREEN_UV, TIME) * 0.28;

		// Subtle atmospheric sun rays
		float rays = get_sun_rays(SCREEN_UV, TIME, depth_factor) * sun_ray_strength;

		base_water.rgb += vec3(caustic + bubbles + rays);

		// Realistic Ocean Sea Foam
		vec4 final_water = base_water;
		float effective_foam_alpha = 0.0;
		vec4 current_foam_col = foam_color;

		if (enable_foam && foam_intensity > 0.0) {
			// 1. Detect True Top Surface by raymarching vertically upwards (-Y)
			float max_search_uv = max(foam_thickness, 0.02) * 0.18;
			float step_uv = max_search_uv / 4.0;
			float top_foam_gradient = 0.0;
			float prev_d = density;

			for (int k = 1; k <= 4; k++) {
				float cur_offset = float(k) * step_uv;
				vec2 sample_uv = SCREEN_UV - vec2(0.0, cur_offset);
				float sample_d = get_water_density(water_mask, sample_uv);

				if (sample_d < effective_threshold) {
					// Found air above! Interpolate precise surface distance
					float frac = clamp((prev_d - effective_threshold) / max(prev_d - sample_d, 0.001), 0.0, 1.0);
					float dist_to_surface = (float(k - 1) + frac) * step_uv;
					top_foam_gradient = clamp(1.0 - (dist_to_surface / max_search_uv), 0.0, 1.0);
					break;
				}
				prev_d = sample_d;
			}

			// Rim gradient for splashes, droplets, and side boundaries
			float rim_gradient = clamp(1.0 - (density - effective_threshold) / 0.12, 0.0, 1.0) * 0.45;
			float foam_gradient = max(top_foam_gradient, rim_gradient);

			// Wall detection and backwash rebound gradient
			float sample_dist = ps.x * 6.0;
			float dens_left = texture(water_mask, SCREEN_UV - vec2(sample_dist, 0.0)).r;
			float dens_right = texture(water_mask, SCREEN_UV + vec2(sample_dist, 0.0)).r;
			// wall_grad: Sol duvarda pozitif (+), sağ duvarda negatif (-), suyun ortasında 0.0
			float wall_grad = clamp((dens_right - dens_left) * 2.5, -1.0, 1.0);
			float near_wall = abs(wall_grad);

			foam_gradient = clamp(foam_gradient + near_wall * 0.18, 0.0, 1.0);

			if (foam_gradient > 0.001) {
				// Screen aspect ratio correction so foam bubbles are uniformly round
				vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.0001), 1.0);
				vec2 foam_uv = SCREEN_UV * aspect;

				// Standing wave / sloshing oscillation (keeps foam alive without constant conveyor drift)
				float slosh_x = sin(foam_uv.x * 18.0 + TIME * wave_speed) * cos(TIME * foam_speed * 0.85) * 0.018;
				vec2 drift = vec2(foam_flow_offset + slosh_x, sin(TIME * foam_speed * 0.8) * 0.005);
				vec2 foam_coord = (foam_uv + drift) * foam_scale;

				// Rebound wave and foam compression near walls
				float rebound = sin(TIME * wave_speed * 2.5) * cos(TIME * 1.8) * 0.012 * near_wall;
				foam_coord.x += (wall_grad * rebound + wall_grad * 0.02) * foam_scale;

				// Churn and agitation modulation: slows down when water is calm, speeds up when turbulent
				float anim_time = TIME * foam_speed * mix(0.25, 1.4, clamp(water_agitation, 0.0, 1.0));

				// Fluid domain warp to stretch bubbles organically along ocean currents
				vec2 warp = vec2(
					sin(foam_coord.y * 0.15 + anim_time * 1.5),
					cos(foam_coord.x * 0.15 - anim_time * 1.2)
				) * 0.35;
				foam_coord += warp;

				// Voronoi bubble cell analysis
				vec2 v = voronoi_foam(foam_coord, anim_time);
				float d1 = v.x;        // Distance to bubble center (0.0 inside bubble)
				float d2_d1 = v.y;     // Bubble wall metric (0.0 on wall)

				// Interconnected lace webbing (bubble cell walls)
				float bubble_lace = 1.0 - smoothstep(0.03, 0.22, d2_d1);
				// Milky froth fill inside bubble clusters
				float bubble_body = 1.0 - smoothstep(0.12, 0.55 * foam_bubble_density, d1);
				// High-frequency surface fizz
				float froth = froth_wave(foam_coord * 1.6, anim_time);

				// Robust high-contrast cellular noise structure (no destructive cancellations)
				float noise_structure = max(bubble_lace, bubble_body * 0.85) + froth * 0.35;

				// Wave crest clumping (breaks up continuous lines into natural patches)
				float wave_clump = sin(foam_uv.x * 24.0 + TIME * wave_speed * 0.8) * 0.5 + 0.5;
				wave_clump = mix(0.78, 1.22, wave_clump);

				// Continuous bright crest at the very top meniscus (foam_gradient > 0.70)
				float crest = smoothstep(0.70, 0.95, foam_gradient);

				// Thresholding: transitioning down into porous bubble lace and specks
				float foam_threshold = 1.0 - (foam_gradient * wave_clump);
				float lace_mask = smoothstep(foam_threshold - 0.25, foam_threshold + 0.20, noise_structure);

				// Combine crest and lace
				float foam_mask = clamp(max(crest, lace_mask), 0.0, 1.0);

				// Blend from primary foam color (bright sea white) to translucent edge tint
				current_foam_col = mix(foam_edge_color, foam_color, smoothstep(0.1, 0.55, foam_mask));

				// Sunlight shimmer on bubble edges
				float glint = pow(clamp(sin(foam_coord.x * 1.6 + TIME * 5.0) * cos(foam_coord.y * 1.6 - TIME * 4.0), 0.0, 1.0), 7.0) * 0.30;
				current_foam_col.rgb += vec3(glint);

				// Effective foam opacity
				effective_foam_alpha = foam_mask * current_foam_col.a * foam_transparency * foam_intensity;
				effective_foam_alpha = clamp(effective_foam_alpha, 0.0, 1.0);

				// Blend foam with base water color
				final_water.rgb = mix(base_water.rgb, current_foam_col.rgb, effective_foam_alpha);
				final_water.a = mix(base_water.a, 1.0, effective_foam_alpha * 0.95);
			}
		}

		// Final composite with refracted background
		vec3 combined_rgb = mix(bg_color, final_water.rgb, final_water.a);

		// Overlay crisp, prominent sea foam directly on top so refraction never washes it out
		if (enable_foam && effective_foam_alpha > 0.001) {
			combined_rgb = mix(combined_rgb, current_foam_col.rgb, effective_foam_alpha);
		}

		COLOR = vec4(combined_rgb, edge_alpha);
	} else {
		COLOR = vec4(0.0);
	}
}