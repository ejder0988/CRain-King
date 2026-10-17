extends CharacterBody2D
class_name CraneController

# ==============================================================================
# 1. PARAMETERS AND CONFIGURATION
# ==============================================================================
@export_group("Trolley Movement")
@export var trolley_speed: float = 360.0 ## Horizontal speed of the trolley along the boom (px/s)
@export var min_trolley_distance: float = 85.0 ## Minimum distance from mast (inner limit)
@export var max_trolley_distance: float = 780.0 ## Maximum distance along boom (outer tip limit)
@export var initial_trolley_distance: float = 380.0 ## Initial trolley starting distance

@export_group("Cable Length and Winch Control")
@export var min_rope_length: float = 120.0 ## Minimum cable length when fully retracted (UP position)
@export var max_rope_length: float = 580.0 ## Maximum cable length when fully extended (DOWN position)
@export var rope_winch_speed: float = 240.0 ## Winch retract/extend speed (px/s)
@export var rope_offset_y: float = 30.0 ## Vertical offset from TrolleyPivot where the rope hangs down
@export var rope_stiffness: float = 1.0 ## 1.0 = Inextensible steel wire constraint

@export_group("Aim & Swing Physics")
@export var swing_max_angle_deg: float = 72.0 ## Maximum swing angle in degrees (-72 to +72)
@export var pendulum_gravity: float = 850.0 ## Restoring force pulling rope back toward vertical
@export var pendulum_damping: float = 2.4 ## Smooth damping bringing rope to rest when not pushed
@export var swing_inertia_scale: float = 0.85 ## How strongly trolley push/movement accelerates the swing
@export var movement_swing_strength: float = 2.0 ## How strongly continuous trolley movement tilts the rope opposite to motion
@export var turn_swing_kick: float = 5.2 ## Swing angular impulse applied when crane turns (significantly amplified)
@export var lock_trolley_during_descent: bool = true ## Keep trolley fixed in place while claw is deployed
@export var auto_retract_after_landing: bool = true ## Auto-retract back to top after grab/landing
@export var landing_retract_delay: float = 0.5 ## Delay before auto-retracting if no object caught
@export var arrow_distance: float = 123.0 ## Distance of arrow from TrolleyPivot

@export_group("Aim Trajectory & Arrow Juice")
## Enable pulsing bob animation along the aim direction
@export var enable_arrow_bob: bool = true
## Bob distance in pixels along the aim vector
@export var arrow_bob_amplitude: float = 8.5
## Speed of the bob oscillation
@export var arrow_bob_speed: float = 7.0
## Enable velocity stretch and inertia tilt when swinging
@export var enable_arrow_stretch: bool = true
## Enable streaming dotted trajectory laser line
@export var enable_trajectory_dots: bool = true
## Enable smart target detection and color lock-on
@export var enable_target_lockon: bool = true
## Default aim color (electric cyan / neon blue)
@export var aim_color_normal: Color = Color(0.2, 0.9, 1.0, 1.0)
## Lock-on aim color when aligned with a crate (electric gold)
@export var aim_color_locked: Color = Color(1.0, 0.84, 0.12, 1.0)
## Aim color when carrying cargo to show drop trajectory (warm coral amber)
@export var aim_color_cargo: Color = Color(1.0, 0.55, 0.25, 1.0)

@export_group("Cargo Carrying & Release")
@export var cargo_carry_offset_y: float = 36.0 ## Vertical distance of cargo below payload center

@export_group("Visual Rendering")
@export var rope_segments: int = 12 ## Curve resolution segments when cable is slack
@export var mast_local_x: float = -28.0 ## Local X position of the mast center
@export var boom_local_y: float = -596.0 ## Local Y position of the trolley track along the boom

@export_group("Idle Shake Effect")
## Enable continuous subtle millimetric shake for designated sprites
@export var enable_idle_shake: bool = true
## Primary 3 sprites to apply the idle shake to (assignable in Inspector)
@export var shake_sprite_1: CanvasItem = null
@export var shake_sprite_2: CanvasItem = null
@export var shake_sprite_3: CanvasItem = null
## Additional sprites to include in the shake if needed
@export var extra_shake_sprites: Array[CanvasItem] = []
## Millimetric shake amplitude in pixels (X: horizontal, Y: vertical)
@export var shake_amplitude: Vector2 = Vector2(0.1, 0.05)
## Speed multiplier for the shake oscillation
@export var shake_speed_scale: float = 1.0

# ==============================================================================
# 2. ENUMS, SIGNALS AND CONSTANTS
# ==============================================================================
enum PayloadLevel {
	TOP,
	MIDDLE,
	BOTTOM
}

signal payload_level_changed(new_level: PayloadLevel)
signal cargo_picked_up(cargo: RigidBody2D)
signal cargo_released(cargo: RigidBody2D)

@export_group("Payload Height State")
@export var current_payload_level: PayloadLevel = PayloadLevel.TOP

# Rotation limits (-75 deg to +75 deg)
const MAX_PAYLOAD_ROTATION: float = deg_to_rad(75.0)
const MIN_PAYLOAD_ROTATION: float = deg_to_rad(-75.0)

# ==============================================================================
# 3. NODE REFERENCES
# ==============================================================================
@onready var visuals: Node2D = get_node_or_null("Visuals")
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var trolley_pivot: Marker2D = get_node_or_null("TrolleyPivot")
@onready var line_2d: Line2D = get_node_or_null("Line2D")
@onready var payload: RigidBody2D = get_node_or_null("Payload")
@onready var rope_ray_cast: RayCast2D = get_node_or_null("RopeRayCast")
@onready var payload_sprite: AnimatedSprite2D = _find_payload_sprite()
@onready var arrow: Sprite2D = _find_arrow()
@onready var crane_body_sprite: AnimatedSprite2D = _find_crane_body_sprite()
@onready var trolley_sprite: AnimatedSprite2D = _find_trolley_sprite()

# ==============================================================================
# 4. INTERNAL RUNTIME STATE
# ==============================================================================
var current_trolley_dist: float = 380.0
var target_rope_length: float = 120.0 ## Target cable length (min_rope_length or max_rope_length)
var current_rope_length: float = 120.0 ## Instantaneous cable length
var facing_direction: int = 1 ## 1: Right, -1: Left
var is_turning: bool = false ## Input lock during turn animation
var _is_turn_reversing: bool = false ## Tracks second half of flip turnaround
var _trolley_tween: Tween = null ## Smooth 1-second tween to opposite side on turn

var _shake_tweens: Array[Tween] = []
var _shaking_sprites: Array[CanvasItem] = []

var prev_trolley_pos: Vector2 = Vector2.ZERO
var trolley_velocity: Vector2 = Vector2.ZERO

var is_at_top: bool = true ## True when hook is at the top swinging
var swing_timer: float = 0.0 ## Oscillator time tracker
var current_swing_angle: float = 0.0 ## Current swing angle in radians
var swing_angular_velocity: float = 0.0 ## Current swing angular velocity in radians/sec
var prev_trolley_velocity: Vector2 = Vector2.ZERO ## Tracks trolley acceleration for inertial swing
var locked_aim_angle: float = 0.0 ## Angle locked when DOWN was pressed
var locked_aim_dir: Vector2 = Vector2.DOWN ## Direction vector locked when DOWN was pressed

var is_carrying_cargo: bool = false ## True when cargo crate is held by payload
var grabbed_body: RigidBody2D = null ## Currently grabbed cargo body
var can_release_cargo: bool = false ## True once initial descent down key is released after pickup
var prev_down_pressed: bool = false ## Tracks down key state for just_pressed detection
var just_released_cargo_this_frame: bool = false ## Prevents SPACE from triggering crane flip on release frame
var waiting_for_down_release: bool = false ## Requires releasing DOWN key after cargo drop before launching next descent

var is_descending: bool = false ## True when lowering winch with catch sequence
var has_resolved_landing: bool = false ## True once ground/cargo landing has resolved
var has_caught_object: bool = false ## True if hook contacted a grabbable object

var _base_arrow_scale: Vector2 = Vector2(2.75, 2.75)
var _arrow_anim_timer: float = 0.0
var _aim_trajectory: CraneAimTrajectory = null
var is_aim_locked_on: bool = false
var locked_target_node: Node2D = null
var _was_locked_on_prev_frame: bool = false


func _find_payload_sprite() -> AnimatedSprite2D:
	if has_node("Payload/PayloadAnimationSprite2d"):
		return get_node("Payload/PayloadAnimationSprite2d") as AnimatedSprite2D
	if has_node("Payload/AnimatedSprite2D"):
		return get_node("Payload/AnimatedSprite2D") as AnimatedSprite2D
	if payload:
		for child in payload.get_children():
			if child is AnimatedSprite2D:
				return child
	return null


func _find_arrow() -> Sprite2D:
	if has_node("TrolleyPivot/Arrow"):
		return get_node("TrolleyPivot/Arrow") as Sprite2D
	if trolley_pivot and trolley_pivot.has_node("Arrow"):
		return trolley_pivot.get_node("Arrow") as Sprite2D
	for child in get_children():
		if child.name == "TrolleyPivot":
			var a = child.get_node_or_null("Arrow")
			if a:
				return a as Sprite2D
	return null


func _find_crane_body_sprite() -> AnimatedSprite2D:
	if has_node("Visuals/CraneBodyAnimationSprite2D"):
		return get_node("Visuals/CraneBodyAnimationSprite2D") as AnimatedSprite2D
	if has_node("Visuals/CraneBodyAnimationSprite2d"):
		return get_node("Visuals/CraneBodyAnimationSprite2d") as AnimatedSprite2D
	if visuals:
		for child in visuals.get_children():
			if child is AnimatedSprite2D:
				return child
	return null


func _find_trolley_sprite() -> AnimatedSprite2D:
	if has_node("TrolleyPivot/CraneTrolleyAnimationSprite2d"):
		return get_node("TrolleyPivot/CraneTrolleyAnimationSprite2d") as AnimatedSprite2D
	if has_node("TrolleyPivot/CraneTrolleyAnimationSprite2D"):
		return get_node("TrolleyPivot/CraneTrolleyAnimationSprite2D") as AnimatedSprite2D
	if trolley_pivot:
		for child in trolley_pivot.get_children():
			if child is AnimatedSprite2D:
				return child
	return null


func _get_rope_origin() -> Vector2:
	if trolley_pivot:
		return trolley_pivot.global_position + Vector2(0.0, rope_offset_y)
	return global_position


func _ready() -> void:
	# Crane base is anchored to ground
	velocity = Vector2.ZERO
	
	current_trolley_dist = initial_trolley_distance
	target_rope_length = min_rope_length
	current_rope_length = min_rope_length
	is_at_top = true
	current_payload_level = PayloadLevel.TOP
	is_carrying_cargo = false
	grabbed_body = null

	# Fallback node lookups
	if not payload:
		payload = get_node_or_null("Payload") as RigidBody2D
	if not payload:
		payload = get_node_or_null("Rope") as RigidBody2D
	if not payload_sprite:
		payload_sprite = _find_payload_sprite()
	if not visuals:
		visuals = get_node_or_null("Visuals")
	if not animated_sprite:
		animated_sprite = get_node_or_null("AnimatedSprite2D")
	if not trolley_pivot:
		trolley_pivot = get_node_or_null("TrolleyPivot")
	if not trolley_pivot:
		trolley_pivot = Marker2D.new()
		trolley_pivot.name = "TrolleyPivot"
		add_child(trolley_pivot)
	if not line_2d:
		line_2d = get_node_or_null("Line2D")
		if not line_2d:
			line_2d = Line2D.new()
			line_2d.name = "Line2D"
			line_2d.width = 3.0
			line_2d.default_color = Color(0.2, 0.22, 0.25, 1.0)
			add_child(line_2d)
	if not arrow:
		arrow = _find_arrow()
	if arrow:
		_base_arrow_scale = arrow.scale
		arrow.modulate = aim_color_normal

	_aim_trajectory = get_node_or_null("AimTrajectory") as CraneAimTrajectory
	if not _aim_trajectory:
		_aim_trajectory = CraneAimTrajectory.new()
		_aim_trajectory.name = "AimTrajectory"
		add_child(_aim_trajectory)

	_update_trolley_position()
	prev_trolley_pos = trolley_pivot.global_position

	# CRITICAL: Payload lives independently in world space
	if payload:
		payload.top_level = true
		payload.global_position = _get_rope_origin() + Vector2(0, current_rope_length)
		payload.gravity_scale = 0.0 # Guided trajectory during aim, descent and carry
		payload.linear_damp = 0.0
		payload.angular_damp = 2.0
		payload.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
		
		# Enable collision reporting for object detection
		payload.contact_monitor = true
		payload.max_contacts_reported = 8
		if not payload.body_entered.is_connected(_on_payload_body_entered):
			payload.body_entered.connect(_on_payload_body_entered)

	# Crane mast beacon AnimatedSprite2D signal connections
	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")

	# Payload hook AnimatedSprite2D signal connections & default animation
	if payload_sprite:
		if not payload_sprite.animation_finished.is_connected(_on_payload_animation_finished):
			payload_sprite.animation_finished.connect(_on_payload_animation_finished)
		if payload_sprite.sprite_frames and payload_sprite.sprite_frames.has_animation("default"):
			payload_sprite.play("default")

	# Crane body AnimatedSprite2D signal connections & default animation
	if crane_body_sprite:
		if not crane_body_sprite.animation_finished.is_connected(_on_crane_body_animation_finished):
			crane_body_sprite.animation_finished.connect(_on_crane_body_animation_finished)
		if crane_body_sprite.sprite_frames and crane_body_sprite.sprite_frames.has_animation("default"):
			crane_body_sprite.play("default")

	# Crane trolley AnimatedSprite2D default animation
	if trolley_sprite:
		if trolley_sprite.sprite_frames and trolley_sprite.sprite_frames.has_animation("default"):
			trolley_sprite.play("default")

	# Initialize Arrow state: visible only when at the top
	if arrow:
		if arrow.position.length() > 0.0:
			arrow_distance = arrow.position.length()
		arrow.visible = is_at_top
		arrow.rotation = 0.0
		arrow.position = Vector2(0.0, rope_offset_y) + Vector2.DOWN * arrow_distance

	# Continuous subtle millimetric idle shake for designated sprites
	_init_idle_shake()


func _process(_delta: float) -> void:
	_update_rope_visual()


func _physics_process(delta: float) -> void:
	# 1. Cable trolley moves back and forth along the boom (carrying cargo anywhere player wants)
	_handle_trolley_movement(delta)

	# 2. Aim & swing oscillation when at the top, or angled descent trajectory when deployed
	if is_at_top:
		_update_swing_oscillation(delta)
	else:
		_update_deployed_trajectory(delta)

	# 3. Cargo release input (Space, E, or dedicated drop action)
	_handle_cargo_release_input()

	# 4. Cable up/down input control
	_handle_rope_winch_target(delta)

	# 5. Flip direction (Space) - allowed at top
	_handle_flip_input()

	# 6. Check cargo contact during descent
	_check_payload_descent_contact()

	# 7. Payload rotation limit [-75 deg, +75 deg]
	_apply_payload_rotation_limit(delta)

	# Enable releasing cargo once user has released the down key after grab
	if is_carrying_cargo and not can_release_cargo:
		var down_currently_pressed: bool = Input.is_action_pressed("rope_down") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
		if not down_currently_pressed:
			can_release_cargo = true

	# Reset one-frame release flag
	just_released_cargo_this_frame = false


# ==============================================================================
# 5. TROLLEY MOVEMENT (FORWARD / BACKWARD)
# ==============================================================================
func _get_horizontal_input() -> float:
	var axis: float = 0.0
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		axis -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		axis += 1.0
	return axis


func _handle_trolley_movement(delta: float) -> void:
	if is_turning:
		if delta > 0.0 and prev_trolley_pos != Vector2.ZERO and trolley_pivot:
			trolley_velocity = (trolley_pivot.global_position - prev_trolley_pos) / delta
		else:
			trolley_velocity = Vector2.ZERO
		if trolley_pivot:
			prev_trolley_pos = trolley_pivot.global_position
		return
	if not is_at_top and lock_trolley_during_descent:
		trolley_velocity = Vector2.ZERO
		if trolley_sprite and trolley_sprite.sprite_frames and trolley_sprite.sprite_frames.has_animation("default"):
			if trolley_sprite.animation != &"default":
				trolley_sprite.play("default")
		return

	var input_x: float = _get_horizontal_input()
	var actually_moved: bool = false

	if input_x != 0.0:
		var move_delta: float = input_x * float(facing_direction) * trolley_speed * delta
		var prev_dist: float = current_trolley_dist
		current_trolley_dist = clampf(current_trolley_dist + move_delta, min_trolley_distance, max_trolley_distance)
		actually_moved = absf(current_trolley_dist - prev_dist) > 0.001

	if actually_moved:
		if trolley_sprite and trolley_sprite.sprite_frames and trolley_sprite.sprite_frames.has_animation("move"):
			if trolley_sprite.animation != &"move" or not trolley_sprite.is_playing():
				trolley_sprite.play("move")
	else:
		if trolley_sprite and trolley_sprite.sprite_frames and trolley_sprite.sprite_frames.has_animation("default"):
			if trolley_sprite.animation != &"default":
				trolley_sprite.play("default")

	_update_trolley_position()

	if delta > 0.0 and prev_trolley_pos != Vector2.ZERO:
		trolley_velocity = (trolley_pivot.global_position - prev_trolley_pos) / delta
	prev_trolley_pos = trolley_pivot.global_position


func _update_trolley_position() -> void:
	if trolley_pivot:
		# Do not overwrite position.x while trolley tween is actively animating
		if _trolley_tween and _trolley_tween.is_running():
			trolley_pivot.position.y = boom_local_y
			return

		trolley_pivot.position = Vector2(
			mast_local_x + (current_trolley_dist * float(facing_direction)),
			boom_local_y
		)


# ==============================================================================
# 6. AIM, SWING & CARGO TRAJECTORY
# ==============================================================================
func _update_swing_oscillation(delta: float) -> void:
	if delta > 0.0:
		# Effective cable length for pendulum physics
		var eff_len: float = maxf(current_rope_length, 50.0)

		# Horizontal acceleration of the trolley (inertia pushes the pendulum)
		var trolley_accel_x: float = (trolley_velocity.x - prev_trolley_velocity.x) / delta
		trolley_accel_x = clampf(trolley_accel_x, -4000.0, 4000.0)

		# 1. Restoring gravity torque (pulls toward 0)
		var restoring: float = -(pendulum_gravity / eff_len) * sin(current_swing_angle)

		# 2. Damping torque (smoothly settles to rest when idle)
		var damping: float = -pendulum_damping * swing_angular_velocity

		# 3. Inertial push from trolley movement / acceleration (opposite to motion)
		var inertial: float = +(trolley_accel_x / eff_len) * cos(current_swing_angle) * swing_inertia_scale

		# 4. Continuous movement lag (rope and payload lag behind the moving trolley)
		var drag: float = +(trolley_velocity.x / eff_len) * movement_swing_strength * cos(current_swing_angle) * swing_inertia_scale

		var total_angular_accel: float = restoring + damping + inertial + drag

		# Semi-implicit Euler integration
		swing_angular_velocity += total_angular_accel * delta
		swing_angular_velocity = clampf(swing_angular_velocity, -10.5, 10.5)

		current_swing_angle += swing_angular_velocity * delta

		# Limit angle to maximum allowed swing
		var max_rad: float = deg_to_rad(swing_max_angle_deg)
		if absf(current_swing_angle) > max_rad:
			current_swing_angle = clampf(current_swing_angle, -max_rad, max_rad)
			swing_angular_velocity *= -0.3 # soft bounce against boom limit

		# Prevent tiny floating-point jitter when near 0 and nearly still
		if absf(current_swing_angle) < 0.001 and absf(swing_angular_velocity) < 0.005 and trolley_velocity.length_squared() < 1.0:
			current_swing_angle = 0.0
			swing_angular_velocity = 0.0

	prev_trolley_velocity = trolley_velocity

	_arrow_anim_timer += delta

	# 1. Target Lock-On Detection along current aim angle
	var aim_dir: Vector2 = Vector2.DOWN.rotated(current_swing_angle)
	var locked_node: Node2D = null
	if enable_target_lockon and not is_carrying_cargo:
		locked_node = _check_target_lockon(aim_dir)

	is_aim_locked_on = (locked_node != null)
	locked_target_node = locked_node

	if is_aim_locked_on and not _was_locked_on_prev_frame:
		_play_lockon_pop()
	_was_locked_on_prev_frame = is_aim_locked_on

	# Determine active aim color
	var target_color: Color = aim_color_normal
	if is_carrying_cargo:
		target_color = aim_color_cargo
	elif is_aim_locked_on:
		target_color = aim_color_locked

	# 2. Update Arrow: visible, bobbing, inertia stretch and glowing
	if arrow:
		arrow.visible = true

		# Bobbing along aim vector
		var bob_speed: float = arrow_bob_speed * (1.6 if is_aim_locked_on else 1.0)
		var dynamic_dist: float = arrow_distance
		if enable_arrow_bob:
			dynamic_dist += sin(_arrow_anim_timer * bob_speed) * arrow_bob_amplitude

		arrow.position = Vector2(0.0, rope_offset_y) + aim_dir * dynamic_dist

		# Velocity inertia stretch & tilt
		if enable_arrow_stretch:
			var stretch: float = clampf(absf(swing_angular_velocity) * 0.065, 0.0, 0.35)
			var pulse_scale: float = 1.0 + (0.08 if is_aim_locked_on else 0.03) * sin(_arrow_anim_timer * 14.0)
			arrow.scale.y = _base_arrow_scale.y * (1.0 + stretch) * pulse_scale
			arrow.scale.x = _base_arrow_scale.x * (1.0 - stretch * 0.45) * pulse_scale
			arrow.rotation = current_swing_angle - swing_angular_velocity * 0.035
		else:
			arrow.rotation = current_swing_angle

		# Smooth modulate transition to active aim color
		arrow.modulate = arrow.modulate.lerp(target_color, 12.0 * delta)

	# 3. Update Trajectory Dotted Laser Beam & Target Reticle
	if _aim_trajectory:
		var rope_origin: Vector2 = _get_rope_origin()
		var target_pos: Vector2 = locked_target_node.global_position if is_aim_locked_on else (rope_origin + aim_dir * max_rope_length)
		_aim_trajectory.update_aim(
			arrow.global_position if arrow else rope_origin,
			aim_dir,
			max_rope_length,
			is_aim_locked_on,
			target_pos,
			target_color,
			is_at_top and enable_trajectory_dots
		)

	# 4. Update Payload position and rotation to swing in unison
	if payload and trolley_pivot:
		var swing_dir: Vector2 = Vector2.DOWN.rotated(current_swing_angle)
		payload.global_position = _get_rope_origin() + swing_dir * current_rope_length
		payload.rotation = current_swing_angle
		payload.linear_velocity = Vector2.ZERO
		payload.angular_velocity = 0.0

	# 3. If carrying cargo, it remains attached under the payload at the top
	if is_carrying_cargo and grabbed_body and is_instance_valid(grabbed_body):
		grabbed_body.global_position = payload.global_position + Vector2.DOWN.rotated(current_swing_angle) * cargo_carry_offset_y
		grabbed_body.rotation = current_swing_angle
		grabbed_body.linear_velocity = Vector2.ZERO
		grabbed_body.angular_velocity = 0.0

	# Keep level at TOP
	if current_payload_level != PayloadLevel.TOP:
		current_payload_level = PayloadLevel.TOP
		payload_level_changed.emit(current_payload_level)


func _check_target_lockon(aim_dir: Vector2) -> Node2D:
	var rope_orig: Vector2 = _get_rope_origin()
	var best_target: Node2D = null
	var min_perp: float = 62.0 # Catch zone width threshold

	var tree := get_tree()
	if not tree:
		return null

	var candidates: Array[Node] = []
	for c in tree.get_nodes_in_group("cargo"):
		if not candidates.has(c):
			candidates.append(c)
	for g in tree.get_nodes_in_group("grabbable"):
		if not candidates.has(g):
			candidates.append(g)

	# Proximity check along aim ray
	for node in candidates:
		if node is Node2D and node != payload and node != grabbed_body and is_instance_valid(node):
			var to_node: Vector2 = node.global_position - rope_orig
			var proj: float = to_node.dot(aim_dir)
			# Only check objects in front along the aim vector within winch reach
			if proj > 60.0 and proj <= max_rope_length + 65.0:
				var perp: float = (to_node - aim_dir * proj).length()
				if perp < min_perp:
					min_perp = perp
					best_target = node as Node2D

	return best_target


func _play_lockon_pop() -> void:
	if not arrow:
		return
	var pop := create_tween()
	pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(arrow, "scale", _base_arrow_scale * 1.3, 0.08)
	pop.tween_property(arrow, "scale", _base_arrow_scale, 0.12)


func _launch_aimed_descent() -> void:
	is_at_top = false
	locked_aim_angle = current_swing_angle
	locked_aim_dir = Vector2.DOWN.rotated(locked_aim_angle)

	# Launch burst juice effect on arrow
	if arrow:
		var burst_tween := create_tween().set_parallel(true)
		burst_tween.tween_property(arrow, "position", arrow.position + locked_aim_dir * 36.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		burst_tween.tween_property(arrow, "scale", _base_arrow_scale * 1.35, 0.12)
		burst_tween.tween_property(arrow, "modulate:a", 0.0, 0.12)
		burst_tween.chain().tween_callback(func():
			if arrow:
				arrow.visible = false
				arrow.modulate.a = 1.0
				arrow.scale = _base_arrow_scale
		)
	if _aim_trajectory:
		_aim_trajectory.play_launch_burst()

	target_rope_length = max_rope_length
	_start_payload_descent()


func _update_deployed_trajectory(delta: float) -> void:
	# Arrow and trajectory are strictly inactive while deployed
	if arrow and arrow.visible and not is_at_top:
		arrow.visible = false
	if _aim_trajectory and _aim_trajectory.is_active:
		_aim_trajectory.is_active = false

	# Interpolate current cable length toward target at winch speed
	if current_rope_length != target_rope_length:
		current_rope_length = move_toward(current_rope_length, target_rope_length, rope_winch_speed * delta)

	# Update payload level tracking (TOP, MIDDLE, BOTTOM)
	if current_rope_length <= min_rope_length + 4.0:
		if current_payload_level != PayloadLevel.TOP:
			current_payload_level = PayloadLevel.TOP
			payload_level_changed.emit(current_payload_level)
	elif current_rope_length >= max_rope_length - 4.0:
		if current_payload_level != PayloadLevel.BOTTOM:
			current_payload_level = PayloadLevel.BOTTOM
			payload_level_changed.emit(current_payload_level)

	# Guide payload along the locked aim direction
	if payload and trolley_pivot:
		var target_pos: Vector2 = _get_rope_origin() + locked_aim_dir * current_rope_length
		payload.global_position = target_pos
		payload.rotation = locked_aim_angle

		if current_rope_length < target_rope_length:
			payload.linear_velocity = locked_aim_dir * rope_winch_speed
		elif current_rope_length > target_rope_length:
			payload.linear_velocity = - locked_aim_dir * rope_winch_speed
		else:
			payload.linear_velocity = Vector2.ZERO

	# Move grabbed cargo with payload while deployed
	if is_carrying_cargo and grabbed_body and is_instance_valid(grabbed_body):
		grabbed_body.global_position = payload.global_position + Vector2.DOWN.rotated(payload.rotation) * cargo_carry_offset_y
		grabbed_body.rotation = payload.rotation
		grabbed_body.linear_velocity = payload.linear_velocity
		grabbed_body.angular_velocity = 0.0

	# Check return to top
	if current_rope_length <= min_rope_length + 4.0 and target_rope_length == min_rope_length:
		current_rope_length = min_rope_length
		is_at_top = true
		is_descending = false
		has_resolved_landing = false
		current_payload_level = PayloadLevel.TOP
		if arrow:
			arrow.visible = true
			arrow.scale = _base_arrow_scale * 0.2
			var pop_tween := create_tween()
			pop_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pop_tween.tween_property(arrow, "scale", _base_arrow_scale, 0.22)
		if _aim_trajectory:
			_aim_trajectory.play_reset_pop()

		# When returning to top, ensure default animation is playing
		if payload_sprite and payload_sprite.sprite_frames and payload_sprite.sprite_frames.has_animation("default"):
			if payload_sprite.animation == &"catch_start" or payload_sprite.animation == &"catch_loop":
				payload_sprite.play("default")

		# Resume swinging seamlessly from current angle
		current_swing_angle = locked_aim_angle
		swing_angular_velocity = 0.0


# ==============================================================================
# 7. WINCH TARGET & INPUT CONTROL
# ==============================================================================
func _handle_rope_winch_target(_delta: float) -> void:
	if is_turning:
		return

	# UP input: winch back up to the top
	var pressed_up: bool = Input.is_action_just_pressed("rope_up") or Input.is_action_pressed("rope_up") \
		or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	if pressed_up:
		target_rope_length = min_rope_length
		if is_descending:
			is_descending = false
			has_resolved_landing = false
			if not is_carrying_cargo and payload_sprite:
				var anim: StringName = payload_sprite.animation
				if anim == &"catch_start" or anim == &"catch_loop":
					if payload_sprite.sprite_frames and payload_sprite.sprite_frames.has_animation("default"):
						payload_sprite.play("default")

	# DOWN input: release held cargo if carrying, otherwise launch aimed descent
	var is_down_pressed: bool = Input.is_action_pressed("rope_down") \
		or Input.is_key_pressed(KEY_S) \
		or Input.is_key_pressed(KEY_DOWN)

	if not is_down_pressed:
		waiting_for_down_release = false

	if waiting_for_down_release or just_released_cargo_this_frame:
		prev_down_pressed = is_down_pressed
		return

	var is_down_just_pressed: bool = Input.is_action_just_pressed("rope_down") \
		or (is_down_pressed and not prev_down_pressed)

	if is_down_just_pressed:
		if is_carrying_cargo and can_release_cargo:
			just_released_cargo_this_frame = true
			waiting_for_down_release = true
			_release_cargo()
		elif is_at_top and not is_carrying_cargo:
			_launch_aimed_descent()
		elif not is_at_top:
			target_rope_length = max_rope_length

	prev_down_pressed = is_down_pressed


func _start_payload_descent() -> void:
	if not payload_sprite or not payload_sprite.sprite_frames:
		return
	if is_turning:
		return
	if is_descending and not has_resolved_landing:
		return

	is_descending = true
	has_resolved_landing = false

	# If carrying cargo, maintain hold pose while descending to place it
	if is_carrying_cargo:
		if payload_sprite.sprite_frames.has_animation("hold"):
			payload_sprite.play("hold")
	else:
		has_caught_object = false
		if payload_sprite.sprite_frames.has_animation("catch_start"):
			payload_sprite.play("catch_start")
		elif payload_sprite.sprite_frames.has_animation("catch"):
			payload_sprite.play("catch")


func _check_payload_descent_contact() -> void:
	if not payload_sprite or not payload:
		return
	if not is_descending or has_resolved_landing:
		return

	# 1. Contact with grabbable object
	if _is_touching_grabbable_object():
		has_caught_object = true
		_resolve_landing()
		return

	# 2. Reached bottom rope limit
	if current_rope_length >= max_rope_length - 4.0:
		_resolve_landing()
		return

	# 3. Payload grounded on static floor or another body
	if payload.contact_monitor and payload.get_contact_count() > 0:
		_resolve_landing()
		return


func _resolve_landing() -> void:
	if has_resolved_landing:
		return
	has_resolved_landing = true
	is_descending = false

	# CASE A: Currently carrying cargo and lowered onto surface -> Release/Deposit cargo
	if is_carrying_cargo:
		_release_cargo()
		if auto_retract_after_landing and is_inside_tree():
			var tree := get_tree()
			if tree:
				tree.create_timer(landing_retract_delay).timeout.connect(func():
					if not is_at_top:
						target_rope_length = min_rope_length
				)
		return

	# CASE B: Empty hook landing to catch new cargo
	var caught: bool = has_caught_object or _is_touching_grabbable_object()
	if not payload_sprite or not payload_sprite.sprite_frames:
		return

	if caught:
		grabbed_body = _find_touching_grabbable_body()
		if grabbed_body:
			is_carrying_cargo = true
			can_release_cargo = false
			grabbed_body.set_deferred("freeze", true)
			if payload:
				payload.add_collision_exception_with(grabbed_body)
			cargo_picked_up.emit(grabbed_body)

		if payload_sprite.sprite_frames.has_animation("hold"):
			payload_sprite.play("hold")
		elif payload_sprite.sprite_frames.has_animation("default"):
			payload_sprite.play("default")

		# Auto-retract back to top with the caught cargo
		if auto_retract_after_landing and is_inside_tree():
			var tree := get_tree()
			if tree:
				tree.create_timer(0.3).timeout.connect(func():
					if not is_at_top:
						target_rope_length = min_rope_length
				)
	else:
		if payload_sprite.sprite_frames.has_animation("default"):
			payload_sprite.play("default")
		if auto_retract_after_landing and is_inside_tree():
			var tree := get_tree()
			if tree:
				tree.create_timer(landing_retract_delay).timeout.connect(func():
					if not is_at_top:
						target_rope_length = min_rope_length
				)


# ==============================================================================
# 8. CARGO RELEASE MECHANISM (DOWN KEY ONLY)
# ==============================================================================
func _handle_cargo_release_input() -> void:
	if not is_carrying_cargo:
		return
	if is_turning:
		return
	if not can_release_cargo:
		return

	# Cargo release is triggered ONLY by the DOWN key (S / Down Arrow / rope_down)
	var is_down_just_pressed: bool = (
		(InputMap.has_action("rope_down") and Input.is_action_just_pressed("rope_down"))
		or Input.is_key_pressed(KEY_S)
		or Input.is_key_pressed(KEY_DOWN)
	)

	if is_down_just_pressed and not waiting_for_down_release:
		just_released_cargo_this_frame = true
		waiting_for_down_release = true
		_release_cargo()


func _release_cargo() -> void:
	if not is_carrying_cargo or not grabbed_body or not is_instance_valid(grabbed_body):
		is_carrying_cargo = false
		grabbed_body = null
		has_caught_object = false
		return

	var released_ref: RigidBody2D = grabbed_body

	# 1. Unfreeze physics body so it falls under normal gravity
	released_ref.set_deferred("freeze", false)

	# 2. Inherit crane velocity + slight downward release momentum
	var release_velocity: Vector2 = payload.linear_velocity
	if is_at_top:
		# If swinging at top, inherit tangential release impulse
		var swing_dir: Vector2 = Vector2.DOWN.rotated(current_swing_angle)
		var angular_vel: float = swing_angular_velocity
		var tangent_dir: Vector2 = Vector2(-swing_dir.y, swing_dir.x)
		release_velocity = tangent_dir * (angular_vel * current_rope_length) + trolley_velocity + Vector2(0, 30.0)
	else:
		release_velocity += Vector2(0, 30.0)

	grabbed_body.linear_velocity = release_velocity
	grabbed_body.angular_velocity = payload.angular_velocity

	# Remove collision exception
	if payload:
		payload.remove_collision_exception_with(grabbed_body)

	# 3. Clear grabbed reference and carrying state
	grabbed_body = null
	is_carrying_cargo = false
	has_caught_object = false
	can_release_cargo = false
	waiting_for_down_release = true
	cargo_released.emit(released_ref)

	# Open hook back to default animation
	if payload_sprite and payload_sprite.sprite_frames:
		if payload_sprite.sprite_frames.has_animation("default"):
			payload_sprite.play("default")


func _on_payload_body_entered(body: Node) -> void:
	if body is RigidBody2D and body != payload and not is_carrying_cargo:
		has_caught_object = true
		if is_descending and not has_resolved_landing:
			call_deferred("_resolve_landing")
	elif body is StaticBody2D:
		if is_descending and not has_resolved_landing:
			call_deferred("_resolve_landing")


func _is_touching_grabbable_object() -> bool:
	if not payload:
		return false
	if is_carrying_cargo:
		return false

	# 1. Physics collision contacts
	if payload.contact_monitor:
		for b in payload.get_colliding_bodies():
			if b is RigidBody2D and b != payload and b != grabbed_body:
				return true
			if b.is_in_group("cargo") or b.is_in_group("grabbable"):
				return true

	# 2. Proximity check to CargoCrate or grabbable objects in scene
	var root_node: Node = get_parent()
	if root_node:
		var crate: RigidBody2D = root_node.get_node_or_null("CargoCrate") as RigidBody2D
		if crate and crate != grabbed_body:
			var diff: Vector2 = crate.global_position - payload.global_position
			if absf(diff.x) <= 60.0 and diff.y >= -20.0 and diff.y <= 85.0:
				return true

	if is_inside_tree():
		var tree := get_tree()
		if tree:
			for node in tree.get_nodes_in_group("cargo"):
				if node is Node2D and node != payload and node != grabbed_body:
					var diff: Vector2 = node.global_position - payload.global_position
					if absf(diff.x) <= 60.0 and diff.y >= -20.0 and diff.y <= 85.0:
						return true

	return false


func _find_touching_grabbable_body() -> RigidBody2D:
	if not payload:
		return null
	if payload.contact_monitor:
		for b in payload.get_colliding_bodies():
			if b is RigidBody2D and b != payload:
				return b
	var root_node: Node = get_parent()
	if root_node:
		var crate: RigidBody2D = root_node.get_node_or_null("CargoCrate") as RigidBody2D
		if crate:
			var diff: Vector2 = crate.global_position - payload.global_position
			if absf(diff.x) <= 60.0 and diff.y >= -20.0 and diff.y <= 85.0:
				return crate
	if is_inside_tree():
		var tree := get_tree()
		if tree:
			for node in tree.get_nodes_in_group("cargo"):
				if node is RigidBody2D and node != payload and node != grabbed_body:
					var diff: Vector2 = node.global_position - payload.global_position
					if absf(diff.x) <= 60.0 and diff.y >= -20.0 and diff.y <= 85.0:
						return node
			for node in tree.get_nodes_in_group("grabbable"):
				if node is RigidBody2D and node != payload and node != grabbed_body:
					var diff: Vector2 = node.global_position - payload.global_position
					if absf(diff.x) <= 60.0 and diff.y >= -20.0 and diff.y <= 85.0:
						return node
	return null


func _is_payload_touching_surface() -> bool:
	if not payload:
		return false
	if payload.contact_monitor and payload.get_contact_count() > 0:
		return true
	return _is_touching_grabbable_object()


func _on_payload_animation_finished() -> void:
	if not payload_sprite or not payload_sprite.sprite_frames:
		return

	var current_anim: StringName = payload_sprite.animation

	if current_anim == &"catch_start":
		# When catch_start finishes, immediately transition to catch_loop
		if is_descending and not has_resolved_landing:
			if payload_sprite.sprite_frames.has_animation("catch_loop"):
				payload_sprite.play("catch_loop")
			elif payload_sprite.sprite_frames.has_animation("catch"):
				payload_sprite.play("catch")
		elif not is_descending:
			if payload_sprite.sprite_frames.has_animation("default"):
				payload_sprite.play("default")
	elif current_anim == &"hold":
		is_descending = false
		# As requested: after hold animation finishes, immediately play default animation
		if payload_sprite.sprite_frames.has_animation("default"):
			payload_sprite.play("default")
		if auto_retract_after_landing and not is_at_top:
			target_rope_length = min_rope_length
	elif current_anim == &"catch":
		_resolve_landing()


# ==============================================================================
# 9. DIRECTION FLIP (SPACE)
# ==============================================================================
func _handle_flip_input() -> void:
	if not is_at_top:
		return
	if just_released_cargo_this_frame:
		return
	var pressed_flip: bool = Input.is_action_just_pressed("crane_flip") or Input.is_key_pressed(KEY_SPACE)
	if pressed_flip and not is_turning:
		_start_turn()


func _start_turn() -> void:
	is_turning = true
	_is_turn_reversing = false

	# Apply turn swing impulse (rope swings dynamically as the crane flips)
	swing_angular_velocity += -float(facing_direction) * turn_swing_kick

	# Smoothly tween trolley to the exact opposite position across mast within 1 second
	if _trolley_tween and _trolley_tween.is_valid():
		_trolley_tween.kill()

	if trolley_pivot:
		var current_offset: float = trolley_pivot.position.x - mast_local_x
		var target_x: float = mast_local_x - current_offset

		if trolley_sprite and trolley_sprite.sprite_frames and trolley_sprite.sprite_frames.has_animation("move"):
			trolley_sprite.play("move")

		_trolley_tween = create_tween()
		_trolley_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_trolley_tween.tween_property(trolley_pivot, "position:x", target_x, 0.4)
		_trolley_tween.tween_callback(func():
			if trolley_sprite and trolley_sprite.sprite_frames and trolley_sprite.sprite_frames.has_animation("default"):
				trolley_sprite.play("default")
		)

	# 1. Play crane body turn animation forward
	if crane_body_sprite and crane_body_sprite.sprite_frames and crane_body_sprite.sprite_frames.has_animation("turn"):
		crane_body_sprite.play("turn")
		if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("turn"):
			animated_sprite.play("turn")
	elif animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("turn"):
		animated_sprite.play("turn")
	else:
		_run_procedural_turn()


func _on_crane_body_animation_finished() -> void:
	if not is_turning:
		return

	if not _is_turn_reversing:
		# --- Phase 1 complete: Forward turn finished, flip X and reverse ---
		_is_turn_reversing = true
		facing_direction *= -1
		_apply_flip_state(float(facing_direction))
		# Additional swing impulse as the crane boom whips around
		swing_angular_velocity += -float(facing_direction) * (turn_swing_kick * 0.45)

		if crane_body_sprite and crane_body_sprite.sprite_frames and crane_body_sprite.sprite_frames.has_animation("turn"):
			var last_frame: int = crane_body_sprite.sprite_frames.get_frame_count("turn") - 1
			crane_body_sprite.frame = last_frame
			crane_body_sprite.play_backwards("turn")
		else:
			_complete_turn()

		if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("turn"):
			var beacon_last: int = animated_sprite.sprite_frames.get_frame_count("turn") - 1
			animated_sprite.frame = beacon_last
			animated_sprite.play_backwards("turn")
	else:
		# --- Phase 2 complete: Reverse turn reached start, switch to default ---
		_complete_turn()


func _run_procedural_turn() -> void:
	var target_scale_x: float = -1.0 if facing_direction == 1 else 1.0
	var tween: Tween = create_tween()
	if visuals:
		tween.tween_property(visuals, "scale:x", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func():
			facing_direction *= -1
			_apply_flip_state(float(facing_direction))
		)
		tween.tween_property(visuals, "scale:x", target_scale_x, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_on_turn_completed)
	else:
		facing_direction *= -1
		_apply_flip_state(float(facing_direction))
		_complete_turn()


func _on_animation_finished() -> void:
	# Fallback if crane_body_sprite is not present
	if not crane_body_sprite and is_turning and animated_sprite and animated_sprite.animation == "turn":
		_complete_turn()


func _complete_turn() -> void:
	is_turning = false
	_is_turn_reversing = false

	if _trolley_tween and _trolley_tween.is_running():
		_trolley_tween.kill()

	_update_trolley_position()

	if crane_body_sprite and crane_body_sprite.sprite_frames and crane_body_sprite.sprite_frames.has_animation("default"):
		crane_body_sprite.play("default")

	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")

	if trolley_sprite and trolley_sprite.sprite_frames and trolley_sprite.sprite_frames.has_animation("default"):
		trolley_sprite.play("default")


func _apply_flip_state(dir_x: float) -> void:
	if visuals:
		visuals.scale.x = dir_x
	if animated_sprite and not visuals:
		animated_sprite.scale.x = dir_x

	_update_trolley_position()


func _on_turn_completed() -> void:
	_complete_turn()


# ==============================================================================
# 10. ROTATION CLAMP & CABLE VISUAL RENDERING
# ==============================================================================
func _apply_payload_rotation_limit(_delta: float) -> void:
	if not payload:
		return

	# Strictly clamp rotation between -75 degrees and +75 degrees
	if payload.rotation > MAX_PAYLOAD_ROTATION:
		payload.rotation = MAX_PAYLOAD_ROTATION
		if payload.angular_velocity > 0.0:
			payload.angular_velocity = 0.0
	elif payload.rotation < MIN_PAYLOAD_ROTATION:
		payload.rotation = MIN_PAYLOAD_ROTATION
		if payload.angular_velocity < 0.0:
			payload.angular_velocity = 0.0


func _update_rope_visual() -> void:
	if not line_2d or not trolley_pivot or not payload:
		return

	line_2d.clear_points()
	var start_pos: Vector2 = line_2d.to_local(_get_rope_origin())
	var end_pos: Vector2 = line_2d.to_local(payload.global_position)
	line_2d.add_point(start_pos)
	line_2d.add_point(end_pos)


# ==============================================================================
# 11. CONTINUOUS IDLE SHAKE (TWEEN)
# ==============================================================================
func _init_idle_shake() -> void:
	if not enable_idle_shake:
		return

	var targets: Array[CanvasItem] = []
	if shake_sprite_1 and is_instance_valid(shake_sprite_1):
		targets.append(shake_sprite_1)
	if shake_sprite_2 and is_instance_valid(shake_sprite_2):
		targets.append(shake_sprite_2)
	if shake_sprite_3 and is_instance_valid(shake_sprite_3):
		targets.append(shake_sprite_3)

	for extra in extra_shake_sprites:
		if extra and is_instance_valid(extra) and not targets.has(extra):
			targets.append(extra)

	# If no sprites were manually assigned in Inspector, automatically check for children named ShakeSprite1/2/3
	if targets.is_empty():
		for name_pattern in ["ShakeSprite1", "ShakeSprite2", "ShakeSprite3"]:
			var found := find_child(name_pattern, true, false) as CanvasItem
			if found:
				targets.append(found)

	for i in range(targets.size()):
		add_shake_sprite(targets[i])


func add_shake_sprite(item: CanvasItem) -> void:
	if not item or not is_instance_valid(item):
		return
	if _shaking_sprites.has(item):
		return
	_shaking_sprites.append(item)
	_start_sprite_idle_shake(item, _shaking_sprites.size() - 1)


func _start_sprite_idle_shake(target: CanvasItem, index: int) -> void:
	if not is_instance_valid(target):
		return

	# If the item has an 'offset' property (Sprite2D, AnimatedSprite2D), animating offset
	# prevents modifying 'position', keeping transforms and hierarchy 100% stable.
	var use_offset: bool = "offset" in target
	var base_vec: Vector2 = target.offset if use_offset else target.position
	var prop_name: String = "offset" if use_offset else "position"

	var tween: Tween = create_tween().set_loops()
	_shake_tweens.append(tween)

	# Phase desynchronization so the 3 sprites move organically rather than in robotic lockstep
	var phase: float = float(index) * 2.094 # ~120 degrees apart
	var s1 := Vector2(cos(phase) * shake_amplitude.x * 0.75, sin(phase) * shake_amplitude.y * 0.85)
	var s2 := Vector2(-sin(phase + 1.2) * shake_amplitude.x * 0.85, cos(phase + 0.9) * shake_amplitude.y * 0.7)
	var s3 := Vector2(cos(phase + 2.5) * shake_amplitude.x * 0.6, -sin(phase + 1.8) * shake_amplitude.y * 0.9)
	var s4 := Vector2(-cos(phase + 3.8) * shake_amplitude.x * 0.8, -cos(phase + 3.1) * shake_amplitude.y * 0.6)

	var step_dur: float = 0.24 / maxf(shake_speed_scale, 0.05)

	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target, prop_name, base_vec + s1, step_dur * 1.0)
	tween.tween_property(target, prop_name, base_vec + s2, step_dur * 1.15)
	tween.tween_property(target, prop_name, base_vec + s3, step_dur * 0.95)
	tween.tween_property(target, prop_name, base_vec + s4, step_dur * 1.1)
	tween.tween_property(target, prop_name, base_vec, step_dur * 1.0)
