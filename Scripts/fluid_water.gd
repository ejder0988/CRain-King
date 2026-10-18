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
## Maximum particle limit (0 veya negatif = Sınırsız / Sahne maksimum su sınırı kaldırıldı)
@export var max_particles: int = 0


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

@export_group("Tsunami Push & Force Settings")
## Tsunami su itme açısı (Derece cinsinden: 45.0 = sola ve yukarı 45° açıyla çapraz fırlatma/itme)
@export_range(0.0, 90.0, 1.0) var tsunami_push_angle_degrees: float = 45.0

## Tsunami dalgası ilerlerken sulara uygulanan sürekli itme kuvveti
@export var tsunami_push_force: float = 1450.0

## Kavisli sahil ve yükselen tepecik bölgesinde uygulanan ekstra itme kuvveti (X: Duvar - 1980)
@export var tsunami_coastal_push_force: float = 1750.0

## Tsunami başladığı anda uygulanan ilk darbe/fırlatma kuvveti (Kickoff impulse)
@export var tsunami_kickoff_impulse: float = 240.0

## Tsunami dalgası sırasında suların yukarı doğru fırlayabileceği maksimum dikey hız limiti (px/s)
@export var tsunami_max_upward_speed: float = 450.0

## Tsunami dalgası sırasında suların sola doğru gidebileceği maksimum yatay hız limiti (px/s)
@export var tsunami_max_horizontal_speed: float = 480.0

@export_group("Tsunami Water Scaling Settings")
## İlk tsunamide eklenecek temel su damlası sayısı (Game düğümüyle senkronize çalışır)
@export var tsunami_base_water_amount: int = 60
## Her tsunamide önceki tsunamiye göre suyun yüzde artış oranı (% cinsinden: 20 = %20)
@export_range(0.0, 500.0, 1.0, "suffix:%") var tsunami_water_growth_percentage: float = 20.0:
	set(val):
		_tsunami_water_growth_percentage = maxf(val, 0.0)
		tsunami_water_growth_rate = _tsunami_water_growth_percentage / 100.0
	get:
		return _tsunami_water_growth_percentage
## Her tsunamide önceki tsunamiye göre suyun artış oranı (0.20 = %20)
@export_range(0.0, 5.0, 0.01) var tsunami_water_growth_rate: float = 0.20:
	set(val):
		tsunami_water_growth_rate = maxf(val, 0.0)
		_tsunami_water_growth_percentage = tsunami_water_growth_rate * 100.0
	get:
		return tsunami_water_growth_rate
## Tsunami dalgası hücum anında ekstra dalga takviye damlası sayısı (Varsayılan: 0 - tüm su rezervuardan gelir)
@export var tsunami_surge_boost_drops: int = 0

var _tsunami_water_growth_percentage: float = 20.0

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

enum TsunamiPhase {
	IDLE,
	DRAWBACK,      ## 1. Aşama: Suların sağa (ekran dışı havuza) çekilmesi (2.0s)
	ROLLING_WAVE,  ## 2. Aşama: Geriden gelen hareketli dalga cephesi (2.5s)
	IMPACT,        ## 3. Aşama: Duvara çarpma anı
	BACKWASH       ## 4. Aşama: Suların sağa doğal geri çekilmesi (3.0s)
}

var _tsunami_phase: TsunamiPhase = TsunamiPhase.IDLE
var _tsunami_phase_timer: float = 0.0
var _wave_front_x: float = 2100.0
var _wave_start_x: float = 2100.0
var _wave_travel_speed: float = 224.0
var _surge_cycle_level: int = 1
var _cached_stone_wall_x: float = 1540.0
var _temp_boost_particles: Dictionary = {} # RID -> true
var _impact_foam_timer: float = 0.0
var _wave_curl_node: Node2D = null

# Gradual Rain Reservoir Fill Variables:
var _rain_reservoir_drops_to_spawn: int = 0
var _rain_reservoir_spawn_interval: float = 0.0
var _rain_reservoir_timer: float = 0.0
var _tsunami_spawn_cycle: int = 0

# Orphan Ball Cleaner Timer:
var _orphan_clean_timer: float = 0.0

# Backward compatibility flags
var _tsunami_surge_active: bool:
	get: return _tsunami_phase == TsunamiPhase.ROLLING_WAVE
var _accumulating: bool = false


func _get_wall_x() -> float:
	var sw = get_tree().get_first_node_in_group("stone_wall")
	if sw and is_instance_valid(sw):
		_cached_stone_wall_x = sw.global_position.x
	return _cached_stone_wall_x


## Tsunami itme açısına göre normalize edilmiş 2D yön vektörünü hesaplar (Varsayılan 45° = sola ve yukarı)
func get_tsunami_push_direction() -> Vector2:
	var rad: float = deg_to_rad(tsunami_push_angle_degrees)
	return Vector2(-cos(rad), -sin(rad))


## Tsunami itme açısını dinamik olarak değiştirmek için yardımcı fonksiyon
func set_tsunami_push_angle(degrees: float) -> void:
	tsunami_push_angle_degrees = degrees


## Tsunami itme kuvvetini dinamik olarak değiştirmek için yardımcı fonksiyon
func set_tsunami_push_force(force: float) -> void:
	tsunami_push_force = force


## Tsunami su artış oranını dinamik olarak değiştirmek için yardımcı fonksiyon
func set_tsunami_water_growth_rate(rate: float) -> void:
	tsunami_water_growth_rate = maxf(rate, 0.0)


## Tsunami su artış yüzdesini dinamik olarak değiştirmek için yardımcı fonksiyon
func set_tsunami_water_growth_percentage(percent: float) -> void:
	tsunami_water_growth_percentage = maxf(percent, 0.0)


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

	# Setup dynamic wave curl visual node
	_setup_wave_curl_visual()

	# Ensure impenetrable right boundary wall at X = 2400.0 (world space, covering the expanded off-screen pool)
	var boundary := StaticBody2D.new()
	boundary.name = "RightScreenBoundaryWall"
	boundary.top_level = true
	boundary.global_position = Vector2.ZERO
	var b_col := CollisionShape2D.new()
	var b_seg := SegmentShape2D.new()
	b_seg.a = Vector2(2400.0, -1000.0)
	b_seg.b = Vector2(2400.0, 2000.0)
	b_col.shape = b_seg
	boundary.add_child(b_col)
	boundary.collision_layer = water_collision_layer
	boundary.collision_mask = water_collision_mask
	add_child(boundary)

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

		var num_large: int = int(round(count * 0.10))
		var num_medium: int = int(round(count * 0.25))
		var num_small: int = maxi(count - num_large - num_medium, 0)

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
			if max_particles > 0 and objects.size() >= max_particles:
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
	if max_particles > 0 and objects.size() >= max_particles:
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
	var local_pos := pos - global_position
	var initial_trans: Transform2D
	if pos.x < _cached_stone_wall_x and tier == WaterTier.SMALL:
		initial_trans = Transform2D(0.0, Vector2(1.6, 0.45), 0.0, local_pos)
	else:
		initial_trans = trans
		initial_trans.origin = local_pos
	rs.canvas_item_set_transform(img, initial_trans)

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

	# Yağmur aşaması boyunca sağdaki genişletilmiş havuzda (X > 1920) kademeli rezervuar dolumu
	if _rain_reservoir_drops_to_spawn > 0:
		_rain_reservoir_timer += delta
		while _rain_reservoir_timer >= _rain_reservoir_spawn_interval and _rain_reservoir_drops_to_spawn > 0:
			_rain_reservoir_timer -= _rain_reservoir_spawn_interval
			_rain_reservoir_drops_to_spawn -= 1
			if max_particles <= 0 or objects.size() < max_particles:
				var rx: float = randf_range(1960.0, 2360.0)
				var ry: float = randf_range(720.0, 830.0)
				var rvel: Vector2 = Vector2(randf_range(-15.0, 15.0), randf_range(30.0, 90.0))
				var tier: int = WaterTier.SMALL
				var r_rnd := randf()
				if r_rnd < 0.20:
					tier = WaterTier.LARGE
				elif r_rnd < 0.50:
					tier = WaterTier.MEDIUM
				create_object(Vector2(rx, ry), rvel, tier)

	# Sular ve dalgalar yerinde kalmalı, silinmemeli

	if _tsunami_cooldown > 0.0:
		_tsunami_cooldown -= delta
		if _tsunami_cooldown <= 0.0:
			_tsunami_active = false

	# Impact foam timer decay
	if _impact_foam_timer > 0.0:
		_impact_foam_timer -= delta
		_set_water_shader_param("tsunami_impact_foam", clampf(_impact_foam_timer * 2.0, 0.0, 1.0))
	else:
		_set_water_shader_param("tsunami_impact_foam", 0.0)

	# Process 4-Phase Tsunami State Machine
	var crest_height: float = 20.0 + float(_surge_cycle_level - 1) * (245.0 / 23.0)
	var target_wave_crest_y: float = 917.0 - crest_height
	var viewport_w: float = get_viewport_rect().size.x if is_inside_tree() else 1920.0
	var viewport_h: float = get_viewport_rect().size.y if is_inside_tree() else 1080.0

	match _tsunami_phase:
		TsunamiPhase.DRAWBACK:
			_tsunami_phase_timer -= delta
			_set_water_shader_param("tsunami_wave_front_uv", -1.0)
			if _wave_curl_node:
				_wave_curl_node.visible = false
			if _tsunami_phase_timer <= 0.0:
				_tsunami_phase = TsunamiPhase.IDLE

		TsunamiPhase.ROLLING_WAVE:
			_tsunami_phase_timer -= delta
			_wave_front_x -= _wave_travel_speed * delta

			var front_uv_x: float = _wave_front_x / viewport_w
			var crest_uv_y: float = target_wave_crest_y / viewport_h
			_set_water_shader_param("tsunami_wave_front_uv", front_uv_x)
			_set_water_shader_param("tsunami_crest_uv_y", crest_uv_y)

			# Position dynamic wave curl visual
			if _wave_curl_node and _particle_container:
				_wave_curl_node.visible = true
				_wave_curl_node.position = Vector2(_wave_front_x, target_wave_crest_y) - global_position

			# Check if wave reached the wall
			if _wave_front_x <= _cached_stone_wall_x or _tsunami_phase_timer <= 0.0:
				_on_wave_impact_wall(target_wave_crest_y)

		TsunamiPhase.IMPACT:
			_tsunami_phase_timer -= delta
			if _wave_curl_node:
				_wave_curl_node.visible = false
			if _tsunami_phase_timer <= 0.0:
				start_tsunami_backwash(3.0)

		TsunamiPhase.BACKWASH:
			_tsunami_phase_timer -= delta
			_set_water_shader_param("tsunami_wave_front_uv", -1.0)
			if _wave_curl_node:
				_wave_curl_node.visible = false
			if _tsunami_phase_timer <= 0.0:
				_tsunami_phase = TsunamiPhase.IDLE
				_tsunami_active = false

	var mouse_pos := get_global_mouse_position()
	var mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var icon_scale := icon_node.scale.x if icon_node and is_instance_valid(icon_node) else 1.0
	var active_disturbance: bool = mouse_down or payload_holding_water or payload_stir_active or _tsunami_active or _tsunami_phase != TsunamiPhase.IDLE

	var total_vx: float = 0.0
	var total_speed: float = 0.0
	var active_particle_count: int = 0
	var ps := PhysicsServer2D
	var now_ms := Time.get_ticks_msec()

	# Quarantine cleanup: Erase expired records purely by timestamp (no invalid body_get_state calls)
	if not _payload_released_particles.is_empty():
		var expired_rids: Array[RID] = []
		for p_rid in _payload_released_particles.keys():
			if (now_ms - _payload_released_particles[p_rid]) > 3500:
				expired_rids.append(p_rid)
		for f in expired_rids:
			_payload_released_particles.erase(f)

	# Water KillBox önbelleği (Varsa killbox kontrollerini çok hızlı yapar)
	var killboxes: Array = get_tree().get_nodes_in_group("water_killbox")
	var has_killboxes: bool = not killboxes.is_empty()
	if has_killboxes:
		for kb in killboxes:
			if kb.has_method("update_cached_bounds"):
				kb.update_cached_bounds()

	# Water PushBox önbelleği (Suyu belirlenen yöne iten alanlar)
	var pushboxes: Array = get_tree().get_nodes_in_group("water_pushbox")
	var has_pushboxes: bool = not pushboxes.is_empty()
	if has_pushboxes:
		for pb in pushboxes:
			if pb.has_method("update_cached_bounds"):
				pb.update_cached_bounds()

	for i in range(objects.size() - 1, -1, -1):
		var item: Array = objects[i]
		var object: RID = item[0]
		var img: RID = item[1]
		var tier: int = item[2]
		item[3] = float(item[3]) + delta

		var trans_var = ps.body_get_state(object, PhysicsServer2D.BODY_STATE_TRANSFORM)
		if trans_var == null:
			objects.remove_at(i)
			if _held_particles.has(object):
				_held_particles.erase(object)
			if _payload_released_particles.has(object):
				_payload_released_particles.erase(object)
			continue

		var trans: Transform2D = trans_var
		var world_pos := trans.origin

		# 0. Killbox check: bu alana temas eden veya giren su anında yok edilir
		if has_killboxes:
			var in_killbox: bool = false
			for kb in killboxes:
				if kb.enabled and kb.contains_point(world_pos):
					in_killbox = true
					if "kill_count" in kb:
						kb.kill_count += 1
					if kb.has_signal("water_destroyed"):
						kb.water_destroyed.emit(world_pos)
					break
			if in_killbox:
				objects.remove_at(i)
				if _held_particles.has(object):
					_held_particles.erase(object)
				if _payload_released_particles.has(object):
					_payload_released_particles.erase(object)
				ps.free_rid(object)
				RenderingServer.free_rid(img)
				continue

		# Once payload-flung water lands on ground level (Y >= 800), lift quarantine
		if _payload_released_particles.has(object):
			if world_pos.y >= 800.0:
				_payload_released_particles.erase(object)

		# PushBox check: Parçacığın bir itme alanı içinde olup olmadığını tespit et
		var active_pushbox = null
		if has_pushboxes:
			for pb in pushboxes:
				var pb_active: bool = pb.is_push_active() if pb.has_method("is_push_active") else pb.enabled
				if pb_active and pb.contains_point(world_pos):
					active_pushbox = pb
					break

		# 1. Abyss kill check
		if world_pos.y > kill_y:
			objects.remove_at(i)
			if _held_particles.has(object):
				_held_particles.erase(object)
			if _payload_released_particles.has(object):
				_payload_released_particles.erase(object)
			ps.free_rid(object)
			RenderingServer.free_rid(img)
			continue

		var vel_var = ps.body_get_state(object, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		var cur_v: Vector2 = vel_var if vel_var != null else Vector2.ZERO

		# 0. Right Screen Boundary Protection (expanded off-screen pool up to X ~ 2380)
		if world_pos.x > 2380.0:
			world_pos.x = 2380.0
			trans.origin.x = 2380.0
			ps.body_set_state(object, PhysicsServer2D.BODY_STATE_TRANSFORM, trans)
			if cur_v.x > 0.0:
				cur_v.x = -absf(cur_v.x) * 0.3
				ps.body_set_state(object, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, cur_v)



		# 1. HARD VELOCITY CLAMP: Absolute safety clamp prevents water from rocketing uncontrollably off slopes
		# Tsunami dalgası sırasında 45 derecelik açıyla rahatça yükselebilmesi ve fırlayabilmesi için tavan dinamik olarak açılır
		var is_tsunami_surging: bool = (_tsunami_phase == TsunamiPhase.ROLLING_WAVE or _tsunami_active)
		var max_up: float = -tsunami_max_upward_speed if is_tsunami_surging else -130.0
		var max_left: float = -tsunami_max_horizontal_speed if is_tsunami_surging else -420.0
		var max_right: float = 250.0
		var max_down: float = 500.0

		# İtme kutusu içindeyken kutunun hız ve tavan sınırlarına dinamik izin ver
		if active_pushbox != null:
			var pb_limit: float = maxf(active_pushbox.max_exit_speed, active_pushbox.target_speed)
			max_up = minf(max_up, -pb_limit)
			max_left = minf(max_left, -pb_limit)
			max_right = maxf(max_right, pb_limit)
			max_down = maxf(max_down, pb_limit)

		var clamped_vx: float = clampf(cur_v.x, max_left, max_right)
		var clamped_vy: float = clampf(cur_v.y, max_up, max_down)
		if clamped_vx != cur_v.x or clamped_vy != cur_v.y:
			cur_v = Vector2(clamped_vx, clamped_vy)
			ps.body_set_state(object, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, cur_v)

		var cur_speed := cur_v.length()

		# 2. BÖLGESEL SINIRLANDIRMA (No Big Balls on Left Side):
		# Duvarın sol tarafındaki düz zeminde (pos.x < wall_x) ASLA MEDIUM veya LARGE su parçacığı bulunamaz!
		# Duvarı aşan her MEDIUM veya LARGE parçacık duvarı geçtiği an (pos.x < wall_x) anında silinir ve yatay eksende [-20px, 0px, +20px] 3 adet SMALL parçacığa bölünür.
		var wall_x := _get_wall_x()
		if (tier == WaterTier.MEDIUM or tier == WaterTier.LARGE) and world_pos.x < wall_x:
			objects.remove_at(i)
			if _held_particles.has(object):
				_held_particles.erase(object)
			if _payload_released_particles.has(object):
				_payload_released_particles.erase(object)
			ps.free_rid(object)
			RenderingServer.free_rid(img)
			var offsets: Array[float] = [-20.0, 0.0, 20.0]
			for ox in offsets:
				create_object(Vector2(world_pos.x + ox, world_pos.y), cur_v, WaterTier.SMALL)
			continue

		# 3. High-Velocity Splitting (Yalnızca normal/sakin zamanlarda vinçten fırlatılan büyük su kütleleri için; tsunami sırasında parçalanma kesinlikle engellenir)
		if _tsunami_phase == TsunamiPhase.IDLE:
			if tier == WaterTier.LARGE and cur_speed > 520.0 and (max_particles <= 0 or objects.size() < max_particles - 4):
				objects.remove_at(i)
				if _held_particles.has(object):
					_held_particles.erase(object)
				if _payload_released_particles.has(object):
					_payload_released_particles.erase(object)
				ps.free_rid(object)
				RenderingServer.free_rid(img)
				var off1 := Vector2(-12.0, randf_range(-6.0, 6.0))
				var off2 := Vector2(12.0, randf_range(-6.0, 6.0))
				create_object(world_pos + off1, cur_v + Vector2(-15.0, -10.0), WaterTier.MEDIUM)
				create_object(world_pos + off2, cur_v + Vector2(15.0, -10.0), WaterTier.MEDIUM)
				continue
			elif tier == WaterTier.MEDIUM and cur_speed > 620.0 and (max_particles <= 0 or objects.size() < max_particles - 4):
				objects.remove_at(i)
				if _held_particles.has(object):
					_held_particles.erase(object)
				if _payload_released_particles.has(object):
					_payload_released_particles.erase(object)
				ps.free_rid(object)
				RenderingServer.free_rid(img)
				var off1 := Vector2(-8.0, randf_range(-4.0, 4.0))
				var off2 := Vector2(8.0, randf_range(-4.0, 4.0))
				create_object(world_pos + off1, cur_v + Vector2(-10.0, -8.0), WaterTier.SMALL)
				create_object(world_pos + off2, cur_v + Vector2(10.0, -8.0), WaterTier.SMALL)
				continue

		# 4. Sleeping particle optimization & Flattened Shallow Layer for Left Side:
		var is_sleeping: bool = bool(ps.body_get_state(object, PhysicsServer2D.BODY_STATE_SLEEPING))
		if not is_sleeping or active_disturbance or active_pushbox != null:
			var local_pos := trans.origin - global_position
			if world_pos.x < wall_x and tier == WaterTier.SMALL:
				# Zemine Yapışık Sığ Su Ölçeklemesi (Flattened Shallow Layer):
				# Dikeyde basık (0.45), yatayda geniş (1.6) -> elips: Vector2(1.6, 0.45)
				var shallow_trans := Transform2D(0.0, Vector2(1.6, 0.45), 0.0, local_pos)
				RenderingServer.canvas_item_set_transform(img, shallow_trans)
			else:
				var local_trans := trans
				local_trans.origin = local_pos
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
		# D. Water PushBox (Alana giren her suyu belirlenen yönde iter)
		elif active_pushbox != null:
			if active_pushbox.wake_sleeping_water:
				ps.body_set_state(object, PhysicsServer2D.BODY_STATE_SLEEPING, false)
			var p_mass: float = particle_mass * mass_mult
			var push_dir: Vector2 = active_pushbox.get_effective_push_direction()
			var push_force_vec: Vector2 = push_dir * active_pushbox.push_force * p_mass
			ps.body_set_constant_force(object, push_force_vec)
			force_applied = true

			if active_pushbox.apply_velocity_boost:
				var target_v: Vector2 = push_dir * active_pushbox.target_speed
				if active_pushbox.cancel_opposing_velocity:
					var dot: float = cur_v.dot(push_dir)
					if dot < 0.0:
						cur_v -= push_dir * dot
				cur_v = cur_v.lerp(target_v, clampf(active_pushbox.velocity_blend, 0.01, 1.0))
				if cur_v.length() > active_pushbox.max_exit_speed:
					cur_v = cur_v.normalized() * active_pushbox.max_exit_speed
				ps.body_set_state(object, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, cur_v)

			if "push_count" in active_pushbox:
				active_pushbox.push_count += 1
			if active_pushbox.has_signal("water_pushed"):
				active_pushbox.water_pushed.emit(world_pos, push_dir)
		if not force_applied:
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
		if _held_particles.has(object) or _payload_released_particles.has(object):
			continue

		var vel_var = ps.body_get_state(object, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		if vel_var == null:
			continue
		var vel: Vector2 = vel_var
		if vel.length() > 90.0:
			continue # Only settled, calm water particles coalesce

		var trans_var = ps.body_get_state(object, PhysicsServer2D.BODY_STATE_TRANSFORM)
		if trans_var == null:
			continue
		var trans: Transform2D = trans_var
		var p: Vector2 = trans.origin

		# Duvarın sol tarafında (pos.x <= wall_x + 20.0) ASLA birleşme olamaz, sol taraf daima sığ su kalır!
		if p.x <= (_get_wall_x() + 20.0):
			continue

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

			var t0 = ps.body_get_state(objects[idx0][0], PhysicsServer2D.BODY_STATE_TRANSFORM)
			var t1 = ps.body_get_state(objects[idx1][0], PhysicsServer2D.BODY_STATE_TRANSFORM)
			var t2 = ps.body_get_state(objects[idx2][0], PhysicsServer2D.BODY_STATE_TRANSFORM)
			var t3 = ps.body_get_state(objects[idx3][0], PhysicsServer2D.BODY_STATE_TRANSFORM)
			if t0 == null or t1 == null or t2 == null or t3 == null:
				continue
			var p0: Vector2 = (t0 as Transform2D).origin
			var p1: Vector2 = (t1 as Transform2D).origin
			var p2: Vector2 = (t2 as Transform2D).origin
			var p3: Vector2 = (t3 as Transform2D).origin
			var avg_pos := (p0 + p1 + p2 + p3) * 0.25

			var v0_var = ps.body_get_state(objects[idx0][0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var v1_var = ps.body_get_state(objects[idx1][0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var v2_var = ps.body_get_state(objects[idx2][0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var v3_var = ps.body_get_state(objects[idx3][0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var v0: Vector2 = v0_var if v0_var != null else Vector2.ZERO
			var v1: Vector2 = v1_var if v1_var != null else Vector2.ZERO
			var v2: Vector2 = v2_var if v2_var != null else Vector2.ZERO
			var v3: Vector2 = v3_var if v3_var != null else Vector2.ZERO
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

			var t0 = ps.body_get_state(objects[idx0][0], PhysicsServer2D.BODY_STATE_TRANSFORM)
			var t1 = ps.body_get_state(objects[idx1][0], PhysicsServer2D.BODY_STATE_TRANSFORM)
			var t2 = ps.body_get_state(objects[idx2][0], PhysicsServer2D.BODY_STATE_TRANSFORM)
			if t0 == null or t1 == null or t2 == null:
				continue
			var p0: Vector2 = (t0 as Transform2D).origin
			var p1: Vector2 = (t1 as Transform2D).origin
			var p2: Vector2 = (t2 as Transform2D).origin
			var avg_pos := (p0 + p1 + p2) * 0.333333

			var v0_var = ps.body_get_state(objects[idx0][0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var v1_var = ps.body_get_state(objects[idx1][0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var v2_var = ps.body_get_state(objects[idx2][0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var v0: Vector2 = v0_var if v0_var != null else Vector2.ZERO
			var v1: Vector2 = v1_var if v1_var != null else Vector2.ZERO
			var v2: Vector2 = v2_var if v2_var != null else Vector2.ZERO
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
		if _payload_released_particles.has(obj):
			_payload_released_particles.erase(obj)
		if obj.is_valid():
			ps.free_rid(obj)
		if img.is_valid():
			RenderingServer.free_rid(img)
		objects.remove_at(del_idx)

	# Spawn new consolidated tiers
	for spawn_info in new_creations:
		create_object(spawn_info[0], spawn_info[1], spawn_info[2])


## Kalan rezervuar damlalarını anında havuza doldurur (yağmur atlandığında veya bittiğinde eksik kalmaması için)
func finish_pending_rain_reservoir() -> void:
	if _rain_reservoir_drops_to_spawn <= 0:
		return
	var left := _rain_reservoir_drops_to_spawn
	_rain_reservoir_drops_to_spawn = 0
	for i in range(left):
		if max_particles <= 0 or objects.size() < max_particles:
			var rx: float = randf_range(1960.0, 2360.0)
			var ry: float = randf_range(720.0, 830.0)
			var rvel: Vector2 = Vector2(randf_range(-15.0, 15.0), randf_range(30.0, 90.0))
			var tier: int = WaterTier.SMALL
			var r_rnd := randf()
			if r_rnd < 0.20:
				tier = WaterTier.LARGE
			elif r_rnd < 0.50:
				tier = WaterTier.MEDIUM
			create_object(Vector2(rx, ry), rvel, tier)


## Phase 1: DRAWBACK - Suları sağ tarafa (ekran dışı havuza) yumuşakça çeker (2.0s)
func start_tsunami_drawback(duration: float = 2.0) -> void:
	finish_pending_rain_reservoir()
	_tsunami_phase = TsunamiPhase.DRAWBACK
	_tsunami_phase_timer = duration
	_set_water_shader_param("tsunami_wave_front_uv", -1.0)
	if _wave_curl_node:
		_wave_curl_node.visible = false
	print("[FluidWater] Tsunami DRAWBACK başladı! Sular geriye (sağ havuza) çekiliyor. Süre: %.1fs" % duration)


## Phase 2: ROLLING_WAVE - Ekran dışından gelip tuğla duvara doğru ilerleyen hareketli dalga cephesi (2.5s)
func start_rolling_wave(duration: float = 2.5, cycle_level: int = 1) -> void:
	_tsunami_active = true
	_tsunami_phase = TsunamiPhase.ROLLING_WAVE
	_tsunami_phase_timer = duration
	_surge_cycle_level = clampi(cycle_level, 1, 24)

	var sw = get_tree().get_first_node_in_group("stone_wall")
	if sw and is_instance_valid(sw):
		_cached_stone_wall_x = sw.global_position.x
	else:
		_cached_stone_wall_x = 1540.0

	_wave_start_x = global_position.x + 250.0 # Ekranın sağ dışındaki havuz (~2104.0)
	_wave_front_x = _wave_start_x
	var wave_dist: float = maxf(_wave_start_x - _cached_stone_wall_x, 100.0)
	_wave_travel_speed = wave_dist / maxf(duration, 0.5)

	# Dalga vuruşu anında ekstra takviye damlaları (Varsayılan: 0, tüm su rezervuardan gelir)
	var boost_count: int = tsunami_surge_boost_drops
	if boost_count > 0:
		for b in range(boost_count):
			if max_particles > 0 and objects.size() >= max_particles:
				break
			var bx: float = randf_range(2040.0, 2240.0)
			var by: float = randf_range(810.0, 890.0)
			var bv: Vector2 = Vector2(randf_range(-20.0, 0.0), randf_range(10.0, 40.0))
			var tier: int = WaterTier.SMALL if randf() > 0.3 else WaterTier.MEDIUM
			var obj_rid := create_object(Vector2(bx, by), bv, tier)
			if obj_rid.is_valid():
				_temp_boost_particles[obj_rid] = true

	print("[FluidWater] Tsunami ROLLING_WAVE başladı! Seviye: %d/24 | X: %.1f -> %.1f | Takviye Su: +%d" % [_surge_cycle_level, _wave_front_x, _cached_stone_wall_x, boost_count])


## Phase 3: IMPACT - Dalga duvara vurduğunda duvar seviyesi ve çarpma kontrolü
func _on_wave_impact_wall(target_wave_crest_y: float) -> void:
	_tsunami_phase = TsunamiPhase.IMPACT
	_tsunami_phase_timer = 0.8
	_impact_foam_timer = 1.0

	var sw = get_tree().get_first_node_in_group("stone_wall")
	var wall_top_y: float = 917.0
	var wall_stage: int = 0
	if sw and is_instance_valid(sw):
		wall_top_y = sw.get_wall_top_y_world()
		wall_stage = sw.current_stage if "current_stage" in sw else 0
	else:
		wall_top_y = 917.0

	var wall_defended: bool = wall_top_y <= target_wave_crest_y

	print("[FluidWater] ★ DALGA DUVARA ÇARPTI! Seviye: %d/24 | Duvar Top Y: %.1f | Dalga Crest Y: %.1f | Korundu: %s" % [wall_stage, wall_top_y, target_wave_crest_y, str(wall_defended)])

	var ps := PhysicsServer2D
	for item in objects:
		var obj: RID = item[0]
		if not obj.is_valid():
			continue
		var trans_var = ps.body_get_state(obj, PhysicsServer2D.BODY_STATE_TRANSFORM)
		if trans_var == null:
			continue
		var pos: Vector2 = (trans_var as Transform2D).origin
		if absf(pos.x - _cached_stone_wall_x) < 55.0:
			var v_var = ps.body_get_state(obj, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var v: Vector2 = v_var if v_var != null else Vector2.ZERO
			if wall_defended:
				# Duvar yeterince yüksek: su duvardan yansır, zıplamaz, köpük oluşturur
				v.x = absf(v.x) * 0.35 + 50.0
				v.y = maxf(v.y, -20.0)
				ps.body_set_state(obj, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, v)
			else:
				# Duvar alçak: sadece duvarın üstündeki kısım sol tarafa (evlere doğru) akar
				if pos.y < wall_top_y:
					v.x = minf(v.x, -160.0)
					ps.body_set_state(obj, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, v)
				else:
					# Duvarın altında kalan kısım duvara çarpıp durur/yansır
					v.x = absf(v.x) * 0.2 + 30.0
					ps.body_set_state(obj, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, v)


## Phase 4: BACKWASH - Suların sağa doğal geri çekilmesi (3.0s)
func start_tsunami_backwash(duration: float = 3.0) -> void:
	_tsunami_phase = TsunamiPhase.BACKWASH
	_tsunami_phase_timer = duration
	_set_water_shader_param("tsunami_wave_front_uv", -1.0)
	if _wave_curl_node:
		_wave_curl_node.visible = false
	print("[FluidWater] Tsunami BACKWASH başladı! Sular sağ havuza geri çekiliyor. Süre: %.1fs" % duration)


## Backward compatibility aliases
func start_controlled_surge(duration: float = 2.5, cycle_level: int = 1) -> void:
	start_rolling_wave(duration, cycle_level)


func start_tsunami_surge(duration: float = 2.5) -> void:
	start_rolling_wave(duration, _surge_cycle_level)


func apply_tsunami_surge(_direction: Vector2 = Vector2(-1.0, 0.0), _force: float = 0.0, _min_x: float = -INF, _max_x: float = INF) -> void:
	start_rolling_wave(2.5, _surge_cycle_level)


## Tsunami başladığı anda spawn_initial_drops çağrılır ve her seferinde initial_drops %20 artar
func on_tsunami_started() -> int:
	var drops_now: int = initial_drops
	spawn_initial_drops(drops_now)
	initial_drops = int(round(float(initial_drops) * 1.20))
	print("[FluidWater] 🌊 Tsunami başladı: spawn_initial_drops(%d) çağrıldı! Bir sonraki tsunami için initial_drops: %d (+%%20)" % [
		drops_now, initial_drops
	])
	return drops_now


func spawn_tsunami_burst(_cycle_index: int = -1, _override_amount: int = -1) -> int:
	return on_tsunami_started()


## Belirli bir tsunami döngüsü için üretilecek su miktarını hesaplar
func calculate_tsunami_water_amount(_cycle_idx: int) -> int:
	return initial_drops


func fill_tsunami_liquid_water(_total_drops: int, _duration: float = 8.0) -> void:
	on_tsunami_started()


## Geriye dönük uyumluluk takma adı
func start_rain_reservoir_fill(total_drops: int, duration: float = 8.0) -> void:
	fill_tsunami_liquid_water(total_drops, duration)


func start_water_accumulation(total_drops: int, duration: float = 4.0) -> void:
	fill_tsunami_liquid_water(total_drops, duration)


func start_gradual_rain_collection(total_drops: int, duration: float = 4.0) -> void:
	fill_tsunami_liquid_water(total_drops, duration)


## Dalgalar ve taşan sular yerinde kalmalı, kesinlikle silinmemeli
func _clean_orphan_particles() -> void:
	pass


func _setup_wave_curl_visual() -> void:
	if _wave_curl_node or not _particle_container:
		return
	_wave_curl_node = Node2D.new()
	_wave_curl_node.name = "TsunamiWaveCurl"
	_wave_curl_node.visible = false
	_particle_container.add_child(_wave_curl_node)

	var offsets := [
		Vector2(0.0, 0.0),
		Vector2(-22.0, 8.0),
		Vector2(-40.0, 24.0),
		Vector2(-35.0, 44.0),
		Vector2(26.0, 10.0),
		Vector2(56.0, 26.0),
		Vector2(88.0, 48.0)
	]
	var scales := [1.8, 1.6, 1.4, 1.2, 1.9, 2.2, 2.5]

	for k in range(offsets.size()):
		var sp := Sprite2D.new()
		sp.texture = tex
		if _particle_material:
			sp.material = _particle_material
		sp.position = offsets[k]
		sp.scale = Vector2.ONE * scales[k] * 0.85
		_wave_curl_node.add_child(sp)


## Dalga sonrasında su durumunu sakinleştirir; sular kesinlikle silinmez, yerinde kalır!
func calm_and_cleanup_post_surge(_target_max_particles: int = 160) -> void:
	_tsunami_phase = TsunamiPhase.IDLE
	_set_water_shader_param("tsunami_wave_front_uv", -1.0)
	_set_water_shader_param("tsunami_impact_foam", 0.0)
	if _wave_curl_node:
		_wave_curl_node.visible = false

	var ps := PhysicsServer2D

	# Suları sakinleştir (hızlarını yumuşat, ancak hiçbir suyu silme!)
	for item in objects:
		var obj: RID = item[0]
		if obj.is_valid():
			var v_var = ps.body_get_state(obj, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			if v_var != null:
				var v: Vector2 = v_var
				ps.body_set_state(obj, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, v * 0.4)

	print("[FluidWater] Dalga sona erdi, sular sakinleşti ve yerinde kaldı! Parçacık sayısı: %d" % objects.size())


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
		if max_particles > 0 and objects.size() >= max_particles:
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
	_payload_released_particles.clear()



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
			var trans_var = ps.body_get_state(obj, PhysicsServer2D.BODY_STATE_TRANSFORM)
			if trans_var == null:
				continue
			var trans: Transform2D = trans_var
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
			var trans_var = ps.body_get_state(obj, PhysicsServer2D.BODY_STATE_TRANSFORM)
			if trans_var == null:
				continue
			var trans: Transform2D = trans_var
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


## Calculates the volumetric submersion ratio (0.0 to 1.0) of a given world Rect2 using a 3x3 grid.
## Evaluates 9 sample points (Bottom, Middle, Top across Left, Center, Right columns).
## Visual water coverage radii by tier:
## - Tier 0 (Small): texSize * 0.65
## - Tier 1 (Medium): texSize * 1.35
## - Tier 2 (Large): texSize * 2.4
## Top (roof) points only count if their respective column's bottom and middle points are also submerged,
## ensuring stray splashes overhead do not contribute to submersion.
func get_rect_submersion_ratio(target_rect: Rect2) -> float:
	var norm_rect := target_rect.abs()
	if norm_rect.size.x <= 0.0 or norm_rect.size.y <= 0.0 or objects.is_empty():
		return 0.0

	# 3 Columns in X: Left (20%), Center (50%), Right (80%)
	var col_x: Array[float] = [
		norm_rect.position.x + norm_rect.size.x * 0.20,
		norm_rect.position.x + norm_rect.size.x * 0.50,
		norm_rect.position.x + norm_rect.size.x * 0.80
	]

	# 3 Rows in Godot 2D (Y increases downwards):
	# Top (Çatı): smaller Y
	# Middle: center Y
	# Bottom (Taban): larger Y
	var y_top: float = norm_rect.position.y + norm_rect.size.y * 0.20
	var y_mid: float = norm_rect.position.y + norm_rect.size.y * 0.50
	var y_bot: float = norm_rect.position.y + norm_rect.size.y * 0.80

	var bot_submerged: Array[bool] = [false, false, false]
	var mid_submerged: Array[bool] = [false, false, false]
	var top_submerged: Array[bool] = [false, false, false]
	var remaining_points: int = 9

	var ps := PhysicsServer2D
	var max_water_r: float = texSize * 2.4
	var aabb_min_x: float = norm_rect.position.x - max_water_r
	var aabb_max_x: float = norm_rect.end.x + max_water_r
	var aabb_min_y: float = norm_rect.position.y - max_water_r
	var aabb_max_y: float = norm_rect.end.y + max_water_r

	for item in objects:
		if remaining_points <= 0:
			break

		var obj: RID = item[0]
		if not obj.is_valid():
			continue
		# Ignore particles currently held in crane bucket
		if _held_particles.has(obj):
			continue

		var trans_var = ps.body_get_state(obj, PhysicsServer2D.BODY_STATE_TRANSFORM)
		if trans_var == null:
			continue
		var pos: Vector2 = (trans_var as Transform2D).origin

		# Fast AABB reject
		if pos.x < aabb_min_x or pos.x > aabb_max_x or pos.y < aabb_min_y or pos.y > aabb_max_y:
			continue

		var tier: int = item[2]
		var water_r: float
		match tier:
			WaterTier.LARGE:
				water_r = texSize * 2.4
			WaterTier.MEDIUM:
				water_r = texSize * 1.35
			_: # WaterTier.SMALL
				water_r = texSize * 0.65

		var water_r_sq: float = water_r * water_r

		for c in range(3):
			var cx: float = col_x[c]

			if not bot_submerged[c]:
				if pos.distance_squared_to(Vector2(cx, y_bot)) <= water_r_sq:
					bot_submerged[c] = true
					remaining_points -= 1

			if not mid_submerged[c]:
				if pos.distance_squared_to(Vector2(cx, y_mid)) <= water_r_sq:
					mid_submerged[c] = true
					remaining_points -= 1

			if not top_submerged[c]:
				if pos.distance_squared_to(Vector2(cx, y_top)) <= water_r_sq:
					top_submerged[c] = true
					remaining_points -= 1

	# Submersion calculation with bottom-up validation
	# Top points only count if both bottom and middle in that column are submerged
	var valid_points: int = 0
	for c in range(3):
		if bot_submerged[c]:
			valid_points += 1
			if mid_submerged[c]:
				valid_points += 1
				if top_submerged[c]:
					valid_points += 1

	return clampf(float(valid_points) / 9.0, 0.0, 1.0)


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
			var trans_var = ps.body_get_state(obj, PhysicsServer2D.BODY_STATE_TRANSFORM)
			if trans_var == null:
				continue
			var trans: Transform2D = trans_var
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
			var trans_var = ps.body_get_state(object, PhysicsServer2D.BODY_STATE_TRANSFORM)
			if trans_var == null:
				continue
			var trans: Transform2D = trans_var
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
			var trans_var = ps.body_get_state(object, PhysicsServer2D.BODY_STATE_TRANSFORM)
			if trans_var == null:
				continue
			var trans: Transform2D = trans_var
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
			var trans_check = ps.body_get_state(obj, PhysicsServer2D.BODY_STATE_TRANSFORM)
			if trans_check == null:
				continue
			_payload_released_particles[obj] = now_ms
			var spread := Vector2(randf_range(-45.0, 45.0), randf_range(-45.0, 45.0))
			ps.body_set_state(obj, PhysicsServer2D.BODY_STATE_SLEEPING, false)
			ps.body_set_state(obj, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, launch_vel + spread)
			ps.body_set_constant_force(obj, Vector2.ZERO)
	_held_particles.clear()


## Evin bütün kat collision alanlarının suların collision'ı tarafından %100 içine alınıp alınmadığını kontrol eder.
## Evin tabanından en üst katının çatısına kadar suyun tam olarak örtmesi gerekir.
## Üst katlar yukarıda kaldığı sürece veya su seviyesi çatının altındaysa false döner.
func is_house_100_percent_submerged(full_house_rect: Rect2, floor_rects: Array[Rect2] = []) -> bool:
	if objects.is_empty():
		return false

	var norm_rect := full_house_rect.abs()
	if norm_rect.size.x <= 0.0 or norm_rect.size.y <= 0.0:
		return false

	# 1. 3x3 ızgarada taban, orta ve çatı noktalarının su altında kalma oranını kontrol et (en az %88)
	var ratio := get_rect_submersion_ratio(norm_rect)
	if ratio < 0.88:
		return false

	# 2. En üst katın (çatının) üzerinde/seviyesinde su parçacığı olduğunu doğrula
	var roof_y: float = norm_rect.position.y
	var margin_x: float = 12.0
	var house_left: float = norm_rect.position.x - margin_x
	var house_right: float = norm_rect.end.x + margin_x
	var roof_touched: bool = false
	var ps := PhysicsServer2D

	for item in objects:
		var obj: RID = item[0]
		if not obj.is_valid() or _held_particles.has(obj):
			continue
		var trans_var = ps.body_get_state(obj, PhysicsServer2D.BODY_STATE_TRANSFORM)
		if trans_var == null:
			continue
		var pos: Vector2 = (trans_var as Transform2D).origin
		var tier: int = item[2]
		var r: float = particle_radius if tier == WaterTier.SMALL else (particle_radius * 2.2 if tier == WaterTier.MEDIUM else particle_radius * 4.0)

		# Çatı seviyesine (veya yukarısına) ulaşan su parçacığı var mı?
		if pos.x >= house_left and pos.x <= house_right:
			if pos.y <= (roof_y + r + 6.0):
				roof_touched = true
				break

	if not roof_touched:
		return false

	# 3. Eğer kat rect'leri verilmişse, en üst kat collision'ında en az 2 su parçacığı bulunmalı
	if not floor_rects.is_empty():
		var top_rect: Rect2 = floor_rects[floor_rects.size() - 1]
		var top_count: int = count_particles_in_rect(top_rect.grow(10.0))
		if top_count < 2:
			return false

	return true


## Evin bütün kat collision shape'lerine suyun tam olarak değip değmediğini kontrol eder.
func are_all_floor_collisions_touched(floor_rects: Array[Rect2]) -> bool:
	if floor_rects.is_empty() or objects.is_empty():
		return false

	var union_rect: Rect2 = floor_rects[0]
	for i in range(1, floor_rects.size()):
		union_rect = union_rect.merge(floor_rects[i])

	return is_house_100_percent_submerged(union_rect, floor_rects)


## Ev Su Baskını Değerlendirmesi:
## Eğer dalga gelip giderse kırılmaz; sadece su bütün kat collisionlarına değerse ve 3 saniye durursa yıkılır.
func evaluate_house_hazard(house_rect: Rect2, floor_rects: Array[Rect2] = []) -> Dictionary:
	var result := {
		"is_massive_wave_impact": false,
		"all_collisions_touched": false,
		"dam_fill_ratio": 0.0,
		"particle_count": 0,
		"avg_vel": Vector2.ZERO
	}
	if objects.is_empty():
		return result

	var is_submerged: bool = false
	if not floor_rects.is_empty():
		is_submerged = are_all_floor_collisions_touched(floor_rects)
	else:
		is_submerged = is_house_100_percent_submerged(house_rect)

	result["all_collisions_touched"] = is_submerged
	result["dam_fill_ratio"] = 1.0 if is_submerged else get_rect_submersion_ratio(house_rect)

	return result
