shader_type canvas_item;

// Dış çizgi rengi (Inspector'dan renk seçici ile değiştirilebilir)
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Dış çizgi kalınlığı (0 yaparsanız çizgi tamamen kapanır)
uniform float line_thickness : hint_range(0.0, 10.0, 0.1) = 1.0;

// 8 yönlü tarama (daha pürüzsüz köşeler için)
const vec2 OFFSETS[8] = {
	vec2(-1, -1), vec2(-1, 0), vec2(-1, 1), vec2(0, -1), 
	vec2(0, 1), vec2(1, -1), vec2(1, 0), vec2(1, 1)
};

void fragment() {
	// Piksel boyutunu kalınlıkla çarpıyoruz
	vec2 size = TEXTURE_PIXEL_SIZE * line_thickness;
	float outline = 0.0;
	
	// Komşu piksellerin alfa (görünürlük) değerlerini topla
	for (int i = 0; i < OFFSETS.length(); i++) {
		outline += texture(TEXTURE, UV + size * OFFSETS[i]).a;
	}
	// Toplamı maksimum 1.0 olacak şekilde sınırla
	outline = min(outline, 1.0);
	
	vec4 color = texture(TEXTURE, UV);
	// Orijinal görselin şeffaf olduğu ama komşularının dolu olduğu yerlere line_color bas
	COLOR = mix(color, line_color, outline - color.a);
}