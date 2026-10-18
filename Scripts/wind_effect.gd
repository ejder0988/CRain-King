extends Node2D
class_name UpperWindEffect

## UpperWindEffect: Renders a continuous, gentle ambient breeze across the screen.
## Includes flowing sinusoidal wind streaks with soft tapered tails and curling tips,
## plus floating airborne breeze specks that drift continuously.

@export_group("Wind Area")
## Minimum Y (vertical) screen boundary for the wind
@export var min_y: float = 25.0
## Maximum Y (vertical) screen boundary for the wind
@export var max_y: float = 340.0
## Left horizontal spawn boundary
@export var min_x: float = -120.0
## Right horizontal boundary before wrapping
@export var max_x: float = 2040.0

@export_group("Wind Dynamics")
## Wind direction: -1.0 for blowing left (default), 1.0 for blowing right
@export var wind_direction: float = -1.0
## Base horizontal drift speed (px/sec)
@export var base_speed: float = 175.0
## Speed variation between different streaks
@export var speed_variation: float = 65.0
## Number of concurrent wind ribbon streaks
@export var streak_count: int = 15
## Number of concurrent drifting breeze specks / airborne particles
@export var speck_count: int = 26
## Overall wind streak tint and maximum opacity
@export var wind_color: Color = Color(0.92, 0.97, 1.0, 0.30)
## Specks tint
@export var speck_color: Color = Color(0.95, 0.98, 1.0, 0.38)

class StreakData:
	var head_x: float = 0.0
	var base_y: float = 0.0
	var length: float = 140.0
	var speed: float = 175.0
	var thickness: float = 2.0
	var wave_amp: float = 6.0
	var wave_freq: float = 0.015
	var phase: float = 0.0
	var alpha_mult: float = 1.0
	var has_curl: bool = false
	var curl_radius: float = 6.0
	var curl_dir: float = 1.0

class SpeckData:
	var x: float = 0.0
	var base_y: float = 0.0
	var speed: float = 160.0
	var radius: float = 1.6
	var bob_freq: float = 2.2
	var bob_amp: float = 7.0
	var phase: float = 0.0
	var alpha: float = 0.35

var _streaks: Array[StreakData] = []
var _specks: Array[SpeckData] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 2
	_rng.randomize()
	_initialize_wind()


func _initialize_wind() -> void:
	_streaks.clear()
	_specks.clear()

	# 1. Pre-warm and distribute wind streaks across screen width
	for i in range(streak_count):
		var streak := StreakData.new()
		streak.head_x = _rng.randf_range(min_x, max_x)
		streak.base_y = _rng.randf_range(min_y, max_y)
		streak.length = _rng.randf_range(90.0, 230.0)
		streak.speed = base_speed + _rng.randf_range(-speed_variation, speed_variation)
		streak.thickness = _rng.randf_range(1.4, 2.4)
		streak.wave_amp = _rng.randf_range(4.0, 9.0)
		streak.wave_freq = _rng.randf_range(0.012, 0.024)
		streak.phase = _rng.randf_range(0.0, TAU)
		streak.alpha_mult = _rng.randf_range(0.65, 1.1)
		streak.has_curl = (_rng.randf() < 0.35)
		streak.curl_radius = _rng.randf_range(4.0, 8.0)
		streak.curl_dir = 1.0 if (_rng.randf() < 0.5) else -1.0
		_streaks.append(streak)

	# 2. Pre-warm drifting breeze particles / specks
	for j in range(speck_count):
		var speck := SpeckData.new()
		speck.x = _rng.randf_range(min_x, max_x)
		speck.base_y = _rng.randf_range(min_y, max_y)
		speck.speed = base_speed * _rng.randf_range(0.8, 1.25)
		speck.radius = _rng.randf_range(1.2, 2.4)
		speck.bob_freq = _rng.randf_range(1.5, 3.2)
		speck.bob_amp = _rng.randf_range(4.0, 10.0)
		speck.phase = _rng.randf_range(0.0, TAU)
		speck.alpha = _rng.randf_range(0.2, 0.45)
		_specks.append(speck)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return

	var dir: float = -1.0 if wind_direction < 0.0 else 1.0

	# Update wind streaks
	for streak in _streaks:
		streak.head_x += streak.speed * dir * delta
		streak.phase += delta * 2.8

		if dir < 0.0:
			# Moving LEFT: wraps when tail (head_x + length) is past min_x
			if streak.head_x + streak.length < min_x:
				streak.head_x = max_x + _rng.randf_range(0.0, 80.0)
				streak.base_y = _rng.randf_range(min_y, max_y)
				streak.length = _rng.randf_range(90.0, 230.0)
				streak.speed = base_speed + _rng.randf_range(-speed_variation, speed_variation)
				streak.thickness = _rng.randf_range(1.4, 2.4)
				streak.wave_amp = _rng.randf_range(4.0, 9.0)
				streak.has_curl = (_rng.randf() < 0.35)
				streak.curl_radius = _rng.randf_range(4.0, 8.0)
				streak.curl_dir = 1.0 if (_rng.randf() < 0.5) else -1.0
		else:
			# Moving RIGHT: wraps when tail (head_x - length) is past max_x
			if streak.head_x - streak.length > max_x:
				streak.head_x = min_x - _rng.randf_range(0.0, 80.0)
				streak.base_y = _rng.randf_range(min_y, max_y)
				streak.length = _rng.randf_range(90.0, 230.0)
				streak.speed = base_speed + _rng.randf_range(-speed_variation, speed_variation)
				streak.thickness = _rng.randf_range(1.4, 2.4)
				streak.wave_amp = _rng.randf_range(4.0, 9.0)
				streak.has_curl = (_rng.randf() < 0.35)
				streak.curl_radius = _rng.randf_range(4.0, 8.0)
				streak.curl_dir = 1.0 if (_rng.randf() < 0.5) else -1.0

	# Update breeze particles
	for speck in _specks:
		speck.x += speck.speed * dir * delta
		speck.phase += delta * speck.bob_freq

		if dir < 0.0:
			if speck.x < min_x:
				speck.x = max_x + _rng.randf_range(0.0, 60.0)
				speck.base_y = _rng.randf_range(min_y, max_y)
				speck.speed = base_speed * _rng.randf_range(0.8, 1.25)
		else:
			if speck.x > max_x:
				speck.x = min_x - _rng.randf_range(0.0, 60.0)
				speck.base_y = _rng.randf_range(min_y, max_y)
				speck.speed = base_speed * _rng.randf_range(0.8, 1.25)

	queue_redraw()


func _draw() -> void:
	var dir: float = -1.0 if wind_direction < 0.0 else 1.0

	# 1. DRAW DRIFTING WIND STREAKS (Soft undulating breeze ribbons)
	for streak in _streaks:
		var tail_x: float = streak.head_x - (streak.length * dir)
		var segments: int = 10
		var step: float = (streak.length * dir) / float(segments)

		var points: PackedVector2Array = PackedVector2Array()
		var colors: PackedColorArray = PackedColorArray()

		for i in range(segments + 1):
			var px: float = tail_x + float(i) * step
			var py: float = streak.base_y + sin(streak.phase + px * streak.wave_freq) * streak.wave_amp

			# Normalized progress along streak from 0 (tail) to 1 (head)
			var u: float = float(i) / float(segments)
			# Smooth bell-curve alpha: zero at ends, peak in middle
			var a: float = sin(u * PI) * wind_color.a * streak.alpha_mult

			# Fade out near screen edges
			if px < min_x + 100.0:
				a *= clampf((px - min_x) / 100.0, 0.0, 1.0)
			elif px > max_x - 100.0:
				a *= clampf((max_x - px) / 100.0, 0.0, 1.0)

			var c := wind_color
			c.a = a

			points.append(Vector2(px, py))
			colors.append(c)

		if points.size() >= 2:
			# Draw multi-colored tapering polyline with antialiasing
			for s in range(points.size() - 1):
				var p1: Vector2 = points[s]
				var p2: Vector2 = points[s + 1]
				var seg_col: Color = (colors[s] + colors[s + 1]) * 0.5
				if seg_col.a > 0.01:
					var w: float = streak.thickness * (0.6 + 0.6 * sin(float(s) / float(segments) * PI))
					draw_line(p1, p2, seg_col, w, true)

		# If streak has a spiral curl at the head (artistic wind swirl)
		if streak.has_curl and points.size() > 0:
			var head_pt: Vector2 = points[points.size() - 1]
			var curl_a: float = colors[colors.size() - 1].a * 0.8
			if curl_a > 0.02:
				var curl_col := wind_color
				curl_col.a = curl_a
				var curl_center: Vector2 = head_pt + Vector2(0.0, -streak.curl_radius * streak.curl_dir)
				var start_ang: float = 0.0 if dir > 0.0 else PI
				var ang_span: float = PI * 1.25 * streak.curl_dir * (1.0 if dir > 0.0 else -1.0)
				draw_arc(curl_center, streak.curl_radius, start_ang, start_ang + ang_span, 10, curl_col, streak.thickness * 0.8, true)

	# 2. DRAW AIRBORNE BREEZE PARTICLES (Floating specks)
	for speck in _specks:
		var py: float = speck.base_y + sin(speck.phase) * speck.bob_amp
		var c := speck_color
		var a: float = speck.alpha

		# Edge fade
		if speck.x < min_x + 80.0:
			a *= clampf((speck.x - min_x) / 80.0, 0.0, 1.0)
		elif speck.x > max_x - 80.0:
			a *= clampf((max_x - speck.x) / 80.0, 0.0, 1.0)

		c.a = a
		if c.a > 0.01:
			draw_circle(Vector2(speck.x, py), speck.radius, c)
			# Subtle trailing wisp behind the moving particle
			var tail_col := c
			tail_col.a *= 0.4
			draw_line(Vector2(speck.x - 6.0 * dir, py), Vector2(speck.x, py), tail_col, speck.radius * 0.8)
