extends RigidBody2D
class_name Rock

## Rock: Heavy stone cargo mined from the RockPit.
## Can be picked up by the Crane and delivered to the Factory for brick processing.
## Does NOT collide with or block water particles (passes through water freely like houses).

@export var is_spawned_animated: bool = true
@export var splash_sound: AudioStream = preload("res://Sounds/Rain/water_splash.mp3")

@export_group("Impact & Pickup Audio")
## Yere veya sert yüzeye düştüğü zaman çalan çarpma sesi
@export var impact_sound: AudioStream = preload("res://Sounds/kaya_tuğla bütün etkileşimler.wav")
## Çarpma sesi seviyesi (dB)
@export var impact_volume_db: float = 0.0
## Çarpma sesinin tetiklenmesi için minimum hız
@export var min_impact_speed: float = 70.0
## Yerden vinçle alındığı zaman çalan ses
@export var pickup_sound: AudioStream = preload("res://Sounds/kaya_tuğla bütün etkileşimler.wav")
## Alınma sesi seviyesi (dB)
@export var pickup_volume_db: float = 0.0

var _is_submerged: bool = false
var _cached_fluid_water: Node = null
var _audio_player: AudioStreamPlayer2D = null
var _impact_audio_player: AudioStreamPlayer2D = null
var _last_impact_time: float = -1.0


func _ready() -> void:
	add_to_group("rock")
	add_to_group("cargo")
	add_to_group("grabbable")

	contact_monitor = true
	max_contacts_reported = 4
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# Layer 2: Cargo layer (collides with ground Layer 1, but NOT water particles)
	collision_layer = 2
	collision_mask = 1

	_cached_fluid_water = _find_fluid_water()
	if _cached_fluid_water and _cached_fluid_water.has_method("add_collision_exception"):
		_cached_fluid_water.add_collision_exception(self)

	# Setup splash audio player
	if splash_sound:
		_audio_player = AudioStreamPlayer2D.new()
		_audio_player.stream = splash_sound
		_audio_player.bus = &"Master"
		_audio_player.max_distance = 2500.0
		add_child(_audio_player)

	# Setup impact & pickup audio player
	var sfx_bus: String = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	_impact_audio_player = AudioStreamPlayer2D.new()
	_impact_audio_player.name = "RockAudioPlayer"
	_impact_audio_player.bus = sfx_bus
	_impact_audio_player.max_distance = 2800.0
	add_child(_impact_audio_player)

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

	var in_water: bool = (surf_y != INF and current_y >= surf_y - 10.0)

	if in_water and not _is_submerged:
		_is_submerged = true
		var speed := linear_velocity.length()
		if speed > 50.0:
			_play_splash_audio(speed)
			_play_splash_particle_effect()

	elif in_water and _is_submerged:
		# Realistic fluid drag & buoyancy damping while in water (zero force applied to water)
		linear_velocity = linear_velocity.move_toward(Vector2(0.0, 80.0), delta * 350.0)
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


func _play_splash_audio(speed: float) -> void:
	if _audio_player and is_instance_valid(_audio_player):
		var vol_db: float = clampf(remap(speed, 50.0, 500.0, -16.0, -2.0), -20.0, 0.0)
		_audio_player.volume_db = vol_db
		_audio_player.pitch_scale = randf_range(0.9, 1.1)
		_audio_player.play()


func _play_splash_particle_effect() -> void:
	var ripple := Line2D.new()
	ripple.width = 2.5
	ripple.default_color = Color(0.85, 0.95, 1.0, 0.7)
	var pts := PackedVector2Array()
	var segs := 16
	for i in range(segs + 1):
		var angle := float(i) * TAU / float(segs)
		pts.append(Vector2(cos(angle), sin(angle)) * 12.0)
	ripple.points = pts
	ripple.global_position = global_position
	ripple.top_level = true
	get_parent().add_child(ripple)

	var tw := ripple.create_tween().set_parallel(true)
	tw.tween_property(ripple, "scale", Vector2(2.5, 1.2), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ripple, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(ripple.queue_free)


func _play_spawn_effect() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if not sprite:
		return

	var target_scale := sprite.scale
	sprite.scale = target_scale * 0.2
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", target_scale, 0.35)


func _on_body_entered(body: Node) -> void:
	var speed := linear_velocity.length()
	if speed >= min_impact_speed:
		play_impact_sound(speed)


## Yere veya sert bir zemine düştüğünde çarpma sesi çalar
func play_impact_sound(speed: float = 0.0) -> void:
	if not _impact_audio_player:
		return
	var current_time := Time.get_ticks_msec() / 1000.0
	if _last_impact_time > 0.0 and (current_time - _last_impact_time) < 0.12:
		return
	_last_impact_time = current_time

	if impact_sound and _impact_audio_player.stream != impact_sound:
		_impact_audio_player.stream = impact_sound

	if _impact_audio_player.stream:
		var spd := speed if speed > 0.0 else linear_velocity.length()
		var vol_offset: float = clampf(remap(spd, min_impact_speed, 600.0, -10.0, 3.0), -12.0, 4.0)
		_impact_audio_player.volume_db = impact_volume_db + vol_offset
		_impact_audio_player.pitch_scale = randf_range(0.92, 1.08)
		_impact_audio_player.play()


## Yerden vinç tarafından yakalanıp kaldırıldığında çalar
func play_pickup_sound() -> void:
	if not _impact_audio_player:
		return
	if pickup_sound:
		_impact_audio_player.stream = pickup_sound
		_impact_audio_player.volume_db = pickup_volume_db
		_impact_audio_player.pitch_scale = randf_range(0.96, 1.04)
		_impact_audio_player.play()

