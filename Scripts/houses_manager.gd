extends Node2D
class_name HousesManager

## HousesManager:
## 1. Ensures houses NEVER collide with fluid water simulation (collision isolation).
## 2. Detects when water level rises and submerges each house (water_y <= house_top_y).
## 3. Plays user-defined breaking animation (or procedural fallback if not yet added).
## 4. Spawns physical debris fragments that interact with water (Layer 1/Mask 1 + buoyancy).
## 5. Prints collapsed houses to console ("Ev yıkıldı: [HouseName]").

signal house_destroyed(house: Node2D, house_name: String)
signal all_houses_destroyed

@export_group("Breaking Animation & Destruction")
## Name of the break animation to play on the house's AnimationPlayer or AnimatedSprite2D
@export var break_animation_name: String = "break"
## Fallback duration (in seconds) if user has not yet added an AnimationPlayer/AnimatedSprite2D
@export var fallback_break_duration: float = 1.2
## Margin in pixels above roof level to confirm house is submerged (water Y <= roof Y + margin)
@export var submerged_margin_px: float = 4.0
## Minimum water particles in house column to confirm flooding rather than a stray drop
@export var min_water_particles_to_flood: int = 3

@export_group("Debris Settings")
## Number of debris fragments spawned per collapsed house
@export var debris_count_min: int = 6
@export var debris_count_max: int = 10
## Outward horizontal scatter speed of debris
@export var debris_scatter_h: float = 75.0
## Upward launch speed of debris
@export var debris_scatter_v: float = 110.0

var _managed_houses: Array[StaticBody2D] = []
var _collapsing_houses: Dictionary = {} # house -> bool
var _cached_fluid_water: FluidWater = null


func _ready() -> void:
	_init_houses()


func _init_houses() -> void:
	_managed_houses.clear()
	_collapsing_houses.clear()

	_cached_fluid_water = _find_fluid_water()

	for child in get_children():
		if child is StaticBody2D:
			var house := child as StaticBody2D
			_managed_houses.append(house)
			_collapsing_houses[house] = false

			# Sadece evlerin collision'ı olmayacak (evlerin collision'ları tamamen devre dışı):
			house.collision_layer = 0
			house.collision_mask = 0

			var col := house.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if col:
				col.disabled = true

			# Su simülasyonuna da ek güvence olarak bildir
			if _cached_fluid_water:
				_cached_fluid_water.add_collision_exception(house)

	print("[HousesManager] Başlatıldı: ", _managed_houses.size(), " ev aktif. Evlerin collision'ları kapalı, su StaticBody2D zeminine serbestçe çarpacak.")


func _physics_process(_delta: float) -> void:
	if _managed_houses.is_empty():
		return

	if not _cached_fluid_water or not is_instance_valid(_cached_fluid_water):
		_cached_fluid_water = _find_fluid_water()
		if not _cached_fluid_water:
			return

	for i in range(_managed_houses.size() - 1, -1, -1):
		var house: StaticBody2D = _managed_houses[i]
		if not is_instance_valid(house):
			_managed_houses.remove_at(i)
			continue

		if _collapsing_houses.get(house, false):
			continue

		var bounds := _get_house_bounds(house)
		var water_y: float = _cached_fluid_water.get_water_surface_y_in_range(
			bounds.left,
			bounds.right,
			min_water_particles_to_flood
		)

		# If water surface height is at or above the house roof:
		# (In 2D, lower Y = higher in the world. Water exceeding house height means water_y <= bounds.top)
		if water_y <= bounds.top + submerged_margin_px:
			_start_house_destruction(house, bounds)


func _start_house_destruction(house: StaticBody2D, bounds: Dictionary) -> void:
	_collapsing_houses[house] = true
	print("Ev su aldı, kırılma animasyonu başlıyor: ", house.name)

	# 1. Check for AnimationPlayer or AnimatedSprite2D on the house
	var anim_player := house.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var anim_sprite := house.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

	var has_played_custom_anim: bool = false

	if anim_player:
		var target_anim := _find_best_anim_name(anim_player)
		if not target_anim.is_empty():
			has_played_custom_anim = true
			anim_player.play(target_anim)
			anim_player.animation_finished.connect(func(_anim_name: StringName):
				_finish_house_collapse(house, bounds)
			, CONNECT_ONE_SHOT)

	elif anim_sprite:
		var sprite_frames := anim_sprite.sprite_frames
		if sprite_frames:
			var target_anim := _find_best_sprite_anim(sprite_frames)
			if not target_anim.is_empty():
				has_played_custom_anim = true
				anim_sprite.play(target_anim)
				anim_sprite.animation_finished.connect(func():
					_finish_house_collapse(house, bounds)
				, CONNECT_ONE_SHOT)

	# 2. Fallback procedural animation if user has not yet added custom animation
	if not has_played_custom_anim:
		_play_fallback_break_animation(house, bounds)


func _find_best_anim_name(anim_player: AnimationPlayer) -> String:
	var candidates: Array[String] = [
		break_animation_name,
		"break",
		"kırılma",
		"kirilma",
		"collapse",
		"destroy",
		"fall"
	]
	for c in candidates:
		if anim_player.has_animation(c):
			return c

	# If only one custom animation exists in library
	var anim_list := anim_player.get_animation_list()
	for a in anim_list:
		if a != "RESET" and a != "default":
			return a

	return ""


func _find_best_sprite_anim(frames: SpriteFrames) -> String:
	var candidates: Array[String] = [
		break_animation_name,
		"break",
		"kırılma",
		"kirilma",
		"collapse",
		"destroy"
	]
	for c in candidates:
		if frames.has_animation(c):
			return c
	return ""


func _play_fallback_break_animation(house: StaticBody2D, bounds: Dictionary) -> void:
	var start_pos := house.position
	var tween := create_tween().set_parallel(true)

	# Foundation shudder shake
	var sprite := house.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		var shake_tween := create_tween()
		for s in range(8):
			shake_tween.tween_property(sprite, "offset:x", randf_range(-3.0, 3.0), 0.06)
			shake_tween.tween_property(sprite, "offset:x", 0.0, 0.06)

	# Slight sink and foundation tilt
	var tilt_angle: float = deg_to_rad(randf_range(6.0, 14.0) * (1.0 if randf() > 0.5 else -1.0))
	tween.tween_property(house, "rotation", tilt_angle, fallback_break_duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(house, "position:y", start_pos.y + 12.0, fallback_break_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(house, "modulate:a", 0.0, fallback_break_duration).set_delay(fallback_break_duration * 0.6)

	tween.chain().tween_callback(func():
		_finish_house_collapse(house, bounds)
	)


func _finish_house_collapse(house: StaticBody2D, bounds: Dictionary) -> void:
	if not is_instance_valid(house):
		return

	# 1. Print statement requested by user
	print("Ev yıkıldı: ", house.name)
	house_destroyed.emit(house, house.name)

	# 2. Spawn physical debris pieces that interact with water
	_spawn_house_debris(house, bounds)

	# 3. Clean up house node
	_managed_houses.erase(house)
	_collapsing_houses.erase(house)
	house.queue_free()

	if _managed_houses.is_empty():
		all_houses_destroyed.emit()
		print("[HousesManager] Tüm evler sular altında kalarak yıkıldı!")


## Spawns water-interacting physics debris from the collapsed house
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

		# Scatter spawn position across the house rectangle
		var spawn_x: float = randf_range(bounds.left + 4.0, bounds.right - 4.0)
		var spawn_y: float = randf_range(bounds.top + 6.0, bounds.bottom - 4.0)
		debris.global_position = Vector2(spawn_x, spawn_y)

		# Initial burst velocity (outward arc)
		var dir_x: float = (spawn_x - center_pos.x) / maxf(bounds.width * 0.5, 1.0)
		var vel_x: float = dir_x * debris_scatter_h + randf_range(-25.0, 25.0)
		var vel_y: float = -randf_range(debris_scatter_v * 0.5, debris_scatter_v)
		debris.linear_velocity = Vector2(vel_x, vel_y)
		debris.angular_velocity = randf_range(-12.0, 12.0)

		root_node.add_child(debris)

	print("[HousesManager] ", count, " adet enkaz parçası suya saçıldı.")


func _get_house_bounds(house: StaticBody2D) -> Dictionary:
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
