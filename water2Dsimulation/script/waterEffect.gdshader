shader_type canvas_item;

uniform sampler2D water_mask : filter_linear;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

group_uniforms Ocean_Colors;
uniform vec4 water_color : source_color = vec4(0.04, 0.62, 0.88, 0.82);
uniform vec4 deep_water_color : source_color = vec4(0.01, 0.24, 0.52, 0.94);
uniform vec4 abyss_water_color : source_color = vec4(0.005, 0.08, 0.26, 0.98);
uniform vec4 foam_color : source_color = vec4(0.92, 0.98, 1.0, 0.96);

group_uniforms Surface_And_Waves;
uniform float threshold : hint_range(0.1, 2.5, 0.05) = 0.62;
uniform float surface_flatness : hint_range(1.0, 6.0, 0.1) = 3.6;
uniform float foam_thickness : hint_range(0.01, 0.4, 0.01) = 0.08;
uniform float wave_speed : hint_range(0.0, 5.0, 0.1) = 1.8;
uniform float wave_amount : hint_range(0.0, 0.08, 0.002) = 0.014;

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

		// Wave crest seafoam with micro-sparkles
		float foam_mask = 1.0 - smoothstep(effective_threshold, effective_threshold + foam_thickness, density);
		float sparkle = sin(SCREEN_UV.x * 240.0 + TIME * 7.0) * cos(SCREEN_UV.y * 180.0 + TIME * 5.0);
		sparkle = pow(clamp(sparkle * 0.5 + 0.5, 0.0, 1.0), 6.0) * 0.35;
		vec4 foam = vec4(foam_color.rgb + vec3(sparkle), foam_color.a);

		vec4 final_water = mix(base_water, foam, foam_mask * 0.92);

		// Final composite with refracted background
		vec3 combined_rgb = mix(bg_color, final_water.rgb, final_water.a);
		COLOR = vec4(combined_rgb, edge_alpha);
	} else {
		COLOR = vec4(0.0);
	}
}