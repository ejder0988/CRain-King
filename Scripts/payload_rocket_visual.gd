extends Node2D
class_name PayloadRocketVisual

## PayloadRocketVisual: Renders dual high-octane rocket thruster exhaust, electric cyan flame plumes,
## and trailing plasma embers for the crane payload's boosted state (better_catch animation).
## Features two thruster nozzles positioned on top of the metallic cylinders shown in the design.

@export var is_firing: bool = false
@export var flame_scale: float = 1.0

## Left and right thruster nozzle local coordinates on the better_catch crane payload sprite
@export var left_nozzle: Vector2 = Vector2(-13.5, -43.0)
@export var right_nozzle: Vector2 = Vector2(13.5, -40.5)

## Electric cyan / neon blue theme colors matching user reference
@export var flame_outer_color: Color = Color(0.0, 0.95, 1.0, 0.92) # #00FFF9
@export var flame_mid_color: Color = Color(0.35, 1.0, 1.0, 0.96)
@export var flame_core_color: Color = Color(0.95, 1.0, 1.0, 1.0) # White-hot plasma core
@export var flame_halo_color: Color = Color(0.0, 0.8, 1.0, 0.22)

var _embers: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 1
	_rng.randomize()


func set_firing(firing: bool) -> void:
	if is_firing != firing:
		is_firing = firing
		queue_redraw()


func _process(delta: float) -> void:
	var needs_redraw: bool = is_firing or (_embers.size() > 0)

	# Update existing embers
	var i: int = _embers.size() - 1
	while i >= 0:
		var ember: Dictionary = _embers[i]
		ember.life -= delta * 3.5
		ember.pos += ember.vel * delta
		ember.vel *= 0.94
		if ember.life <= 0.0:
			_embers.remove_at(i)
		i -= 1

	# Spawn new embers from both nozzles while firing
	if is_firing and delta > 0.0:
		var spawn_count: int = _rng.randi_range(1, 3)
		for s in range(spawn_count):
			var nozzle: Vector2 = left_nozzle if _rng.randf() < 0.5 else right_nozzle
			_embers.append({
				"pos": nozzle + Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-2.0, 2.0)),
				"vel": Vector2(_rng.randf_range(-16.0, 16.0), _rng.randf_range(-135.0, -75.0)),
				"life": 1.0,
				"max_life": 1.0,
				"size": _rng.randf_range(1.8, 3.8),
				"is_smoke": _rng.randf() < 0.35
			})

	if needs_redraw:
		queue_redraw()


func _draw() -> void:
	# 1. DRAW DRIFTING CYAN PLASMA EMBERS & SMOKE
	for ember in _embers:
		var u: float = ember.life / ember.max_life
		if ember.is_smoke:
			# Soft semi-transparent cyan/white smoke wisp
			var col := Color(0.7, 0.9, 1.0, u * 0.3)
			draw_circle(ember.pos, ember.size * (1.8 - u * 0.8), col)
		else:
			# Electric cyan / blue spark
			var col: Color = flame_outer_color.lerp(Color(0.0, 0.5, 1.0, 0.0), 1.0 - u)
			col.a = u * 0.95
			draw_circle(ember.pos, ember.size * u, col)

	# 2. DRAW DUAL ROCKET EXHAUST FLAMES (LEFT & RIGHT NOZZLES)
	if not is_firing:
		return

	var t: float = Time.get_ticks_msec() * 0.04
	var nozzles := [left_nozzle, right_nozzle]

	for idx in range(nozzles.size()):
		var nozzle_pos: Vector2 = nozzles[idx]
		var phase_offset: float = float(idx) * 2.35
		var flicker: float = sin(t * 1.8 + phase_offset) * 3.2 + cos(t * 2.6 + phase_offset) * 1.8
		var flame_len: float = (30.0 + flicker) * flame_scale
		var flame_w: float = 7.5 * flame_scale

		# A. Soft cyan glow halo
		draw_circle(nozzle_pos + Vector2(0.0, -flame_len * 0.35), flame_w * 1.7, flame_halo_color)

		# B. Outer vibrant electric cyan plume (#00FFF9)
		var outer_pts := PackedVector2Array([
			nozzle_pos + Vector2(-flame_w * 0.85, 0.0),
			nozzle_pos + Vector2(0.0, -flame_len),
			nozzle_pos + Vector2(flame_w * 0.85, 0.0)
		])
		draw_colored_polygon(outer_pts, flame_outer_color)

		# C. Mid bright cyan plume
		var mid_pts := PackedVector2Array([
			nozzle_pos + Vector2(-flame_w * 0.52, 0.0),
			nozzle_pos + Vector2(0.0, -flame_len * 0.72),
			nozzle_pos + Vector2(flame_w * 0.52, 0.0)
		])
		draw_colored_polygon(mid_pts, flame_mid_color)

		# D. Core intense white/cyan plasma jet
		var core_pts := PackedVector2Array([
			nozzle_pos + Vector2(-flame_w * 0.26, 0.0),
			nozzle_pos + Vector2(0.0, -flame_len * 0.44),
			nozzle_pos + Vector2(flame_w * 0.26, 0.0)
		])
		draw_colored_polygon(core_pts, flame_core_color)
