extends Node2D
class_name FluidWater

## Fluid Water simulation controller based on PhysicsServer2D and metaball shader
## Ported from godot-v4-fluid-water-2D-simulator for President Crane.

@export_group("Fluid Water Spawn Settings")
## Number of water drops to spawn at game start from the generator's position (set to 0 if you want to spawn only on demand)
@export var initial_drops: int = 100
## 0: POINT (drops pour down from the spawn point), 1: AREA (drops fill a rectangular pool area)
@export_enum("POINT:0", "AREA:1") var spawn_mode: int = 0
## Size of the pool area to distribute drops inside if spawn_mode is AREA
@export var spawn_area: Vector2 = Vector2(300, 100)
## Radius around the spawn point to scatter drops
@export var spawn_radius: float = 24.0
## If true, continuously streams water from the spawn point
@export var continuous_stream: bool = false
## Number of drops emitted per frame when streaming
@export var stream_rate: int = 1
## Key to spawn a burst of water drops
@export var spawn_key: Key = KEY_G

@export_group("Mouse Interaction")
## Enable mouse pointer interaction to stir/push water
@export var enable_pointer: bool = false
## Key to toggle pointer mode
@export var toggle_pointer_key: Key = KEY_P

@onready var water_generator: Node2D = get_node_or_null("WaterGenerator")
@onready var water_shader: ColorRect = get_node_or_null("WaterShader")
@onready var pointer_node: RigidBody2D = get_node_or_null("UI/pointer")
@onready var icon_node: Sprite2D = get_node_or_null("UI/Icon")


func _ready() -> void:
	# Hide WaterShader in editor so NO water appears when the game is closed
	if Engine.is_editor_hint():
		if water_shader:
			water_shader.visible = false
		return

	# Show shader only at runtime
	if water_shader:
		water_shader.visible = true

	if water_generator:
		water_generator.set("initial_drops", initial_drops)
		water_generator.set("spawn_mode", spawn_mode)
		water_generator.set("spawn_area", spawn_area)
		water_generator.set("spawnRad", spawn_radius)
		water_generator.set("continuous_stream", continuous_stream)
		water_generator.set("stream_rate", stream_rate)
		water_generator.set("spawn_key", spawn_key)

	_update_pointer_visibility()
	var drops: int = int(water_generator.objects.size()) if (water_generator and "objects" in water_generator) else 0
	var spawn_pos: Vector2 = water_generator.global_position if water_generator else global_position
	print("[FluidWater] Ready! Spawn position: ", spawn_pos, " with ", drops, " initial drops. Controls: 'G' to burst drops, 'P' to toggle mouse pointer.")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_pointer_key:
			enable_pointer = not enable_pointer
			_update_pointer_visibility()
			get_viewport().set_input_as_handled()
		elif event.keycode == spawn_key and not continuous_stream:
			# Burst 15 drops on press
			spawn_water_burst(15)


func _process(_delta: float) -> void:
	if enable_pointer:
		var mouse_pos: Vector2 = get_global_mouse_position()
		if icon_node:
			icon_node.global_position = mouse_pos
			icon_node.visible = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if pointer_node:
			pointer_node.global_position = mouse_pos


func _update_pointer_visibility() -> void:
	if pointer_node:
		pointer_node.visible = enable_pointer
		pointer_node.process_mode = Node.PROCESS_MODE_INHERIT if enable_pointer else Node.PROCESS_MODE_DISABLED
	if icon_node:
		icon_node.visible = enable_pointer
	if water_generator:
		water_generator.set("pointer", not enable_pointer)


## Spawns a burst of water particles at the generator's position
func spawn_water_burst(amount: int = 15) -> void:
	if not water_generator:
		return
	var srad: float = float(water_generator.get("spawnRad")) if water_generator.get("spawnRad") != null else spawn_radius
	for i in range(amount):
		var offset: Vector2 = Vector2(randf() - 0.5, randf() - 0.5).normalized() * srad * randf()
		water_generator.call("create_object", water_generator.global_position + offset, Vector2(randf_range(-20, 20), randf_range(20, 80)))


## Starts a continuous stream of water
func start_stream() -> void:
	continuous_stream = true
	if water_generator:
		water_generator.set("continuous_stream", true)


## Stops the stream of water
func stop_stream() -> void:
	continuous_stream = false
	if water_generator:
		water_generator.set("continuous_stream", false)


## Clears all active water drops
func clear_all_water() -> void:
	if water_generator and water_generator.has_method("_exit_tree"):
		water_generator._exit_tree()


## Returns current number of active water drops
func get_drop_count() -> int:
	if water_generator and "objects" in water_generator:
		return int(water_generator.objects.size())
	return 0
