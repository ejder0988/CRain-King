extends RigidBody2D
class_name HouseDebris

## HouseDebris: Physical debris pieces spawned when a house collapses.
## Interacts physically with water particles (Layer 1/Mask 1) and features realistic fluid buoyancy & floating.

enum DebrisType {
	WOOD_PLANK,
	BRICK,
	ROOF_TILE,
	RUBBLE
}

@export var debris_type: DebrisType = DebrisType.WOOD_PLANK
@export var buoyancy_force: float = 480.0
@export var water_drag: float = 3.5
@export var angular_drag: float = 4.0

var _fluid_water: FluidWater = null
var _time_alive: float = 0.0
var _max_lifetime: float = 45.0
var _is_in_water: bool = false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	contact_monitor = true
	max_contacts_reported = 3
	gravity_scale = 1.0

	_find_fluid_water()
	_setup_visual()


func _find_fluid_water() -> void:
	if is_inside_tree():
		var found = get_tree().get_first_node_in_group("fluid_water")
		if found is FluidWater:
			_fluid_water = found as FluidWater
		else:
			var root := get_tree().current_scene
			if root:
				var fw := root.find_child("FluidWater", true, false)
				if fw is FluidWater:
					_fluid_water = fw as FluidWater


func _setup_visual() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)

	var w: int = 10
	var h: int = 6
	var base_col: Color = Color(0.65, 0.45, 0.25) # Wood

	match debris_type:
		DebrisType.WOOD_PLANK:
			w = randi_range(12, 18)
			h = randi_range(4, 6)
			base_col = Color(0.65, 0.42, 0.22).lerp(Color(0.5, 0.3, 0.15), randf() * 0.4)
			mass = 0.35
		DebrisType.BRICK:
			w = randi_range(8, 12)
			h = randi_range(6, 8)
			base_col = Color(0.75, 0.32, 0.22).lerp(Color(0.6, 0.25, 0.18), randf() * 0.3)
			mass = 0.55
		DebrisType.ROOF_TILE:
			w = randi_range(9, 14)
			h = randi_range(5, 7)
			base_col = Color(0.35, 0.4, 0.48).lerp(Color(0.25, 0.3, 0.38), randf() * 0.4)
			mass = 0.45
		DebrisType.RUBBLE:
			w = randi_range(6, 10)
			h = randi_range(6, 10)
			base_col = Color(0.5, 0.5, 0.5).lerp(Color(0.38, 0.38, 0.4), randf() * 0.3)
			mass = 0.65

	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(base_col)

	# Dark outline/border for pixel-art consistency
	var border_col := base_col.darkened(0.35)
	for x in range(w):
		img.set_pixel(x, 0, border_col)
		img.set_pixel(x, h - 1, border_col)
	for y in range(h):
		img.set_pixel(0, y, border_col)
		img.set_pixel(w - 1, y, border_col)

	sprite.texture = ImageTexture.create_from_image(img)

	# Setup collision shape if not already defined
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not col:
		col = CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(w, h)
		col.shape = rect
		add_child(col)


func _physics_process(delta: float) -> void:
	_time_alive += delta
	if _time_alive > _max_lifetime or global_position.y > 2500.0:
		queue_free()
		return

	if not _fluid_water or not is_instance_valid(_fluid_water):
		_find_fluid_water()
		if not _fluid_water:
			return

	# Query water surface height at this piece's X position
	var water_y: float = _fluid_water.get_water_surface_y_in_range(
		global_position.x - 12.0,
		global_position.x + 12.0,
		1
	)

	# Check if submerged or touching water
	if global_position.y >= water_y - 4.0:
		_is_in_water = true
		var depth: float = clampf((global_position.y - water_y) / 20.0, 0.2, 2.5)

		# 1. Buoyancy: Upward counter-force to gravity based on submergence depth
		var upward_accel: float = (buoyancy_force * depth) / maxf(mass, 0.1)
		linear_velocity.y -= upward_accel * delta

		# 2. Fluid drag: Water dampens fast motion and rapid spinning
		linear_velocity.x = move_toward(linear_velocity.x, 0.0, absf(linear_velocity.x) * water_drag * delta)
		linear_velocity.y = move_toward(linear_velocity.y, 0.0, absf(linear_velocity.y) * 1.5 * delta)
		angular_velocity = move_toward(angular_velocity, 0.0, absf(angular_velocity) * angular_drag * delta)

		# 3. Gentle wave bobbing on water surface
		var bob: float = sin(Time.get_ticks_msec() * 0.004 + global_position.x * 0.1) * 8.0
		linear_velocity.y += bob * delta
	else:
		_is_in_water = false
