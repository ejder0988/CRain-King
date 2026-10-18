extends Node2D
class_name RockPit

## RockPit: Stone quarry pit where the crane retrieves raw rock cargo.
## 1. Does NOT spawn a rock on its own into the scene.
## 2. When the crane hook (payload) enters/reaches the rock pit, the pit immediately
##    dispenses a rock from behind/inside the pit directly onto the crane's hook.
## 3. Cleans up any other rocks elsewhere in the scene, ensuring at most max_active_rocks.
## 4. Collision never blocks water (flows freely like houses).

signal rock_dispensed(rock: RigidBody2D)

@export_group("Rock Pit Settings")
## Maximum allowed simultaneous rocks in the scene (default: 1)
@export var max_active_rocks: int = 1
## Cooldown after dispensing before another rock can be retrieved
@export var dispense_cooldown: float = 1.5
## PackedScene of the rock to dispense
@export var rock_scene: PackedScene = preload("res://Scenes/rock.tscn")
## Offset inside the pit where the rock emerges from
@export var dispense_offset: Vector2 = Vector2(0.0, 12.0)

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var pointer: Sprite2D = get_node_or_null("PointerSprite2D")

var _is_on_cooldown: bool = false
var _cooldown_timer: float = 0.0
var _original_sprite_scale: Vector2 = Vector2(3.0, 3.0)
var _base_pointer_y: float = -72.0
var has_mined_first_rock: bool = false


func _ready() -> void:
	add_to_group("rock_pit")

	if sprite:
		_original_sprite_scale = sprite.scale

	if pointer:
		_base_pointer_y = pointer.position.y
		pointer.visible = not has_mined_first_rock

	_register_water_exception()

	var area := get_node_or_null("PickupArea") as Area2D
	if area:
		area.body_entered.connect(_on_pickup_area_body_entered)


func _process(delta: float) -> void:
	if _is_on_cooldown:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_is_on_cooldown = false

	# Pointer animation while awaiting first mining
	if pointer and pointer.visible:
		var time := Time.get_ticks_msec() / 1000.0
		pointer.position.y = _base_pointer_y + sin(time * 4.5) * 4.0

	# Proximity check: If crane hook enters the rock pit area while empty
	_check_crane_payload_proximity()


func _check_crane_payload_proximity() -> void:
	if _is_on_cooldown:
		return

	var tree := get_tree()
	if not tree:
		return
	var crane = tree.get_first_node_in_group("crane")
	if not crane or not is_instance_valid(crane):
		return

	# Only dispense if crane is not already carrying cargo or water
	if ("is_carrying_cargo" in crane and crane.is_carrying_cargo) or ("is_carrying_water" in crane and crane.is_carrying_water):
		return

	var payload: Node2D = crane.get("payload") as Node2D
	if not payload or not is_instance_valid(payload):
		return

	var diff: Vector2 = payload.global_position - global_position
	# Check if payload is lowered into the pit
	if absf(diff.x) <= 80.0 and diff.y >= -60.0 and diff.y <= 65.0:
		var rock := dispense_rock_to_crane(crane)
		if rock and crane.has_method("pickup_cargo_direct"):
			crane.pickup_cargo_direct(rock)


func _on_pickup_area_body_entered(body: Node) -> void:
	if _is_on_cooldown:
		return

	var tree := get_tree()
	if not tree:
		return
	var crane = tree.get_first_node_in_group("crane")
	if not crane or not is_instance_valid(crane):
		return

	var payload: Node2D = crane.get("payload") as Node2D
	if body == payload:
		if ("is_carrying_cargo" in crane and not crane.is_carrying_cargo) and ("is_carrying_water" in crane and not crane.is_carrying_water):
			var rock := dispense_rock_to_crane(crane)
			if rock and crane.has_method("pickup_cargo_direct"):
				crane.pickup_cargo_direct(rock)


## Dispenses a rock directly to the crane hook from inside/behind the pit
func dispense_rock_to_crane(crane: Node) -> RigidBody2D:
	if _is_on_cooldown:
		return null

	if not rock_scene:
		rock_scene = load("res://Scenes/rock.tscn")
	if not rock_scene:
		return null

	var rock := rock_scene.instantiate() as RigidBody2D
	if not rock:
		return null

	# Emerge from slightly behind/inside the pit
	var emerge_pos := global_position + dispense_offset
	rock.global_position = emerge_pos
	rock.z_index = (sprite.z_index - 1) if sprite else 0

	var target_parent: Node = get_tree().current_scene
	if not target_parent:
		target_parent = get_parent()
	target_parent.add_child(rock)

	# Clean up any other rocks elsewhere in the scene (enforces max_active_rocks)
	_cleanup_other_rocks(rock)

	# Smooth visual handoff tween: rock rises from behind the pit directly onto the payload hook
	var payload: Node2D = crane.get("payload") as Node2D if crane else null
	var target_pos := payload.global_position + Vector2(0, 35.0) if payload else global_position + Vector2(0, -30.0)

	var orig_scale := rock.scale
	rock.scale = orig_scale * 0.35
	var handoff_tween := rock.create_tween().set_parallel(true)
	handoff_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	handoff_tween.tween_property(rock, "global_position", target_pos, 0.16)
	handoff_tween.tween_property(rock, "scale", orig_scale, 0.16)
	handoff_tween.chain().tween_callback(func():
		if is_instance_valid(rock):
			rock.z_index = 0
	)

	# Pit sprite punch bounce
	if sprite:
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "scale", _original_sprite_scale * Vector2(1.15, 0.9), 0.1)
		tw.tween_property(sprite, "scale", _original_sprite_scale, 0.2)

	_is_on_cooldown = true
	_cooldown_timer = dispense_cooldown

	# The pointer is permanently turned off the very first time a rock is mined
	has_mined_first_rock = true
	if pointer and is_instance_valid(pointer):
		pointer.visible = false

	rock_dispensed.emit(rock)
	print("[RockPit] Vinç payload girdi, kaya pit arkasından doğrudan kancaya verildi!")
	return rock


## Destroys any excess rocks elsewhere in the scene
func _cleanup_other_rocks(keep_rock: RigidBody2D) -> void:
	var tree := get_tree()
	if not tree:
		return

	var all_rocks := tree.get_nodes_in_group("rock")
	for node in all_rocks:
		if node is RigidBody2D and node != keep_rock and is_instance_valid(node):
			if node.is_in_group("brick"):
				continue
			_disintegrate_rock(node as RigidBody2D)


func _disintegrate_rock(rock_body: RigidBody2D) -> void:
	if not is_instance_valid(rock_body):
		return

	rock_body.set_deferred("freeze", true)
	rock_body.remove_from_group("rock")
	rock_body.remove_from_group("cargo")
	rock_body.remove_from_group("grabbable")

	var tw := rock_body.create_tween().set_parallel(true)
	tw.tween_property(rock_body, "scale", rock_body.scale * 0.05, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(rock_body, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(func():
		if is_instance_valid(rock_body):
			rock_body.queue_free()
	)


func _register_water_exception() -> void:
	var tree := get_tree()
	if not tree:
		return
	var w = tree.get_first_node_in_group("fluid_water")
	if not w and tree.current_scene:
		w = tree.current_scene.find_child("FluidWater", true, false)
	if w and w.has_method("add_collision_exception"):
		for child in get_children():
			if child is CollisionObject2D:
				w.add_collision_exception(child)
