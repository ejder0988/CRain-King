extends RigidBody2D
class_name EventRock

## EventRock / UpgradeRock:
## 1. Spawns at user-defined spawn_pos in the background (z_index = -2).
## 2. Accelerates upward, transitions to foreground (z_index = 5), and arcs down to landing_pos.
## 3. Upon first bounce at landing_pos, begins continuously bouncing.
## 4. First bounce starts a random 5.0 to 7.0 second countdown timer.
## 5. Player attempts to catch it with the crane payload.
## 6. If caught: consumed as fuel, crane switches to better_catch animation and activates rocket boost!
## 7. If time expires without being caught: disintegrates with a pop effect.

signal expired()
signal consumed()
signal first_bounce()

@export_group("Spawn Arc Settings")
## İlk çıkış (spawn) konumu (arkaplanda başlar)
@export var spawn_pos: Vector2 = Vector2(230, 800)
## İkinci düşüş ve sekme hedef konumu
@export var landing_pos: Vector2 = Vector2(550, 890)
## Fırlatma arkının tepe yüksekliği
@export var launch_height: float = 260.0
## Fırlatma süresi (saniye)
@export var launch_duration: float = 1.25
## Başlangıç arkaplan z-index'i
@export var background_z_index: int = -2
## Ön plan z-index'i
@export var foreground_z_index: int = 5

@export_group("Bouncing & Lifetime Settings")
## Zıplama / sekme kuvveti
@export var bounce_force: float = 420.0
## İlk zıplamadan sonra yok olma süresi min (saniye)
@export var lifetime_min: float = 5.0
## İlk zıplamadan sonra yok olma süresi max (saniye)
@export var lifetime_max: float = 7.0
## Kalan süreyi gösteren halka göstergesi
@export var show_countdown_ring: bool = true
## Tema rengi (Cyan / Enderpearl)
@export var theme_color: Color = Color(0.0, 0.95, 1.0, 1.0)
## Süre tükenirken uyarı rengi
@export var warning_color: Color = Color(1.0, 0.35, 0.2, 1.0)

@export_group("Impact & Pickup Audio")
## Yere çarptığı / sektiği zaman çalan ses
@export var impact_sound: AudioStream = preload("res://Sounds/kaya_tuğla bütün etkileşimler.wav")
## Çarpma sesi seviyesi (dB)
@export var impact_volume_db: float = -2.0
## Vinç tarafından yakalandığı zaman çalan ses
@export var pickup_sound: AudioStream = preload("res://Sounds/kaya_tuğla bütün etkileşimler.wav")
## Yakalanma sesi seviyesi (dB)
@export var pickup_volume_db: float = 0.0

var time_remaining: float = 6.0
var lifetime: float = 6.0
var is_consumed: bool = false
var is_expired: bool = false
var is_grabbed: bool = false
var has_bounced_first_time: bool = false

var _is_launching: bool = false
var _is_bouncing: bool = false
var _launch_progress: float = 0.0
var _ground_y: float = 890.0

var _pulse_tween: Tween = null
var _original_sprite_scale: Vector2 = Vector2.ONE
var _flash_timer: float = 0.0
var _last_bounce_time: float = 0.0
var _impact_audio_player: AudioStreamPlayer2D = null

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")


func _ready() -> void:
	add_to_group("rock")
	add_to_group("event_rock")
	add_to_group("upgrade_rock")
	add_to_group("cargo")
	add_to_group("grabbable")
	set_meta("is_event_rock", true)
	set_meta("is_upgrade_rock", true)

	var sfx_bus: String = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	_impact_audio_player = AudioStreamPlayer2D.new()
	_impact_audio_player.name = "EventRockAudioPlayer"
	_impact_audio_player.bus = sfx_bus
	_impact_audio_player.max_distance = 2800.0
	add_child(_impact_audio_player)

	time_remaining = randf_range(lifetime_min, lifetime_max)
	lifetime = time_remaining
	_ground_y = landing_pos.y

	if sprite:
		_original_sprite_scale = sprite.scale

	contact_monitor = true
	max_contacts_reported = 4
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_register_water_exception()
	_start_subtle_glow()


func _register_water_exception() -> void:
	var tree := get_tree()
	if not tree:
		return
	var fluid = tree.get_first_node_in_group("fluid_water")
	if fluid and fluid.has_method("add_collision_exception"):
		fluid.add_collision_exception(self)


func _start_subtle_glow() -> void:
	if not sprite:
		return
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(sprite, "scale", _original_sprite_scale * 1.12, 0.35).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(sprite, "scale", _original_sprite_scale, 0.35).set_trans(Tween.TRANS_SINE)


## Starts the launch arc from start_p to target_p
func launch_arc(start_p: Vector2, target_p: Vector2, height: float = -1.0, duration: float = -1.0) -> void:
	spawn_pos = start_p
	landing_pos = target_p
	if height > 0.0:
		launch_height = height
	if duration > 0.0:
		launch_duration = duration
	_ground_y = landing_pos.y

	global_position = spawn_pos
	z_index = background_z_index
	freeze = true
	linear_velocity = Vector2.ZERO

	# Temporarily disable grabbable during flight
	remove_from_group("grabbable")
	collision_layer = 0
	collision_mask = 0

	_is_launching = true
	_is_bouncing = false
	_launch_progress = 0.0
	has_bounced_first_time = false
	time_remaining = randf_range(lifetime_min, lifetime_max)
	lifetime = time_remaining

	print("[UpgradeRock] Fırlatma arkı başladı! Çıkış: ", spawn_pos, " -> Hedef: ", landing_pos)


func _process(delta: float) -> void:
	if is_consumed or is_expired:
		return

	# 1. Havada süzülme / fırlatma aşaması
	if _is_launching:
		_launch_progress += delta / maxf(launch_duration, 0.1)
		var t := clampf(_launch_progress, 0.0, 1.0)

		# Yatayda lineer, düşeyde parabolik yukarı ivmelenme eğrisi
		var cur_x := lerpf(spawn_pos.x, landing_pos.x, t)
		var base_y := lerpf(spawn_pos.y, landing_pos.y, t)
		var arc_offset := 4.0 * launch_height * t * (1.0 - t)
		global_position = Vector2(cur_x, base_y - arc_offset)

		# Yükselirken arkaplandan ön plana geçiş
		if t >= 0.35 and z_index != foreground_z_index:
			z_index = foreground_z_index

		if _launch_progress >= 1.0:
			_is_launching = false
			_start_bouncing()
		return

	# 2. Sekme ve geri sayım aşaması
	if _is_bouncing and not is_grabbed:
		time_remaining -= delta
		queue_redraw()

		# Son 2 saniye acil uyarı yanıp sönmesi
		if time_remaining <= 2.0 and sprite:
			_flash_timer += delta * (14.0 if time_remaining <= 1.0 else 8.0)
			var flash: float = (sin(_flash_timer) + 1.0) * 0.5
			sprite.modulate = Color.WHITE.lerp(warning_color, flash * 0.85)

		if time_remaining <= 0.0:
			time_remaining = 0.0
			disintegrate()


func _physics_process(_delta: float) -> void:
	if not _is_bouncing or is_consumed or is_expired or is_grabbed:
		return

	# Zemin seviyesine ulaştığında sürekli yukarı sek
	if global_position.y >= _ground_y and linear_velocity.y >= 0.0:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_bounce_time > 0.12:
			_last_bounce_time = now
			global_position.y = _ground_y
			linear_velocity.y = -bounce_force
			linear_velocity.x = randf_range(-30.0, 30.0)
			_play_bounce_juice()

	# Hedef X etrafında kalmasını sağla (aşırı uzaklaşmasın)
	var dist_x: float = global_position.x - landing_pos.x
	if absf(dist_x) > 80.0:
		linear_velocity.x = -signf(dist_x) * 40.0


func _start_bouncing() -> void:
	_is_bouncing = true
	has_bounced_first_time = true
	first_bounce.emit()

	# 5 ve 7 saniye arası süre
	lifetime = randf_range(lifetime_min, lifetime_max)
	time_remaining = lifetime

	global_position = landing_pos
	z_index = foreground_z_index
	freeze = false
	collision_layer = 2
	collision_mask = 1 | 2

	# Payload tarafından tutulabilmesi için grabbable grubuna ekle
	add_to_group("rock")
	add_to_group("event_rock")
	add_to_group("upgrade_rock")
	add_to_group("cargo")
	add_to_group("grabbable")

	linear_velocity = Vector2(randf_range(-20.0, 20.0), -bounce_force)
	_play_bounce_juice()

	print("[UpgradeRock] İlk zıplama gerçekleşti! Yok olma sayacı başladı: ", "%.2f" % time_remaining, " saniye.")


func _on_body_entered(body: Node) -> void:
	if not _is_bouncing or is_consumed or is_expired or is_grabbed:
		return
	if body is StaticBody2D or body.is_in_group("ground") or body.is_in_group("stone_wall"):
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_bounce_time > 0.12:
			_last_bounce_time = now
			linear_velocity.y = -bounce_force
			_play_bounce_juice()


func _play_bounce_juice() -> void:
	play_impact_sound()
	if not sprite:
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", Vector2(_original_sprite_scale.x * 1.35, _original_sprite_scale.y * 0.65), 0.06)
	tw.tween_property(sprite, "scale", Vector2(_original_sprite_scale.x * 0.85, _original_sprite_scale.y * 1.3), 0.10)
	tw.tween_property(sprite, "scale", _original_sprite_scale, 0.12)


## Yere veya duvara çarptığında çalar
func play_impact_sound() -> void:
	if not _impact_audio_player:
		return
	if impact_sound and _impact_audio_player.stream != impact_sound:
		_impact_audio_player.stream = impact_sound
	if _impact_audio_player.stream:
		_impact_audio_player.volume_db = impact_volume_db
		_impact_audio_player.pitch_scale = randf_range(0.95, 1.1)
		_impact_audio_player.play()


## Vinç tarafından yakalandığında çalar
func play_pickup_sound() -> void:
	if not _impact_audio_player:
		return
	if pickup_sound:
		_impact_audio_player.stream = pickup_sound
		_impact_audio_player.volume_db = pickup_volume_db
		_impact_audio_player.pitch_scale = randf_range(0.96, 1.04)
		_impact_audio_player.play()



func _draw() -> void:
	if not show_countdown_ring or is_consumed or is_expired or is_grabbed or _is_launching:
		return

	var progress: float = clampf(time_remaining / maxf(lifetime, 0.01), 0.0, 1.0)
	var radius: float = 34.0
	var ring_col: Color = warning_color.lerp(theme_color, clampf(progress * 1.5, 0.0, 1.0))
	ring_col.a = 0.85

	# Arka plan çemberi
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(ring_col.r, ring_col.g, ring_col.b, 0.22), 2.0, true)

	# Geri sayım yayı
	var start_angle: float = -PI * 0.5
	var end_angle: float = start_angle + TAU * progress
	if progress > 0.01:
		draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 32, ring_col, 3.2, true)


## İlk zıplamadan 5-7 saniye sonra yok olma
func disintegrate() -> void:
	if is_expired or is_consumed:
		return
	is_expired = true
	expired.emit()

	remove_from_group("rock")
	remove_from_group("event_rock")
	remove_from_group("upgrade_rock")
	remove_from_group("cargo")
	remove_from_group("grabbable")
	set_deferred("freeze", true)
	collision_layer = 0
	collision_mask = 0

	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	print("[UpgradeRock] Süre doldu! (5-7s) Upgrade Rock yok oldu.")

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", scale * 1.5, 0.18)
	tw.tween_property(self, "modulate", Color(0.2, 0.9, 1.0, 0.0), 0.22)
	tw.chain().tween_callback(queue_free)


## Payload tarafından tutulduğunda çağrılır, crane boost'unu tetikler
func consume() -> void:
	if is_consumed or is_expired:
		return
	is_consumed = true
	consumed.emit()

	remove_from_group("rock")
	remove_from_group("event_rock")
	remove_from_group("upgrade_rock")
	remove_from_group("cargo")
	remove_from_group("grabbable")
	set_deferred("freeze", true)
	collision_layer = 0
	collision_mask = 0

	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	print("[UpgradeRock] Crane payload tarafından başarıyla yakalandı! Boost aktif ediliyor.")

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", scale * 0.1, 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(queue_free)
