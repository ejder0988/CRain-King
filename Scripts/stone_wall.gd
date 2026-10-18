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
## Texture sheet containing the 24 progressive wall sprites
@export var wall_sheet: Texture2D = preload("res://Sprites/Crane/wallbuild.png")

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

# Frame width in wallbuild.png (1152 / 24 = 48)
const FRAME_WIDTH: int = 48
const FRAME_HEIGHT: int = 144
# Ground baseline is at y = 144 in local sprite coordinates


func _ready() -> void:
	add_to_group("stone_wall")
	collision_layer = 1
	collision_mask = 1

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
	if current_stage <= 0:
		return 68.0 # Foundation level (near ground)
	# Each frame from 1 to 23 adds exactly 5 pixels of height
	var frame_idx: int = clampi(current_stage - 1, 0, 23)
	var top_y: float = 124.0 - float(frame_idx) * 5.0
	# Convert from texture coordinates (0 to 144 with center at 72)
	return top_y - 72.0


## Returns the current height of the wall in local pixels
func get_wall_height_local() -> float:
	if current_stage <= 0:
		return 8.0
	var frame_idx: int = clampi(current_stage - 1, 0, 23)
	return 20.0 + float(frame_idx) * 5.0


func _update_wall_state(animated: bool = true) -> void:
	# 1. Update visual sprite frame (0 to 23 in wallbuild.png)
	if _atlas_tex:
		var frame_idx: int = 0
		if current_stage > 0:
			frame_idx = clampi(current_stage - 1, 0, 23)
			sprite.visible = true
		else:
			# Stage 0: invisible or very faint ghost outline
			frame_idx = 0
			sprite.visible = false

		_atlas_tex.region = Rect2(frame_idx * FRAME_WIDTH, 0, FRAME_WIDTH, FRAME_HEIGHT)

	# 2. Elevate the top rock deposit collision and drop zone
	var top_y: float = get_wall_top_y_local()
	var wall_h: float = get_wall_height_local()

	if drop_zone:
		drop_zone.position = Vector2(0.0, top_y - 6.0)

	if drop_collision and drop_collision.shape is RectangleShape2D:
		var r_shape := drop_collision.shape as RectangleShape2D
		r_shape.size = Vector2(44.0, 18.0)

	# 3. Expand main water/solid collision block upward as wall grows
	if main_collision:
		var col_shape := main_collision.shape as RectangleShape2D
		if not col_shape:
			col_shape = RectangleShape2D.new()
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

	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("add_money"):
		gm.add_money(10)

	print("[StoneWall] Tuğla duvara yerleştirildi! Duvar seviyesi: ", current_stage, "/", max_stages, " (+10$ Kazanıldı)")

	if current_stage >= max_stages:
		wall_completed.emit()
		print("[StoneWall] TEBRİKLER! Duvar tamamen örüldü (24/24)! Şehir sulara karşı koruma altında!")

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
