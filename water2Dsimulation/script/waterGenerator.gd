extends Node2D
class_name WaterGenerator2D

var objects: Array[Array] = []

@onready var cir_shape := CircleShape2D.new()

@export_group("Fluid Particles")
@export var tex: Texture2D
@export var spawnRad: float = 16.0
@export var texSize: float = 48.0
@export var particle_radius: float = 8.0
@export var particle_mass: float = 0.1
@export var particle_friction: float = 0.05
@export var particle_linear_damp: float = 0.3
@export var kill_y: float = 3000.0
@export var max_particles: int = 6000

@export_group("Spawning")
## Number of drops to spawn at start from this generator's position
@export var initial_drops: int = 1000
## 0: POINT (pour from marker), 1: AREA (fill an area around marker)
@export_enum("POINT:0", "AREA:1") var spawn_mode: int = 0
## Area size if spawn_mode is AREA
@export var spawn_area: Vector2 = Vector2(300, 100)
## Key to spawn water drops
@export var spawn_key: Key = KEY_G
## If true, continuously streams drops from this generator
@export var continuous_stream: bool = false
## Drops per frame when continuous_stream is active
@export var stream_rate: int = 1

@export_group("Interaction")
@export var attrForce: float = 500.0
@export var pointer: bool = false

var _icon_node: Node2D = null


func _ready() -> void:
	cir_shape.radius = particle_radius
	cir_shape.custom_solver_bias = 0.1

	if not tex:
		if ResourceLoader.exists("res://water2Dsimulation/asset/part.png"):
			tex = load("res://water2Dsimulation/asset/part.png")
		if not tex:
			tex = _create_fallback_texture()

	var parent = get_parent()
	if parent and "initial_drops" in parent:
		initial_drops = parent.initial_drops
	if parent and "spawn_mode" in parent:
		spawn_mode = parent.spawn_mode
	if parent and "spawn_area" in parent:
		spawn_area = parent.spawn_area
	if parent and "spawn_radius" in parent:
		spawnRad = parent.spawn_radius
	if parent and "continuous_stream" in parent:
		continuous_stream = parent.continuous_stream
	if parent and "stream_rate" in parent:
		stream_rate = parent.stream_rate
	if parent and "spawn_key" in parent:
		spawn_key = parent.spawn_key
	if parent and "attrForce" in parent:
		attrForce = parent.attrForce
	if parent and "pointer" in parent:
		pointer = parent.pointer

	_icon_node = get_node_or_null("../UI/Icon")

	if initial_drops > 0:
		spawn_initial_drops(initial_drops)


func _create_fallback_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center := Vector2(32, 32)
	for y in range(64):
		for x in range(64):
			var d := Vector2(x, y).distance_to(center)
			var a := clampf(1.0 - (d / 32.0), 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(0.92, 0.92, 0.92, a))
	return ImageTexture.create_from_image(img)


## Spawns drops directly at this generator's global position
func spawn_initial_drops(count: int) -> void:
	for i in range(count):
		var pos: Vector2
		var vel: Vector2
		if spawn_mode == 1:
			pos = global_position + Vector2(randf_range(-spawn_area.x * 0.5, spawn_area.x * 0.5), randf_range(-spawn_area.y * 0.5, spawn_area.y * 0.5))
			vel = Vector2.ZERO
		else:
			var offset := Vector2(randf() - 0.5, randf() - 0.5).normalized() * spawnRad * randf()
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
	ps.body_set_param(object, ps.BODY_PARAM_MASS, particle_mass)
	ps.body_set_param(object, ps.BODY_PARAM_LINEAR_DAMP, particle_linear_damp)
	ps.body_set_mode(object, ps.BODY_MODE_RIGID_LINEAR)

	var trans := Transform2D(0, pos)
	ps.body_set_state(object, ps.BODY_STATE_TRANSFORM, trans)
	if initial_vel != Vector2.ZERO:
		ps.body_set_state(object, ps.BODY_STATE_LINEAR_VELOCITY, initial_vel)

	var rs := RenderingServer
	var img := rs.canvas_item_create()
	rs.canvas_item_set_parent(img, get_canvas_item())
	var tex_rid: RID = tex.get_rid()
	rs.canvas_item_add_texture_rect(img, Rect2(texSize / -2.0, texSize / -2.0, texSize, texSize), tex_rid)
	rs.canvas_item_set_transform(img, trans)

	objects.append([object, img])



func _physics_process(_delta: float) -> void:
	var mouse_pos := get_global_mouse_position()
	var mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var icon_scale := _icon_node.scale.x if _icon_node and is_instance_valid(_icon_node) else 1.0

	var killboxes: Array = get_tree().get_nodes_in_group("water_killbox")
	var has_killboxes: bool = not killboxes.is_empty()
	if has_killboxes:
		for kb in killboxes:
			if kb.has_method("update_cached_bounds"):
				kb.update_cached_bounds()

	var pushboxes: Array = get_tree().get_nodes_in_group("water_pushbox")
	var has_pushboxes: bool = not pushboxes.is_empty()
	if has_pushboxes:
		for pb in pushboxes:
			if pb.has_method("update_cached_bounds"):
				pb.update_cached_bounds()

	for i in range(objects.size() - 1, -1, -1):
		var pair = objects[i]
		var object: RID = pair[0]
		var img: RID = pair[1]
		var trans: Transform2D = PhysicsServer2D.body_get_state(object, PhysicsServer2D.BODY_STATE_TRANSFORM)
		var world_pos := trans.origin

		var in_killbox: bool = false
		if has_killboxes:
			for kb in killboxes:
				if kb.enabled and kb.contains_point(world_pos):
					in_killbox = true
					if "kill_count" in kb:
						kb.kill_count += 1
					if kb.has_signal("water_destroyed"):
						kb.water_destroyed.emit(world_pos)
					break

		if in_killbox or world_pos.y > kill_y or world_pos.x < -200 or world_pos.x > 4000:
			objects.remove_at(i)
			PhysicsServer2D.free_rid(object)
			RenderingServer.free_rid(img)
		else:
			var local_trans := trans
			local_trans.origin -= global_position
			RenderingServer.canvas_item_set_transform(img, local_trans)

			var active_pushbox = null
			if has_pushboxes:
				for pb in pushboxes:
					var pb_active: bool = pb.is_push_active() if pb.has_method("is_push_active") else pb.enabled
					if pb_active and pb.contains_point(world_pos):
						active_pushbox = pb
						break

			if mouse_down and not pointer and mouse_pos.distance_to(world_pos) < 60.0 * icon_scale:
				var dir := (mouse_pos - world_pos).normalized()
				PhysicsServer2D.body_set_constant_force(object, dir * attrForce)
			elif active_pushbox != null:
				var p_dir: Vector2 = active_pushbox.get_effective_push_direction()
				PhysicsServer2D.body_set_constant_force(object, p_dir * active_pushbox.push_force * 0.1)
				if active_pushbox.apply_velocity_boost:
					var cur_v = PhysicsServer2D.body_get_state(object, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
					if cur_v != null:
						var target_v: Vector2 = p_dir * active_pushbox.target_speed
						PhysicsServer2D.body_set_state(object, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, cur_v.lerp(target_v, active_pushbox.velocity_blend))
			else:
				PhysicsServer2D.body_set_constant_force(object, Vector2.ZERO)


func _exit_tree() -> void:
	for pair in objects:
		var object: RID = pair[0]
		var img: RID = pair[1]
		if object.is_valid():
			PhysicsServer2D.free_rid(object)
		if img.is_valid():
			RenderingServer.free_rid(img)
	objects.clear()


func _process(_delta: float) -> void:
	var parent = get_parent()
	if parent and "attrForce" in parent:
		attrForce = parent.attrForce
	if parent and "pointer" in parent:
		pointer = parent.pointer

	var should_spawn: bool = false
	var gm = get_node_or_null("/root/GameManager")
	var is_debug: bool = gm and gm.debug_mode
	if continuous_stream:
		should_spawn = true
	elif is_debug and Input.is_key_pressed(spawn_key):
		should_spawn = true

	if should_spawn:
		for s in range(stream_rate):
			var offset := Vector2(randf() - 0.5, randf() - 0.5).normalized() * spawnRad * randf()
			create_object(global_position + offset, Vector2(randf_range(-15, 15), randf_range(10, 60)))
