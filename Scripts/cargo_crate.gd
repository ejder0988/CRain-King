extends RigidBody2D
class_name CargoCrate

## CargoCrate: Physical rock cargo crate.
## Does NOT block water particles (passes through water freely like houses),
## but generates dynamic water waves/ripples when dropped into water from above.

@export var is_spawned_animated: bool = true
@export var grow_duration: float = 0.45
@export var settle_duration: float = 0.25
@export var overshoot_scale: float = 1.12
@export var splash_sound: AudioStream = preload("res://Sounds/Rain/water_splash.mp3")

var _is_submerged: bool = false
var _cached_fluid_water: Node = null
var _audio_player: AudioStreamPlayer2D = null


func _ready() -> void:
	add_to_group("rock")
	add_to_group("cargo")
	add_to_group("grabbable")

	contact_monitor = true
	max_contacts_reported = 4
	collision_layer = 2
	collision_mask = 1

	_cached_fluid_water = _find_fluid_water()
	if _cached_fluid_water and _cached_fluid_water.has_method("add_collision_exception"):
		_cached_fluid_water.add_collision_exception(self)

	if splash_sound:
		_audio_player = AudioStreamPlayer2D.new()
		_audio_player.stream = splash_sound
		_audio_player.bus = &"Master"
		_audio_player.max_distance = 2500.0
		add_child(_audio_player)

	if is_spawned_animated:
		_play_spawn_effect()


func _physics_process(delta: float) -> void:
	if not _cached_fluid_water or not is_instance_valid(_cached_fluid_water):
		_cached_fluid_water = _find_fluid_water()
		if not _cached_fluid_water:
			return

	var current_y := global_position.y
	var surf_y: float = INF
	if _cached_fluid_water.has_method("get_water_surface_y_in_range"):
		surf_y = _cached_fluid_water.get_water_surface_y_in_range(global_position.x - 25.0, global_position.x + 25.0, 2)

	var near_drops: int = 0
	if _cached_fluid_water.has_method("count_particles_near"):
		near_drops = _cached_fluid_water.count_particles_near(global_position, 40.0)

	var in_water: bool = (surf_y != INF and current_y >= surf_y - 12.0) or near_drops >= 2

	if in_water and not _is_submerged:
		_is_submerged = true
		var speed := linear_velocity.length()
		if speed > 50.0 and _audio_player and is_instance_valid(_audio_player):
			_audio_player.pitch_scale = randf_range(0.9, 1.1)
			_audio_player.play()


	elif in_water and _is_submerged:
		linear_velocity = linear_velocity.move_toward(Vector2(0.0, 70.0), delta * 350.0)
		angular_velocity *= 0.94

	elif not in_water and _is_submerged:
		_is_submerged = false


func _find_fluid_water() -> Node:
	var tree := get_tree()
	if not tree:
		return null
	var w = tree.get_first_node_in_group("fluid_water")
	if w:
		return w
	if tree.current_scene:
		w = tree.current_scene.find_child("FluidWater", true, false)
		if w:
			return w
	return null


func _play_spawn_effect() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if not sprite:
		return

	var target_scale := sprite.scale
	sprite.scale = Vector2.ZERO

	var tween := create_tween()
	tween.tween_property(sprite, "scale", target_scale * overshoot_scale, grow_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", target_scale, settle_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
