extends Node2D
class_name HousesManager

## HousesManager:
## 1. Ensures houses NEVER collide with fluid water simulation (collision isolation).
## 2. Detects when water level rises and ACTUALLY submerges the house collision (not stray splashes).
## 3. Handles multi-level house damage (roof-downwards destruction) and Level 1 total collapse.
## 4. House levels represent player health. When total health reaches 0 -> GAME OVER!
## 5. Spawns physical debris fragments that interact with water (Layer 1/Mask 1 + buoyancy).
## 6. Shows Health HUD & stylish Game Over screen with 'R' restart.

signal house_destroyed(house: Node2D, house_name: String)
signal all_houses_destroyed
signal health_changed(current_health: int, max_health: int)
signal game_over

@export_group("Breaking Animation & Destruction")
## Name of the break animation to play on the house's AnimationPlayer or AnimatedSprite2D
@export var break_animation_name: String = "destroy"
## Fallback duration (in seconds) if user has not yet added an AnimationPlayer/AnimatedSprite2D
@export var fallback_break_duration: float = 1.2

@export_group("Submersion & Flood Detection")
## Minimum water particles that must be inside the house collision rectangle to consider it flooded
@export var min_particles_in_collision: int = 5
## Duration (in seconds) the house collision must be continuously submerged under water before taking damage
@export var submersion_duration: float = 0.35
## Cooldown in seconds before an upgraded house can take another flood damage step
@export var flood_damage_cooldown: float = 1.2

@export_group("Debris Settings")
## Number of debris fragments spawned per collapsed house or broken floor
@export var debris_count_min: int = 6
@export var debris_count_max: int = 10
## Outward horizontal scatter speed of debris
@export var debris_scatter_h: float = 75.0
## Upward launch speed of debris
@export var debris_scatter_v: float = 110.0

@export_group("UI & Health Display")
## Show total house health HUD at top-center of screen
@export var show_health_hud: bool = true

var _managed_houses: Array[StaticBody2D] = []
var _submerged_timers: Dictionary = {}       # house -> float (elapsed continuous submersion time)
var _damage_cooldown_until: Dictionary = {}  # house -> int (msec timestamp)
var _cached_fluid_water: FluidWater = null

var _hud_layer: CanvasLayer = null
var _health_label: Label = null
var _game_over_ui: Control = null
var _is_game_over: bool = false


func _ready() -> void:
	add_to_group("houses_manager")
	_init_houses()
	if show_health_hud:
		_create_health_hud()
	_update_health_hud()


## Controls the upgrade pointer visibility across all managed houses
func set_upgrade_pointers_visible(show: bool) -> void:
	for house in _managed_houses:
		if is_instance_valid(house) and house.has_method("set_pointer_visible"):
			house.set_pointer_visible(show)


func _init_houses() -> void:
	_managed_houses.clear()
	_submerged_timers.clear()
	_damage_cooldown_until.clear()

	_cached_fluid_water = _find_fluid_water()

	for child in get_children():
		if child is StaticBody2D:
			var house := child as StaticBody2D
			_managed_houses.append(house)
			_submerged_timers[house] = 0.0

			# Evlerin collision'ı su simülasyonunu engellemeyecek
			house.collision_layer = 0
			house.collision_mask = 0

			var col := house.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if col:
				col.disabled = true

			# Su simülasyonuna da ek güvence olarak bildir
			if _cached_fluid_water:
				_cached_fluid_water.add_collision_exception(house)

			# House sinyallerini doğrudan bağla
			if house.has_signal("level_changed"):
				if not house.level_changed.is_connected(_on_house_level_changed):
					house.level_changed.connect(_on_house_level_changed)
			if house.has_signal("floor_broken"):
				if not house.floor_broken.is_connected(_on_house_floor_broken):
					house.floor_broken.connect(_on_house_floor_broken)
			if house.has_signal("house_destroyed"):
				if not house.house_destroyed.is_connected(_on_house_destroyed):
					house.house_destroyed.connect(_on_house_destroyed)

	print("[HousesManager] Başlatıldı: ", _managed_houses.size(), " ev aktif. Toplam Can: ", get_total_health())


func _physics_process(delta: float) -> void:
	if _is_game_over or _managed_houses.is_empty():
		return

	if not _cached_fluid_water or not is_instance_valid(_cached_fluid_water):
		_cached_fluid_water = _find_fluid_water()
		if not _cached_fluid_water:
			return

	var current_time_msec := Time.get_ticks_msec()

	for i in range(_managed_houses.size() - 1, -1, -1):
		var house: StaticBody2D = _managed_houses[i]
		if not is_instance_valid(house):
			_managed_houses.remove_at(i)
			continue

		# Kırılma animasyonu oynarken veya yok edilirken yeni hasar almasın
		if ("is_breaking" in house and house.is_breaking) or ("is_destroyed" in house and house.is_destroyed):
			_submerged_timers[house] = 0.0
			continue

		# Hasar bekleme süresi kontrolü (cooldown)
		if current_time_msec < _damage_cooldown_until.get(house, 0):
			_submerged_timers[house] = 0.0
			continue

		var bounds := _get_house_bounds(house)
		var is_submerged := _check_house_collision_submerged(bounds)

		if is_submerged:
			var t: float = _submerged_timers.get(house, 0.0) + delta
			_submerged_timers[house] = t

			# Evin collision'ı belirlenen süre boyunca (0.35s) kesintisiz su altında kaldıysa hasar ver
			if t >= submersion_duration:
				_submerged_timers[house] = 0.0
				_damage_cooldown_until[house] = current_time_msec + int(flood_damage_cooldown * 1000.0)
				_start_house_destruction(house, bounds)
		else:
			# Su çekildiğinde batma sayacını hızla sıfırla (tekil sıçramaların birikmesini önler)
			var t: float = _submerged_timers.get(house, 0.0)
			if t > 0.0:
				_submerged_timers[house] = maxf(t - delta * 2.5, 0.0)


## Evin collision kutusunun GERÇEKTEN su altında kalıp kalmadığını kontrol eder.
## Tekil havaya sıçrayan damlalar evi yıkamaz; gerçek su kütlesinin collision'ı doldurması gerekir.
func _check_house_collision_submerged(bounds: Dictionary) -> bool:
	if not _cached_fluid_water or not is_instance_valid(_cached_fluid_water):
		return false

	# 1. Evin zemin temelinde su var mı kontrol et!
	# Çatıya dökülen veya havadan geçen sular zemin seli yükselmeden evi yıkamaz.
	var base_rect := Rect2(bounds.left, bounds.bottom - 16.0, bounds.width, 24.0)
	var base_particles := _cached_fluid_water.count_particles_in_rect(base_rect)
	if base_particles < 2:
		return false

	var col_rect := Rect2(bounds.left, bounds.top, bounds.width, bounds.height)

	# 2. Collision kutusunun içindeki gerçek su parçacığı sayısını kontrol et
	var particles_inside: int = _cached_fluid_water.count_particles_in_rect(col_rect)
	if particles_inside < min_particles_in_collision:
		return false

	# 3. Yoğun su kütlesinin yüzeyini kontrol et (havada tek uçuşan damlaları filtreler)
	var dense_water_y: float = _cached_fluid_water.get_dense_water_surface_y(bounds.left, bounds.right, 4)
	if is_inf(dense_water_y):
		return false

	# Yoğun su seviyesi evin collision'ının üst kenarına (çatısına) ulaştı mı?
	return dense_water_y <= bounds.top + 2.0


func _start_house_destruction(house: StaticBody2D, bounds: Dictionary) -> void:
	# 1. Eğer ev hasar alma metoduna sahipse multi-level hasar mekaniğini çağır
	if house.has_method("take_damage"):
		var lvl = house.get("current_level")
		print("Ev collision'ı su altında kaldı, hasar alıyor: ", house.name, " (Mevcut Seviye: ", lvl, ")")
		house.take_damage()
		return

	# 2. Standart StaticBody2D için geriye uyumlu prosedürel yıkılma
	print("Ev collision'ı su altında kaldı, yıkılma animasyonu başlıyor: ", house.name)
	_play_fallback_break_animation(house, bounds)


func _on_house_level_changed(_new_lvl: int, _max_lvl: int) -> void:
	_update_health_hud()


func _on_house_floor_broken(house: Node2D, broken_floor: int, remaining_level: int) -> void:
	if is_instance_valid(house):
		var bounds := _get_house_bounds(house)
		_spawn_house_debris(house, bounds)
	_update_health_hud()
	var h_name: String = house.name if is_instance_valid(house) else "Ev"
	print("[HousesManager] ", h_name, " çatı katı (Kat ", broken_floor, ") kırıldı. Kalan seviye: ", remaining_level)


func _on_house_destroyed(house: Node2D) -> void:
	var h_name: String = house.name if is_instance_valid(house) else "Ev"
	_managed_houses.erase(house)
	_submerged_timers.erase(house)
	_damage_cooldown_until.erase(house)

	if is_instance_valid(house):
		var bounds := _get_house_bounds(house)
		_spawn_house_debris(house, bounds)
		house_destroyed.emit(house, h_name)

	_update_health_hud()

	if _managed_houses.is_empty() or get_total_health() <= 0:
		all_houses_destroyed.emit()
		_trigger_game_over()


func _play_fallback_break_animation(house: StaticBody2D, bounds: Dictionary) -> void:
	if not is_instance_valid(house):
		return

	var start_pos := house.position
	var tween := create_tween().set_parallel(true)

	var sprite := house.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		var shake_tween := create_tween()
		for s in range(8):
			shake_tween.tween_property(sprite, "offset:x", randf_range(-3.0, 3.0), 0.06)
			shake_tween.tween_property(sprite, "offset:x", 0.0, 0.06)

	var tilt_angle: float = deg_to_rad(randf_range(6.0, 14.0) * (1.0 if randf() > 0.5 else -1.0))
	tween.tween_property(house, "rotation", tilt_angle, fallback_break_duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(house, "position:y", start_pos.y + 12.0, fallback_break_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(house, "modulate:a", 0.0, fallback_break_duration).set_delay(fallback_break_duration * 0.6)

	tween.chain().tween_callback(_finish_house_collapse.bind(house, bounds))


func _finish_house_collapse(house: StaticBody2D, bounds: Dictionary) -> void:
	if not is_instance_valid(house):
		return

	var h_name := house.name
	print("Ev yıkıldı: ", h_name)
	house_destroyed.emit(house, h_name)
	_spawn_house_debris(house, bounds)

	_managed_houses.erase(house)
	_submerged_timers.erase(house)
	_damage_cooldown_until.erase(house)
	house.queue_free()

	_update_health_hud()

	if _managed_houses.is_empty() or get_total_health() <= 0:
		all_houses_destroyed.emit()
		_trigger_game_over()


## Oyundaki tüm aktif evlerin toplam seviyesini (oyuncunun canını) hesaplar
func get_total_health() -> int:
	var total: int = 0
	for h in _managed_houses:
		if is_instance_valid(h):
			if "current_level" in h:
				total += int(h.current_level)
			else:
				total += 1
	return total


## Oyundaki maksimum can miktarını hesaplar
func get_max_health() -> int:
	var max_hp: int = 0
	for h in _managed_houses:
		if is_instance_valid(h):
			if "max_level" in h:
				max_hp += int(h.max_level)
			else:
				max_hp += 1
	return maxi(max_hp, 1)


## Tüm evler yıkıldığında veya oyuncunun canı bittiğinde tetiklenir
func _trigger_game_over() -> void:
	if _is_game_over:
		return
	_is_game_over = true
	print("========================================")
	print("[GAME OVER] TÜM EVLERİN CANI BİTTİ! OYUN BİTTİ!")
	print("Yeniden başlamak için 'R' tuşuna basın.")
	print("========================================")
	game_over.emit()
	_show_game_over_ui()


func _create_health_hud() -> void:
	if _hud_layer and is_instance_valid(_hud_layer):
		return

	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HouseHealthHUD"
	_hud_layer.layer = 10
	add_child(_hud_layer)

	var panel := PanelContainer.new()
	panel.name = "HealthPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-220.0, 16.0)
	panel.custom_minimum_size = Vector2(190.0, 48.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.85)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.2, 0.7, 1.0, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	_health_label = Label.new()
	_health_label.name = "HealthLabel"
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_label.text = "🏠 CAN: 0"
	_health_label.add_theme_font_size_override("font_size", 16)
	_health_label.modulate = Color(1.0, 0.85, 0.2)

	panel.add_child(_health_label)
	_hud_layer.add_child(panel)


func _update_health_hud() -> void:
	var cur := get_total_health()
	var max_hp := get_max_health()
	health_changed.emit(cur, max_hp)

	if _health_label and is_instance_valid(_health_label):
		_health_label.text = "🏠 ŞEHİR CANI: %d" % cur
		if cur <= 1:
			_health_label.modulate = Color(1.0, 0.25, 0.25)
		elif cur <= 3:
			_health_label.modulate = Color(1.0, 0.75, 0.2)
		else:
			_health_label.modulate = Color(0.3, 1.0, 0.5)


func _show_game_over_ui() -> void:
	if _game_over_ui and is_instance_valid(_game_over_ui):
		return

	if not _hud_layer or not is_instance_valid(_hud_layer):
		_create_health_hud()

	var overlay := ColorRect.new()
	overlay.name = "GameOverOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.02, 0.02, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var center_box := VBoxContainer.new()
	center_box.set_anchors_preset(Control.PRESET_CENTER)
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 18)

	var title := Label.new()
	title.text = "OYUN BİTTİ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.modulate = Color(1.0, 0.2, 0.2)
	center_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Tüm evler yıkıldı! Şehir sular altında kaldı."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.modulate = Color(0.9, 0.9, 0.9, 0.9)
	center_box.add_child(subtitle)

	var restart_btn := Button.new()
	restart_btn.text = "Yeniden Başla  [R]"
	restart_btn.custom_minimum_size = Vector2(200.0, 48.0)
	restart_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart_btn.pressed.connect(restart_game)
	center_box.add_child(restart_btn)

	overlay.add_child(center_box)
	_hud_layer.add_child(overlay)
	_game_over_ui = overlay

	# Yumuşak kararma animasyonu
	var tw := create_tween()
	tw.tween_property(overlay, "color", Color(0.04, 0.02, 0.03, 0.85), 0.8)


func _unhandled_input(_event: InputEvent) -> void:
	# Oyun yeniden başlatma buttons.gd içerisindeki R tuşunu basılı tutma barı ile yönetilir
	pass


func restart_game() -> void:
	print("[HousesManager] Oyun yeniden başlatılıyor...")
	get_tree().reload_current_scene()


## Enkaz parçaları saçar
func _spawn_house_debris(_house: StaticBody2D, bounds: Dictionary) -> void:
	var root_node := get_tree().current_scene
	if not root_node:
		root_node = owner if owner else get_parent()

	var count: int = randi_range(debris_count_min, debris_count_max)
	var center_pos := Vector2((bounds.left + bounds.right) * 0.5, (bounds.top + bounds.bottom) * 0.5)

	var debris_types: Array[int] = [
		HouseDebris.DebrisType.WOOD_PLANK,
		HouseDebris.DebrisType.BRICK,
		HouseDebris.DebrisType.ROOF_TILE,
		HouseDebris.DebrisType.RUBBLE
	]

	for i in range(count):
		var debris := HouseDebris.new()
		debris.debris_type = debris_types[randi() % debris_types.size()]

		var spawn_x: float = randf_range(bounds.left + 4.0, bounds.right - 4.0)
		var spawn_y: float = randf_range(bounds.top + 4.0, bounds.bottom - 4.0)
		debris.global_position = Vector2(spawn_x, spawn_y)

		var dir_x: float = (spawn_x - center_pos.x) / maxf(bounds.width * 0.5, 1.0)
		var vel_x: float = dir_x * debris_scatter_h + randf_range(-25.0, 25.0)
		var vel_y: float = -randf_range(debris_scatter_v * 0.5, debris_scatter_v)
		debris.linear_velocity = Vector2(vel_x, vel_y)
		debris.angular_velocity = randf_range(-12.0, 12.0)

		root_node.add_child(debris)

	print("[HousesManager] ", count, " adet enkaz parçası suya saçıldı.")


func _get_house_bounds(house: StaticBody2D) -> Dictionary:
	if house.has_method("get_bounds"):
		return house.call("get_bounds")

	var pos := house.global_position
	var width: float = 86.0
	var height: float = 66.0

	var sprite := house.get_node_or_null("Sprite2D") as Sprite2D
	if sprite and sprite.texture:
		var tex_size := sprite.texture.get_size()
		width = tex_size.x * house.global_scale.x * sprite.scale.x
		height = tex_size.y * house.global_scale.y * sprite.scale.y
	elif house.has_node("CollisionShape2D"):
		var col := house.get_node("CollisionShape2D") as CollisionShape2D
		if col.shape is RectangleShape2D:
			var rect := col.shape as RectangleShape2D
			width = rect.size.x * house.global_scale.x
			height = rect.size.y * house.global_scale.y

	var half_w := width * 0.5
	var half_h := height * 0.5
	return {
		"left": pos.x - half_w,
		"right": pos.x + half_w,
		"top": pos.y - half_h,
		"bottom": pos.y + half_h,
		"width": width,
		"height": height
	}


func _find_fluid_water() -> FluidWater:
	if is_inside_tree():
		var found = get_tree().get_first_node_in_group("fluid_water")
		if found is FluidWater:
			return found as FluidWater
		var parent_node := get_parent()
		if parent_node:
			var fw := parent_node.get_node_or_null("FluidWater")
			if fw is FluidWater:
				return fw as FluidWater
	return null
