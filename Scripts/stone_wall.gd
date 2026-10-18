extends StaticBody2D
class_name StoneWall

## StoneWall: Sea wall built rock-by-rock from 1 to 24 layers using wallbuild.png.
## Each brick delivered raises the wall visual and elevates the top deposit collision higher.
## Blocks fluid water particles from reaching the city as it rises.

signal stage_changed(new_stage: int, max_stages: int)
signal wall_completed

@export_group("Wall Progression")
## Total construction stages (from 0 to 24)
@export var max_stages: int = 24
## Current construction stage (0: not started, 1..24: layers built)
@export var current_stage: int = 0
## Duvarın başlangıç collision yüksekliği (piksel, Varsayılan: 5.0)
@export var base_collision_height: float = 5.0
## Her seviye / tuğla başına collision yüksekliğinin artış miktarı (piksel, Varsayılan: 5.0)
@export var collision_height_per_stage: float = 5.0
## Texture sheet containing the 24 progressive wall sprites
@export var wall_sheet: Texture2D = preload("res://Sprites/Crane/wallbuild.png")

@export_group("Wall Audio Settings")
## Tuğla koyulduğu zaman garanti çalacak olan duvar örme sesi (Varsayılan: res://Sounds/WallBuild.wav)
@export var wall_build_sound: AudioStream = null
## Duvar örme ses seviyesi (dB)
@export var wall_build_volume_db: float = 0.0

## Tuğla koyulduktan sonra rastgele çalacak gülme sesleri (Gülme1.wav, Gülme2.wav, Gülme3.wav)
@export var laugh_sounds: Array[AudioStream] = []
## Gülme sesi seviyesi (dB)
@export var laugh_volume_db: float = -2.0
## Tuğla koyulduktan sonra gülme sesinin çalma gecikmesi (saniye, örn: 0.12s)
@export var laugh_delay: float = 0.12

@export_group("Pointer Settings")
## When true, the tutorial pointer bobs up and down; when false, it remains stationary
@export var enable_pointer_movement: bool = false

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var main_collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var drop_zone: Area2D = get_node_or_null("DropZone")
@onready var drop_collision: CollisionShape2D = get_node_or_null("DropZone/CollisionShape2D")
@onready var pointer: Sprite2D = get_node_or_null("PointerSprite2D")

var _atlas_tex: AtlasTexture = null
var _original_sprite_scale: Vector2 = Vector2.ONE
var _base_pointer_pos: Vector2 = Vector2(-1.5, 42.0)
var _base_pointer_scale: Vector2 = Vector2(2.56, 1.87)
var _build_player: AudioStreamPlayer2D = null
var _laugh_player: AudioStreamPlayer2D = null

# Frame width in wallbuild.png (1152 / 24 = 48)
const FRAME_WIDTH: int = 48
const FRAME_HEIGHT: int = 144
# Ground baseline is at y = 144 in local sprite coordinates


func _ready() -> void:
	add_to_group("stone_wall")
	collision_layer = 1
	collision_mask = 1

	_init_wall_audio()

	if sprite:
		_original_sprite_scale = sprite.scale
		_atlas_tex = AtlasTexture.new()
		_atlas_tex.atlas = wall_sheet
		sprite.texture = _atlas_tex

	if pointer:
		_base_pointer_pos = pointer.position
		_base_pointer_scale = pointer.scale
		pointer.visible = false
		_update_pointer_transform()

	if drop_zone and not drop_zone.body_entered.is_connected(_on_drop_zone_body_entered):
		drop_zone.body_entered.connect(_on_drop_zone_body_entered)

	_update_wall_state(false)
	print("[StoneWall] Ready! Construction stage: ", current_stage, "/", max_stages, ". Deliver bricks to build wall.")


func _process(_delta: float) -> void:
	if enable_pointer_movement and pointer and pointer.visible:
		var time := Time.get_ticks_msec() / 1000.0
		var top_y: float = get_wall_top_y_local()
		pointer.position.y = (top_y - 14.0) + sin(time * 5.0) * 3.0


## Returns the top Y position of the wall in local coordinates based on stage
func get_wall_top_y_local() -> float:
	var h: float = get_wall_height_local()
	# Baseline ground level is at local y = 72.0
	return 72.0 - h


## Returns the current height of the wall collision in local pixels
## Starts at 5px (base_collision_height) and increases by 5px per stage (collision_height_per_stage)
func get_wall_height_local() -> float:
	return base_collision_height + float(current_stage) * collision_height_per_stage


## Returns the world top Y position of the wall
func get_wall_top_y_world() -> float:
	return to_global(Vector2(0.0, get_wall_top_y_local())).y


## Returns the world height of the wall in pixels
func get_wall_height_world() -> float:
	return get_wall_height_local() * global_scale.y


func _update_wall_state(animated: bool = true) -> void:
	# 1. Update visual sprite frame (0 to 23 in wallbuild.png)
	if _atlas_tex:
		var frame_idx: int = 0
		if current_stage > 0:
			frame_idx = clampi(current_stage - 1, 0, 23)
		else:
			frame_idx = 0

		sprite.visible = true
		_atlas_tex.region = Rect2(frame_idx * FRAME_WIDTH, 0, FRAME_WIDTH, FRAME_HEIGHT)

	# 2. Elevate the top rock deposit collision and drop zone
	var top_y: float = get_wall_top_y_local()
	var wall_h: float = get_wall_height_local()

	if drop_zone:
		drop_zone.position = Vector2(0.0, top_y - 6.0)

	if drop_collision and drop_collision.shape is RectangleShape2D:
		var r_shape := drop_collision.shape as RectangleShape2D
		r_shape.size = Vector2(44.0, 18.0)

	# 3. Expand main water/solid collision block upward strictly matching drawn brick height
	# (Empty/invisible upper space has NO collision, allowing water to wash over if wall is low)
	if main_collision:
		var col_shape := main_collision.shape as RectangleShape2D
		if not col_shape or not col_shape.resource_local_to_scene:
			col_shape = RectangleShape2D.new()
			col_shape.resource_local_to_scene = true
			main_collision.shape = col_shape
		col_shape.size = Vector2(40.0, wall_h)
		main_collision.position = Vector2(0.0, 72.0 - (wall_h * 0.5))

	# 4. Update Pointer position and scale based on wall stage
	_update_pointer_transform()

	# 5. Visual juice bounce when adding a stone
	if animated and sprite:
		sprite.visible = true
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", _original_sprite_scale * Vector2(1.15, 0.9), 0.1)
		tween.tween_property(sprite, "scale", _original_sprite_scale, 0.18)


func _on_drop_zone_body_entered(body: Node) -> void:
	if body is RigidBody2D:
		if body.is_in_group("brick"):
			place_brick(body)
		elif body.is_in_group("rock"):
			_reject_rock(body)


## Deposits a brick onto the wall, advancing the construction stage
func place_brick(brick_body: Node2D) -> bool:
	if current_stage >= max_stages:
		print("[StoneWall] Duvar zaten maksimum seviyede (24/24)!")
		return false

	# Consume the brick
	if is_instance_valid(brick_body):
		# Detach from crane if held
		var tree := get_tree()
		if tree:
			var crane = tree.get_first_node_in_group("crane")
			if crane and "grabbed_body" in crane and crane.grabbed_body == brick_body:
				crane._release_cargo()

		# Quick shrink absorption tween
		var absorb_tween := create_tween()
		absorb_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		absorb_tween.tween_property(brick_body, "scale", brick_body.scale * 0.1, 0.15)
		absorb_tween.tween_callback(func():
			if is_instance_valid(brick_body):
				brick_body.queue_free()
		)

	current_stage += 1
	_update_wall_state(true)
	stage_changed.emit(current_stage, max_stages)

	_play_wall_build_audio()
	_play_random_laugh_audio()

	print("[StoneWall] Tuğla duvara yerleştirildi! Duvar seviyesi: ", current_stage, "/", max_stages)

	if current_stage >= max_stages:
		wall_completed.emit()
		print("[StoneWall] TEBRİKLER! Duvar tamamen örüldü (24/24)! Şehir sulara karşı koruma altında!")

	return true


## Debug test: Duvar seviyesini 1 artırır (+1 stage)
func debug_upgrade_wall() -> bool:
	if current_stage >= max_stages:
		print("[StoneWall] Duvar zaten maksimum seviyede (%d/%d)!" % [current_stage, max_stages])
		return false
	current_stage = clampi(current_stage + 1, 0, max_stages)
	_update_wall_state(true)
	stage_changed.emit(current_stage, max_stages)
	_play_wall_build_audio()
	print("[StoneWall] [DEBUG] Duvar seviyesi yükseltildi: %d/%d (Collision H: %.1f px)" % [current_stage, max_stages, get_wall_height_local()])
	if current_stage >= max_stages:
		wall_completed.emit()
	return true


## Debug test: Duvar seviyesini 1 düşürür (-1 stage)
func debug_downgrade_wall() -> bool:
	if current_stage <= 0:
		print("[StoneWall] Duvar zaten temel / en alt seviyede (0/%d)!" % max_stages)
		return false
	current_stage = clampi(current_stage - 1, 0, max_stages)
	_update_wall_state(true)
	stage_changed.emit(current_stage, max_stages)
	print("[StoneWall] [DEBUG] Duvar seviyesi düşürüldü: %d/%d (Collision H: %.1f px)" % [current_stage, max_stages, get_wall_height_local()])
	return true


## Updates the pointer position above the rising wall top and scales it with stage
func _update_pointer_transform() -> void:
	if not pointer or not is_instance_valid(pointer):
		pointer = get_node_or_null("PointerSprite2D") as Sprite2D
	if not pointer:
		return

	var top_y: float = get_wall_top_y_local()
	pointer.position.x = _base_pointer_pos.x
	pointer.position.y = top_y - 14.0

	# Pointer scales with wall stage ("wall stage kadar büyümeli")
	var stage_ratio: float = float(current_stage) / float(maxf(float(max_stages), 1.0))
	pointer.scale = _base_pointer_scale * (1.0 + stage_ratio * 0.8)


## Controls the pointer visibility (shown only when crane carries brick)
func set_pointer_visible(show: bool) -> void:
	if not pointer or not is_instance_valid(pointer):
		pointer = get_node_or_null("PointerSprite2D") as Sprite2D
	if not pointer:
		return
	if current_stage >= max_stages:
		pointer.visible = false
		return
	_update_pointer_transform()
	pointer.visible = show


## Backward compatibility alias
func place_rock(body: Node2D) -> bool:
	if is_instance_valid(body) and body.is_in_group("brick"):
		return place_brick(body)
	_reject_rock(body)
	return false


func _reject_rock(body: Node2D) -> void:
	print("[StoneWall] Reddedildi! Duvar inşaatı için artık ham kaya değil, fabrikada üretilen Tuğla (Brick) gerekiyor.")
	if is_instance_valid(body) and body is RigidBody2D:
		var tw := body.create_tween()
		tw.tween_property(body, "modulate", Color(1.8, 0.3, 0.3), 0.1)
		tw.tween_property(body, "modulate", Color(1.0, 1.0, 1.0), 0.25)


# ==============================================================================
# WALL CONSTRUCTION AUDIO SYSTEM
# ==============================================================================
func _init_wall_audio() -> void:
	var sfx_bus: String = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"

	# 1. Garanti çalacak olan Duvar Örme Sesi (WallBuild.wav) Oynatıcısı
	if not _build_player:
		_build_player = AudioStreamPlayer2D.new()
		_build_player.name = "WallBuildAudioPlayer"
		_build_player.bus = sfx_bus
		_build_player.volume_db = wall_build_volume_db
		_build_player.max_distance = 2800.0
		_build_player.attenuation = 1.0
		add_child(_build_player)

	# 2. Rastgele çalacak olan Gülme Sesleri (Gülme1.wav, Gülme2.wav, Gülme3.wav) Oynatıcısı
	if not _laugh_player:
		_laugh_player = AudioStreamPlayer2D.new()
		_laugh_player.name = "WallLaughAudioPlayer"
		_laugh_player.bus = sfx_bus
		_laugh_player.volume_db = laugh_volume_db
		_laugh_player.max_distance = 2800.0
		_laugh_player.attenuation = 1.0
		add_child(_laugh_player)

	# WallBuild.wav otomatik tespit ve atama
	if wall_build_sound == null:
		var build_candidates: Array[String] = [
			"res://Sounds/WallBuild.wav",
			"res://Sounds/wallbuild.wav",
			"res://Sounds/Wallbuild.wav",
			"res://Sounds/wall_build.wav"
		]
		for path in build_candidates:
			if ResourceLoader.exists(path):
				wall_build_sound = load(path)
				break

	if wall_build_sound and _build_player:
		_build_player.stream = wall_build_sound

	# Gülme sesleri listesi boşsa Sounds klasöründeki Gülme1.wav, Gülme2.wav, Gülme3.wav'ı otomatik ekle
	if laugh_sounds.is_empty():
		var laugh_candidates: Array[String] = [
			"res://Sounds/Gülme1.wav",
			"res://Sounds/Gülme2.wav",
			"res://Sounds/Gülme3.wav",
			"res://Sounds/gülme1.wav",
			"res://Sounds/gülme2.wav",
			"res://Sounds/gülme3.wav"
		]
		for path in laugh_candidates:
			if ResourceLoader.exists(path):
				var stream = load(path)
				if stream and not laugh_sounds.has(stream):
					laugh_sounds.append(stream)


## Tuğla duvara koyulduğunda kesin olarak WallBuild.wav çalar
func _play_wall_build_audio() -> void:
	if not _build_player:
		_init_wall_audio()
	if not _build_player:
		return

	if wall_build_sound and _build_player.stream != wall_build_sound:
		_build_player.stream = wall_build_sound
	elif _build_player.stream == null:
		if ResourceLoader.exists("res://Sounds/WallBuild.wav"):
			_build_player.stream = load("res://Sounds/WallBuild.wav")
		elif ResourceLoader.exists("res://Sounds/wallbuild.wav"):
			_build_player.stream = load("res://Sounds/wallbuild.wav")

	if _build_player.stream:
		_build_player.volume_db = wall_build_volume_db
		_build_player.pitch_scale = randf_range(0.97, 1.03)
		_build_player.play()


## Tuğla duvara koyulduktan sonra gülme seslerinden (Gülme1, Gülme2, Gülme3) rastgele birini çalar
func _play_random_laugh_audio() -> void:
	if not _laugh_player:
		_init_wall_audio()
	if not _laugh_player:
		return

	if laugh_sounds.is_empty():
		_init_wall_audio()
	if laugh_sounds.is_empty():
		return

	var chosen_laugh: AudioStream = laugh_sounds.pick_random()
	if not chosen_laugh:
		return

	if laugh_delay > 0.0 and is_inside_tree():
		var tree := get_tree()
		if tree:
			tree.create_timer(laugh_delay).timeout.connect(func():
				if is_instance_valid(_laugh_player):
					_laugh_player.stream = chosen_laugh
					_laugh_player.volume_db = laugh_volume_db
					_laugh_player.pitch_scale = randf_range(0.95, 1.05)
					_laugh_player.play()
			)
			return

	_laugh_player.stream = chosen_laugh
	_laugh_player.volume_db = laugh_volume_db
	_laugh_player.pitch_scale = randf_range(0.95, 1.05)
	_laugh_player.play()
