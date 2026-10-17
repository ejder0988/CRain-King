extends StaticBody2D
class_name Factory

## Factory:
## 1. Upgrades up to 5 times (Level 1 to 5).
## 2. Spawns CargoCrate when Q is pressed (or when trigger_spawn() is called).
## 3. Spawn cooldown decreases with each level (producing crates faster and faster).
## 4. Upgrade via key (U or E) or via upgrade() method.

signal factory_upgraded(new_level: int)
signal crate_spawned(crate: RigidBody2D, level: int)

@export_group("Upgrade Settings")
## Maximum upgrade level
@export var max_level: int = 5
## Starting level (1 to 5)
@export var current_level: int = 1
## Key to upgrade factory
@export var upgrade_key: Key = KEY_U
## Alternative key to upgrade factory
@export var alt_upgrade_key: Key = KEY_E

@export_group("Spawn Settings")
## Key to spawn CargoCrate
@export var spawn_key: Key = KEY_Q
## PackedScene of the crate to spawn
@export var crate_scene: PackedScene = preload("res://Scenes/cargo_crate.tscn")
## Global position where the crate is spawned (front loading platform)
@export var spawn_position: Vector2 = Vector2(383, 862)
## Spawn cooldowns (in seconds) for each level (Level 1 to 5). Cooldown decreases per level.
@export var level_cooldowns: Array[float] = [3.0, 2.2, 1.6, 1.1, 0.6]

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var label: Label = get_node_or_null("Label")
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

var cooldown_timer: float = 0.0
var _original_sprite_scale: Vector2 = Vector2.ONE
var _original_label_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	current_level = clampi(current_level, 1, max_level)
	if sprite:
		_original_sprite_scale = sprite.scale
	if label:
		_original_label_pos = label.position

	_update_label_text()
	print("[Factory] Ready! Level: ", current_level, "/", max_level, ". Press 'Q' to spawn crate, 'U'/'E' to upgrade.")


func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer = maxf(cooldown_timer - delta, 0.0)
		_update_label_text()
	elif cooldown_timer == 0.0 and label and not label.text.begins_with("Q\n"):
		_update_label_text()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# Q Key: Spawn crate
	if event.keycode == spawn_key:
		get_viewport().set_input_as_handled()
		spawn_crate()

	# U or E Key: Upgrade factory
	elif event.keycode == upgrade_key or event.keycode == alt_upgrade_key:
		get_viewport().set_input_as_handled()
		upgrade()


## Attempts to upgrade the factory to the next level (up to max_level).
func upgrade() -> bool:
	if current_level >= max_level:
		print("[Factory] Already at maximum level (", max_level, ").")
		_jiggle_label(Color(1.0, 0.8, 0.2)) # Amber pulse for max
		return false

	current_level += 1
	var cd: float = get_current_cooldown()
	print("[Factory] Upgraded to Level ", current_level, "/", max_level, "! New spawn cooldown: ", cd, "s.")
	factory_upgraded.emit(current_level)

	# Visual upgrade punch
	_play_upgrade_effect()
	_update_label_text()
	return true


## Spawns a CargoCrate if cooldown is ready.
func spawn_crate() -> RigidBody2D:
	if cooldown_timer > 0.0:
		print("[Factory] Cooldown active (", snapped(cooldown_timer, 0.1), "s remaining).")
		_jiggle_label(Color(1.0, 0.3, 0.3)) # Red jiggle for cooldown
		return null

	# Reset cooldown according to current level
	cooldown_timer = get_current_cooldown()

	# Play popout animation if present
	if animation_player and animation_player.has_animation("popout"):
		animation_player.play("popout")

	# Instantiate crate
	var crate: RigidBody2D = null
	if crate_scene:
		crate = crate_scene.instantiate() as RigidBody2D
	else:
		# Fallback if scene is missing
		crate = RigidBody2D.new()
		crate.mass = 6.0
		var col := CollisionShape2D.new()
		var cir := CircleShape2D.new()
		cir.radius = 18.0
		col.shape = cir
		crate.add_child(col)

	crate.add_to_group("cargo")
	crate.add_to_group("grabbable")

	# Target spawn location with slight offset if a body is already right there
	var spawn_pos: Vector2 = spawn_position
	var existing_crates := get_tree().get_nodes_in_group("cargo")
	for c in existing_crates:
		if c is Node2D and c.global_position.distance_to(spawn_pos) < 25.0:
			spawn_pos.x += randf_range(20.0, 40.0)
			break

	crate.global_position = spawn_pos

	# Add to main scene root so physics and scale remain clean
	var target_parent: Node = get_tree().current_scene
	if not target_parent:
		target_parent = owner if owner else get_parent()
	target_parent.add_child(crate)

	# Slight spawn pop animation on sprite
	if sprite:
		var pop_tween := create_tween()
		pop_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop_tween.tween_property(sprite, "scale", _original_sprite_scale * 1.15, 0.12)
		pop_tween.tween_property(sprite, "scale", _original_sprite_scale, 0.18)

	crate_spawned.emit(crate, current_level)
	print("[Factory] Crate spawned at ", spawn_pos, " (Level ", current_level, ", Next cooldown: ", cooldown_timer, "s)")
	_update_label_text()
	return crate


func get_current_cooldown() -> float:
	var idx: int = current_level - 1
	if idx >= 0 and idx < level_cooldowns.size():
		return level_cooldowns[idx]
	return 1.0


func _update_label_text() -> void:
	if not label:
		return

	if cooldown_timer > 0.0:
		label.text = "Q (%.1fs)\nLv.%d/%d" % [cooldown_timer, current_level, max_level]
		label.modulate = Color(0.7, 0.7, 0.7, 0.85)
	else:
		label.text = "Q\nLv.%d/%d" % [current_level, max_level]
		label.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _play_upgrade_effect() -> void:
	if sprite:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", _original_sprite_scale * 1.3, 0.25)
		tween.tween_property(sprite, "scale", _original_sprite_scale, 0.35)

	if label:
		var l_tween := create_tween()
		l_tween.tween_property(label, "modulate", Color(0.3, 1.0, 0.4), 0.15)
		l_tween.tween_property(label, "modulate", Color(1.0, 1.0, 1.0), 0.25)


func _jiggle_label(tint: Color) -> void:
	if not label:
		return
	var tween := create_tween()
	label.modulate = tint
	tween.tween_property(label, "position:x", _original_label_pos.x - 4.0, 0.04)
	tween.tween_property(label, "position:x", _original_label_pos.x + 4.0, 0.04)
	tween.tween_property(label, "position:x", _original_label_pos.x, 0.04)
	tween.tween_property(label, "modulate", Color(1.0, 1.0, 1.0), 0.15)
