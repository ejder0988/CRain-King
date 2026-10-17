shader_type canvas_item;

uniform sampler2D water_mask : filter_linear;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec4 water_color : source_color = vec4(0.04, 0.55, 0.85, 0.78);
uniform vec4 deep_water_color : source_color = vec4(0.01, 0.25, 0.52, 0.92);
uniform vec4 foam_color : source_color = vec4(0.88, 0.97, 1.0, 0.95);

uniform float threshold : hint_range(0.1, 2.5, 0.05) = 0.65;
uniform float foam_thickness : hint_range(0.01, 0.5, 0.01) = 0.12;
uniform float surface_flatness : hint_range(1.0, 6.0, 0.1) = 3.5;
uniform float wave_speed : hint_range(0.0, 5.0, 0.1) = 2.0;
uniform float wave_amount : hint_range(0.0, 0.08, 0.005) = 0.02;
uniform float refraction_strength : hint_range(0.0, 0.03, 0.001) = 0.006;

void fragment() {
	vec2 tex_size = vec2(textureSize(water_mask, 0));
	// Yatayda (X) daha geniş örnekleme yaparak top top görünümü düzleştiriyoruz
	vec2 ps = vec2(surface_flatness, 1.25) / tex_size;

	// 13-noktalı yatay ağırlıklı metaball bulanıklaştırma
	vec4 m = texture(water_mask, SCREEN_UV) * 0.22;
	m += texture(water_mask, SCREEN_UV + vec2(ps.x, 0.0)) * 0.15;
	m += texture(water_mask, SCREEN_UV - vec2(ps.x, 0.0)) * 0.15;
	m += texture(water_mask, SCREEN_UV + vec2(ps.x * 2.0, 0.0)) * 0.10;
	m += texture(water_mask, SCREEN_UV - vec2(ps.x * 2.0, 0.0)) * 0.10;
	m += texture(water_mask, SCREEN_UV + vec2(0.0, ps.y)) * 0.07;
	m += texture(water_mask, SCREEN_UV - vec2(0.0, ps.y)) * 0.07;
	m += texture(water_mask, SCREEN_UV + vec2(ps.x, ps.y)) * 0.035;
	m += texture(water_mask, SCREEN_UV + vec2(-ps.x, ps.y)) * 0.035;
	m += texture(water_mask, SCREEN_UV + vec2(ps.x, -ps.y)) * 0.035;
	m += texture(water_mask, SCREEN_UV + vec2(-ps.x, -ps.y)) * 0.035;

	float density = (m.r + m.g + m.b) * 0.333 * m.a;

	// Yüzeyde hafif su dalgası
	float surface_wave = sin(SCREEN_UV.x * 45.0 + TIME * wave_speed) * cos(SCREEN_UV.x * 18.0 - TIME * wave_speed * 0.7) * wave_amount;
	float effective_threshold = threshold + surface_wave;

	if (density > effective_threshold) {
		// Kenar yumuşatma (Anti-aliasing)
		float edge_alpha = smoothstep(effective_threshold, effective_threshold + 0.04, density);

		// Su yoğunluğuna göre derinlik faktörü (0.0 = yüzey, 1.0 = derin su)
		float depth_factor = clamp((density - effective_threshold) / 0.85, 0.0, 1.0);

		// Birleşen su içinde arka plan kırılması (Refraction)
		vec2 refract_offset = vec2(
			sin(SCREEN_UV.y * 60.0 + TIME * 3.0),
			cos(SCREEN_UV.x * 60.0 + TIME * 2.5)
		) * refraction_strength * clamp(depth_factor + 0.3, 0.0, 1.0);
		vec4 bg_color = texture(SCREEN_TEXTURE, SCREEN_UV + refract_offset);

		// Sığ ve derin su renklerini yumuşakça karıştır
		vec4 base_water = mix(water_color, deep_water_color, smoothstep(0.15, 0.9, depth_factor));

		// Birleşen suyun içinde hareketli su dalgası / kostik parlamalar
		float caustic1 = sin(SCREEN_UV.x * 55.0 + SCREEN_UV.y * 25.0 + TIME * 2.2);
		float caustic2 = cos(SCREEN_UV.x * 35.0 - SCREEN_UV.y * 40.0 - TIME * 1.6);
		float caustic = smoothstep(0.65, 0.95, (caustic1 + caustic2) * 0.5) * 0.14 * (1.0 - depth_factor * 0.5);
		base_water.rgb += vec3(caustic);

		// Yüzey köpüğü geçişi
		float foam_mask = 1.0 - smoothstep(effective_threshold, effective_threshold + foam_thickness, density);
		vec4 final_water = mix(base_water, foam_color, foam_mask * 0.9);

		// Arka plan kırılması ile su rengini birleştir
		vec3 combined_rgb = mix(bg_color.rgb, final_water.rgb, final_water.a);
		COLOR = vec4(combined_rgb, edge_alpha);
	} else {
		COLOR = vec4(0.0);
	}
}