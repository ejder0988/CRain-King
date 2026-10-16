extends CharacterBody2D
class_name CraneController

# ==============================================================================
# 1. PARAMETERS AND CONFIGURATION
# ==============================================================================
@export_group("Trolley Movement")
@export var trolley_speed: float = 360.0          ## Horizontal speed of the trolley along the boom (px/s)
@export var min_trolley_distance: float = 85.0    ## Minimum distance from mast (inner limit)
@export var max_trolley_distance: float = 780.0   ## Maximum distance along boom (outer tip limit)
@export var initial_trolley_distance: float = 380.0 ## Initial trolley starting distance

@export_group("Cable Length and Winch Control")
@export var min_rope_length: float = 120.0        ## Minimum cable length when fully retracted (UP position)
@export var max_rope_length: float = 580.0        ## Maximum cable length when fully extended (DOWN position)
@export var rope_winch_speed: float = 240.0       ## Winch retract/extend speed (px/s)
@export var rope_stiffness: float = 1.0           ## 1.0 = Inextensible steel wire constraint
@export var pendulum_damping: float = 0.999       ## Atmospheric damping for pendulum swing

@export_group("Visual Rendering")
@export var rope_segments: int = 12               ## Curve resolution segments when cable is slack
@export var mast_local_x: float = -28.0           ## Local X position of the mast center
@export var boom_local_y: float = -596.0          ## Local Y position of the trolley track along the boom

# ==============================================================================
# 2. NODE REFERENCES
# ==============================================================================
@onready var visuals: Node2D = get_node_or_null("Visuals")
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var trolley_pivot: Marker2D = get_node_or_null("TrolleyPivot")
@onready var line_2d: Line2D = get_node_or_null("Line2D")
@onready var payload: RigidBody2D = get_node_or_null("Payload")
@onready var rope_ray_cast: RayCast2D = get_node_or_null("RopeRayCast")

# ==============================================================================
# 3. INTERNAL STATE VARIABLES
# ==============================================================================
var current_trolley_dist: float = 380.0
var target_rope_length: float = 260.0             ## Player target length (min or max)
var current_rope_length: float = 260.0            ## Instantaneous cable length (interpolates toward target)
var facing_direction: int = 1                     ## 1: Right, -1: Left
var is_turning: bool = false                      ## Input lock during turn animation

var prev_trolley_pos: Vector2 = Vector2.ZERO
var trolley_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Crane base is anchored to ground and does not move
	velocity = Vector2.ZERO
	
	current_trolley_dist = initial_trolley_distance
	target_rope_length = 260.0
	current_rope_length = 260.0

	# Fallback node lookups
	if not payload:
		payload = get_node_or_null("Rope") as RigidBody2D
	if not trolley_pivot:
		trolley_pivot = Marker2D.new()
		trolley_pivot.name = "TrolleyPivot"
		add_child(trolley_pivot)
	if not line_2d:
		line_2d = Line2D.new()
		line_2d.name = "Line2D"
		line_2d.width = 3.0
		line_2d.default_color = Color(0.2, 0.22, 0.25, 1.0)
		add_child(line_2d)

	_update_trolley_position()
	prev_trolley_pos = trolley_pivot.global_position

	# CRITICAL: Payload must live independently in world space
	if payload:
		payload.top_level = true
		payload.global_position = trolley_pivot.global_position + Vector2(0, current_rope_length)
		payload.gravity_scale = 1.8
		payload.linear_damp = 0.4
		payload.angular_damp = 2.0
		payload.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY

	# AnimatedSprite2D signal connections
	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")


func _process(_delta: float) -> void:
	_update_rope_visual()


func _physics_process(delta: float) -> void:
	# 1. Crane base is static (move_and_slide is not called)
	# 2. Cable trolley moves back and forth along the boom
	_handle_trolley_movement(delta)
	
	# 3. Cable up/down target control (locks to min or max target)
	_handle_rope_winch_target(delta)
	
	# 4. Flip direction (Space)
	_handle_flip_input()
	
	# 5. Cable physics constraint (XPBD / Distance Constraint)
	_apply_rope_physics_constraint(delta)


# ==============================================================================
# 4. TROLLEY MOVEMENT (FORWARD / BACKWARD)
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
		trolley_velocity = Vector2.ZERO
		return

	var input_x: float = _get_horizontal_input()
	if input_x != 0.0:
		# input_x * facing_direction:
		# Positive -> toward boom tip (forward)
		# Negative -> toward mast (backward)
		var move_delta: float = input_x * float(facing_direction) * trolley_speed * delta
		current_trolley_dist = clampf(current_trolley_dist + move_delta, min_trolley_distance, max_trolley_distance)

	_update_trolley_position()

	# Calculate true trolley velocity for inertia transfer to hook pendulum
	if delta > 0.0 and prev_trolley_pos != Vector2.ZERO:
		trolley_velocity = (trolley_pivot.global_position - prev_trolley_pos) / delta
	prev_trolley_pos = trolley_pivot.global_position


func _update_trolley_position() -> void:
	if trolley_pivot:
		trolley_pivot.position = Vector2(
			mast_local_x + (current_trolley_dist * float(facing_direction)),
			boom_local_y
		)


# ==============================================================================
# 5. CABLE UP / DOWN TARGET CONTROL (WINCH TARGET)
# ==============================================================================
func _handle_rope_winch_target(delta: float) -> void:
	if is_turning:
		return

	# When UP is pressed, target locks directly to shortest length (min_rope_length)
	var pressed_up: bool = Input.is_action_just_pressed("rope_up") or Input.is_action_pressed("rope_up") \
		or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	if pressed_up:
		target_rope_length = min_rope_length

	# When DOWN is pressed, target locks directly to longest length (max_rope_length)
	var pressed_down: bool = Input.is_action_just_pressed("rope_down") or Input.is_action_pressed("rope_down") \
		or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	if pressed_down:
		target_rope_length = max_rope_length

	# Current cable length moves toward target at winch speed
	if current_rope_length != target_rope_length:
		current_rope_length = move_toward(current_rope_length, target_rope_length, rope_winch_speed * delta)


# ==============================================================================
# 6. DIRECTION FLIP AND ANIMATION FLOW (SPACE)
# ==============================================================================
func _handle_flip_input() -> void:
	var pressed_flip: bool = Input.is_action_just_pressed("crane_flip") or Input.is_key_pressed(KEY_SPACE)
	if pressed_flip and not is_turning:
		_start_turn()


func _start_turn() -> void:
	is_turning = true

	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("turn"):
		animated_sprite.play("turn")
	else:
		_run_procedural_turn()


func _run_procedural_turn() -> void:
	var target_scale_x: float = -1.0 if facing_direction == 1 else 1.0
	var tween: Tween = create_tween()
	if visuals:
		tween.tween_property(visuals, "scale:x", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): _apply_flip_state(target_scale_x))
		tween.tween_property(visuals, "scale:x", target_scale_x, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_on_turn_completed)
	else:
		_complete_turn()


func _on_animation_finished() -> void:
	if is_turning and animated_sprite and animated_sprite.animation == "turn":
		_complete_turn()


func _complete_turn() -> void:
	facing_direction *= -1
	_apply_flip_state(float(facing_direction))
	_on_turn_completed()


func _apply_flip_state(dir_x: float) -> void:
	if visuals:
		visuals.scale.x = dir_x
	if animated_sprite and not visuals:
		animated_sprite.scale.x = dir_x

	_update_trolley_position()


func _on_turn_completed() -> void:
	is_turning = false
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")


# ==============================================================================
# 7. CABLE PHYSICS CONSTRAINT (XPBD / CABLE & PENDULUM CONSTRAINT)
# ==============================================================================
func _apply_rope_physics_constraint(_delta: float) -> void:
	if not payload or not trolley_pivot:
		return

	var anchor_pos: Vector2 = trolley_pivot.global_position
	var payload_pos: Vector2 = payload.global_position
	var to_payload: Vector2 = payload_pos - anchor_pos
	var current_distance: float = to_payload.length()

	if current_distance <= 0.001:
		return

	var rope_dir: Vector2 = to_payload / current_distance

	# When cable is taut (distance reaches current_rope_length boundary)
	if current_distance > current_rope_length:
		var excess: float = (current_distance - current_rope_length) * rope_stiffness

		# 1. Position Correction (Prevents cable stretching or clipping)
		payload.global_position -= rope_dir * excess

		# 2. Velocity Constraint: Cancel outward radial velocity, preserve pendulum swing
		var radial_velocity: float = payload.linear_velocity.dot(rope_dir)
		if radial_velocity > 0.0:
			payload.linear_velocity -= rope_dir * radial_velocity

		# 3. Cable Winch Retract Effect (Upward lift impulse)
		var winch_lift: float = 0.0
		if current_rope_length > target_rope_length:
			winch_lift = -rope_winch_speed * 0.75

		# 4. Trolley Motion Inertia Transfer (Pendulum Swing Impulse)
		var trolley_speed_along_rope: float = trolley_velocity.dot(rope_dir)
		payload.linear_velocity += rope_dir * (trolley_speed_along_rope + winch_lift)

		# 5. Swing Damping (Natural atmospheric resistance)
		payload.linear_velocity *= pendulum_damping


# ==============================================================================
# 8. CABLE VISUAL RENDERING (LINE2D)
# ==============================================================================
func _update_rope_visual() -> void:
	if not line_2d or not trolley_pivot or not payload:
		return

	line_2d.clear_points()

	var start_pos: Vector2 = line_2d.to_local(trolley_pivot.global_position)
	var end_pos: Vector2 = line_2d.to_local(payload.global_position)
	var actual_distance: float = trolley_pivot.global_position.distance_to(payload.global_position)

	# Straight wire line when cable is taut
	if actual_distance >= current_rope_length * 0.96:
		line_2d.add_point(start_pos)
		line_2d.add_point(end_pos)
	else:
		# Parabolic catenary sag when cable is slack
		var slack: float = (current_rope_length - actual_distance) * 0.5
		for i in range(rope_segments + 1):
			var t: float = float(i) / float(rope_segments)
			var pt: Vector2 = start_pos.lerp(end_pos, t)
			var sag_amount: float = 4.0 * t * (1.0 - t) * slack
			pt.y += sag_amount
			line_2d.add_point(pt)
