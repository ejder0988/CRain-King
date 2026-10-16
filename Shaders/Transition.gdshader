shader_type canvas_item;

uniform sampler2D mask;
// Akıcı bir animasyon için step değerini 0.001 yaptık
uniform float scale : hint_range(0.0, 1.0, 0.001) = 0.0;
// AnimationPlayer'dan kolayca kontrol edebilmen için derece cinsinden dönüş (0 ile 360 arası tam tur)
uniform float rotation_degrees : hint_range(-360.0, 360.0, 0.1) = 0.0;

void fragment() {
	float s = scale == 0.0 ? 0.0 : pow(2.0, 10.0 * scale - 10.0);
	s *= 75.0f;
	int cutoff = int(s / 75.0f);
	
	// 1. UV merkezini (0.5, 0.5) noktasından (0.0, 0.0) noktasına taşı
	vec2 centered_uv = UV - vec2(0.5);
	
	// 2. Dereceyi radyana çevir ve döndürme (rotasyon) matrisini uygula
	float rad = radians(rotation_degrees);
	float c = cos(rad);
	float sn = sin(rad);
	vec2 rotated_uv = vec2(
		centered_uv.x * c - centered_uv.y * sn,
		centered_uv.x * sn + centered_uv.y * c
	);
	
	// 3. Ölçeklendirmeyi uygula ve merkezi tekrar (0.5, 0.5) noktasına geri çek
	vec2 final_uv = rotated_uv * s + vec2(0.5);
	
	vec4 mask_color = texture(mask, final_uv);
	COLOR.a = 1.0 - mask_color.a + float(cutoff);
}