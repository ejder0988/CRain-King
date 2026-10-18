extends Node2D
class_name FluidWater

## 2D Multi-Scale Fluid Water Simulation (PhysicsServer2D + Metaball Canvas Shader)
## Optimized with Multi-Scale Collision Tiers, Dynamic Coalescing & Base Water Source.
## The position of this node in the 2D editor IS the spawn point for water!

enum WaterTier { SMALL = 0, MEDIUM = 1, LARGE = 2 }

# Array of [body_rid: RID, canvas_item_rid: RID, tier: int, age: float]
var objects: Array[Array] = []

var _sub_viewport: SubViewport
var _particle_container: Node2D
var _particle_material: CanvasItemMaterial

# 3 Shared collision shapes (Multi-Scale Architecture)
var _shape_small: CircleShape2D
var _shape_medium: CircleShape2D
var _shape_large: CircleShape2D

# Backwards compatibility shape pointer
@onready var cir_shape: CircleShape2D = CircleShape2D.new()

@export_group("Fluid Water Spawn Settings")
## Number of water drops to spawn at game start from this node's position (set to 0 for no initial water)
@export var initial_drops: int = 200
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
@export var stream_rate: int = 6

@export_group("Fluid Particle Physics")
@export var tex: Texture2D
@export var texSize: float = 64.0
@export var particle_radius: float = 8.0
@export var particle_mass: float = 0.1
@export var particle_friction: float = 0.0
@export var particle_linear_damp: float = 0.3
## Drops are only destroyed if they fall into the abyss below this Y value
@export var kill_y: float = 3000.0
## Maximum particle limit (optimized to ~250 for multi-scale macro water)
@export var max_particles: int = 250


@export_group("Fluid Collision")
## Collision layer for water particles (Default: 1)
@export var water_collision_layer: int = 1
## Collision mask for water particles (Default: 1 -> touches all StaticBody2D terrain shapes and water particles)
@export var water_collision_mask: int = 1

@export_group("Sea Foam Visuals")
## Enable sea foam around the water surface
@export var enable_foam: bool = true:
	set(val):
		enable_foam = val
		_set_water_shader_param("enable_foam", val)
## Primary foam color (froth & bubble walls)
@export var foam_color: Color = Color(0.95, 0.98, 1.0, 0.92):
	set(val):
		foam_color = val
		_set_water_shader_param("foam_color", val)
## Secondary translucent foam tint (soft dissolution into water)
@export var foam_edge_color: Color = Color(0.70, 0.90, 0.98, 0.65):
	set(val):
		foam_edge_color = val
		_set_water_shader_param("foam_edge_color", val)
## How deep the foam extends from the surface
@export_range(0.02, 0.50, 0.01) var foam_thickness: float = 0.16:
	set(val):
		foam_thickness = val
		_set_water_shader_param("foam_thickness", val)
## Overall foam intensity multiplier
@export_range(0.0, 2.0, 0.05) var foam_intensity: float = 1.0:
	set(val):
		foam_intensity = val
		_set_water_shader_param("foam_intensity", val)
## Scale/frequency of foam bubbles (higher = smaller bubbles)
@export_range(10.0, 150.0, 1.0) var foam_scale: float = 45.0:
	set(val):
		foam_scale = val
		_set_water_shader_param("foam_scale", val)
## Overall foam opacity / softness
@export_range(0.0, 1.0, 0.05) var foam_transparency: float = 0.90:
	set(val):
		foam_transparency = val
		_set_water_shader_param("foam_transparency", val)

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
var _payload_released_particles: Dictionary = {} # RID -> release_time_msec (quarantine until ground contact)

# Realistic foam flow & agitation tracking:
var _foam_flow_offset: float = 0.0
var _smoothed_flow_x: float = 0.0
var _smoothed_agitation: float = 0.0


# Periodic merge timer & tsunami state:
var _merge_timer: float = 0.0
var _tsunami_active: bool = false
var _tsunami_cooldown: float = 0.0


func _set_water_shader_param(param_name: String, value: Variant) -> void:
	if water_shader and water_shader.material is ShaderMaterial:
		(water_shader.material as ShaderMaterial).set_shader_parameter(param_name, value)


## Dynamically set the main foam color at runtime
func set_foam_color(color: Color) -> void:
	foam_color = color
	_set_water_shader_param("foam_color", color)


## Dynamically set the edge foam tint at runtime
func set_foam_edge_color(color: Color) -> void:
	foam_edge_color = color
	_set_water_shader_param("foam_edge_color", color)


## Dynamically set the foam transparency at runtime (0.0: invisible, 1.0: fully opaque)
func set_foam_transparency(transparency: float) -> void:
	foam_transparency = transparency
	_set_water_shader_param("foam_transparency", transparency)


func _init_shared_shapes() -> void:
	_shape_small = CircleShape2D.new()
	_shape_small.radius = particle_radius
	_shape_small.custom_solver_bias = 0.1

	_shape_medium = CircleShape2D.new()
	_shape_medium.radius = particle_radius * 2.2
	_shape_medium.custom_solver_bias = 0.1

	_shape_large = CircleShape2D.new()
	_shape_large.radius = particle_radius * 4.0
	_shape_large.custom_solver_bias = 0.1

	cir_shape.radius = particle_radius
	cir_shape.custom_solver_bias = 0.1


func _ready() -> void:
	add_to_group("fluid_water")
	_init_shared_shapes()

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
		var mat := water_shader.material as ShaderMaterial
		mat.set_shader_parameter("water_mask", _sub_viewport.get_texture())
		# Sync exported visual foam parameters
		mat.set_shader_parameter("enable_foam", enable_foam)
		mat.set_shader_parameter("foam_color", foam_color)
		mat.set_shader_parameter("foam_edge_color", foam_edge_color)
		mat.set_shader_parameter("foam_thickness", foam_thickness)
		mat.set_shader_parameter("foam_intensity", foam_intensity)
		mat.set_shader_parameter("foam_scale", foam_scale)
		mat.set_shader_parameter("foam_transparency", foam_transparency)
		mat.set_shader_parameter("foam_flow_offset", _foam_flow_offset)
		mat.set_shader_parameter("water_agitation", _smoothed_agitation)

	if not tex:
		if ResourceLoader.exists("res://water2Dsimulation/asset/part.png"):
			tex = load("res://water2Dsimulation/asset/part.png")
		if not tex:
			tex = _create_fallback_texture()

	_update_pointer_visibility()

	if initial_drops > 0:
		spawn_initial_drops(initial_drops)

	print("[FluidWater] Ready! Multi-Scale Physics active. Initial bodies: ", objects.size(), ". Controls: 'G' burst, 'P' pointer.")


func _create_fallback_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center := Vector2(32, 32)
	for y in range(64):
		for x in range(64):
			var d := Vector2(x, y).distance_to(center)
			var a := pow(clampf(1.0 - (d / 32.0), 0.0, 1.0), 2.2)
			img.set_pixel(x, y, Color(0.92, 0.92, 0.92, a))
	return ImageTexture.create_from_image(img)




## Spawns drops directly from this node's global position with multi-scale depth stratification
func spawn_initial_drops(count: int) -> void:
	if spawn_mode == 1:
		# AREA MODE: Stratify depth into 3 tiers
		# Deep bottom (50%): Tier 2 (Large Water Sources, 16x volume each)
		# Middle layer (30%): Tier 1 (Medium Water Sources, 5x volume each)
		# Surface layer (20%): Tier 0 (Small Water, fine waves & foam)
		var half_w: float = spawn_area.x * 0.5
		var half_h: float = spawn_area.y * 0.5
		var top_y: float = global_position.y - half_h
		var bot_y: float = global_position.y + half_h

		var num_large: int = clampi(int(count * 0.04), 8, 30)
		var num_medium: int = clampi(int(count * 0.10), 16, 65)
		var num_small: int = clampi(int(count * 0.28), 45, 160)

		# 1. Deep layer: Tier 2 Large Water Sources
		for i in range(num_large):
			var rx: float = randf_range(-half_w * 0.95, half_w * 0.95)
			var ry: float = lerpf(top_y + spawn_area.y * 0.52, bot_y - 12.0, randf())
			create_object(Vector2(global_position.x + rx, ry), Vector2.ZERO, WaterTier.LARGE)

		# 2. Middle layer: Tier 1 Medium Water Sources
		for i in range(num_medium):
			var rx: float = randf_range(-half_w * 0.95, half_w * 0.95)
			var ry: float = lerpf(top_y + spawn_area.y * 0.22, top_y + spawn_area.y * 0.65, randf())
			create_object(Vector2(global_position.x + rx, ry), Vector2.ZERO, WaterTier.MEDIUM)

		# 3. Surface layer: Tier 0 Small Water
		for i in range(num_small):
			var rx: float = randf_range(-half_w * 0.98, half_w * 0.98)
			var ry: float = lerpf(top_y, top_y + spawn_area.y * 0.25, randf())
			create_object(Vector2(global_position.x + rx, ry), Vector2.ZERO, WaterTier.SMALL)
	else:
		# POINT MODE: Pour drops down from nozzle
		for i in range(count):
			if objects.size() >= max_particles:
				break
			var offset := Vector2(randf() - 0.5, randf() - 0.5).normalized() * spawn_radius * randf()
			var pos := global_position + offset
			var vel := Vector2(randf_range(-10, 10), randf_range(0, 30))
			var tier: int = WaterTier.SMALL
			if randf() < 0.12:
				tier = WaterTier.MEDIUM
			create_object(pos, vel, tier)


## Creates a physical water particle of the specified scale tier (0: Small, 1: Medium, 2: Large)
func create_object(pos: Vector2, initial_vel: Vector2 = Vector2.ZERO, tier: int = WaterTier.SMALL) -> RID:
	if objects.size() >= max_particles:
		return RID()

	if not tex:
		tex = _create_fallback_texture()

	tier = clampi(tier, 0, 2)
	var shape: CircleShape2D
	var mass: float
	var draw_size: float

	match tier:
		WaterTier.LARGE: # Tier 2 (Macro Water Source)
			shape = _shape_large
			mass = particle_mass * 6.0
			draw_size = texSize * 5.8
		WaterTier.MEDIUM: # Tier 1 (Mid Water)
			shape = _shape_medium
			mass = particle_mass * 3.0
			draw_size = texSize * 3.2
		_: # Tier 0 (Small / Surface)
			shape = _shape_small
			mass = particle_mass
			draw_size = texSize * 1.6

	var ps := PhysicsServer2D
	var object = ps.body_create()
	var space_rid: RID = get_world_2d().space if get_world_2d() else get_tree().root.get_world_2d().space
	ps.body_set_space(object, space_rid)
	ps.body_add_shape(object, shape)
	ps.body_set_param(object, ps.BODY_PARAM_FRICTION, particle_friction)
	ps.body_set_param(object, ps.BODY_PARAM_BOUNCE, 0.0)
	ps.body_set_param(object, ps.BODY_PARAM_MASS, mass)
	ps.body_set_param(object, ps.BODY_PARAM_LINEAR_DAMP, particle_linear_damp)
	ps.body_set_mode(object, ps.BODY_MODE_RIGID_LINEAR)
	ps.body_set_state(object, ps.BODY_STATE_CAN_SLEEP, true)
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
	var w := draw_size
	var h := draw_size
	rs.canvas_item_add_texture_rect(img, Rect2(-w * 0.5, -h * 0.5, w, h), tex_rid)
	if _particle_material:
		rs.canvas_item_set_material(img, _particle_material.get_rid())
	var local_trans := trans
	local_trans.origin -= global_position
	rs.canvas_item_set_transform(img, local_trans)

	objects.append([object, img, tier, 0.0])
	return object


func _physics_process(delta: float) -> void:
	if _sub_viewport:
		_sub_viewport.size = get_viewport_rect().size
		_sub_viewport.canvas_transform = get_viewport().canvas_transform
	if _particle_container:
		_particle_container.global_position = global_position

	# Dynamic coalescing (merging) timer
	_merge_timer += delta
	if _merge_timer >= 0.25:
		_merge_timer = 0.0
		_merge_dense_particles()

	if _tsunami_cooldown > 0.0:
		_tsunami_cooldown -= delta
		if _tsunami_cooldown <= 0.0:
			_tsunami_active = false

	var mouse_pos := get_global_mouse_position()
	var mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var icon_scale := icon_node.scale.x if icon_node and is_instance_valid(icon_node) else 1.0
	var active_disturbance: bool = mouse_down or payload_holding_water or payload_stir_active or _tsunami_active

	var total_vx: float = 0.0
	var total_speed: float = 0.0
	var active_particle_count: int = 0
	var ps := PhysicsServer2D

	# Quarantine cleanup: Once payload-released water lands on the ground (Y >= 800) or settles, reintegrate it
	if not _payload_released_particles.is_empty():
		var now_ms := Time.get_ticks_msec()
		var freed_rids: Array[RID] = []
		for p_rid in _payload_released_particles.keys():
			if not p_rid.is_valid():
				freed_rids.append(p_rid)
				continue
			var trans: Transform2D = ps.body_get_state(p_rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
			if trans.origin.y >= 800.0 or (now_ms - _payload_released_particles[p_rid]) > 4000:
				freed_rids.append(p_rid)
		for f in freed_rids:
			_payload_released_particles.erase(f)


	for i in range(objects.size() - 1, -1, -1):
		var item: Array = objects[i]
		var object: RID = item[0]
		var img: RID = item[1]
		var tier: int = item[2]
		item[3] = float(item[3]) + delta

		var trans: Transform2D = ps.body_get_state(object, PhysicsServer2D.BODY_STATE_TRANSFORM)
		var world_pos := trans.origin

		# 1. Abyss kill check
		if world_pos.y > kill_y:
			objects.remove_at(i)
			if _held_particles.has(object):
				_held_particles.erase(object)
			ps.free_rid(object)
			RenderingServer.free_rid(img)
			continue

		var cur_v: Vector2 = ps.body_get_state(object, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		var cur_speed := cur_v.length()

		# 2. High-Velocity Splitting (Tsunami surge or violent catapulting breaks large sources into lively spray)
		if tier == WaterTier.LARGE and cur_speed > 450.0 and objects.size() < max_particles - 4:
			objects.remove_at(i)
			if _held_particles.has(object):
				_held_particles.erase(object)
			ps.free_rid(object)
			RenderingServer.free_rid(img)
			var off1 := Vector2(-12.0, randf_range(-6.0, 6.0))
			var off2 := Vector2(12.0, randf_range(-6.0, 6.0))
			create_object(world_pos + off1, cur_v + Vector2(-15.0, -10.0), WaterTier.MEDIUM)
			create_object(world_pos + off2, cur_v + Vector2(15.0, -10.0), WaterTier.MEDIUM)
			continue
		elif tier == WaterTier.MEDIUM and cur_speed > 550.0 and objects.size() < max_particles - 4:
			objects.remove_at(i)
			if _held_particles.has(object):
				_held_particles.erase(object)
			ps.free_rid(object)
			RenderingServer.free_rid(img)
			var off1 := Vector2(-8.0, randf_range(-4.0, 4.0))
			var off2 := Vector2(8.0, randf_range(-4.0, 4.0))
			create_object(world_pos + off1, cur_v + Vector2(-10.0, -8.0), WaterTier.SMALL)
			create_object(world_pos + off2, cur_v + Vector2(10.0, -8.0), WaterTier.SMALL)
			continue

		# 4. Sleeping particle optimization: skip RenderingServer IPC update if particle is static
		var is_sleeping: bool = bool(ps.body_get_state(object, PhysicsServer2D.BODY_STATE_SLEEPING))
		if not is_sleeping or active_disturbance:
			var local_trans := trans
			local_trans.origin -= global_position
			RenderingServer.canvas_item_set_transform(img, local_trans)

		total_vx += cur_v.x
		total_speed += cur_speed
		active_particle_count += 1

		# Mass scaling multiplier (Tier 0: 1.0, Tier 1: 3.0, Tier 2: 6.0)
		var mass_mult: float = 1.0 if tier == WaterTier.SMALL else (3.0 if tier == WaterTier.MEDIUM else 6.0)
		var force_applied: bool = false

		# A. Mouse pointer attraction
		if mouse_down and enable_pointer and mouse_pos.distance_to(world_pos) < 60.0 * icon_scale:
			ps.body_set_state(object, PhysicsServer2D.BODY_STATE_SLEEPING, false)
			var dir := (mouse_pos - world_pos).normalized()
			ps.body_set_constant_force(object, dir * attrForce * mass_mult)
			force_applied = true
		# B. Crane Payload water holding (attraction toward scoop bucket)
		elif payload_holding_water and payload_attractor_pos != Vector2.ZERO:
			var d_payload: float = payload_attractor_pos.distance_to(world_pos)
			if _held_particles.has(object) or d_payload < payload_attractor_radius:
				if not _held_particles.has(object) and _held_particles.size() < 350:
					_held_particles.append(object)
				ps.body_set_state(object, PhysicsServer2D.BODY_STATE_SLEEPING, false)
				var to_payload: Vector2 = payload_attractor_pos - world_pos
				var dir := to_payload.normalized()
				var pull: float = clampf(to_payload.length() * 22.0, 240.0, payload_attractor_force)
				ps.body_set_constant_force(object, dir * pull * mass_mult)
				var target_v: Vector2 = payload_linear_vel + dir * minf(d_payload * 8.0, 420.0)
				ps.body_set_state(object, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, cur_v.lerp(target_v, 0.4))
				force_applied = true
		# C. Crane Payload water stirring & displacement
		elif payload_stir_active and payload_stir_pos != Vector2.ZERO:
			var d_stir: float = payload_stir_pos.distance_to(world_pos)
			if d_stir < payload_stir_radius:
				ps.body_set_state(object, PhysicsServer2D.BODY_STATE_SLEEPING, false)
				var push_dir: Vector2 = (world_pos - payload_stir_pos).normalized()
				var push_force: Vector2 = push_dir * 180.0 + payload_linear_vel * 0.4
				ps.body_set_constant_force(object, push_force * mass_mult)
				force_applied = true

		if not force_applied and not _tsunami_active:
			ps.body_set_constant_force(object, Vector2.ZERO)

	if active_particle_count > 0:
		var avg_vx: float = total_vx / float(active_particle_count)
		var avg_speed: float = total_speed / float(active_particle_count)
		_smoothed_flow_x = lerpf(_smoothed_flow_x, clampf(avg_vx / 250.0, -1.0, 1.0), delta * 5.0)
		_smoothed_agitation = lerpf(_smoothed_agitation, clampf(avg_speed / 180.0, 0.0, 1.0), delta * 4.0)
	else:
		_smoothed_flow_x = lerpf(_smoothed_flow_x, 0.0, delta * 5.0)
		_smoothed_agitation = lerpf(_smoothed_agitation, 0.0, delta * 4.0)

	_foam_flow_offset += _smoothed_flow_x * delta * 0.25
	_set_water_shader_param("foam_flow_offset", _foam_flow_offset)
	_set_water_shader_param("water_agitation", _smoothed_agitation)


## Spatial grid coalescing: Combines 4 dense small particles into 1 medium, and 3 medium into 1 large source
func _merge_dense_particles() -> void:
	if objects.size() < 4:
		return

	var cell_size: float = 64.0
	var grid_tier0: Dictionary = {}
	var grid_tier1: Dictionary = {}
	var ps := PhysicsServer2D

	for i in range(objects.size()):
		var item: Array = objects[i]
		var tier: int = item[2]
		if tier >= WaterTier.LARGE:
			continue

		var object: RID = item[0]
		if not object.is_valid():
			continue

		var vel: Vector2 = ps.body_get_state(object, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		if vel.length() > 90.0:
			continue # Only settled, calm water particles coalesce

		var trans: Transform2D = ps.body_get_state(object, PhysicsServer2D.BODY_STATE_TRANSFORM)
		var p: Vector2 = trans.origin
		var cell_key := Vector2i(int(floor(p.x / cell_size)), int(floor(p.y / cell_size)))

		if tier == WaterTier.SMALL:
			if not grid_tier0.has(cell_key):
				grid_tier0[cell_key] = []
			grid_tier0[cell_key].append(i)
		elif tier == WaterTier.MEDIUM:
			if not grid_tier1.has(cell_key):
				grid_tier1[cell_key] = []
			grid_tier1[cell_key].append(i)

	var to_remove_set: Dictionary = {}
	var new_creations: Array = []

	# 1. Merge 4 Tier 0 (Small) -> 1 Tier 1 (Medium)
	for cell_key in grid_tier0:
		var indices: Array = grid_tier0[cell_key]
		while indices.size() >= 4:
			var idx0: int = indices.pop_back()
			var idx1: int = indices.pop_back()
			var idx2: int = indices.pop_back()
			var idx3: int = indices.pop_back()
			if to_remove_set.has(idx0) or to_remove_set.has(idx1) or to_remove_set.has(idx2) or to_remove_set.has(idx3):
				continue

			var p0: Vector2 = (ps.body_get_state(objects[idx0][0], PhysicsServer2D.BODY_STATE_TRANSFORM) as Transform2D).origin
			var p1: Vector2 = (ps.body_get_state(objects[idx1][0], PhysicsServer2D.BODY_STATE_TRANSFORM) as Transform2D).origin
			var p2: Vector2 = (ps.body_get_state(objects[idx2][0], PhysicsServer2D.BODY_STATE_TRANSFORM) as Transform2D).origin
			var p3: Vector2 = (ps.body_get_state(objects[idx3][0], PhysicsServer2D.BODY_STATE_TRANSFORM) as Transform2D).origin
			var avg_pos := (p0 + p1 + p2 + p3) * 0.25

			var v0: Vector2 = ps.body_get_state(objects[idx0][0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var v1: Vector2 = ps.body_get_state(objects[idx1][0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var v2: Vector2 = ps.body_get_state(objects[idx2][0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var v3: Vector2 = ps.body_get_state(objects[idx3][0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var avg_vel := (v0 + v1 + v2 + v3) * 0.25

			to_remove_set[idx0] = true
			to_remove_set[idx1] = true
			to_remove_set[idx2] = true
			to_remove_set[idx3] = true
			new_creations.append([avg_pos, avg_vel, WaterTier.MEDIUM])

	# 2. Merge 3 Tier 1 (Medium) -> 1 Tier 2 (Large)
	for cell_key in grid_tier1:
		var indices: Array = grid_tier1[cell_key]
		while indices.size() >= 3:
			var idx0: int = indices.pop_back()
			var idx1: int = indices.pop_back()
			var idx2: int = indices.pop_back()
			if to_remove_set.has(idx0) or to_remove_set.has(idx1) or to_remove_set.has(idx2):
				continue

			var p0: Vector2 = (ps.body_get_state(objects[idx0][0], PhysicsServer2D.BODY_STATE_TRANSFORM) as Transform2D).origin
			var p1: Vector2 = (ps.body_get_state(objects[idx1][0], PhysicsServer2D.BODY_STATE_TRANSFORM) as Transform2D).origin
			var p2: Vector2 = (ps.body_get_state(objects[idx2][0], PhysicsServer2D.BODY_STATE_TRANSFORM) as Transform2D).origin
			var avg_pos := (p0 + p1 + p2) * 0.333333

			var v0: Vector2 = ps.body_get_state(objects[idx0][0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var v1: Vector2 = ps.body_get_state(objects[idx1][0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var v2: Vector2 = ps.body_get_state(objects[idx2][0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var avg_vel := (v0 + v1 + v2) * 0.333333

			to_remove_set[idx0] = true
			to_remove_set[idx1] = true
			to_remove_set[idx2] = true
			new_creations.append([avg_pos, avg_vel, WaterTier.LARGE])

	if to_remove_set.is_empty():
		return

	# Remove marked indices in descending order
	var sorted_indices: Array = to_remove_set.keys()
	sorted_indices.sort()
	for k in range(sorted_indices.size() - 1, -1, -1):
		var del_idx: int = sorted_indices[k]
		var item: Array = objects[del_idx]
		var obj: RID = item[0]
		var img: RID = item[1]
		if _held_particles.has(obj):
			_held_particles.erase(obj)
		if obj.is_valid():
			ps.free_rid(obj)
		if img.is_valid():
			RenderingServer.free_rid(img)
		objects.remove_at(del_idx)

	# Spawn new consolidated tiers
	for spawn_info in new_creations:
		create_object(spawn_info[0], spawn_info[1], spawn_info[2])


## Triggers or updates a global or directional tsunami surge across the water body
func apply_tsunami_surge(direction: Vector2, force: float, min_x: float = -INF, max_x: float = INF) -> void:
	_tsunami_active = true
	_tsunami_cooldown = 1.5
	var ps := PhysicsServer2D
	for item in objects:
		var obj: RID = item[0]
		if not obj.is_valid():
			continue
		var trans: Transform2D = ps.body_get_state(obj, PhysicsServer2D.BODY_STATE_TRANSFORM)
		if trans.origin.x >= min_x and trans.origin.x <= max_x:
			ps.body_set_state(obj, PhysicsServer2D.BODY_STATE_SLEEPING, false)
			var tier: int = item[2]
			var mass_mult: float = 1.0 if tier == WaterTier.SMALL else (3.0 if tier == WaterTier.MEDIUM else 6.0)
			ps.body_apply_central_impulse(obj, direction.normalized() * force * mass_mult)


## Creates a circular impulse / wave burst at world position (e.g. impact, explosion, tsunami crest)
func apply_wave_impulse(pos: Vector2, radius: float, force: float, upward_bias: float = 0.5) -> void:
	var ps := PhysicsServer2D
	for item in objects:
		var obj: RID = item[0]
		if not obj.is_valid():
			continue
		var trans: Transform2D = ps.body_get_state(obj, PhysicsServer2D.BODY_STATE_TRANSFORM)
		var d: float = pos.distance_to(trans.origin)
		if d < radius:
			ps.body_set_state(obj, PhysicsServer2D.BODY_STATE_SLEEPING, false)
			var dir: Vector2 = (trans.origin - pos).normalized()
			dir.y -= upward_bias
			dir = dir.normalized()
			var tier: int = item[2]
			var mass_mult: float = 1.0 if tier == WaterTier.SMALL else (3.0 if tier == WaterTier.MEDIUM else 6.0)
			var strength: float = (1.0 - (d / radius)) * force * mass_mult
			ps.body_apply_central_impulse(obj, dir * strength)


func _unhandled_input(event: InputEvent) -> void:
	var gm = get_node_or_null("/root/GameManager")
	var is_debug: bool = gm and gm.debug_mode
	if not is_debug:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_pointer_key:
			enable_pointer = not enable_pointer
			_update_pointer_visibility()
			get_viewport().set_input_as_handled()
		elif event.keycode == spawn_key and not continuous_stream:
			spawn_water_burst(15)


func _process(_delta: float) -> void:
	var gm = get_node_or_null("/root/GameManager")
	var is_debug: bool = gm and gm.debug_mode

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
	elif is_debug and Input.is_key_pressed(spawn_key):
		should_spawn = true

	if should_spawn:
		for s in range(stream_rate):
			var offset := Vector2(randf() - 0.5, randf() - 0.5).normalized() * spawn_radius * randf()
			var tier: int = WaterTier.SMALL
			if randf() < 0.15:
				tier = WaterTier.MEDIUM
			create_object(global_position + offset, Vector2(randf_range(-15, 15), randf_range(10, 60)), tier)


func _update_pointer_visibility() -> void:
	if pointer_node:
		pointer_node.visible = enable_pointer
		pointer_node.process_mode = Node.PROCESS_MODE_INHERIT if enable_pointer else Node.PROCESS_MODE_DISABLED
	if icon_node:
		icon_node.visible = enable_pointer


func spawn_water_burst(amount: int = 15) -> void:
	for i in range(amount):
		if objects.size() >= max_particles:
			break
		var offset := Vector2(randf() - 0.5, randf() - 0.5).normalized() * spawn_radius * randf()
		var vel := Vector2(randf_range(-20, 20), randf_range(20, 80))
		var tier: int = WaterTier.SMALL
		if randf() < 0.2:
			tier = WaterTier.MEDIUM
		create_object(global_position + offset, vel, tier)


func start_stream() -> void:
	continuous_stream = true


func stop_stream() -> void:
	continuous_stream = false


func clear_all_water() -> void:
	_exit_tree()


func get_drop_count() -> int:
	return objects.size()


func _exit_tree() -> void:
	var ps := PhysicsServer2D
	var rs := RenderingServer
	for item in objects:
		var object: RID = item[0]
		var img: RID = item[1]
		if object.is_valid():
			ps.free_rid(object)
		if img.is_valid():
			rs.free_rid(img)
	objects.clear()
	_held_particles.clear()



## Registers a body to be completely ignored by all current and future water particles
func add_collision_exception(body: CollisionObject2D) -> void:
	if not body:
		return
	var r: RID = body.get_rid()
	if not _collision_exceptions.has(r):
		_collision_exceptions.append(r)
		var ps := PhysicsServer2D
		for item in objects:
			var obj: RID = item[0]
			if obj.is_valid():
				ps.body_add_collision_exception(obj, r)


## Returns the highest water level (lowest Y coordinate) in the horizontal range [min_x, max_x].
## Returns INF if fewer than min_count particles exist in that range.
func get_water_surface_y_in_range(min_x: float, max_x: float, min_count: int = 3) -> float:
	var lowest_y: float = INF
	var weighted_count: int = 0
	var ps := PhysicsServer2D
	for item in objects:
		var obj: RID = item[0]
		if obj.is_valid():
			if _held_particles.has(obj) or _payload_released_particles.has(obj):
				continue
			var trans: Transform2D = ps.body_get_state(obj, PhysicsServer2D.BODY_STATE_TRANSFORM)
			var p: Vector2 = trans.origin
			if p.x >= min_x and p.x <= max_x:
				var tier: int = item[2]
				weighted_count += 1 if tier == WaterTier.SMALL else (5 if tier == WaterTier.MEDIUM else 16)
				var r: float = particle_radius if tier == WaterTier.SMALL else (particle_radius * 2.2 if tier == WaterTier.MEDIUM else particle_radius * 4.0)
				var surface_p: float = p.y - r * 0.7
				if surface_p < lowest_y:
					lowest_y = surface_p

	return lowest_y if weighted_count >= min_count else INF


## Returns the dense water surface level (Y coordinate) in the horizontal range [min_x, max_x].
## Unlike raw minimum Y, this requires a cluster of particles to define the surface,
## completely ignoring stray airborne splash droplets. Returns INF if water body is not present.
func get_dense_water_surface_y(min_x: float, max_x: float, min_density: int = 4) -> float:
	var y_coords: Array[float] = []
	var ps := PhysicsServer2D
	for item in objects:
		var obj: RID = item[0]
		if obj.is_valid():
			if _held_particles.has(obj) or _payload_released_particles.has(obj):
				continue
			var trans: Transform2D = ps.body_get_state(obj, PhysicsServer2D.BODY_STATE_TRANSFORM)
			var p: Vector2 = trans.origin
			if p.x >= min_x and p.x <= max_x:
				var tier: int = item[2]
				var r: float = particle_radius if tier == WaterTier.SMALL else (particle_radius * 2.2 if tier == WaterTier.MEDIUM else particle_radius * 4.0)
				var surface_p: float = p.y - r * 0.7
				var count := 1 if tier == WaterTier.SMALL else (3 if tier == WaterTier.MEDIUM else 6)
				for c in range(count):
					y_coords.append(surface_p)

	if y_coords.size() < min_density:
		return INF

	y_coords.sort()
	var surface_idx := clampi(min_density - 1, 0, y_coords.size() - 1)
	return y_coords[surface_idx]


## Returns weighted volume of water particles currently inside the given world Rect2.
## Large sources contribute proportional volume (Tier 0: 1, Tier 1: 5, Tier 2: 16).
func count_particles_in_rect(rect: Rect2) -> int:
	var count: int = 0
	var ps := PhysicsServer2D
	for item in objects:
		var obj: RID = item[0]
		if obj.is_valid():
			if _held_particles.has(obj) or _payload_released_particles.has(obj):
				continue
			var trans: Transform2D = ps.body_get_state(obj, PhysicsServer2D.BODY_STATE_TRANSFORM)
			if rect.has_point(trans.origin):
				var tier: int = item[2]
				count += 1 if tier == WaterTier.SMALL else (5 if tier == WaterTier.MEDIUM else 16)

	return count


## Returns weighted count of water particles currently within radius of the given world position
func count_particles_near(pos: Vector2, radius: float) -> int:
	var count: int = 0
	var ps := PhysicsServer2D
	for item in objects:
		var object: RID = item[0]
		if object.is_valid():
			var trans: Transform2D = ps.body_get_state(object, PhysicsServer2D.BODY_STATE_TRANSFORM)
			if pos.distance_to(trans.origin) < radius:
				var tier: int = item[2]
				count += 1 if tier == WaterTier.SMALL else (5 if tier == WaterTier.MEDIUM else 16)
	return count


## Captures and locks nearby water particles into the payload bucket
func start_payload_water_grab(center: Vector2, radius: float = 75.0, force: float = 750.0) -> int:
	payload_holding_water = true
	payload_attractor_pos = center
	payload_attractor_radius = radius
	payload_attractor_force = force
	_held_particles.clear()
	var ps := PhysicsServer2D
	for item in objects:
		var object: RID = item[0]
		if object.is_valid():
			var trans: Transform2D = ps.body_get_state(object, PhysicsServer2D.BODY_STATE_TRANSFORM)
			if center.distance_to(trans.origin) < radius:
				ps.body_set_state(object, PhysicsServer2D.BODY_STATE_SLEEPING, false)
				_held_particles.append(object)
				if _held_particles.size() >= 350:
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
	var now_ms := Time.get_ticks_msec()
	for obj in _held_particles:
		if obj.is_valid():
			_payload_released_particles[obj] = now_ms
			var spread := Vector2(randf_range(-45.0, 45.0), randf_range(-45.0, 45.0))
			ps.body_set_state(obj, PhysicsServer2D.BODY_STATE_SLEEPING, false)
			ps.body_set_state(obj, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, launch_vel + spread)
			ps.body_set_constant_force(obj, Vector2.ZERO)
	_held_particles.clear()
