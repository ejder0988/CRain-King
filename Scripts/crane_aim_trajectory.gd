extends Node2D
class_name CraneAimTrajectory

## CraneAimTrajectory: Renders dynamic animated energy beads (dotted laser line)
## and a sci-fi target reticle / lock-on crosshair for the crane aim system.

@export var show_dots: bool = false ## Set to true if dotted laser trail should be drawn (disabled per user request)
@export var dot_count: int = 7
@export var dot_radius: float = 3.5
@export var dot_spacing: float = 46.0
@export var flow_speed: float = 140.0 ## Pixels per second of marching beam flow

var is_active: bool = true
var is_locked_on: bool = false
var aim_origin_local: Vector2 = Vector2.ZERO
var aim_dir: Vector2 = Vector2.DOWN
var aim_distance: float = 460.0
var locked_target_local: Vector2 = Vector2.ZERO
var current_color: Color = Color(0.2, 0.9, 1.0, 0.95)

var _flow_timer: float = 0.0
var _reticle_angle: float = 0.0
var _fade_alpha: float = 1.0
var _burst_tween: Tween = null


func _process(delta: float) -> void:
	if not is_active and _fade_alpha <= 0.01:
		return

	_flow_timer += delta * flow_speed
	_reticle_angle += delta * (4.5 if is_locked_on else 1.8)
	queue_redraw()


var is_rocket_tier: bool = false


func update_aim(
	origin: Vector2,
	direction: Vector2,
	distance: float,
	locked: bool,
	target_global_pos: Vector2,
	color: Color,
	active: bool,
	rocket_tier: bool = false
) -> void:
	is_active = active
	aim_origin_local = to_local(origin)
	aim_dir = direction.normalized()
	aim_distance = distance
	is_locked_on = locked
	locked_target_local = to_local(target_global_pos) if locked else aim_origin_local + aim_dir * distance
	current_color = color
	is_rocket_tier = rocket_tier

	if is_active and _fade_alpha < 1.0 and (_burst_tween == null or not _burst_tween.is_running()):
		_fade_alpha = move_toward(_fade_alpha, 1.0, 4.0 * get_process_delta_time())


func play_launch_burst() -> void:
	if _burst_tween and _burst_tween.is_valid():
		_burst_tween.kill()
	_burst_tween = create_tween()
	_burst_tween.tween_property(self, "_fade_alpha", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_burst_tween.tween_callback(func(): is_active = false)


func play_reset_pop() -> void:
	if _burst_tween and _burst_tween.is_valid():
		_burst_tween.kill()
	is_active = true
	_fade_alpha = 0.0
	_burst_tween = create_tween()
	_burst_tween.tween_property(self, "_fade_alpha", 1.0, 0.2).set_trans(Tween.TRANS_SINE)


func _draw() -> void:
	if _fade_alpha <= 0.01:
		return

	var draw_col := current_color
	draw_col.a *= _fade_alpha

	var glow_col := draw_col
	glow_col.a *= 0.35

	# 1. STREAMING ENERGY BEADS (Disabled per user request: dots removed, target reticle & crosshairs kept)
	if show_dots:
		var flow_offset: float = fmod(_flow_timer, dot_spacing)
		var max_dist: float = minf(aim_distance, (locked_target_local - aim_origin_local).length() - 20.0)

		var curr_d: float = flow_offset + 25.0
		while curr_d < max_dist:
			var dot_pos: Vector2 = aim_origin_local + aim_dir * curr_d
			var dist_factor: float = 1.0 - (curr_d / maxf(aim_distance, 1.0)) * 0.4
			var r: float = dot_radius * dist_factor

			# Subtle pulse
			var pulse: float = 1.0 + sin(_flow_timer * 0.06 + curr_d * 0.05) * 0.2
			r *= pulse

			# Outer soft glow
			draw_circle(dot_pos, r * 2.0, glow_col)
			# Core bright bead
			draw_circle(dot_pos, r, draw_col)

			curr_d += dot_spacing

	# 2. DRAW TARGET RETICLE / LANDING CROSSHAIR
	var reticle_center: Vector2 = locked_target_local
	var base_r: float = 24.0 if is_locked_on else 16.0
	var pulse_r: float = base_r + (sin(Time.get_ticks_msec() * 0.01) * 3.0 if is_locked_on else 0.0)

	if is_locked_on:
		# Lock-on Bracket Ring (Electric Gold/Green Target Box)
		_draw_lockon_reticle(reticle_center, pulse_r, draw_col, glow_col)
	else:
		# Sleek landing diamond / crosshair on terrain or max reach
		_draw_landing_crosshair(reticle_center, pulse_r, draw_col)


func _draw_lockon_reticle(center: Vector2, radius: float, col: Color, glow: Color) -> void:
	if is_rocket_tier:
		# Tier 2: Advanced Guided Rocket Tracking HUD
		var rocket_col := Color(1.0, 0.72, 0.15, col.a) # High-tech fiery gold/amber
		var rocket_glow := Color(1.0, 0.45, 0.05, glow.a * 0.9)
		var r_outer: float = radius * 1.35

		# Outer pulse tracking ring
		draw_arc(center, r_outer, 0.0, TAU, 28, rocket_glow, 2.5)
		draw_arc(center, r_outer, 0.0, TAU, 28, rocket_col, 1.5)

		# Inner rotating missile bracket ring
		var corners: int = 4
		var step: float = TAU / float(corners)
		var bracket_len: float = radius * 0.55
		for i in range(corners):
			var a: float = _reticle_angle + float(i) * step
			var corner_pt: Vector2 = center + Vector2(cos(a), sin(a)) * radius
			var t1: Vector2 = corner_pt + Vector2(-sin(a), cos(a)) * bracket_len
			var t2: Vector2 = corner_pt + Vector2(sin(a), -cos(a)) * bracket_len
			draw_line(corner_pt, t1, rocket_col, 2.4)
			draw_line(corner_pt, t2, rocket_col, 2.4)

		# Center rocket target cross
		var cross_arm: float = radius * 0.35
		draw_line(center + Vector2(-cross_arm, 0), center + Vector2(cross_arm, 0), rocket_col, 1.5)
		draw_line(center + Vector2(0, -cross_arm), center + Vector2(0, cross_arm), rocket_col, 1.5)
		draw_circle(center, 3.5, rocket_col)
	else:
		# Standard Tier 1 Target Reticle
		var corners: int = 4
		var step: float = TAU / float(corners)
		var bracket_len: float = radius * 0.45

		draw_arc(center, radius + 2.0, 0.0, TAU, 24, glow, 2.0)
		draw_arc(center, radius, 0.0, TAU, 24, col, 1.5)

		for i in range(corners):
			var a: float = _reticle_angle + float(i) * step
			var corner_pt: Vector2 = center + Vector2(cos(a), sin(a)) * radius
			var t1: Vector2 = corner_pt + Vector2(-sin(a), cos(a)) * bracket_len
			var t2: Vector2 = corner_pt + Vector2(sin(a), -cos(a)) * bracket_len
			draw_line(corner_pt, t1, col, 2.0)
			draw_line(corner_pt, t2, col, 2.0)

		draw_circle(center, 3.0, col)


func _draw_landing_crosshair(center: Vector2, radius: float, col: Color) -> void:
	var arm: float = radius * 0.65
	draw_line(center + Vector2(-arm, 0), center + Vector2(arm, 0), col, 1.2)
	draw_line(center + Vector2(0, -arm), center + Vector2(0, arm), col, 1.2)
	draw_arc(center, radius * 0.5, 0.0, TAU, 16, col, 1.0)
