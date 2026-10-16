shader_type canvas_item;

uniform float cutoff : hint_range(0.0, 0.5) = 0.25;

void fragment() {
	vec2 uv = UV;
	
	float dx = abs(uv.x - 0.5);
	float dy = abs(uv.y - 0.5);
	
	if (dx + dy > cutoff) {
		discard;
	}
	
	COLOR = texture(TEXTURE, uv);	
}