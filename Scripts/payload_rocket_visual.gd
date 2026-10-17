extends Node2D
class_name PayloadRocketVisual

## PayloadRocketVisual: Renders high-octane rocket thruster exhaust, flame plumes,
## and trailing smoke/embers for Tier 2 rocket-powered payload descent & flinging.

@export var is_firing: bool = false
@export var flame_scale: float = 1.0

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

	# Spawn new embers while firing
	if is_firing and delta > 0.0:
		var spawn_count: int = _rng.randi_range(1, 3)
		for s in range(spawn_count):
			_embers.append({
				"pos": Vector2(_rng.randf_range(-6.0, 6.0), -20.0),
				"vel": Vector2(_rng.randf_range(-25.0, 25.0), _rng.randf_range(-140.0, -80.0)),
				"life": 1.0,
				"max_life": 1.0,
				"size": _rng.randf_range(2.0, 4.5),
				"is_smoke": _rng.randf() < 0.4
			})

	if needs_redraw:
		queue_redraw()


func _draw() -> void:
	# 1. DRAW DRIFTING EMBERS & SMOKE
	for ember in _embers:
		var u: float = ember.life / ember.max_life
		if ember.is_smoke:
			# Gray/ash smoke puff
			var col := Color(0.4, 0.45, 0.52, u * 0.4)
			draw_circle(ember.pos, ember.size * (1.8 - u * 0.8), col)
		else:
			# Fiery ember / spark
			var col: Color = Color(1.0, 0.6, 0.1, u * 0.9).lerp(Color(1.0, 0.2, 0.05, 0.0), 1.0 - u)
			draw_circle(ember.pos, ember.size * u, col)

	# 2. DRAW MAIN ROCKET EXHAUST FLAME
	if not is_firing:
		return

	var t: float = Time.get_ticks_msec() * 0.04
	var flicker: float = sin(t * 1.8) * 3.5 + cos(t * 2.7) * 2.0
	var flame_len: float = (32.0 + flicker) * flame_scale
	var flame_w: float = 12.0 * flame_scale

	var nozzle_pos := Vector2(0.0, -18.0)

	# Outer fiery orange/red plume
	var outer_pts := PackedVector2Array([
		nozzle_pos + Vector2(-flame_w * 0.8, 0.0),
		nozzle_pos + Vector2(0.0, -flame_len),
		nozzle_pos + Vector2(flame_w * 0.8, 0.0)
	])
	draw_colored_polygon(outer_pts, Color(1.0, 0.45, 0.08, 0.9))

	# Mid bright yellow plume
	var mid_pts := PackedVector2Array([
		nozzle_pos + Vector2(-flame_w * 0.5, 0.0),
		nozzle_pos + Vector2(0.0, -flame_len * 0.72),
		nozzle_pos + Vector2(flame_w * 0.5, 0.0)
	])
	draw_colored_polygon(mid_pts, Color(1.0, 0.88, 0.25, 0.95))

	# Core intense white/cyan plasma jet
	var core_pts := PackedVector2Array([
		nozzle_pos + Vector2(-flame_w * 0.25, 0.0),
		nozzle_pos + Vector2(0.0, -flame_len * 0.42),
		nozzle_pos + Vector2(flame_w * 0.25, 0.0)
	])
	draw_colored_polygon(core_pts, Color(0.85, 0.98, 1.0, 1.0))

	# Outer soft glow halo
	draw_circle(nozzle_pos + Vector2(0.0, -flame_len * 0.3), flame_w * 1.6, Color(1.0, 0.55, 0.1, 0.25))
