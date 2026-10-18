shader_type canvas_item;

// Karadelik çöküşü: girdap + piksel blok kopuşu + olay ufku + yığılma diski.
// intensity 0 = normal ekran, 1 = tam karanlık.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float radius = 0.22;
uniform float swirl = 2.5;
uniform float spin_speed = 2.0;
uniform float anim_time = 0.0;
uniform float block_count = 180.0;
uniform vec4 disk_color : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform float fov_widen = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 sz = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 asp = vec2(sz.x / sz.y, 1.0);
	vec2 d = (uv - center) * asp;
	float dist = length(d);
	vec2 n = d / max(dist, 0.0001);

	// 1. Girdap: her tetiklemede anim_time (0.0'dan başlayan yerel süre) kullanılır,
	// böylece oyunun ne kadar süredir açık kaldığından bağımsız daima aynı sabit hızla döner.
	float fall = exp(-dist * 3.0);
	float rot = (anim_time * spin_speed * fall + swirl * exp(-dist * 4.0)) * intensity;
	float cs = cos(rot);
	float sn = sin(rot);
	vec2 rd = mat2(vec2(cs, -sn), vec2(sn, cs)) * d;
	vec2 suv = center + rd / asp;

	// 2. Piksel blok kopuşu: her blok hash'ine göre farklı anda merkeze çakılır
	vec2 cell = floor(uv * block_count);
	vec2 buv = (cell + 0.5) / block_count;
	vec2 bd = (buv - center) * asp;
	float h = hash12(cell);
	float thresh = intensity * 1.4 - length(bd) * 1.1 - (1.0 - h) * 0.4;
	float suck = clamp(thresh, 0.0, 1.0);
	suck = suck * suck * (3.0 - 2.0 * suck);
	// Sonda garanti karanlık: global terim her bloğu tam yutar
	suck = max(suck, smoothstep(0.7, 0.95, intensity));
	suv = mix(suv, center + bd * 0.03 / asp, suck);

	// FOV açılması taklidi: kenarlar dışa gerilir (dolly-zoom hissi)
	suv = center + (suv - center) * (1.0 + fov_widen * dist * dist);

	// 3. Renk kaymalı örnekleme
	float ca = intensity * 0.012 * (0.3 + dist);
	vec3 col = vec3(
		texture(screen_texture, suv + n * ca / asp).r,
		texture(screen_texture, suv).g,
		texture(screen_texture, suv - n * ca / asp).b
	);

	// 4. Olay ufku (kara disk)
	float hor = radius * intensity;
	float in_hole = (1.0 - smoothstep(hor * 0.9, max(hor, 0.0001), dist)) * step(0.001, hor);
	col = mix(col, vec3(0.0), in_hole);

	// 5. Yığılma diski + foton halkası (sonda o da yutulur)
	float endfade = 1.0 - smoothstep(0.75, 1.0, intensity);
	float gate = step(0.001, hor);
	float rim = (1.0 - smoothstep(0.0, 0.012, abs(dist - hor * 1.05))) * gate;
	float ang = atan(d.y, d.x);
	float bands = 0.5 + 0.5 * sin(ang * 3.0 - anim_time * spin_speed * 4.0 / (dist + 0.25) + dist * 14.0);
	float ring = exp(-pow((dist - hor * 1.6) / max(hor * 0.4, 0.001), 2.0)) * gate;
	vec3 glow = disk_color.rgb * (bands * ring * 0.8 + rim * 1.0);
	col += glow * intensity * endfade;

	// 6. Kıyamet vinyeti
	col *= 1.0 - intensity * 0.35 * smoothstep(0.3, 0.9, dist);

	// 7. Final mühür: sonda mutlak karanlık
	col = mix(col, vec3(0.0), smoothstep(0.9, 1.0, intensity));

	COLOR = vec4(col, 1.0);
}
