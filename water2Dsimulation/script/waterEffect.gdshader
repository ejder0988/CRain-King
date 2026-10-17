shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec4 water_color : source_color = vec4(0.0, 0.52, 0.78, 0.88);
uniform vec4 deep_water_color : source_color = vec4(0.0, 0.32, 0.58, 0.95);
uniform vec4 foam_color : source_color = vec4(0.85, 0.96, 1.0, 0.95);
uniform vec4 TG_COLOR : source_color = vec4(1.0, 0.0, 1.0, 1.0);

uniform float color_detect_threshold : hint_range(0.0, 1.0, 0.05) = 0.35;
uniform float threshold : hint_range(0.5, 3.0, 0.05) = 2.05;
uniform float foam_thickness : hint_range(0.0, 0.8, 0.02) = 0.22;

void fragment() {
	vec4 PIXEL = textureLod(SCREEN_TEXTURE, SCREEN_UV, 1.5).rgba;
	float brightness = PIXEL.r + PIXEL.g + PIXEL.b;

	if (brightness > threshold) {
		if (brightness < threshold + foam_thickness) {
			COLOR = foam_color;
		} else if (brightness > threshold + 0.55) {
			COLOR = deep_water_color;
		} else {
			COLOR = water_color;
		}
	} else {
		COLOR = vec4(0.0);
	}
}