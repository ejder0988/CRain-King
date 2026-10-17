extends Node2D
class_name FluidWater

## 2D Fluid Water Simulation (PhysicsServer2D + Metaball Canvas Shader)
## Ported from godot-v4-fluid-water-2D-simulator for President Crane.
## The position of this node in the 2D editor IS the spawn point for water!

var objects: Array[Array] = []

var _sub_viewport: SubViewport
var _particle_container: Node2D
var _particle_material: CanvasItemMaterial

@onready var cir_shape := CircleShape2D.new()

@export_group("Fluid Water Spawn Settings")
## Number of water drops to spawn at game start from this node's position (set to 0 for no initial water)
@export var initial_drops: int = 100
## 0: POINT (drops pour down from this node's position), 1: AREA (drops distributed inside spawn_area)
@export_enum("POINT:0", "AREA:1") var spawn_mode: int = 0
## Size of the pool area to distribute drops inside if spawn_mode is AREA
@export var spawn_area: Vector2 = Vector2(300, 100)
## Radius around this node to scatter drops when pouring
@export var spawn_radius: float = 20.0
## Key to spawn a burst of water drops
@export var spawn_key: Key = KEY_G
## If true, continuously streams water from this node
@export var continuous_stream: bool = false
## Number of drops emitted per frame when streaming
@export var stream_rate: int = 1

@export_group("Fluid Particle Physics")
@export var tex: Texture2D
@export var texSize: float = 64.0
@export var particle_radius: float = 7.0
@export var particle_mass: float = 0.1
@export var particle_friction: float = 0.0
@export var particle_linear_damp: float = 0.3
## Drops are only destroyed if they fall into the abyss below this Y value
@export var kill_y: float = 3000.0
## Maximum particle limit to maintain 60+ FPS
@export var max_particles: int = 600

@export_group("Fluid Collision")
## Collision layer for water particles (Default: 1)
@export var water_collision_layer: int = 1
## Collision mask for water particles (Default: 1 -> touches all StaticBody2D terrain shapes and water particles)
@export var water_collision_mask: int = 1

@export_group("Mouse Interaction")
## Enable mouse pointer interaction to stir/push water
@export var enable_pointer: bool = false
## Key to toggle pointer mode
@export var toggle_pointer_key: Key = KEY_P
@export var attrForce: float = 500.0

@onready var water_shader: ColorRect = get_node_or_null("WaterShader")
@onready var pointer_node: RigidBody2D = get_node_or_null("UI/pointer")
@onready var icon_node: Sprite2D = get_node_or_null("UI/Icon")

var _collision_exceptions: Array[RID] = []

# Payload attraction & scoop state:
var payload_holding_water: bool = false
var payload_attractor_pos: Vector2 = Vector2.ZERO
var payload_attractor_radius: float = 75.0
var payload_attractor_force: float = 750.0
var payload_linear_vel: Vector2 = Vector2.ZERO
var payload_stir_active: bool = false
var payload_stir_pos: Vector2 = Vector2.ZERO
var payload_stir_radius: float = 65.0
var _held_particles: Array[RID] = []


func _ready() -> void:
	add_to_group("fluid_water")
	cir_shape.radius = particle_radius
	cir_shape.custom_solver_bias = 0.1

	# Keep WaterShader hidden in editor so NO water appears when the game is closed
	if Engine.is_editor_hint():
		if water_shader:
			water_shader.visible = false
		return
	
	# Show shader only at runtime
	if water_shader:
		water_shader.visible = true

	_sub_viewport = SubViewport.new()
	_sub_viewport.transparent_bg = true
	_sub_viewport.size = get_viewport_rect().size
	add_child(_sub_viewport)

	_particle_container = Node2D.new()
	_sub_viewport.add_child(_particle_container)

	_particle_material = CanvasItemMaterial.new()
	_particle_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	if water_shader and water_shader.material is ShaderMaterial:
		(water_shader.material as ShaderMaterial).set_shader_parameter("water_mask", _sub_viewport.get_texture())

	if not tex:
		if ResourceLoader.exists("res://water2Dsimulation/asset/part.png"):
			tex = load("res://water2Dsimulation/asset/part.png")
		if not tex:
			tex = _create_fallback_texture()

	_update_pointer_visibility()

	if initial_drops > 0:
		spawn_initial_drops(initial_drops)

	print("[FluidWater] Ready! Spawn position: ", global_position, " with ", objects.size(), " initial drops. Controls: 'G' to burst drops, 'P' to toggle mouse pointer.")


func _create_fallback_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center := Vector2(32, 32)
	for y in range(64):
		for x in range(64):
			var d := Vector2(x, y).distance_to(center)
			var a := pow(clampf(1.0 - (d / 32.0), 0.0, 1.0), 2.2)
			img.set_pixel(x, y, Color(0.92, 0.92, 0.92, a))
	return ImageTexture.create_from_image(img)


## Spawns drops directly from this node's global position
func spawn_initial_drops(count: int) -> void:
	for i in range(count):
		var pos: Vector2
		var vel: Vector2
		if spawn_mode == 1:
			pos = global_position + Vector2(randf_range(-spawn_area.x * 0.5, spawn_area.x * 0.5), randf_range(-spawn_area.y * 0.5, spawn_area.y * 0.5))
			vel = Vector2.ZERO
		else:
			var offset := Vector2(randf() - 0.5, randf() - 0.5).normalized() * spawn_radius * randf()
			pos = global_position + offset
			vel = Vector2(randf_range(-10, 10), randf_range(0, 30))
		create_object(pos, vel)


func create_object(pos: Vector2, initial_vel: Vector2 = Vector2.ZERO) -> void:
	if objects.size() >= max_particles:
		return

	if not tex:
		tex = _create_fallback_texture()

	var ps := PhysicsServer2D
	var object = ps.body_create()
	var space_rid: RID = get_world_2d().space if get_world_2d() else get_tree().root.get_world_2d().space
	ps.body_set_space(object, space_rid)
	ps.body_add_shape(object, cir_shape)
	ps.body_set_param(object, ps.BODY_PARAM_FRICTION, particle_friction)
	ps.body_set_param(object, ps.BODY_PARAM_BOUNCE, 0.0)
	ps.body_set_param(object, ps.BODY_PARAM_MASS, particle_mass)
	ps.body_set_param(object, ps.BODY_PARAM_LINEAR_DAMP, particle_linear_damp)
	ps.body_set_mode(object, ps.BODY_MODE_RIGID_LINEAR)
	ps.body_set_collision_layer(object, water_collision_layer)
	ps.body_set_collision_mask(object, water_collision_mask)

	for exc_rid in _collision_exceptions:
		if exc_rid.is_valid():
			ps.body_add_collision_exception(object, exc_rid)

	var trans := Transform2D(0, pos)
	ps.body_set_state(object, ps.BODY_STATE_TRANSFORM, trans)
	if initial_vel != Vector2.ZERO:
		ps.body_set_state(object, ps.BODY_STATE_LINEAR_VELOCITY, initial_vel)

	var rs := RenderingServer
	var img := rs.canvas_item_create()
	var parent_canvas = _particle_container.get_canvas_item() if _particle_container else get_canvas_item()
	rs.canvas_item_set_parent(img, parent_canvas)
	var tex_rid: RID = tex.get_rid()
	var width := texSize * 1.75
	var height := texSize * 1.05
	rs.canvas_item_add_texture_rect(img, Rect2(-width * 0.5, -height * 0.5, width, height), tex_rid)
	if _particle_material:
		rs.canvas_item_set_material(img, _particle_material.get_rid())
	rs.canvas_item_set_transform(img, trans)

	objects.append([object, img])


func _physics_process(_delta: float) -> void:
	if _sub_viewport:
		_sub_viewport.size = get_viewport_rect().size
		_sub_viewport.canvas_transform = get_viewport().canvas_transform
	if _particle_container:
		_particle_container.global_position = global_position

	var mouse_pos := get_global_mouse_position()
	var mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var icon_scale := icon_node.scale.x if icon_node and is_instance_valid(icon_node) else 1.0

	for i in range(objects.size() - 1, -1, -1):
		var pair = objects[i]
		var object: RID = pair[0]
		var img: RID = pair[1]
		var trans: Transform2D = PhysicsServer2D.body_get_state(object, PhysicsServer2D.BODY_STATE_TRANSFORM)
		var world_pos := trans.origin

		if world_pos.y > kill_y:
			objects.remove_at(i)
			PhysicsServer2D.free_rid(object)
			RenderingServer.free_rid(img)
		else:
			var local_trans := trans
			local_trans.origin -= global_position
			RenderingServer.canvas_item_set_transform(img, local_trans)

			var force_applied: bool = false

			# 1. Mouse pointer attraction
			if mouse_down and enable_pointer and mouse_pos.distance_to(world_pos) < 60.0 * icon_scale:
				var dir := (mouse_pos - world_pos).normalized()
				PhysicsServer2D.body_set_constant_force(object, dir * attrForce)
				force_applied = true
			# 2. Crane Payload water holding (attraction toward scoop bucket)
			elif payload_holding_water and payload_attractor_pos != Vector2.ZERO:
				var d_payload: float = payload_attractor_pos.distance_to(world_pos)
				if _held_particles.has(object) or d_payload < payload_attractor_radius:
					if not _held_particles.has(object) and _held_particles.size() < 65:
						_held_particles.append(object)
					var to_payload: Vector2 = payload_attractor_pos - world_pos
					var dir := to_payload.normalized()
					var pull: float = clampf(to_payload.length() * 22.0, 240.0, payload_attractor_force)
					PhysicsServer2D.body_set_constant_force(object, dir * pull)
					# Velocity coupling: ensure held water follows rapid winch and swing motions seamlessly
					var cur_v: Vector2 = PhysicsServer2D.body_get_state(object, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
					var target_v: Vector2 = payload_linear_vel + dir * minf(d_payload * 8.0, 420.0)
					PhysicsServer2D.body_set_state(object, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, cur_v.lerp(target_v, 0.4))
					force_applied = true
			# 3. Crane Payload water stirring & displacement
			elif payload_stir_active and payload_stir_pos != Vector2.ZERO:
				var d_stir: float = payload_stir_pos.distance_to(world_pos)
				if d_stir < payload_stir_radius:
					var push_dir: Vector2 = (world_pos - payload_stir_pos).normalized()
					var push_force: Vector2 = push_dir * 180.0 + payload_linear_vel * 0.4
					PhysicsServer2D.body_set_constant_force(object, push_force)
					force_applied = true

			if not force_applied:
				PhysicsServer2D.body_set_constant_force(object, Vector2.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_pointer_key:
			enable_pointer = not enable_pointer
			_update_pointer_visibility()
			get_viewport().set_input_as_handled()
		elif event.keycode == spawn_key and not continuous_stream:
			spawn_water_burst(15)


func _process(_delta: float) -> void:
	if enable_pointer:
		var mouse_pos := get_global_mouse_position()
		if icon_node:
			icon_node.global_position = mouse_pos
			icon_node.visible = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if pointer_node:
			pointer_node.global_position = mouse_pos

	var should_spawn: bool = false
	if continuous_stream:
		should_spawn = true
	elif Input.is_key_pressed(spawn_key) or Input.is_action_pressed("ui_accept"):
		should_spawn = true

	if should_spawn:
		for s in range(stream_rate):
			var offset := Vector2(randf() - 0.5, randf() - 0.5).normalized() * spawn_radius * randf()
			create_object(global_position + offset, Vector2(randf_range(-15, 15), randf_range(10, 60)))


func _update_pointer_visibility() -> void:
	if pointer_node:
		pointer_node.visible = enable_pointer
		pointer_node.process_mode = Node.PROCESS_MODE_INHERIT if enable_pointer else Node.PROCESS_MODE_DISABLED
	if icon_node:
		icon_node.visible = enable_pointer


func spawn_water_burst(amount: int = 15) -> void:
	for i in range(amount):
		var offset := Vector2(randf() - 0.5, randf() - 0.5).normalized() * spawn_radius * randf()
		create_object(global_position + offset, Vector2(randf_range(-20, 20), randf_range(20, 80)))


func start_stream() -> void:
	continuous_stream = true


func stop_stream() -> void:
	continuous_stream = false


func clear_all_water() -> void:
	_exit_tree()


func get_drop_count() -> int:
	return objects.size()


func _exit_tree() -> void:
	for pair in objects:
		var object: RID = pair[0]
		var img: RID = pair[1]
		if object.is_valid():
			PhysicsServer2D.free_rid(object)
		if img.is_valid():
			RenderingServer.free_rid(img)
	objects.clear()


## Registers a body to be completely ignored by all current and future water particles
func add_collision_exception(body: CollisionObject2D) -> void:
	if not body:
		return
	var r: RID = body.get_rid()
	if not _collision_exceptions.has(r):
		_collision_exceptions.append(r)
		var ps := PhysicsServer2D
		for pair in objects:
			var obj: RID = pair[0]
			if obj.is_valid():
				ps.body_add_collision_exception(obj, r)


## Returns the highest water level (lowest Y coordinate) in the horizontal range [min_x, max_x].
## Returns INF if fewer than min_count particles exist in that range.
func get_water_surface_y_in_range(min_x: float, max_x: float, min_count: int = 3) -> float:
	var lowest_y: float = INF
	var count: int = 0
	var ps := PhysicsServer2D
	for pair in objects:
		var obj: RID = pair[0]
		if obj.is_valid():
			var trans: Transform2D = ps.body_get_state(obj, PhysicsServer2D.BODY_STATE_TRANSFORM)
			var p: Vector2 = trans.origin
			if p.x >= min_x and p.x <= max_x:
				count += 1
				if p.y < lowest_y:
					lowest_y = p.y
	return lowest_y if count >= min_count else INF


## Returns how many water particles are currently within radius of the given world position
func count_particles_near(pos: Vector2, radius: float) -> int:
	var count: int = 0
	var ps := PhysicsServer2D
	for pair in objects:
		var object: RID = pair[0]
		if object.is_valid():
			var trans: Transform2D = ps.body_get_state(object, PhysicsServer2D.BODY_STATE_TRANSFORM)
			if pos.distance_to(trans.origin) < radius:
				count += 1
	return count


## Captures and locks nearby water particles into the payload bucket
func start_payload_water_grab(center: Vector2, radius: float = 75.0, force: float = 750.0) -> int:
	payload_holding_water = true
	payload_attractor_pos = center
	payload_attractor_radius = radius
	payload_attractor_force = force
	_held_particles.clear()
	var ps := PhysicsServer2D
	for pair in objects:
		var object: RID = pair[0]
		if object.is_valid():
			var trans: Transform2D = ps.body_get_state(object, PhysicsServer2D.BODY_STATE_TRANSFORM)
			if center.distance_to(trans.origin) < radius:
				_held_particles.append(object)
				if _held_particles.size() >= 65:
					break
	return _held_particles.size()


## Continuously updates the holding position and momentum of held water
func update_payload_water_pos(center: Vector2, vel: Vector2) -> void:
	payload_attractor_pos = center
	payload_linear_vel = vel


## Displaces/stirs water around payload when moving through it
func set_payload_stir(active: bool, pos: Vector2, radius: float, vel: Vector2) -> void:
	payload_stir_active = active
	payload_stir_pos = pos
	payload_stir_radius = radius
	payload_linear_vel = vel


## Flings and releases all held water particles with dynamic launch velocity
func fling_held_water(launch_vel: Vector2) -> void:
	payload_holding_water = false
	var ps := PhysicsServer2D
	for obj in _held_particles:
		if obj.is_valid():
			var spread := Vector2(randf_range(-45.0, 45.0), randf_range(-45.0, 45.0))
			ps.body_set_state(obj, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, launch_vel + spread)
			ps.body_set_constant_force(obj, Vector2.ZERO)
	_held_particles.clear()
