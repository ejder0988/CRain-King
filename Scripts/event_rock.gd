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
signal meteor_crashed(pos: Vector2)

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

@export_group("Meteor & Crash Settings")
## Bu nesne volkandan fırlatılan bir meteor mu?
@export var is_meteor: bool = false
## Yere ulaştığında sekmek yerine yere saplanıp çakılsın mı?
@export var crash_into_ground: bool = true
## Meteor alev / kor rengi
@export var meteor_theme_color: Color = Color(1.0, 0.44, 0.08, 1.0)
## Meteor geri sayım uyarı rengi
@export var meteor_warning_color: Color = Color(1.0, 0.16, 0.02, 1.0)
## Meteor yere çakılma patlama sesi
@export var meteor_impact_sound: AudioStream = preload("res://Sounds/Rain/thunder-explosion.wav")
## Meteor çarpma sesi seviyesi (dB)
@export var meteor_impact_volume_db: float = 4.0
## Meteor yere çakıldığında ekran sarsıntı şiddeti (px)
@export var meteor_shake_intensity: float = 14.0
## Meteor yere çakıldığında ekran sarsıntı süresi (saniye)
@export var meteor_shake_duration: float = 0.45

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
var is_crashed: bool = false

var _is_launching: bool = false
var _is_bouncing: bool = false
var _is_sky_drop: bool = false
var _launch_progress: float = 0.0
var _ground_y: float = 890.0

var _pulse_tween: Tween = null
var _original_sprite_scale: Vector2 = Vector2.ONE
var _flash_timer: float = 0.0
var _last_bounce_time: float = 0.0
var _impact_audio_player: AudioStreamPlayer2D = null
var _trail_particles: CPUParticles2D = null
var _ground_smoke_particles: CPUParticles2D = null

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
	if height >= 0.0:
		launch_height = height
	if duration > 0.0:
		launch_duration = duration
	_ground_y = landing_pos.y

	global_position = spawn_pos
	z_index = foreground_z_index if _is_sky_drop else background_z_index
	freeze = true
	linear_velocity = Vector2.ZERO

	# Temporarily disable grabbable during flight
	remove_from_group("grabbable")
	collision_layer = 0
	collision_mask = 0

	_is_launching = true
	_is_bouncing = false
	is_crashed = false
	_launch_progress = 0.0
	has_bounced_first_time = false
	time_remaining = randf_range(lifetime_min, lifetime_max)
	lifetime = time_remaining

	if is_meteor:
		_setup_meteor_visuals()

	print("[EventRock] Düşüş / Fırlatma başladı! Meteor: %s | Çıkış: %s -> Hedef: %s (Süre: %.2fs)" % [str(is_meteor), str(spawn_pos), str(landing_pos), launch_duration])


## Meteor olarak ekran dışı tepeden (yukarıdan) çok hızlı bir şekilde yere düşürür
func drop_from_sky(target_p: Vector2, start_y: float = -180.0, duration: float = 0.48) -> void:
	is_meteor = true
	crash_into_ground = true
	theme_color = meteor_theme_color
	warning_color = meteor_warning_color
	_is_sky_drop = true
	launch_height = 0.0
	launch_duration = duration

	var start_p := Vector2(target_p.x + randf_range(-30.0, 30.0), start_y)
	launch_arc(start_p, target_p, 0.0, duration)


## Meteor olarak gökyüzünden / volkandan iniş başlatır
func launch_as_meteor(start_p: Vector2, target_p: Vector2, height: float = 440.0, duration: float = 0.5) -> void:
	if start_p.y < 0.0 or height <= 0.0:
		drop_from_sky(target_p, minf(start_p.y, -180.0), duration)
	else:
		is_meteor = true
		crash_into_ground = true
		theme_color = meteor_theme_color
		warning_color = meteor_warning_color
		launch_arc(start_p, target_p, height, duration)


func _setup_meteor_visuals() -> void:
	if sprite:
		sprite.modulate = Color(1.3, 0.85, 0.5, 1.0) # Sıcak akkor parıltı

	# Uçuş alevli kuyruk partikülleri
	if not _trail_particles:
		_trail_particles = CPUParticles2D.new()
		_trail_particles.name = "MeteorTrail"
		_trail_particles.amount = 40
		_trail_particles.lifetime = 0.45
		_trail_particles.preprocess = 0.08
		_trail_particles.speed_scale = 1.3
		_trail_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		_trail_particles.emission_sphere_radius = 14.0
		_trail_particles.gravity = Vector2(0, -90) # Hafif yukarı süzülen alev/duman
		_trail_particles.initial_velocity_min = 25.0
		_trail_particles.initial_velocity_max = 75.0
		_trail_particles.scale_amount_min = 3.5
		_trail_particles.scale_amount_max = 7.5
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 0.8, 0.2, 0.95)) # Parlak sarı
		grad.add_point(0.4, Color(1.0, 0.35, 0.05, 0.85)) # Alev turuncu
		grad.add_point(0.8, Color(0.7, 0.12, 0.02, 0.6)) # Koyu kızıl kor
		grad.set_color(1, Color(0.2, 0.2, 0.2, 0.0)) # Gri duman ve sönüş
		_trail_particles.color_ramp = grad
		add_child(_trail_particles)


func _process(delta: float) -> void:
	if is_consumed or is_expired:
		return

	# 1. Havada süzülme / fırlatma aşaması
	if _is_launching:
		_launch_progress += delta / maxf(launch_duration, 0.05)
		var t := clampf(_launch_progress, 0.0, 1.0)

		if _is_sky_drop:
			# Yerçekimi ivmesiyle hızlanan dik ve çok hızlı iniş (Ease-In t*t)
			var fall_t := t * t
			global_position = Vector2(
				lerpf(spawn_pos.x, landing_pos.x, t),
				lerpf(spawn_pos.y, landing_pos.y, fall_t)
			)
			z_index = foreground_z_index
		else:
			# Yatayda lineer, düşeyde parabolik yukarı ivmelenme eğrisi
			var cur_x := lerpf(spawn_pos.x, landing_pos.x, t)
			var base_y := lerpf(spawn_pos.y, landing_pos.y, t)
			var arc_offset := 4.0 * launch_height * t * (1.0 - t)
			global_position = Vector2(cur_x, base_y - arc_offset)

			# Yükselirken arkaplandan ön plana geçiş
			if t >= 0.25 and z_index != foreground_z_index:
				z_index = foreground_z_index

		# Meteor uçuş rotasyonu
		if is_meteor and sprite:
			sprite.rotation += delta * 8.5

		if _launch_progress >= 1.0:
			_is_launching = false
			if is_meteor or crash_into_ground:
				_crash_land()
			else:
				_start_bouncing()
		return

	# 2. Yere çakılma veya sekme sonrası geri sayım aşaması
	if (_is_bouncing or is_crashed) and not is_grabbed:
		time_remaining -= delta
		queue_redraw()

		# Son 2 saniye acil uyarı yanıp sönmesi
		if time_remaining <= 2.0 and sprite:
			_flash_timer += delta * (14.0 if time_remaining <= 1.0 else 8.0)
			var flash: float = (sin(_flash_timer) + 1.0) * 0.5
			var base_col: Color = meteor_theme_color if is_meteor else Color.WHITE
			var target_warn: Color = meteor_warning_color if is_meteor else warning_color
			sprite.modulate = base_col.lerp(target_warn, flash * 0.85)

		if time_remaining <= 0.0:
			time_remaining = 0.0
			disintegrate()


func _physics_process(_delta: float) -> void:
	if not _is_bouncing or is_crashed or is_consumed or is_expired or is_grabbed:
		return

	# Zemin seviyesine ulaştığında sürekli yukarı sek (Sadece klasik sekme modunda)
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


## Klasik sekme başlangıcı
func _start_bouncing() -> void:
	_is_bouncing = true
	has_bounced_first_time = true
	first_bounce.emit()

	lifetime = randf_range(lifetime_min, lifetime_max)
	time_remaining = lifetime

	global_position = landing_pos
	z_index = foreground_z_index
	freeze = false
	collision_layer = 2
	collision_mask = 1 | 2

	add_to_group("rock")
	add_to_group("event_rock")
	add_to_group("upgrade_rock")
	add_to_group("cargo")
	add_to_group("grabbable")

	linear_velocity = Vector2(randf_range(-20.0, 20.0), -bounce_force)
	_play_bounce_juice()
	print("[UpgradeRock] İlk zıplama gerçekleşti! Yok olma sayacı: %.2fs" % time_remaining)


## Meteor yere çakılır, saplanır ve krater/çarpma patlaması oluşturur
func _crash_land() -> void:
	_is_bouncing = false
	is_crashed = true
	has_bounced_first_time = true
	first_bounce.emit()
	meteor_crashed.emit(landing_pos)

	lifetime = randf_range(lifetime_min, lifetime_max)
	time_remaining = lifetime

	# Zemine hafif gömülmüş/çakılmış pozisyon
	global_position = landing_pos + Vector2(0, 5.0)
	rotation = randf_range(-0.16, 0.16)
	z_index = foreground_z_index

	# Fiziksel olarak yere sabitlenir / çakılır
	freeze = true
	linear_velocity = Vector2.ZERO
	collision_layer = 2
	collision_mask = 1 | 2

	# Vinç tarafından yakalanabilmesi için gruba ekle
	add_to_group("rock")
	add_to_group("event_rock")
	add_to_group("upgrade_rock")
	add_to_group("cargo")
	add_to_group("grabbable")

	# Uçuş kuyruğunu kapat, yerde tütme dumanı başlat
	if _trail_particles:
		_trail_particles.emitting = false
	_create_ground_smoke()

	# Çarpma efektlerini ve sesini oynat
	_play_meteor_impact_vfx()
	print("[Meteor] 💥 METEOR YERE ÇAKILDI! Pozisyon: %s | Yok olma sayacı: %.2fs" % [str(global_position), time_remaining])


## Yerde kalan meteorun üzerinden ince duman tütmesi
func _create_ground_smoke() -> void:
	if _ground_smoke_particles:
		return
	_ground_smoke_particles = CPUParticles2D.new()
	_ground_smoke_particles.name = "GroundSmoke"
	_ground_smoke_particles.amount = 14
	_ground_smoke_particles.lifetime = 1.1
	_ground_smoke_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_ground_smoke_particles.emission_sphere_radius = 8.0
	_ground_smoke_particles.direction = Vector2(0, -1)
	_ground_smoke_particles.spread = 25.0
	_ground_smoke_particles.gravity = Vector2(0, -40)
	_ground_smoke_particles.initial_velocity_min = 15.0
	_ground_smoke_particles.initial_velocity_max = 35.0
	_ground_smoke_particles.scale_amount_min = 3.0
	_ground_smoke_particles.scale_amount_max = 6.0
	var grad := Gradient.new()
	grad.set_color(0, Color(0.8, 0.35, 0.1, 0.7))
	grad.add_point(0.3, Color(0.35, 0.35, 0.35, 0.5))
	grad.set_color(1, Color(0.15, 0.15, 0.15, 0.0))
	_ground_smoke_particles.color_ramp = grad
	add_child(_ground_smoke_particles)


## Meteor çarpma anı: Şok dalgası, patlama kıvılcımları, duman, ekran sarsıntısı ve güçlü ses
func _play_meteor_impact_vfx() -> void:
	# 1. Güçlü Çarpma Sesi (thunder-explosion)
	play_meteor_impact_sound()

	# 2. Ekran Sarsıntısı (Screen Shake)
	_trigger_meteor_screen_shake()

	# Sahne köküne eklenen geçici efekt grubu
	var scene_root: Node = get_tree().current_scene if get_tree() else get_parent()
	if not scene_root:
		scene_root = self

	# 3. Kıvılcım & Moloz Patlaması (CPUParticles2D)
	var sparks := CPUParticles2D.new()
	sparks.name = "MeteorSparks"
	sparks.global_position = global_position
	sparks.amount = 40
	sparks.lifetime = 0.75
	sparks.one_shot = true
	sparks.explosiveness = 0.94
	sparks.direction = Vector2(0, -1)
	sparks.spread = 75.0
	sparks.gravity = Vector2(0, 750)
	sparks.initial_velocity_min = 180.0
	sparks.initial_velocity_max = 480.0
	sparks.scale_amount_min = 3.5
	sparks.scale_amount_max = 7.5
	var sp_grad := Gradient.new()
	sp_grad.set_color(0, Color(1.0, 0.9, 0.3, 1.0)) # Kor sarı
	sp_grad.add_point(0.4, Color(1.0, 0.4, 0.05, 0.9)) # Alev turuncu
	sp_grad.set_color(1, Color(0.6, 0.1, 0.0, 0.0)) # Sönen kor
	sparks.color_ramp = sp_grad
	scene_root.add_child(sparks)
	sparks.emitting = true

	# 4. Şok Dalgası Görseli (Shockwave Ring)
	var shockwave := Node2D.new()
	shockwave.name = "MeteorShockwave"
	shockwave.global_position = global_position
	scene_root.add_child(shockwave)

	var sw_radius: Array[float] = [8.0]
	var sw_alpha: Array[float] = [0.9]
	shockwave.draw.connect(func():
		shockwave.draw_arc(Vector2.ZERO, sw_radius[0], 0.0, TAU, 36, Color(1.0, 0.55, 0.15, sw_alpha[0]), 4.0, true)
		shockwave.draw_arc(Vector2.ZERO, sw_radius[0] * 0.75, 0.0, TAU, 36, Color(1.0, 0.85, 0.35, sw_alpha[0] * 0.6), 2.5, true)
	)

	var sw_tween := shockwave.create_tween().set_parallel(true)
	sw_tween.tween_method(func(v: float):
		sw_radius[0] = v
		shockwave.queue_redraw()
	, 8.0, 150.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sw_tween.tween_method(func(a: float):
		sw_alpha[0] = a
		shockwave.queue_redraw()
	, 0.95, 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sw_tween.chain().tween_callback(shockwave.queue_free)

	# 5. Otomatik temizlik (Kıvılcımlar bittiğinde)
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(func():
		if is_instance_valid(sparks):
			sparks.queue_free()
	)


## Ekran sarsıntısı tetikler
func _trigger_meteor_screen_shake() -> void:
	var viewport := get_viewport()
	if not viewport:
		return
	var cam: Camera2D = viewport.get_camera_2d()
	if cam and is_instance_valid(cam):
		var tw := cam.create_tween()
		var steps: int = 8
		var step_dur: float = meteor_shake_duration / float(steps)
		for i in range(steps):
			var damp: float = pow(1.0 - (float(i) / float(steps)), 1.3)
			var shake_offset := Vector2(
				randf_range(-meteor_shake_intensity, meteor_shake_intensity) * damp,
				randf_range(-meteor_shake_intensity * 0.85, meteor_shake_intensity * 0.85) * damp
			)
			tw.tween_property(cam, "offset", shake_offset, step_dur).set_trans(Tween.TRANS_SINE)
		tw.tween_property(cam, "offset", Vector2.ZERO, step_dur * 0.5)


## Meteor yere çakılma sesini çalar
func play_meteor_impact_sound() -> void:
	if not _impact_audio_player:
		return
	if meteor_impact_sound:
		_impact_audio_player.stream = meteor_impact_sound
		_impact_audio_player.volume_db = meteor_impact_volume_db
		_impact_audio_player.pitch_scale = randf_range(0.92, 1.06)
		_impact_audio_player.play()
	else:
		play_impact_sound()


func _on_body_entered(body: Node) -> void:
	if not _is_bouncing or is_crashed or is_consumed or is_expired or is_grabbed:
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
	var base_ring_color: Color = meteor_theme_color if is_meteor else theme_color
	var base_warn_color: Color = meteor_warning_color if is_meteor else warning_color
	var ring_col: Color = base_warn_color.lerp(base_ring_color, clampf(progress * 1.5, 0.0, 1.0))
	ring_col.a = 0.85

	# Arka plan çemberi
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(ring_col.r, ring_col.g, ring_col.b, 0.22), 2.0, true)

	# Geri sayım yayı
	var start_angle: float = -PI * 0.5
	var end_angle: float = start_angle + TAU * progress
	if progress > 0.01:
		draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 32, ring_col, 3.2, true)


## İlk zıplamadan / çakılmadan 5-7 saniye sonra yok olma
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

	if _trail_particles:
		_trail_particles.emitting = false
	if _ground_smoke_particles:
		_ground_smoke_particles.emitting = false

	print("[EventRock] Süre doldu! (5-7s) Taş parçalanarak yok oldu.")

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", scale * 1.5, 0.18)
	var fade_col := Color(1.0, 0.35, 0.05, 0.0) if is_meteor else Color(0.2, 0.9, 1.0, 0.0)
	tw.tween_property(self, "modulate", fade_col, 0.22)
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

	if _trail_particles:
		_trail_particles.emitting = false
	if _ground_smoke_particles:
		_ground_smoke_particles.emitting = false

	print("[EventRock] Crane payload tarafından başarıyla yakalandı! Boost aktif ediliyor.")

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", scale * 0.1, 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(queue_free)
