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
@export var rope_segments: int = 16 ## Physical cable resolution segments for Verlet rope simulation
@export var rope_damping: float = 0.94 ## Air resistance and internal cable damping for Verlet points
@export var rope_constraint_iterations: int = 8 ## Solver iterations for realistic steel cable stiffness

@export_group("Aim & Swing Physics")
## Maximum swing angle in degrees (-52 to +52 standard)
@export var swing_max_angle_deg: float = 52.0
## Maximum swing angle when event boost or rocket upgrade is active (-75 to +75 deg)
@export var event_boost_max_angle_deg: float = 75.0
## Restoring gravity force pulling rope back toward vertical
@export var pendulum_gravity: float = 820.0
## Smooth damping bringing rope to rest when not pushed (higher = less oscillation)
@export var pendulum_damping: float = 1.05

@export_subgroup("Trolley Motor Dynamics (Trolley Motor Fiziği)")
## Acceleration rate of the trolley along the boom (px/s²)
@export var trolley_acceleration: float = 1400.0
## Braking deceleration rate when releasing movement keys (px/s²)
@export var trolley_deceleration: float = 1800.0
## Boosted acceleration rate when Event Rock is active (px/s²)
@export var trolley_accel_boosted: float = 2800.0
## Boosted braking deceleration rate when Event Rock is active (px/s²)
@export var trolley_decel_boosted: float = 3400.0

@export_subgroup("Trolley Movement Swing (Trolley Hareket Savrulması)")
## Acceleration inertia kick multiplier from trolley acceleration
@export var swing_inertia_tier1: float = 1.0
## Acceleration inertia kick multiplier for Tier 2 / Boosted
@export var swing_inertia_tier2: float = 1.35
## Active rocket thrust torque injected into swing when Event Rock is active
@export var rocket_swing_thrust: float = 22.0
## Continuous trolley movement swing tilt for Tier 1 (backward compatibility)
@export var movement_swing_strength_tier1: float = 1.0
## Continuous trolley movement swing tilt for Tier 2 (backward compatibility)
@export var movement_swing_strength_tier2: float = 1.3
## Direct driving lag when holding A/D movement keys (backward compatibility)
@export var drive_lag_tier1: float = 0.0
## Direct driving lag when holding A/D movement keys (backward compatibility)
@export var drive_lag_tier2: float = 0.0

@export_subgroup("Turn Swing & Whip (Dönüş Savrulması)")
## Swing impulse applied when crane turns around (Tier 1)
@export var turn_swing_kick_tier1: float = 8.5
## Swing impulse applied when crane turns around (Tier 2)
@export var turn_swing_kick_tier2: float = 12.0
## Continuous rotational whip torque during mast flip turn (Tier 1)
@export var turn_whip_power_tier1: float = 16.0
## Continuous rotational whip torque during mast flip turn (Tier 2)
@export var turn_whip_power_tier2: float = 22.0

@export_subgroup("Winch & Aim Limits")
@export var lock_trolley_during_descent: bool = false ## Allow subtle trolley steering while deployed
@export var auto_retract_after_landing: bool = true ## Auto-retract back to top after grab/landing
@export var landing_retract_delay: float = 0.5 ## Delay before auto-retracting if no object caught
@export var arrow_distance: float = 123.0 ## Distance of arrow from TrolleyPivot

@export_group("Payload Tier & Speed Upgrades")
## Payload upgrade tier (1: Standard Physics, 2: Fast Rocket-Guided with better_catch animation)
@export var payload_tier: int = 1
## Key to toggle/upgrade payload tier in debug mode (Default: K)
@export var payload_upgrade_key: Key = KEY_K
## Standard trolley traverse speed (px/s) for Tier 1
@export var trolley_speed_tier1: float = 380.0
## Standard winch deploy/retract speed (px/s) for Tier 1
@export var rope_winch_speed_tier1: float = 260.0
## Upgraded agile trolley traverse speed (px/s) for Tier 2
@export var trolley_speed_tier2: float = 580.0
## Upgraded fast winch deploy/retract speed (px/s) for Tier 2
@export var rope_winch_speed_tier2: float = 480.0
## Fling speed multiplier when releasing cargo from swing (Tier 1 vs Tier 2)
@export var fling_multiplier_tier1: float = 2.0
@export var fling_multiplier_tier2: float = 2.6

@export_group("Event Rock Temporary Speed Boost")
## Duration in seconds of the speed boost when an Event Rock is consumed (Default: 15.0s)
@export var event_boost_duration: float = 15.0
var is_event_boost_active: bool = false
var _event_boost_timer: float = 0.0

@export_group("Aim Trajectory & Arrow Juice")
## Enable pulsing bob animation along the aim direction
@export var enable_arrow_bob: bool = true
## Bob distance in pixels along the aim vector
@export var arrow_bob_amplitude: float = 8.5
## Speed of the bob oscillation
@export var arrow_bob_speed: float = 7.0
## Enable velocity stretch and inertia tilt when swinging
@export var enable_arrow_stretch: bool = true
## Enable the landing cursor / target reticle ahead of the arrow showing where payload will go (disabled by default)
@export var enable_aim_cursor: bool = false
## Optional keyboard key to toggle the aim cursor in-game (Default: KEY_NONE / assignable in Inspector)
@export var toggle_aim_cursor_key: Key = KEY_NONE
## Enable streaming dotted trajectory laser line
@export var enable_trajectory_dots: bool = false
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

@export_group("Crane & Payload Audio")
## Custom audio file for payload catching/grabbing cargo or water (default: res://Sounds/PayloadCatch.wav)
@export var payload_catch_audio: AudioStream = null
## Volume (dB) for payload catch sound
@export var payload_catch_volume_db: float = 0.0

## Custom audio file for crane tower turning (default: res://Sounds/CraneTurn.wav)
@export var crane_turn_audio: AudioStream = null
## Volume (dB) for crane turn sound
@export var crane_turn_volume_db: float = 0.0

## Custom audio file for trolley moving along the boom (default: res://Sounds/TrolleyMove.wav)
@export var trolley_move_audio: AudioStream = null
## Volume (dB) for trolley move sound
@export var trolley_move_volume_db: float = 0.0

@export_group("Water Interaction & Audio")
## Enable payload physical interaction and scooping with fluid water
@export var enable_water_interaction: bool = true
## Custom audio file for water contact/splash (assignable in Inspector)
@export var water_splash_audio: AudioStream = null
## Volume (dB) for water splash sound
@export var water_splash_volume_db: float = 0.0
## Radius around payload to detect and scoop water particles
@export var water_scoop_radius: float = 75.0
## Spring attraction force holding water particles in payload bucket
@export var water_hold_force: float = 850.0
## Minimum particles nearby required to trigger a water scoop
@export var water_min_scoop_particles: int = 4

@export_group("Pickup Juice & Screen Shake")
## Enable screen shake when payload catches/picks up an item
@export var enable_pickup_shake: bool = true
## Screen shake intensity in pixels (increased for punchier impact: default 9.0 px)
@export var pickup_shake_intensity: float = 9.0
## Duration of the shake in seconds
@export var pickup_shake_duration: float = 0.32
## Enable hit stop micro-pause when grabbing cargo or water
@export var enable_hit_stop: bool = true
## Duration of hit stop in seconds (increased for more noticeable impact: default 0.15s)
@export var hit_stop_duration: float = 0.15
## Engine time scale during hit stop (deep freeze frame)
@export var hit_stop_time_scale: float = 0.02

@export_group("Visual Rendering")
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
var is_trolley_actually_moving: bool = false
var trolley_current_speed: float = 0.0 ## Real-time physical trolley speed along track (px/s)
var rope_points: Array[Vector2] = [] ## World positions of physical Verlet rope points
var rope_prev_points: Array[Vector2] = [] ## Previous positions for Verlet velocity integration

var is_at_top: bool = true ## True when hook is at the top swinging
var swing_timer: float = 0.0 ## Oscillator time tracker
var current_swing_angle: float = 0.0 ## Current swing angle in radians
var swing_angular_velocity: float = 0.0 ## Current swing angular velocity in radians/sec
var prev_trolley_velocity: Vector2 = Vector2.ZERO ## Tracks trolley acceleration for inertial swing
var movement_swing_strength: float = 1.0 ## Active movement swing multiplier
var swing_inertia_scale: float = 1.0 ## Active acceleration inertia multiplier
var turn_swing_kick: float = 8.5 ## Active turn impulse
var locked_aim_angle: float = 0.0 ## Angle locked when DOWN was pressed
var locked_aim_dir: Vector2 = Vector2.DOWN ## Direction vector locked when DOWN was pressed

var is_carrying_cargo: bool = false ## True when cargo crate is held by payload
var grabbed_body: RigidBody2D = null ## Currently grabbed cargo body
var can_release_cargo: bool = false ## True once initial descent down key is released after pickup
var prev_down_pressed: bool = false ## Tracks down key state for just_pressed detection
var prev_release_pressed: bool = false ## Dedicated tracking for cargo release trigger
var just_released_cargo_this_frame: bool = false ## Prevents SPACE from triggering crane flip on release frame
var waiting_for_down_release: bool = false ## Requires releasing DOWN key after cargo drop before launching next descent

var is_carrying_water: bool = false ## True when fluid water is scooped and held by payload
var can_release_water: bool = false ## True once rope reaches top and down key is released
var _cached_fluid_water: FluidWater = null
var _water_audio_player: AudioStreamPlayer2D = null
var _was_in_water_prev_frame: bool = false
var _water_splash_cooldown: float = 0.0

var _payload_catch_audio_player: AudioStreamPlayer2D = null
var _crane_turn_audio_player: AudioStreamPlayer2D = null
var _trolley_move_audio_player: AudioStreamPlayer = null

var is_descending: bool = false ## True when lowering winch with catch sequence
var has_resolved_landing: bool = false ## True once ground/cargo landing has resolved
var has_caught_object: bool = false ## True if hook contacted a grabbable object

var _base_arrow_scale: Vector2 = Vector2(2.75, 2.75)
var _arrow_anim_timer: float = 0.0
var _aim_trajectory: CraneAimTrajectory = null
var is_aim_locked_on: bool = false
var locked_target_node: Node2D = null
var _was_locked_on_prev_frame: bool = false
var _payload_key_pressed_prev: bool = false
var _toggle_cursor_key_pressed_prev: bool = false
var _rocket_visual: PayloadRocketVisual = null


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
	is_carrying_water = false

	# Fallback node lookups
	if not payload:
		payload = get_node_or_null("Payload") as RigidBody2D
	if not payload:
		payload = get_node_or_null("Rope") as RigidBody2D
	if not payload_sprite:
		payload_sprite = _find_payload_sprite()
	if not visuals:
		visuals = get_node_or_null("Visuals")
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
	_aim_trajectory.show_cursor = enable_aim_cursor
	_aim_trajectory.show_dots = enable_trajectory_dots

	_update_trolley_position()
	prev_trolley_pos = trolley_pivot.global_position
	set_payload_tier(payload_tier)

	# CRITICAL: Payload lives independently in world space
	if payload:
		payload.top_level = true
		payload.global_position = _get_rope_origin() + Vector2(0, current_rope_length)
		payload.gravity_scale = 0.0 # Guided trajectory during aim, descent and carry
		payload.linear_damp = 0.0
		payload.angular_damp = 2.0
		payload.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
		payload.collision_mask |= 2
		payload.collision_layer |= 2
		
		# Enable collision reporting for object detection
		payload.contact_monitor = true
		payload.max_contacts_reported = 8
		if not payload.body_entered.is_connected(_on_payload_body_entered):
			payload.body_entered.connect(_on_payload_body_entered)

		# Initialize Verlet physical cable points and initial render
		_init_rope_physics()
		_update_rope_visual()

		# Setup Rocket Thruster visual on payload for Tier 2
		if not _rocket_visual:
			_rocket_visual = payload.get_node_or_null("RocketVisual") as PayloadRocketVisual
			if not _rocket_visual:
				_rocket_visual = PayloadRocketVisual.new()
				_rocket_visual.name = "RocketVisual"
				payload.add_child(_rocket_visual)

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

	# Initialize water splash audio player
	_init_water_audio_player()
	# Initialize crane, trolley and payload audio players
	_init_crane_audio_players()

	# Initialize active tier physics parameters from Inspector settings
	set_payload_tier(payload_tier)

	_update_house_upgrade_pointers()
	_update_wall_pointer()
	_update_factory_pointer()


func _process(_delta: float) -> void:
	_update_rope_visual()


func _physics_process(delta: float) -> void:
	# 1. Cable trolley moves back and forth along the boom (carrying cargo anywhere player wants)
	_handle_trolley_movement(delta)

	# Manage temporary Event Rock / Upgrade Rock rocket boost
	if is_event_boost_active:
		_event_boost_timer -= delta
		if _rocket_visual:
			_rocket_visual.set_firing(true)
			_rocket_visual.flame_scale = 1.45 if (is_descending or trolley_velocity.length() > 60.0) else 1.0

		if _event_boost_timer <= 0.0:
			_end_event_boost()

	# Handle payload tier upgrade input (K key) - Debug only: triggers temporary boost
	var gm = get_node_or_null("/root/GameManager")
	var is_debug: bool = gm and gm.debug_mode
	if is_debug and Input.is_key_pressed(payload_upgrade_key):
		if not _payload_key_pressed_prev:
			_payload_key_pressed_prev = true
			if not is_event_boost_active:
				trigger_event_boost(event_boost_duration)
			else:
				_end_event_boost()
	else:
		if not Input.is_key_pressed(payload_upgrade_key):
			_payload_key_pressed_prev = false

	# Handle aim cursor toggle key
	if toggle_aim_cursor_key != KEY_NONE and Input.is_key_pressed(toggle_aim_cursor_key):
		if not _toggle_cursor_key_pressed_prev:
			_toggle_cursor_key_pressed_prev = true
			toggle_aim_cursor()
	else:
		if toggle_aim_cursor_key != KEY_NONE and not Input.is_key_pressed(toggle_aim_cursor_key):
			_toggle_cursor_key_pressed_prev = false

	# 2. Aim & swing oscillation when at the top, or angled descent trajectory when deployed
	if is_at_top:
		_update_swing_oscillation(delta)
	else:
		_update_deployed_trajectory(delta)

	# 2b. Update Physical Verlet Rope Simulation
	_update_rope_physics(delta)

	# 3. Cargo release input (Space, S, or dedicated drop action)
	_handle_cargo_release_input()

	# 4. Cable up/down input control (Space lowers at top, raises when deployed)
	_handle_rope_winch_target(delta)

	# 5. Flip direction (Q for left, E for right) - allowed at top
	_handle_flip_input()

	# 6. Check cargo contact during descent
	_check_payload_descent_contact()

	# 7. Check water interaction and scooping
	_check_water_interaction(delta)

	# 8. Payload rotation limit [-75 deg, +75 deg]
	_apply_payload_rotation_limit(delta)

	# Enable releasing cargo ONLY after rope has fully reached the top AND user has released the down/space key
	if is_carrying_cargo and not can_release_cargo:
		if is_at_top:
			var down_currently_pressed: bool = (
				(InputMap.has_action("rope_down") and Input.is_action_pressed("rope_down"))
				or Input.is_key_pressed(KEY_DOWN)
				or Input.is_key_pressed(KEY_SPACE)
			)
			if not down_currently_pressed:
				can_release_cargo = true

	# Enable releasing water ONLY after rope has fully reached the top AND user has released the down/space key
	if is_carrying_water and not can_release_water:
		if is_at_top:
			var down_currently_pressed: bool = (
				(InputMap.has_action("rope_down") and Input.is_action_pressed("rope_down"))
				or Input.is_key_pressed(KEY_DOWN)
				or Input.is_key_pressed(KEY_SPACE)
			)
			if not down_currently_pressed:
				can_release_water = true

	# Reset one-frame release flag
	just_released_cargo_this_frame = false


# ==============================================================================
# 5. TROLLEY MOVEMENT (FORWARD / BACKWARD)
# ==============================================================================
func _get_horizontal_input() -> float:
	if ButtonsController.is_esc_menu_open:
		return 0.0
	var axis: float = 0.0
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		axis -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		axis += 1.0
	return axis


func _handle_trolley_movement(delta: float) -> void:
	if is_turning:
		trolley_current_speed = 0.0
		if delta > 0.0 and prev_trolley_pos != Vector2.ZERO and trolley_pivot:
			trolley_velocity = (trolley_pivot.global_position - prev_trolley_pos) / delta
		else:
			trolley_velocity = Vector2.ZERO
		if trolley_pivot:
			prev_trolley_pos = trolley_pivot.global_position
		_stop_trolley_move_sound()
		return
	if not is_at_top and lock_trolley_during_descent:
		trolley_current_speed = 0.0
		trolley_velocity = Vector2.ZERO
		if trolley_sprite and trolley_sprite.sprite_frames and trolley_sprite.sprite_frames.has_animation("default"):
			if trolley_sprite.animation != &"default":
				trolley_sprite.play("default")
		_stop_trolley_move_sound()
		return

	var input_x: float = _get_horizontal_input()
	var target_speed: float = input_x * float(facing_direction) * trolley_speed

	var active_accel: float = trolley_accel_boosted if (is_event_boost_active or payload_tier >= 2) else trolley_acceleration
	var active_decel: float = trolley_decel_boosted if (is_event_boost_active or payload_tier >= 2) else trolley_deceleration

	if absf(target_speed) > 0.001:
		# Snappy reversal if driving opposite to current momentum
		var rate: float = (active_accel + active_decel) if (signf(target_speed) != signf(trolley_current_speed) and absf(trolley_current_speed) > 10.0) else active_accel
		trolley_current_speed = move_toward(trolley_current_speed, target_speed, rate * delta)
	else:
		trolley_current_speed = move_toward(trolley_current_speed, 0.0, active_decel * delta)

	var actually_moved: bool = false
	if absf(trolley_current_speed) > 0.001:
		var prev_dist: float = current_trolley_dist
		var next_dist: float = current_trolley_dist + trolley_current_speed * delta

		# Boom mechanical stop limits
		if next_dist <= min_trolley_distance:
			current_trolley_dist = min_trolley_distance
			trolley_current_speed = 0.0 # Hits inner mechanical bumper
		elif next_dist >= max_trolley_distance:
			current_trolley_dist = max_trolley_distance
			trolley_current_speed = 0.0 # Hits outer mechanical bumper
		else:
			current_trolley_dist = next_dist

		actually_moved = absf(current_trolley_dist - prev_dist) > 0.0001

	is_trolley_actually_moving = actually_moved

	if actually_moved:
		if trolley_sprite and trolley_sprite.sprite_frames and trolley_sprite.sprite_frames.has_animation("move"):
			if trolley_sprite.animation != &"move" or not trolley_sprite.is_playing():
				trolley_sprite.play("move")
		_play_trolley_move_sound()
	else:
		if trolley_sprite and trolley_sprite.sprite_frames and trolley_sprite.sprite_frames.has_animation("default"):
			if trolley_sprite.animation != &"default":
				trolley_sprite.play("default")
		_stop_trolley_move_sound()

	_update_trolley_position()

	if delta > 0.0 and prev_trolley_pos != Vector2.ZERO and trolley_pivot:
		trolley_velocity = (trolley_pivot.global_position - prev_trolley_pos) / delta
	else:
		trolley_velocity = Vector2.ZERO
	if trolley_pivot:
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
		var eff_len: float = maxf(current_rope_length, 40.0)

		# 1. Genuine physical acceleration of the trolley in world coordinates
		var trolley_accel_x: float = (trolley_velocity.x - prev_trolley_velocity.x) / delta
		trolley_accel_x = clampf(trolley_accel_x, -4000.0, 4000.0)

		# 2. Pendulum Restoring Gravity Torque: - (g / L) * sin(theta)
		var restoring: float = - (pendulum_gravity / eff_len) * sin(current_swing_angle)

		# 3. Dynamic Air & Mechanical Pivot Damping
		# Heavy cargo (stone, brick, water) has higher mass/inertia, swinging longer
		var mass_damping_factor: float = 1.0
		if is_carrying_cargo or is_carrying_water:
			mass_damping_factor = 0.75
		var active_damping: float = pendulum_damping * mass_damping_factor
		var damping: float = - active_damping * swing_angular_velocity

		# 4. Genuine Inertial Push from Trolley Acceleration
		# In Godot 2D coordinates (Y down, clockwise from DOWN is +angle/left):
		# Accelerating right (trolley_accel_x > 0) creates positive angular acceleration (hook lags left).
		# Braking while moving right (trolley_accel_x < 0) creates negative angular acceleration (hook flings forward/right).
		var active_inertia_scale: float = swing_inertia_tier2 if (is_event_boost_active or payload_tier >= 2) else swing_inertia_tier1
		var inertial: float = (trolley_accel_x / eff_len) * cos(current_swing_angle) * active_inertia_scale

		# 5. Continuous rotational whip torque during mast flip turn
		var turn_whip: float = 0.0
		if is_turning:
			var whip_power: float = turn_whip_power_tier2 if (is_event_boost_active or payload_tier >= 2) else turn_whip_power_tier1
			var whip_dir: float = float(facing_direction) if not _is_turn_reversing else -float(facing_direction) * 0.7
			turn_whip = whip_dir * whip_power

		# 6. Event Rock / Rocket Thruster Swing Boost ("fiziğe dayalı olsa bile biraz daha güç ve hız katabilmeli")
		var rocket_swing_torque: float = 0.0
		if is_event_boost_active or payload_tier >= 2:
			var input_axis: float = _get_horizontal_input()
			if input_axis != 0.0:
				# Rocket thrusters apply active physical drive in the movement direction
				rocket_swing_torque += input_axis * float(facing_direction) * rocket_swing_thrust
			if absf(swing_angular_velocity) > 0.05:
				# Tangential rocket thrust assist adding speed and punch to the swing
				rocket_swing_torque += sign(swing_angular_velocity) * (rocket_swing_thrust * 0.45)

			if _rocket_visual:
				var speed_flame: float = clampf(absf(swing_angular_velocity) / 4.0, 0.0, 0.6)
				_rocket_visual.flame_scale = 1.15 + speed_flame

		# 7. Ambient gentle breeze variation
		var ambient_wind: float = (sin(Time.get_ticks_msec() * 0.0016) * 0.08 + sin(Time.get_ticks_msec() * 0.0031) * 0.04)

		var total_angular_accel: float = restoring + damping + inertial + turn_whip + rocket_swing_torque + ambient_wind

		# Semi-implicit Euler integration
		swing_angular_velocity += total_angular_accel * delta
		var max_ang_vel: float = 24.0 if (is_event_boost_active or payload_tier >= 2) else 18.0
		swing_angular_velocity = clampf(swing_angular_velocity, -max_ang_vel, max_ang_vel)

		current_swing_angle += swing_angular_velocity * delta

		# Maximum allowed swing angle limit
		var active_max_angle: float = 88.0 if is_turning else (event_boost_max_angle_deg if (is_event_boost_active or payload_tier >= 2) else swing_max_angle_deg)
		var max_rad: float = deg_to_rad(active_max_angle)
		if absf(current_swing_angle) > max_rad:
			current_swing_angle = clampf(current_swing_angle, -max_rad, max_rad)
			swing_angular_velocity *= -0.65 # Elastic rebound off boom physical limit

		# Subtle resting settling
		if not is_turning and not is_event_boost_active and absf(current_swing_angle) < 0.001 and absf(swing_angular_velocity) < 0.004 and trolley_velocity.length_squared() < 0.5:
			current_swing_angle = 0.0
			swing_angular_velocity = 0.0

	prev_trolley_velocity = trolley_velocity

	_arrow_anim_timer += delta

	# 1. Target Lock-On Detection along current aim angle
	var aim_dir: Vector2 = Vector2.DOWN.rotated(current_swing_angle)
	var locked_node: Node2D = null
	if enable_target_lockon and not is_carrying_cargo and not is_carrying_water:
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
	elif is_carrying_water:
		target_color = Color(0.18, 0.78, 1.0, 1.0)
	elif is_aim_locked_on:
		target_color = Color(1.0, 0.72, 0.15, 1.0) if payload_tier >= 2 else aim_color_locked

	# 2. Update Arrow: visible, bobbing, inertia stretch and glowing
	if arrow:
		arrow.visible = true

		# Bobbing along aim vector
		var bob_speed: float = arrow_bob_speed * (1.8 if is_aim_locked_on else 1.0)
		var dynamic_dist: float = arrow_distance
		if enable_arrow_bob:
			dynamic_dist += sin(_arrow_anim_timer * bob_speed) * arrow_bob_amplitude

		arrow.position = Vector2(0.0, rope_offset_y) + aim_dir * dynamic_dist

		# Velocity inertia stretch & tilt
		if enable_arrow_stretch:
			var stretch: float = clampf(absf(swing_angular_velocity) * 0.075, 0.0, 0.4)
			var pulse_scale: float = 1.0 + (0.1 if is_aim_locked_on else 0.03) * sin(_arrow_anim_timer * 14.0)
			arrow.scale.y = _base_arrow_scale.y * (1.0 + stretch) * pulse_scale
			arrow.scale.x = _base_arrow_scale.x * (1.0 - stretch * 0.45) * pulse_scale
			arrow.rotation = current_swing_angle - swing_angular_velocity * 0.035
		else:
			arrow.rotation = current_swing_angle

		# Smooth modulate transition to active aim color
		arrow.modulate = arrow.modulate.lerp(target_color, 12.0 * delta)

	# 3. Update Trajectory Reticle
	if _aim_trajectory:
		_aim_trajectory.show_cursor = enable_aim_cursor
		_aim_trajectory.show_dots = enable_trajectory_dots
		var rope_origin: Vector2 = _get_rope_origin()
		var target_pos: Vector2 = locked_target_node.global_position if is_aim_locked_on else (rope_origin + aim_dir * max_rope_length)
		_aim_trajectory.update_aim(
			arrow.global_position if arrow else rope_origin,
			aim_dir,
			max_rope_length,
			is_aim_locked_on,
			target_pos,
			target_color,
			is_at_top and (enable_trajectory_dots or enable_aim_cursor),
			(payload_tier >= 2)
		)

	# 4. Update Payload position and rotation to swing in unison
	if payload and trolley_pivot:
		var swing_dir: Vector2 = Vector2.DOWN.rotated(current_swing_angle)
		var tangent_dir: Vector2 = Vector2(-swing_dir.y, swing_dir.x)
		payload.global_position = _get_rope_origin() + swing_dir * current_rope_length
		payload.rotation = current_swing_angle
		payload.linear_velocity = tangent_dir * (swing_angular_velocity * current_rope_length)
		payload.angular_velocity = swing_angular_velocity

	# 5. If carrying cargo, it remains attached under the payload at the top
	if is_carrying_cargo and grabbed_body and is_instance_valid(grabbed_body):
		grabbed_body.global_position = payload.global_position + Vector2.DOWN.rotated(current_swing_angle) * cargo_carry_offset_y
		grabbed_body.rotation = current_swing_angle
		grabbed_body.linear_velocity = payload.linear_velocity
		grabbed_body.angular_velocity = payload.angular_velocity

	# Keep level at TOP
	if current_payload_level != PayloadLevel.TOP:
		current_payload_level = PayloadLevel.TOP
		payload_level_changed.emit(current_payload_level)


func _check_target_lockon(aim_dir: Vector2) -> Node2D:
	var rope_orig: Vector2 = _get_rope_origin()
	var best_target: Node2D = null
	var min_perp: float = 160.0 if payload_tier >= 2 else 72.0 # Tier 2 rocket guidance has wider lock-on corridor
	var max_reach: float = max_rope_length + (150.0 if payload_tier >= 2 else 75.0)

	var tree := get_tree()
	if not tree:
		return null

	var candidates: Array[Node] = []
	if not is_carrying_cargo:
		for p in tree.get_nodes_in_group("rock_pit"):
			if not candidates.has(p):
				candidates.append(p)
	for r in tree.get_nodes_in_group("brick"):
		if not candidates.has(r):
			candidates.append(r)
	for r in tree.get_nodes_in_group("rock"):
		if not candidates.has(r):
			candidates.append(r)
	for c in tree.get_nodes_in_group("cargo"):
		if not candidates.has(c):
			candidates.append(c)
	for g in tree.get_nodes_in_group("grabbable"):
		if not candidates.has(g):
			candidates.append(g)

	# When carrying cargo:
	# If carrying brick -> aim directly at StoneWall
	# If carrying upgrade rock -> aim directly at nearest upgradeable House
	# If carrying rock -> aim directly at Factory
	if is_carrying_cargo and grabbed_body and is_instance_valid(grabbed_body):
		if grabbed_body.is_in_group("brick") or grabbed_body.is_in_group("upgrade_rock"):
			# Tuğla taşırken: Taş duvara veya yükseltilebilir eve doğru nişan almayı destekle
			var wall = tree.get_first_node_in_group("stone_wall")
			var deposit_target: Node2D = null
			var best_proj: float = 999999.0

			# 1. Taş Duvar adayı
			if wall and is_instance_valid(wall) and wall.has_method("get_wall_top_y_local"):
				if "current_stage" in wall and "max_stages" in wall and wall.current_stage < wall.max_stages:
					var wall_target_pos := Vector2(wall.global_position.x, wall.global_position.y + wall.get_wall_top_y_local() * wall.scale.y)
					var to_wall: Vector2 = wall_target_pos - rope_orig
					var proj: float = to_wall.dot(aim_dir)
					if proj > 60.0 and proj <= max_reach + 80.0:
						var perp: float = (to_wall - aim_dir * proj).length()
						if perp < 85.0 * wall.scale.x:
							deposit_target = wall
							best_proj = proj

			# 2. Ev adayları
			var houses := tree.get_nodes_in_group("house")
			for h in houses:
				if not is_instance_valid(h):
					continue
				var house = h
				if ("is_destroyed" in house and house.is_destroyed) or ("current_level" in house and "max_level" in house and house.current_level >= house.max_level):
					continue
				if not house.has_method("get_bounds"):
					continue
				var bounds: Dictionary = house.get_bounds()
				var h_target := Vector2((bounds.left + bounds.right) * 0.5, bounds.top)
				var to_h: Vector2 = h_target - rope_orig
				var proj: float = to_h.dot(aim_dir)
				if proj > 60.0 and proj <= max_reach + 100.0:
					var perp: float = (to_h - aim_dir * proj).length()
					if perp < 75.0:
						if proj < best_proj:
							best_proj = proj
							deposit_target = house

			if deposit_target:
				return deposit_target
		elif grabbed_body.is_in_group("rock"):
			var factory = tree.get_first_node_in_group("factory")
			if not factory and tree.current_scene:
				factory = tree.current_scene.find_child("factory", true, false)
			if factory and is_instance_valid(factory):
				var factory_target_pos: Vector2 = factory.global_position
				var to_factory: Vector2 = factory_target_pos - rope_orig
				var proj: float = to_factory.dot(aim_dir)
				if proj > 60.0 and proj <= max_reach + 80.0:
					var perp: float = (to_factory - aim_dir * proj).length()
					if perp < 110.0:
						return factory

	# Proximity check along aim ray
	for node in candidates:
		if node is Node2D and node != payload and node != grabbed_body and is_instance_valid(node):
			var to_node: Vector2 = node.global_position - rope_orig
			var proj: float = to_node.dot(aim_dir)
			# Check objects along aim vector within reach
			if proj > 50.0 and proj <= max_reach:
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
	# Soften launch angular velocity into controlled descent
	swing_angular_velocity = clampf(swing_angular_velocity, -2.5, 2.5)

	# Ignite rocket thruster visuals for Boosted state
	if (is_event_boost_active or payload_tier >= 2) and _rocket_visual:
		_rocket_visual.set_firing(true)

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

	# If carrying cargo or water, never allow the rope to continue extending downwards
	if (is_carrying_cargo or is_carrying_water) and target_rope_length > current_rope_length:
		target_rope_length = current_rope_length

	# Winch extension/retraction calculation
	var prev_len: float = current_rope_length
	if current_rope_length != target_rope_length:
		current_rope_length = move_toward(current_rope_length, target_rope_length, rope_winch_speed * delta)
	var winch_rate: float = (current_rope_length - prev_len) / maxf(delta, 0.001)

	# Update payload level tracking (TOP, MIDDLE, BOTTOM)
	if current_rope_length <= min_rope_length + 4.0:
		if current_payload_level != PayloadLevel.TOP:
			current_payload_level = PayloadLevel.TOP
			payload_level_changed.emit(current_payload_level)
	elif current_rope_length >= max_rope_length - 4.0:
		if current_payload_level != PayloadLevel.BOTTOM:
			current_payload_level = PayloadLevel.BOTTOM
			payload_level_changed.emit(current_payload_level)

	# --- STABLE PHYSICAL SWING DYNAMICS DURING DESCENT ---
	var eff_len: float = maxf(current_rope_length, 60.0)
	var length_ratio: float = clampf((current_rope_length - min_rope_length) / maxf(max_rope_length - min_rope_length, 1.0), 0.0, 1.0)

	# 1. Restoring gravity torque pulling back toward vertical
	var restoring: float = - (pendulum_gravity / eff_len) * sin(current_swing_angle)

	# 2. Cable damping: higher damping when extended prevents wild whipping/flying
	var active_deployed_damping: float = pendulum_damping * lerpf(1.3, 2.5, length_ratio)
	if is_carrying_cargo or is_carrying_water:
		active_deployed_damping *= 0.8
	if winch_rate < -5.0: # winching back up
		active_deployed_damping *= 1.4
	var damping: float = - active_deployed_damping * swing_angular_velocity

	# 3. Controlled Coriolis torque
	var coriolis: float = clampf(- (2.0 * winch_rate / eff_len) * swing_angular_velocity, -4.5, 4.5)

	var total_deployed_accel: float = restoring + damping + coriolis

	# 4. Inertial sway from trolley movement during deployment (smooth and bounded)
	if delta > 0.0:
		var trolley_accel_x: float = (trolley_velocity.x - prev_trolley_velocity.x) / delta
		trolley_accel_x = clampf(trolley_accel_x, -1200.0, 1200.0)
		var inertia_scale: float = 0.65 if (payload_tier == 1 and not is_event_boost_active) else 0.95
		total_deployed_accel += (trolley_accel_x / eff_len) * cos(current_swing_angle) * inertia_scale

	if is_event_boost_active or payload_tier >= 2:
		# Tier 2 / Boosted: ROCKET-POWERED GUIDED HOOK
		if _rocket_visual:
			_rocket_visual.set_firing(true)
			_rocket_visual.flame_scale = 1.45 if (is_descending or trolley_velocity.length() > 60.0) else 1.0

		# 1. Rocket Guidance towards target if locked or nearby
		if locked_target_node and is_instance_valid(locked_target_node):
			var to_target: Vector2 = locked_target_node.global_position - _get_rope_origin()
			var target_angle: float = Vector2.DOWN.angle_to(to_target)
			var angle_err: float = target_angle - current_swing_angle
			var rocket_thrust: float = clampf(angle_err * 14.0 - swing_angular_velocity * 2.8, -9.0, 9.0)
			total_deployed_accel += rocket_thrust
		else:
			# Auto-homing scan for any nearby grabbable rock or stone wall
			var soft_target = _check_target_lockon(Vector2.DOWN.rotated(current_swing_angle))
			if soft_target and is_instance_valid(soft_target):
				var to_t: Vector2 = soft_target.global_position - _get_rope_origin()
				var t_angle: float = Vector2.DOWN.angle_to(to_t)
				var a_err: float = t_angle - current_swing_angle
				total_deployed_accel += clampf(a_err * 10.0, -7.0, 7.0)

		# 2. Mid-air manual rocket steering with A/D keys
		var steer_input: float = _get_horizontal_input()
		if steer_input != 0.0:
			total_deployed_accel += - steer_input * 5.5
	else:
		if _rocket_visual:
			_rocket_visual.set_firing(false)

	# Semi-implicit Euler integration with length-scaled angular velocity limits
	swing_angular_velocity += total_deployed_accel * delta
	var max_deployed_ang_vel: float = clampf(420.0 / eff_len, 0.85, 3.2)
	if is_event_boost_active or payload_tier >= 2:
		max_deployed_ang_vel *= 1.35
	swing_angular_velocity = clampf(swing_angular_velocity, -max_deployed_ang_vel, max_deployed_ang_vel)

	current_swing_angle += swing_angular_velocity * delta

	# Max swing angle scales with cable length: tighter at bottom so long cable doesn't sweep across the entire screen
	var base_max_angle: float = swing_max_angle_deg if (payload_tier == 1 and not is_event_boost_active) else event_boost_max_angle_deg
	var max_allowed_deg: float = lerpf(base_max_angle, 20.0, length_ratio)
	if is_event_boost_active or payload_tier >= 2:
		max_allowed_deg = lerpf(base_max_angle, 30.0, length_ratio)
	var max_rad: float = deg_to_rad(max_allowed_deg)

	if absf(current_swing_angle) > max_rad:
		current_swing_angle = clampf(current_swing_angle, -max_rad, max_rad)
		swing_angular_velocity *= -0.3

	# Track previous trolley velocity
	prev_trolley_velocity = trolley_velocity

	# Update payload position and velocities along swinging cable
	var swing_dir: Vector2 = Vector2.DOWN.rotated(current_swing_angle)
	var tangent_dir: Vector2 = Vector2(-swing_dir.y, swing_dir.x)
	if payload and trolley_pivot:
		payload.global_position = _get_rope_origin() + swing_dir * current_rope_length
		payload.rotation = current_swing_angle
		payload.linear_velocity = swing_dir * winch_rate + tangent_dir * (swing_angular_velocity * current_rope_length)
		payload.angular_velocity = swing_angular_velocity

	# Move grabbed cargo with payload while deployed
	if is_carrying_cargo and grabbed_body and is_instance_valid(grabbed_body):
		grabbed_body.global_position = payload.global_position + Vector2.DOWN.rotated(payload.rotation) * cargo_carry_offset_y
		grabbed_body.rotation = payload.rotation
		grabbed_body.linear_velocity = payload.linear_velocity
		grabbed_body.angular_velocity = payload.angular_velocity

	# Check return to top
	if current_rope_length <= min_rope_length + 4.0 and target_rope_length == min_rope_length:
		current_rope_length = min_rope_length
		is_at_top = true
		is_descending = false
		has_resolved_landing = false
		current_payload_level = PayloadLevel.TOP
		if not is_event_boost_active and _rocket_visual:
			_rocket_visual.set_firing(false)
		if arrow:
			arrow.visible = true
			arrow.scale = _base_arrow_scale * 0.2
			var pop_tween := create_tween()
			pop_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pop_tween.tween_property(arrow, "scale", _base_arrow_scale, 0.22)
		if _aim_trajectory:
			_aim_trajectory.play_reset_pop()

		# When returning to top, ensure default animation is playing (unless holding cargo!)
		if payload_sprite and payload_sprite.sprite_frames:
			if (is_carrying_cargo or is_carrying_water) and payload_sprite.sprite_frames.has_animation("hold"):
				payload_sprite.play("hold")
			elif payload_sprite.sprite_frames.has_animation("default"):
				payload_sprite.play("default")

		# Resume swinging seamlessly from current angle
		swing_angular_velocity = clampf(swing_angular_velocity, -10.0, 10.0)


# ==============================================================================
# 7. WINCH TARGET & INPUT CONTROL
# ==============================================================================
func _handle_rope_winch_target(_delta: float) -> void:
	if ButtonsController.is_esc_menu_open or is_turning:
		return

	var is_space_pressed: bool = (
		Input.is_key_pressed(KEY_SPACE)
		or (InputMap.has_action("rope_down") and Input.is_action_pressed("rope_down"))
		or (InputMap.has_action("rope_up") and Input.is_action_pressed("rope_up"))
		or Input.is_key_pressed(KEY_DOWN)
		or Input.is_key_pressed(KEY_UP)
	)

	if not is_space_pressed:
		waiting_for_down_release = false

	if waiting_for_down_release or just_released_cargo_this_frame:
		prev_down_pressed = is_space_pressed
		return

	var is_space_just_pressed: bool = (
		(is_space_pressed and not prev_down_pressed)
		or (InputMap.has_action("rope_down") and Input.is_action_just_pressed("rope_down"))
		or (InputMap.has_action("rope_up") and Input.is_action_just_pressed("rope_up"))
		or (InputMap.has_action("ui_accept") and Input.is_action_just_pressed("ui_accept"))
	)

	prev_down_pressed = is_space_pressed

	if not is_space_just_pressed:
		return

	# If carrying cargo or water:
	if is_carrying_cargo:
		if is_at_top and can_release_cargo:
			just_released_cargo_this_frame = true
			waiting_for_down_release = true
			_release_cargo()
		elif not is_at_top:
			# If lowered with cargo, winch back up
			target_rope_length = min_rope_length
			is_descending = false
			has_resolved_landing = false
		return
	elif is_carrying_water:
		if is_at_top and can_release_water:
			just_released_cargo_this_frame = true
			waiting_for_down_release = true
			_release_water()
		elif not is_at_top:
			# If lowered with water, winch back up
			target_rope_length = min_rope_length
			is_descending = false
			has_resolved_landing = false
		return

	# Empty hook: SPACE controls both down and up
	if is_at_top:
		# At top -> launch aimed descent downwards!
		_launch_aimed_descent()
	else:
		# Hook is deployed below top -> toggle descent vs ascent
		if is_descending or target_rope_length > current_rope_length:
			# Going down -> pull back UP!
			target_rope_length = min_rope_length
			is_descending = false
			has_resolved_landing = false
			if payload_sprite and payload_sprite.sprite_frames:
				if payload_sprite.sprite_frames.has_animation("default"):
					payload_sprite.play("default")
			print("[Crane] Space: İniş durduruldu, kanca yukarı çekiliyor.")
		else:
			# Going up -> reverse and go back DOWN!
			target_rope_length = max_rope_length
			is_descending = true
			has_resolved_landing = false
			_start_payload_descent()
			print("[Crane] Space: Çıkış durduruldu, kanca tekrar aşağı iniyor.")


func _start_payload_descent() -> void:
	if not payload_sprite or not payload_sprite.sprite_frames:
		return
	if is_turning:
		return
	if is_descending and not has_resolved_landing:
		return

	is_descending = true
	has_resolved_landing = false

	# If carrying cargo or water, maintain hold pose while descending to place it
	if is_carrying_cargo or is_carrying_water:
		if payload_sprite.sprite_frames.has_animation("hold"):
			payload_sprite.play("hold")
	else:
		has_caught_object = false
		if is_event_boost_active or payload_tier >= 2:
			# Boosted: better_catch animasyonu
			if payload_sprite.sprite_frames.has_animation("better_catch"):
				payload_sprite.play("better_catch")
			elif payload_sprite.sprite_frames.has_animation("catch"):
				payload_sprite.play("catch")
		else:
			# Normal / unboosted: catch animasyonu
			if payload_sprite.sprite_frames.has_animation("catch"):
				payload_sprite.play("catch")
			elif payload_sprite.sprite_frames.has_animation("default"):
				payload_sprite.play("default")


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
	if not is_event_boost_active and _rocket_visual:
		_rocket_visual.set_firing(false)

	# CASE A: Currently carrying cargo and lowered onto surface -> Release/Deposit cargo
	if is_carrying_cargo:
		if _check_and_deposit_to_factory() or _check_and_deposit_to_stone_wall() or _check_and_deposit_to_house():
			if auto_retract_after_landing and is_inside_tree():
				var tree := get_tree()
				if tree:
					tree.create_timer(landing_retract_delay).timeout.connect(func():
						if not is_at_top:
							target_rope_length = min_rope_length
					)
			return
		_release_cargo()
		if auto_retract_after_landing and is_inside_tree():
			var tree := get_tree()
			if tree:
				tree.create_timer(landing_retract_delay).timeout.connect(func():
					if not is_at_top:
						target_rope_length = min_rope_length
				)
		return

	# CASE A2: Currently carrying water and lowered onto surface -> Release/Splash water
	if is_carrying_water:
		_release_water()
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
			# Check if caught body is an Event Rock or Upgrade Rock! Consumes it for rocket boost
			if grabbed_body.is_in_group("event_rock") or grabbed_body.is_in_group("upgrade_rock") or grabbed_body.get_meta("is_event_rock", false) or grabbed_body.get_meta("is_upgrade_rock", false):
				var rock_to_consume = grabbed_body
				grabbed_body = null
				is_carrying_cargo = false
				can_release_cargo = false
				is_descending = false
				has_resolved_landing = true

				if rock_to_consume.has_method("play_pickup_sound"):
					rock_to_consume.play_pickup_sound()

				if rock_to_consume.has_method("consume"):
					rock_to_consume.consume()
				else:
					rock_to_consume.queue_free()

				trigger_event_boost(event_boost_duration)

				if auto_retract_after_landing and is_inside_tree():
					var tree := get_tree()
					if tree:
						tree.create_timer(0.08).timeout.connect(func():
							if not is_at_top:
								target_rope_length = min_rope_length
						)
				return

			is_carrying_cargo = true
			can_release_cargo = false
			grabbed_body.set_deferred("freeze", true)
			if payload:
				payload.add_collision_exception_with(grabbed_body)
			cargo_picked_up.emit(grabbed_body)
			if grabbed_body.has_method("play_pickup_sound"):
				grabbed_body.play_pickup_sound()
			_play_payload_catch_sound()
			_trigger_pickup_screen_shake()
			_trigger_hit_stop()
			_update_house_upgrade_pointers()
			_update_wall_pointer()
			_update_factory_pointer()

		# IMMEDIATELY halt descent: rope stops descending when cargo is grasped!
		is_descending = false
		has_resolved_landing = true
		target_rope_length = current_rope_length

		if is_carrying_cargo and payload_sprite.sprite_frames.has_animation("hold"):
			payload_sprite.play("hold")
		elif payload_sprite.sprite_frames.has_animation("default"):
			payload_sprite.play("default")

		# Auto-retract back to top with the caught cargo
		if auto_retract_after_landing and is_inside_tree():
			var tree := get_tree()
			if tree:
				tree.create_timer(0.12).timeout.connect(func():
					if not is_at_top:
						target_rope_length = min_rope_length
				)
	else:
		if payload_sprite and payload_sprite.sprite_frames and payload_sprite.sprite_frames.has_animation("default"):
			payload_sprite.play("default")
		if auto_retract_after_landing and is_inside_tree():
			var tree := get_tree()
			if tree:
				tree.create_timer(landing_retract_delay).timeout.connect(func():
					if not is_at_top:
						target_rope_length = min_rope_length
				)


## Directly gives and locks a cargo item onto the crane hook (e.g. from rock pit)
func pickup_cargo_direct(cargo: RigidBody2D) -> bool:
	if not cargo or not is_instance_valid(cargo):
		return false
	if is_carrying_cargo or is_carrying_water:
		return false

	if cargo.is_in_group("event_rock") or cargo.is_in_group("upgrade_rock") or cargo.get_meta("is_event_rock", false) or cargo.get_meta("is_upgrade_rock", false):
		if cargo.has_method("consume"):
			cargo.consume()
		else:
			cargo.queue_free()
		trigger_event_boost(event_boost_duration)
		if auto_retract_after_landing and is_inside_tree():
			var tree := get_tree()
			if tree:
				tree.create_timer(0.08).timeout.connect(func():
					if not is_at_top:
						target_rope_length = min_rope_length
				)
		return true

	grabbed_body = cargo
	is_carrying_cargo = true
	can_release_cargo = false
	is_descending = false
	has_resolved_landing = true
	target_rope_length = current_rope_length
	cargo.set_deferred("freeze", true)
	if payload:
		payload.add_collision_exception_with(cargo)
	cargo_picked_up.emit(cargo)
	_play_payload_catch_sound()
	_trigger_pickup_screen_shake()
	_trigger_hit_stop()
	_update_house_upgrade_pointers()
	_update_wall_pointer()
	_update_factory_pointer()

	if payload_sprite and payload_sprite.sprite_frames:
		if payload_sprite.sprite_frames.has_animation("hold"):
			payload_sprite.play("hold")
		elif payload_sprite.sprite_frames.has_animation("default"):
			payload_sprite.play("default")

	# Auto-retract back to top with the caught cargo
	if auto_retract_after_landing and is_inside_tree():
		var tree := get_tree()
		if tree:
			tree.create_timer(0.12).timeout.connect(func():
				if not is_at_top:
					target_rope_length = min_rope_length
			)
	return true



# ==============================================================================
# 8. CARGO RELEASE MECHANISM (DOWN KEY ONLY)
# ==============================================================================
func _handle_cargo_release_input() -> void:
	if not is_carrying_cargo and not is_carrying_water:
		prev_release_pressed = false
		return
	if is_turning:
		prev_release_pressed = false
		return
	# Payload bir obje tutmussa ip en yukari (top) kisma cikmadan kesinlikle birakamaz!
	if not is_at_top:
		prev_release_pressed = false
		return

	var is_space_pressed_release: bool = (
		Input.is_key_pressed(KEY_SPACE)
		or (InputMap.has_action("rope_down") and Input.is_action_pressed("rope_down"))
		or (InputMap.has_action("ui_accept") and Input.is_action_pressed("ui_accept"))
		or Input.is_key_pressed(KEY_DOWN)
	)
	var is_down_just_pressed: bool = (
		(is_space_pressed_release and not prev_release_pressed)
		or (InputMap.has_action("rope_down") and Input.is_action_just_pressed("rope_down"))
		or (InputMap.has_action("ui_accept") and Input.is_action_just_pressed("ui_accept"))
	)

	prev_release_pressed = is_space_pressed_release

	if is_down_just_pressed and not waiting_for_down_release:
		if is_carrying_cargo and can_release_cargo:
			just_released_cargo_this_frame = true
			waiting_for_down_release = true
			_release_cargo()
		elif is_carrying_water and can_release_water:
			just_released_cargo_this_frame = true
			waiting_for_down_release = true
			_release_water()


func _release_cargo() -> void:
	if not is_carrying_cargo or not grabbed_body or not is_instance_valid(grabbed_body):
		is_carrying_cargo = false
		grabbed_body = null
		has_caught_object = false
		can_release_cargo = false
		return

	var released_ref: RigidBody2D = grabbed_body

	# 1. Unfreeze physics body so it flies with real gravity and collisions
	released_ref.set_deferred("freeze", false)

	# 2. Inherit crane velocity + generous tangential swing fling momentum if actively moving/swinging
	var release_velocity: Vector2 = Vector2.ZERO
	if is_at_top:
		var swing_dir: Vector2 = Vector2.DOWN.rotated(current_swing_angle)
		var angular_vel: float = swing_angular_velocity
		var tangent_dir: Vector2 = Vector2(-swing_dir.y, swing_dir.x)

		var fling_multiplier: float = fling_multiplier_tier2 if (payload_tier >= 2 or is_event_boost_active) else fling_multiplier_tier1
		var trolley_mult: float = 1.45 if (payload_tier >= 2 or is_event_boost_active) else 1.15
		var tangential_speed: float = (angular_vel * current_rope_length) * fling_multiplier

		var raw_momentum: Vector2 = tangent_dir * tangential_speed + trolley_velocity * trolley_mult

		# If there is real physics momentum (active swing or moving trolley), fling with momentum!
		if absf(angular_vel) > 0.08 or trolley_velocity.length() > 25.0:
			release_velocity = raw_momentum
			# Loft assist: if releasing while swinging upward, add upward fling trajectory
			if (tangent_dir.y * angular_vel) < 0.0:
				release_velocity.y -= absf(tangential_speed) * 0.32

			# Event Rock / Rocket burst boost in the fling direction
			if (payload_tier >= 2 or is_event_boost_active) and release_velocity.length() > 40.0:
				var fling_dir: Vector2 = release_velocity.normalized()
				release_velocity += fling_dir * 180.0
		else:
			# No significant momentum/physics: drop straight down!
			release_velocity = Vector2(0.0, 30.0)
	else:
		if absf(payload.linear_velocity.x) > 40.0:
			release_velocity = Vector2(payload.linear_velocity.x, maxf(payload.linear_velocity.y, 40.0))
		else:
			release_velocity = Vector2(0.0, maxf(payload.linear_velocity.y, 40.0))

	released_ref.linear_velocity = release_velocity
	released_ref.angular_velocity = swing_angular_velocity * (3.2 if payload_tier >= 2 else 2.4)

	# Remove collision exception
	if payload:
		payload.remove_collision_exception_with(released_ref)

	# 3. Clear grabbed reference and carrying state
	var was_house_upgrade_cargo: bool = released_ref.is_in_group("brick") or released_ref.is_in_group("upgrade_rock")
	grabbed_body = null
	is_carrying_cargo = false
	has_caught_object = false
	can_release_cargo = false
	waiting_for_down_release = true
	cargo_released.emit(released_ref)
	_update_house_upgrade_pointers()
	_update_wall_pointer()
	_update_factory_pointer()

	if was_house_upgrade_cargo:
		_monitor_free_upgrade_rock(released_ref)

	# Open hook back to default animation
	if payload_sprite and payload_sprite.sprite_frames and payload_sprite.sprite_frames.has_animation("default"):
		payload_sprite.play("default")

	# Fling juice: camera recoil punch + claw squash recoil
	_trigger_cargo_fling_juice(release_velocity)


func _trigger_cargo_fling_juice(release_vel: Vector2) -> void:
	# Tactile camera punch in throw direction
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam and is_instance_valid(cam):
		var orig_offset: Vector2 = cam.offset
		var punch: Vector2 = - release_vel.normalized() * clampf(release_vel.length() * 0.012, 3.0, 9.0)
		var cam_tween := create_tween()
		cam_tween.tween_property(cam, "offset", orig_offset + punch, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		cam_tween.tween_property(cam, "offset", orig_offset, 0.18).set_trans(Tween.TRANS_SINE)

	# Claw pop / recoil upwards
	if payload_sprite:
		var claw_tween := create_tween()
		claw_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var base_s: Vector2 = payload_sprite.scale
		claw_tween.tween_property(payload_sprite, "scale", base_s * Vector2(0.85, 1.25), 0.08)
		claw_tween.tween_property(payload_sprite, "scale", base_s, 0.15)


# ==============================================================================
# CRANE, TROLLEY & PAYLOAD AUDIO SYSTEM
# ==============================================================================
func _init_crane_audio_players() -> void:
	var sfx_bus: String = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"

	# 1. Payload Catch Audio Player
	_payload_catch_audio_player = AudioStreamPlayer2D.new()
	_payload_catch_audio_player.name = "PayloadCatchPlayer"
	_payload_catch_audio_player.bus = sfx_bus
	_payload_catch_audio_player.volume_db = payload_catch_volume_db
	_payload_catch_audio_player.max_distance = 3000.0
	_payload_catch_audio_player.attenuation = 1.0

	if payload_catch_audio:
		_payload_catch_audio_player.stream = payload_catch_audio
	elif ResourceLoader.exists("res://Sounds/PayloadCatch.wav"):
		_payload_catch_audio_player.stream = load("res://Sounds/PayloadCatch.wav")

	if payload:
		payload.add_child(_payload_catch_audio_player)
	else:
		add_child(_payload_catch_audio_player)

	# 2. Crane Turn Audio Player
	_crane_turn_audio_player = AudioStreamPlayer2D.new()
	_crane_turn_audio_player.name = "CraneTurnPlayer"
	_crane_turn_audio_player.bus = sfx_bus
	_crane_turn_audio_player.volume_db = crane_turn_volume_db
	_crane_turn_audio_player.max_distance = 3500.0
	_crane_turn_audio_player.attenuation = 1.0

	if crane_turn_audio:
		_crane_turn_audio_player.stream = crane_turn_audio
	elif ResourceLoader.exists("res://Sounds/CraneTurn.wav"):
		_crane_turn_audio_player.stream = load("res://Sounds/CraneTurn.wav")

	if visuals:
		visuals.add_child(_crane_turn_audio_player)
	else:
		add_child(_crane_turn_audio_player)

	# 3. Trolley Move Audio Player (Non-positional AudioStreamPlayer for direct, full-volume arcade audio)
	_trolley_move_audio_player = AudioStreamPlayer.new()
	_trolley_move_audio_player.name = "TrolleyMovePlayer"
	_trolley_move_audio_player.bus = sfx_bus
	_trolley_move_audio_player.volume_db = trolley_move_volume_db

	if trolley_move_audio:
		_trolley_move_audio_player.stream = trolley_move_audio
	elif ResourceLoader.exists("res://Sounds/TrolleyMove.wav"):
		_trolley_move_audio_player.stream = load("res://Sounds/TrolleyMove.wav")

	# Enable valid looping for TrolleyMove so continuous movement remains seamless
	if _trolley_move_audio_player.stream is AudioStreamWAV:
		var wav := _trolley_move_audio_player.stream as AudioStreamWAV
		var bytes_per_sample: int = 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
		var channels: int = 2 if wav.stereo else 1
		var total_samples: int = wav.data.size() / max(1, bytes_per_sample * channels)
		if total_samples > 0:
			wav.loop_begin = 0
			wav.loop_end = total_samples
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD

	_trolley_move_audio_player.finished.connect(func():
		if is_trolley_actually_moving and not ButtonsController.is_esc_menu_open and not is_turning:
			_trolley_move_audio_player.play()
	)

	add_child(_trolley_move_audio_player)


func _play_payload_catch_sound() -> void:
	if _payload_catch_audio_player and _payload_catch_audio_player.stream:
		_payload_catch_audio_player.pitch_scale = randf_range(0.96, 1.04)
		_payload_catch_audio_player.play()


func _play_crane_turn_sound() -> void:
	if _crane_turn_audio_player and _crane_turn_audio_player.stream:
		_crane_turn_audio_player.pitch_scale = randf_range(0.97, 1.03)
		_crane_turn_audio_player.play()


func _play_trolley_move_sound() -> void:
	if not _trolley_move_audio_player or not _trolley_move_audio_player.stream:
		return
	if ButtonsController.is_esc_menu_open or is_turning:
		_stop_trolley_move_sound()
		return
	if not _trolley_move_audio_player.playing:
		_trolley_move_audio_player.play()


func _stop_trolley_move_sound() -> void:
	if _trolley_move_audio_player and _trolley_move_audio_player.playing:
		_trolley_move_audio_player.stop()


# ==============================================================================
# WATER INTERACTION, AUDIO & SCOOP SYSTEM
# ==============================================================================
func _init_water_audio_player() -> void:
	var sfx_bus: String = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	_water_audio_player = AudioStreamPlayer2D.new()
	_water_audio_player.name = "WaterSplashPlayer"
	_water_audio_player.bus = sfx_bus
	_water_audio_player.volume_db = water_splash_volume_db
	_water_audio_player.max_distance = 2500.0
	_water_audio_player.attenuation = 1.0

	# Assign custom audio if set, fallback to heavy rain drops if available
	if water_splash_audio:
		_water_audio_player.stream = water_splash_audio
	elif ResourceLoader.exists("res://Sounds/Rain/heavy-rain-drops.wav"):
		_water_audio_player.stream = load("res://Sounds/Rain/heavy-rain-drops.wav")

	if payload:
		payload.add_child(_water_audio_player)
	else:
		add_child(_water_audio_player)


func _play_water_splash_sound(speed: float = 0.0) -> void:
	if not _water_audio_player:
		return
	if _water_splash_cooldown > 0.0:
		return
	_water_splash_cooldown = 0.22

	# Dynamic reload if inspector assigned stream
	if water_splash_audio and _water_audio_player.stream != water_splash_audio:
		_water_audio_player.stream = water_splash_audio

	if not _water_audio_player.stream:
		return

	# Natural subtle pitch variation
	_water_audio_player.pitch_scale = randf_range(0.92, 1.14)
	var bonus_vol: float = clampf((speed - 120.0) * 0.012, -4.0, 4.0)
	_water_audio_player.volume_db = water_splash_volume_db + bonus_vol
	_water_audio_player.play()


func _get_fluid_water() -> FluidWater:
	if _cached_fluid_water and is_instance_valid(_cached_fluid_water):
		return _cached_fluid_water
	if is_inside_tree():
		var tree := get_tree()
		if not tree:
			return null
		var found = tree.get_first_node_in_group("fluid_water")
		if found is FluidWater:
			_cached_fluid_water = found as FluidWater
			return _cached_fluid_water
		var root := tree.current_scene
		if root:
			var fw = root.get_node_or_null("FluidWater")
			if fw is FluidWater:
				_cached_fluid_water = fw as FluidWater
				return _cached_fluid_water
			var child_fw = root.find_child("FluidWater", true, false)
			if child_fw is FluidWater:
				_cached_fluid_water = child_fw as FluidWater
				return _cached_fluid_water
	return null


func _check_water_interaction(delta: float) -> void:
	if not enable_water_interaction or not payload:
		return

	if _water_splash_cooldown > 0.0:
		_water_splash_cooldown = maxf(0.0, _water_splash_cooldown - delta)

	var fw: FluidWater = _get_fluid_water()
	if not fw:
		return

	var payload_pos: Vector2 = payload.global_position
	var scoop_center: Vector2 = payload_pos + Vector2(0.0, 18.0)
	var particles_near: int = fw.count_particles_near(scoop_center, water_scoop_radius)
	var is_in_water: bool = (particles_near > 0)

	# Splash sound on water entry
	if is_in_water and not _was_in_water_prev_frame:
		_play_water_splash_sound(payload.linear_velocity.length())
	_was_in_water_prev_frame = is_in_water

	# CASE 1: Currently carrying water
	if is_carrying_water:
		# Update held water position & velocity
		fw.update_payload_water_pos(scoop_center, payload.linear_velocity)

		# Allow releasing water only after reaching top and releasing down key
		if is_at_top and not can_release_water:
			var down_currently_pressed: bool = (
				(InputMap.has_action("rope_down") and Input.is_action_pressed("rope_down"))
				or Input.is_key_pressed(KEY_DOWN)
				or Input.is_key_pressed(KEY_SPACE)
			)
			if not down_currently_pressed:
				can_release_water = true
		return

	# CASE 2: Empty hook descending into water -> SCOOP / CATCH WATER!
	if not is_carrying_cargo and not is_carrying_water:
		if is_descending and not has_resolved_landing and particles_near >= water_min_scoop_particles:
			var grabbed_count: int = fw.start_payload_water_grab(scoop_center, water_scoop_radius, water_hold_force)
			if grabbed_count > 0:
				is_carrying_water = true
				can_release_water = false
				has_resolved_landing = true
				is_descending = false

				_play_water_splash_sound(payload.linear_velocity.length() + 80.0)
				_play_payload_catch_sound()

				# Play closed claw/hold animation so it holds water like a bucket
				if payload_sprite and payload_sprite.sprite_frames:
					if payload_sprite.sprite_frames.has_animation("hold"):
						payload_sprite.play("hold")
					elif payload_sprite.sprite_frames.has_animation("default"):
						payload_sprite.play("default")

				# Water dip ripple juice & gentle screen shake
				if enable_pickup_shake:
					_trigger_pickup_screen_shake()
				_trigger_hit_stop()


				# Auto-retract back to top with the caught water
				if auto_retract_after_landing and is_inside_tree():
					var tree := get_tree()
					if tree:
						tree.create_timer(0.2).timeout.connect(func():
							if not is_at_top:
								target_rope_length = min_rope_length
						)
				return

		# Stirring displacement when moving through water
		if is_in_water and payload.linear_velocity.length_squared() > 100.0:
			fw.set_payload_stir(true, scoop_center, water_scoop_radius * 0.9, payload.linear_velocity)
		else:
			fw.set_payload_stir(false, Vector2.ZERO, 0.0, Vector2.ZERO)


func _release_water() -> void:
	if not is_carrying_water:
		return

	var fw: FluidWater = _get_fluid_water()
	var release_velocity: Vector2 = Vector2.ZERO

	if is_at_top:
		var swing_dir: Vector2 = Vector2.DOWN.rotated(current_swing_angle)
		var angular_vel: float = swing_angular_velocity
		var tangent_dir: Vector2 = Vector2(-swing_dir.y, swing_dir.x)

		var fling_multiplier: float = fling_multiplier_tier2 if (payload_tier >= 2 or is_event_boost_active) else fling_multiplier_tier1
		var trolley_mult: float = 1.45 if (payload_tier >= 2 or is_event_boost_active) else 1.15
		var tangential_speed: float = (angular_vel * current_rope_length) * fling_multiplier

		release_velocity = tangent_dir * tangential_speed + trolley_velocity * trolley_mult

		# Loft assist: if releasing while swinging upward, add upward fling trajectory
		if (tangent_dir.y * angular_vel) < 0.0:
			release_velocity.y -= absf(tangential_speed) * 0.32

		# Tier 2 / Event Rock rocket burst boost in the fling direction
		if payload_tier >= 2 or is_event_boost_active:
			var fling_dir: Vector2 = release_velocity.normalized()
			if fling_dir == Vector2.ZERO:
				fling_dir = Vector2(float(facing_direction), -0.5).normalized()
			release_velocity += fling_dir * 220.0

		# Ensure minimum satisfying water toss forward
		if release_velocity.length() < 120.0:
			release_velocity = Vector2(float(facing_direction) * 140.0, -70.0)
	else:
		release_velocity = payload.linear_velocity + Vector2(0, 40.0)

	if fw:
		fw.fling_held_water(release_velocity)

	# Play water splash / throw sound
	_play_water_splash_sound(release_velocity.length())

	is_carrying_water = false
	can_release_water = false
	waiting_for_down_release = true

	# Open hook back to default animation
	if payload_sprite and payload_sprite.sprite_frames:
		if payload_sprite.sprite_frames.has_animation("default"):
			payload_sprite.play("default")

	# Fling juice: camera recoil punch + claw squash recoil
	_trigger_cargo_fling_juice(release_velocity)


func _on_payload_body_entered(body: Node) -> void:
	if body is RigidBody2D and body != payload and not is_carrying_cargo and not is_carrying_water:
		has_caught_object = true
		if is_descending and not has_resolved_landing:
			call_deferred("_resolve_landing")
	elif body is StaticBody2D:
		if is_descending and not has_resolved_landing:
			call_deferred("_resolve_landing")


func _is_touching_grabbable_object() -> bool:
	if not payload:
		return false
	if is_carrying_cargo or is_carrying_water:
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
			var pit = tree.get_first_node_in_group("rock_pit")
			if pit and is_instance_valid(pit):
				var diff: Vector2 = pit.global_position - payload.global_position
				if absf(diff.x) <= 80.0 and diff.y >= -50.0 and diff.y <= 65.0:
					return true
			for node in tree.get_nodes_in_group("event_rock"):
				if node is Node2D and node != payload and node != grabbed_body:
					var diff: Vector2 = node.global_position - payload.global_position
					if absf(diff.x) <= 60.0 and diff.y >= -20.0 and diff.y <= 85.0:
						return true
			for node in tree.get_nodes_in_group("upgrade_rock"):
				if node is Node2D and node != payload and node != grabbed_body:
					var diff: Vector2 = node.global_position - payload.global_position
					if absf(diff.x) <= 60.0 and diff.y >= -20.0 and diff.y <= 85.0:
						return true
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
			var pit = tree.get_first_node_in_group("rock_pit")
			if pit and is_instance_valid(pit) and pit.has_method("dispense_rock_to_crane"):
				var diff: Vector2 = pit.global_position - payload.global_position
				if absf(diff.x) <= 80.0 and diff.y >= -50.0 and diff.y <= 65.0:
					var mined_rock: RigidBody2D = pit.dispense_rock_to_crane(self)
					if mined_rock:
						return mined_rock
			for node in tree.get_nodes_in_group("event_rock"):
				if node is RigidBody2D and node != payload and node != grabbed_body:
					var diff: Vector2 = node.global_position - payload.global_position
					if absf(diff.x) <= 60.0 and diff.y >= -20.0 and diff.y <= 85.0:
						return node
			for node in tree.get_nodes_in_group("upgrade_rock"):
				if node is RigidBody2D and node != payload and node != grabbed_body:
					var diff: Vector2 = node.global_position - payload.global_position
					if absf(diff.x) <= 60.0 and diff.y >= -20.0 and diff.y <= 85.0:
						return node
			for node in tree.get_nodes_in_group("brick"):
				if node is RigidBody2D and node != payload and node != grabbed_body:
					var diff: Vector2 = node.global_position - payload.global_position
					if absf(diff.x) <= 60.0 and diff.y >= -20.0 and diff.y <= 85.0:
						return node
			for node in tree.get_nodes_in_group("rock"):
				if node is RigidBody2D and node != payload and node != grabbed_body:
					var diff: Vector2 = node.global_position - payload.global_position
					if absf(diff.x) <= 60.0 and diff.y >= -20.0 and diff.y <= 85.0:
						return node
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
		if (is_event_boost_active or payload_tier >= 2) and payload_sprite.sprite_frames.has_animation("better_catch"):
			payload_sprite.play("better_catch")
		elif is_descending and not has_resolved_landing:
			if payload_sprite.sprite_frames.has_animation("catch_loop"):
				payload_sprite.play("catch_loop")
			elif payload_sprite.sprite_frames.has_animation("catch"):
				payload_sprite.play("catch")
		elif not is_descending and not is_carrying_cargo:
			if payload_sprite.sprite_frames.has_animation("default"):
				payload_sprite.play("default")
	elif current_anim == &"better_catch":
		if is_descending and not has_resolved_landing:
			payload_sprite.play("better_catch")
		elif not is_descending and not is_carrying_cargo:
			if payload_sprite.sprite_frames.has_animation("default"):
				payload_sprite.play("default")
	elif current_anim == &"catch":
		if is_descending and not has_resolved_landing:
			if is_event_boost_active and payload_sprite.sprite_frames.has_animation("better_catch"):
				payload_sprite.play("better_catch")
			else:
				payload_sprite.play("catch")
		elif not is_descending and not is_carrying_cargo:
			if payload_sprite.sprite_frames.has_animation("default"):
				payload_sprite.play("default")
	elif current_anim == &"hold":
		is_descending = false
		if not is_carrying_cargo and payload_sprite.sprite_frames.has_animation("default"):
			payload_sprite.play("default")
		if auto_retract_after_landing and not is_at_top:
			target_rope_length = min_rope_length


# ==============================================================================
# 9. DIRECTION TURN (Q: LEFT, E: RIGHT)
# ==============================================================================
func _handle_flip_input() -> void:
	if not is_at_top:
		return
	if just_released_cargo_this_frame:
		return
	if ButtonsController.is_esc_menu_open or is_turning:
		return

	# Q: Turn Left (face left: -1), E: Turn Right (face right: 1)
	var want_turn_left: bool = (
		Input.is_key_pressed(KEY_Q)
		or (InputMap.has_action("crane_turn_left") and Input.is_action_just_pressed("crane_turn_left"))
	)
	var want_turn_right: bool = (
		Input.is_key_pressed(KEY_E)
		or (InputMap.has_action("crane_turn_right") and Input.is_action_just_pressed("crane_turn_right"))
	)

	if want_turn_left and facing_direction != -1:
		_start_turn()
	elif want_turn_right and facing_direction != 1:
		_start_turn()


func _start_turn() -> void:
	is_turning = true
	_is_turn_reversing = false
	_stop_trolley_move_sound()
	_play_crane_turn_sound()

	# Apply massive turn swing impulse in the turn direction
	var kick: float = turn_swing_kick_tier2 if payload_tier >= 2 else turn_swing_kick_tier1
	swing_angular_velocity += float(facing_direction) * kick

	# Smoothly tween trolley to the exact opposite position across mast within 0.38 second
	if _trolley_tween and _trolley_tween.is_valid():
		_trolley_tween.kill()

	if trolley_pivot:
		var current_offset: float = trolley_pivot.position.x - mast_local_x
		var target_x: float = mast_local_x - current_offset

		if trolley_sprite and trolley_sprite.sprite_frames and trolley_sprite.sprite_frames.has_animation("move"):
			trolley_sprite.play("move")

		_trolley_tween = create_tween()
		_trolley_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_trolley_tween.tween_property(trolley_pivot, "position:x", target_x, 0.38)
		_trolley_tween.tween_callback(func():
			if trolley_sprite and trolley_sprite.sprite_frames and trolley_sprite.sprite_frames.has_animation("default"):
				trolley_sprite.play("default")
		)

	# 1. Play crane body turn animation forward
	if crane_body_sprite and crane_body_sprite.sprite_frames and crane_body_sprite.sprite_frames.has_animation("turn"):
		crane_body_sprite.play("turn")
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
		# Controlled swing impulse as the crane boom completes the turn
		var phase2_kick: float = (turn_swing_kick_tier2 if payload_tier >= 2 else turn_swing_kick_tier1) * 0.6
		swing_angular_velocity += -float(facing_direction) * phase2_kick

		if crane_body_sprite and crane_body_sprite.sprite_frames and crane_body_sprite.sprite_frames.has_animation("turn"):
			var last_frame: int = crane_body_sprite.sprite_frames.get_frame_count("turn") - 1
			crane_body_sprite.frame = last_frame
			crane_body_sprite.play_backwards("turn")
		else:
			_complete_turn()
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


func _complete_turn() -> void:
	is_turning = false
	_is_turn_reversing = false

	if _trolley_tween and _trolley_tween.is_running():
		_trolley_tween.kill()

	_update_trolley_position()

	if crane_body_sprite and crane_body_sprite.sprite_frames and crane_body_sprite.sprite_frames.has_animation("default"):
		crane_body_sprite.play("default")

	if trolley_sprite and trolley_sprite.sprite_frames and trolley_sprite.sprite_frames.has_animation("default"):
		trolley_sprite.play("default")


func _apply_flip_state(dir_x: float) -> void:
	if visuals:
		visuals.scale.x = dir_x

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


func _init_rope_physics() -> void:
	rope_points.clear()
	rope_prev_points.clear()
	var origin_pos: Vector2 = _get_rope_origin()
	var target_end: Vector2 = payload.global_position if payload else (origin_pos + Vector2.DOWN * current_rope_length)
	var seg_count: int = max(rope_segments, 4)
	for i in range(seg_count):
		var t: float = float(i) / float(seg_count - 1)
		var pt: Vector2 = origin_pos.lerp(target_end, t)
		rope_points.append(pt)
		rope_prev_points.append(pt)


func _update_rope_physics(delta: float) -> void:
	var seg_count: int = max(rope_segments, 4)
	if delta <= 0.0 or rope_points.size() != seg_count:
		_init_rope_physics()
		return

	var origin_pos: Vector2 = _get_rope_origin()
	var payload_pos: Vector2 = payload.global_position if payload else (origin_pos + Vector2.DOWN.rotated(current_swing_angle) * current_rope_length)

	# Pin endpoints strictly
	rope_points[0] = origin_pos
	rope_prev_points[0] = origin_pos
	rope_points[seg_count - 1] = payload_pos
	rope_prev_points[seg_count - 1] = payload_pos

	# Target rest segment length based on instantaneous active cable length
	var segment_len: float = current_rope_length / float(seg_count - 1)

	# Atmospheric forces on cable (gravity + subtle upper breeze)
	var cable_gravity: Vector2 = Vector2.DOWN * 850.0

	# Verlet integration step for free intermediate points
	var delta_sq: float = delta * delta
	for i in range(1, seg_count - 1):
		var cur_pos: Vector2 = rope_points[i]
		var prev_pos: Vector2 = rope_prev_points[i]
		var vel: Vector2 = (cur_pos - prev_pos) * rope_damping

		# Prevent unstable numerical velocity blow-up under extreme frame hitching
		if vel.length_squared() > 160000.0:
			vel = vel.normalized() * 400.0

		var next_pos: Vector2 = cur_pos + vel + cable_gravity * delta_sq
		rope_prev_points[i] = cur_pos
		rope_points[i] = next_pos

	# Distance constraint relaxation passes (enforces realistic steel cable stiffness)
	for iter in range(rope_constraint_iterations):
		rope_points[0] = origin_pos
		rope_points[seg_count - 1] = payload_pos

		for i in range(seg_count - 1):
			var p1: Vector2 = rope_points[i]
			var p2: Vector2 = rope_points[i + 1]
			var delta_vec: Vector2 = p2 - p1
			var dist: float = delta_vec.length()

			if dist > 0.0001:
				var diff: float = (dist - segment_len) / dist
				if i == 0:
					rope_points[i + 1] -= delta_vec * diff
				elif i + 1 == seg_count - 1:
					rope_points[i] += delta_vec * diff
				else:
					rope_points[i] += delta_vec * (0.5 * diff)
					rope_points[i + 1] -= delta_vec * (0.5 * diff)

	# Ensure endpoints stay strictly anchored after relaxation
	rope_points[0] = origin_pos
	rope_points[seg_count - 1] = payload_pos


func _update_rope_visual() -> void:
	if not line_2d or not trolley_pivot or not payload:
		return

	var seg_count: int = max(rope_segments, 4)
	if rope_points.size() != seg_count:
		_init_rope_physics()

	line_2d.clear_points()
	for pt in rope_points:
		line_2d.add_point(line_2d.to_local(pt))


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


# ==============================================================================
# 12. PAYLOAD TIER UPGRADES & STONE WALL DEPOSIT
# ==============================================================================
func set_payload_tier(tier: int) -> void:
	payload_tier = clampi(tier, 1, 2)
	if payload_tier == 2 or is_event_boost_active:
		trolley_speed = trolley_speed_tier2
		rope_winch_speed = rope_winch_speed_tier2
		swing_max_angle_deg = event_boost_max_angle_deg
		pendulum_gravity = 800.0
		pendulum_damping = 0.95
		swing_inertia_scale = swing_inertia_tier2
		turn_swing_kick = turn_swing_kick_tier2
		print("[Crane] Payload Tier 2 / Event Boost Aktif! (Trolley: ", trolley_speed, "px/s, Winch: ", rope_winch_speed, "px/s, Turn Kick: ", turn_swing_kick, ").")
	else:
		trolley_speed = trolley_speed_tier1
		rope_winch_speed = rope_winch_speed_tier1
		swing_max_angle_deg = 52.0
		pendulum_gravity = 840.0
		pendulum_damping = 1.05
		swing_inertia_scale = swing_inertia_tier1
		turn_swing_kick = turn_swing_kick_tier1
		if _rocket_visual:
			_rocket_visual.set_firing(false)
		print("[Crane] Payload Tier 1 Standart (Trolley: ", trolley_speed, "px/s, Winch: ", rope_winch_speed, "px/s, Turn Kick: ", turn_swing_kick, ").")


func trigger_event_boost(duration: float = -1.0) -> void:
	var boost_time: float = duration if duration > 0.0 else event_boost_duration
	is_event_boost_active = true
	_event_boost_timer = boost_time
	set_payload_tier(2)

	if payload_sprite and payload_sprite.sprite_frames and payload_sprite.sprite_frames.has_animation("better_catch"):
		payload_sprite.play("better_catch")

	if _rocket_visual:
		_rocket_visual.set_firing(true)
		_rocket_visual.flame_scale = 1.35

	_play_event_boost_pickup_effect()
	print("[Crane] ★ EVENT ROCK BOOST AKTİF! ", boost_time, " saniye boyunca yüksek güçlü roket fiziği ve hızlandırma devrede.")


func _end_event_boost() -> void:
	is_event_boost_active = false
	_event_boost_timer = 0.0
	set_payload_tier(1)

	if _rocket_visual:
		_rocket_visual.set_firing(false)

	if payload_sprite and payload_sprite.sprite_frames:
		if is_carrying_cargo and payload_sprite.sprite_frames.has_animation("hold"):
			payload_sprite.play("hold")
		elif is_descending and payload_sprite.sprite_frames.has_animation("catch"):
			payload_sprite.play("catch")
		elif payload_sprite.sprite_frames.has_animation("default"):
			payload_sprite.play("default")

	print("[Crane] Event Rock boost süresi tamamlandı. Standart fiziğe dönüldü.")


func _play_event_boost_pickup_effect() -> void:
	_play_payload_catch_sound()
	_trigger_pickup_screen_shake()
	_trigger_hit_stop(hit_stop_duration * 1.25)

	if payload_sprite:
		var pop := create_tween()
		pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(payload_sprite, "scale", payload_sprite.scale * 1.35, 0.14)
		pop.tween_property(payload_sprite, "scale", payload_sprite.scale, 0.20)

	if payload:
		var flash := create_tween()
		flash.tween_property(payload, "modulate", Color(0.2, 1.8, 2.0, 1.0), 0.1)
		flash.tween_property(payload, "modulate", Color.WHITE, 0.25)


func upgrade_payload() -> bool:
	trigger_event_boost(event_boost_duration)
	return true


func _check_and_deposit_to_stone_wall() -> bool:
	if not grabbed_body or not is_instance_valid(grabbed_body):
		return false
	if not grabbed_body.is_in_group("brick"):
		return false # Only bricks upgrade the wall
	var tree := get_tree()
	if not tree:
		return false
	var wall = tree.get_first_node_in_group("stone_wall")
	if not wall or not is_instance_valid(wall) or (not wall.has_method("place_brick") and not wall.has_method("place_rock")):
		return false

	var wall_top_y_world: float = wall.global_position.y
	if wall.has_method("get_wall_top_y_local"):
		wall_top_y_world += wall.get_wall_top_y_local() * wall.scale.y

	var diff: Vector2 = grabbed_body.global_position - Vector2(wall.global_position.x, wall_top_y_world)
	# Check horizontal alignment within wall width and near or slightly above the rising top surface
	if absf(diff.x) <= 75.0 * wall.scale.x and diff.y >= -50.0 and diff.y <= 100.0:
		var brick_to_place: RigidBody2D = grabbed_body
		_release_cargo()
		if wall.has_method("place_brick"):
			wall.place_brick(brick_to_place)
		else:
			wall.place_rock(brick_to_place)
		return true
	return false


func _check_and_deposit_to_factory() -> bool:
	if not grabbed_body or not is_instance_valid(grabbed_body):
		return false
	if not grabbed_body.is_in_group("rock") or grabbed_body.is_in_group("brick") or grabbed_body.is_in_group("upgrade_rock"):
		return false
	var tree := get_tree()
	if not tree:
		return false
	var factory = tree.get_first_node_in_group("factory")
	if not factory and tree.current_scene:
		factory = tree.current_scene.find_child("factory", true, false)
	if not factory or not is_instance_valid(factory) or not factory.has_method("accept_rock"):
		return false
	if "is_producing" in factory and factory.is_producing:
		return false

	var diff: Vector2 = grabbed_body.global_position - factory.global_position
	if absf(diff.x) <= 90.0 and diff.y >= -80.0 and diff.y <= 90.0:
		var rock_to_feed: RigidBody2D = grabbed_body
		_release_cargo()
		factory.accept_rock(rock_to_feed)
		return true
	return false


func _check_and_deposit_to_house() -> bool:
	if not grabbed_body or not is_instance_valid(grabbed_body):
		return false
	if not grabbed_body.is_in_group("brick") and not grabbed_body.is_in_group("upgrade_rock"):
		return false
	var tree := get_tree()
	if not tree:
		return false

	var houses := tree.get_nodes_in_group("house")
	for h in houses:
		if not is_instance_valid(h):
			continue
		var house = h
		if ("is_destroyed" in house and house.is_destroyed) or ("current_level" in house and "max_level" in house and house.current_level >= house.max_level):
			continue
		if not house.has_method("get_bounds"):
			continue

		var bounds: Dictionary = house.get_bounds()
		var rock_pos := grabbed_body.global_position
		# Check if rock is within horizontal bounds of the house and near/above roof
		var within_x: bool = rock_pos.x >= bounds.left - 30.0 and rock_pos.x <= bounds.right + 30.0
		var within_y: bool = rock_pos.y >= bounds.top - 80.0 and rock_pos.y <= bounds.bottom + 30.0

		if within_x and within_y:
			var rock_to_consume: RigidBody2D = grabbed_body
			_release_cargo()
			if rock_to_consume.has_method("consume_for_house"):
				rock_to_consume.consume_for_house(house)
			else:
				house.upgrade()
				_disintegrate_upgrade_rock(rock_to_consume)
			_update_house_upgrade_pointers()
			_update_wall_pointer()
			_update_factory_pointer()
			print("[Crane] Tuğla (Brick) başarıyla ", house.name, " evine verildi! Yeni seviye: Lv.", house.current_level)
			return true
	return false


func _disintegrate_upgrade_rock(rock_body: RigidBody2D) -> void:
	if not is_instance_valid(rock_body):
		return
	rock_body.set_deferred("freeze", true)
	rock_body.remove_from_group("rock")
	rock_body.remove_from_group("upgrade_rock")
	rock_body.remove_from_group("cargo")
	rock_body.remove_from_group("grabbable")

	var tw := rock_body.create_tween().set_parallel(true)
	tw.tween_property(rock_body, "scale", rock_body.scale * 1.4, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(rock_body, "modulate", Color(2.0, 2.0, 1.0, 0.0), 0.25)
	tw.chain().tween_callback(func():
		if is_instance_valid(rock_body):
			rock_body.queue_free()
	)


func _monitor_free_upgrade_rock(rock: RigidBody2D) -> void:
	if not is_instance_valid(rock):
		return
	var tree := get_tree()
	if not tree:
		return
	var tw := rock.create_tween()
	for i in range(40):
		tw.tween_interval(0.1)
		tw.tween_callback(func():
			if not is_instance_valid(rock) or rock.is_queued_for_deletion():
				return
			var houses := tree.get_nodes_in_group("house")
			for h in houses:
				if not is_instance_valid(h):
					continue
				var house = h
				if ("is_destroyed" in house and house.is_destroyed) or ("current_level" in house and "max_level" in house and house.current_level >= house.max_level):
					continue
				if not house.has_method("get_bounds"):
					continue
				var bounds: Dictionary = house.get_bounds()
				var pos := rock.global_position
				if pos.x >= bounds.left - 25.0 and pos.x <= bounds.right + 25.0 and pos.y >= bounds.top - 45.0 and pos.y <= bounds.bottom + 10.0:
					if rock.has_method("consume_for_house"):
						rock.consume_for_house(house)
					else:
						house.upgrade()
						_disintegrate_upgrade_rock(rock)
					print("[Crane] Düşen Upgrade Rock ", house.name, " evine çarptı ve evi yükseltti!")
					return
		)


func _update_house_upgrade_pointers() -> void:
	var holding_upgrade_item: bool = is_carrying_cargo and grabbed_body != null and is_instance_valid(grabbed_body) and (grabbed_body.is_in_group("brick") or grabbed_body.is_in_group("upgrade_rock"))
	var tree := get_tree()
	if not tree:
		return
	var hm = tree.get_first_node_in_group("houses_manager")
	if not hm and tree.current_scene:
		hm = tree.current_scene.find_child("Houses", true, false)
	if hm and hm.has_method("set_upgrade_pointers_visible"):
		hm.set_upgrade_pointers_visible(holding_upgrade_item)
	else:
		for h in tree.get_nodes_in_group("house"):
			if is_instance_valid(h) and h.has_method("set_pointer_visible"):
				h.set_pointer_visible(holding_upgrade_item)


func _update_wall_pointer() -> void:
	var holding_brick: bool = is_carrying_cargo and grabbed_body != null and is_instance_valid(grabbed_body) and grabbed_body.is_in_group("brick")
	var tree := get_tree()
	if not tree:
		return
	var wall = tree.get_first_node_in_group("stone_wall")
	if not wall and tree.current_scene:
		wall = tree.current_scene.find_child("StoneWall", true, false)
	if wall and is_instance_valid(wall) and wall.has_method("set_pointer_visible"):
		wall.set_pointer_visible(holding_brick)


func _update_factory_pointer() -> void:
	var tree := get_tree()
	if not tree:
		return
	var factory = tree.get_first_node_in_group("factory")
	if not factory and tree.current_scene:
		factory = tree.current_scene.find_child("factory", true, false)
	if not factory or not is_instance_valid(factory):
		return

	# Only raw rock triggers the factory pointer (not brick, not upgrade rock)
	var holding_raw_rock: bool = is_carrying_cargo and grabbed_body != null and is_instance_valid(grabbed_body) and grabbed_body.is_in_group("rock") and not grabbed_body.is_in_group("brick") and not grabbed_body.is_in_group("upgrade_rock")

	if holding_raw_rock:
		if factory.has_method("show_first_rock_pointer"):
			factory.show_first_rock_pointer()
	else:
		if factory.has_method("hide_pointer_temporarily"):
			factory.hide_pointer_temporarily()


var _camera_shake_tween: Tween = null
var _claw_squash_tween: Tween = null


func _trigger_pickup_screen_shake() -> void:
	if not enable_pickup_shake:
		return

	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam and is_instance_valid(cam):
		if _camera_shake_tween and _camera_shake_tween.is_valid():
			_camera_shake_tween.kill()
		cam.offset = Vector2.ZERO
		_camera_shake_tween = create_tween()
		var steps: int = 7
		var step_dur: float = pickup_shake_duration / float(steps)
		for i in range(steps):
			var damp: float = pow(1.0 - (float(i) / float(steps)), 1.4)
			var shake_vec := Vector2(
				randf_range(-pickup_shake_intensity, pickup_shake_intensity) * damp,
				randf_range(-pickup_shake_intensity * 0.8, pickup_shake_intensity * 0.8) * damp
			)
			_camera_shake_tween.tween_property(cam, "offset", shake_vec, step_dur).set_trans(Tween.TRANS_SINE)
		_camera_shake_tween.tween_property(cam, "offset", Vector2.ZERO, step_dur * 0.5)
	else:
		# Fallback if camera is not active: shake the scene root
		var root_node := get_tree().current_scene
		if root_node and is_instance_valid(root_node):
			var orig_pos: Vector2 = root_node.position
			var tween := create_tween()
			var steps: int = 7
			var step_dur: float = pickup_shake_duration / float(steps)
			for i in range(steps):
				var damp: float = pow(1.0 - (float(i) / float(steps)), 1.4)
				var shake_vec := Vector2(
					randf_range(-pickup_shake_intensity, pickup_shake_intensity) * damp,
					randf_range(-pickup_shake_intensity * 0.8, pickup_shake_intensity * 0.8) * damp
				)
				tween.tween_property(root_node, "position", orig_pos + shake_vec, step_dur).set_trans(Tween.TRANS_SINE)
			tween.tween_property(root_node, "position", orig_pos, step_dur * 0.5)

	# Tactile squash-and-stretch on the hook claw itself for extra impact feel
	if payload_sprite:
		if _claw_squash_tween and _claw_squash_tween.is_valid():
			_claw_squash_tween.kill()
		_claw_squash_tween = create_tween()
		_claw_squash_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var base_s: Vector2 = Vector2(2.6953125, 2.6953125) if payload_sprite.scale.x > 2.0 else Vector2.ONE
		_claw_squash_tween.tween_property(payload_sprite, "scale", base_s * Vector2(1.25, 0.78), 0.08)
		_claw_squash_tween.tween_property(payload_sprite, "scale", base_s * Vector2(0.92, 1.08), 0.10)
		_claw_squash_tween.tween_property(payload_sprite, "scale", base_s, 0.14)


func _trigger_hit_stop(duration_sec: float = -1.0) -> void:
	if not enable_hit_stop:
		return
	var dur: float = hit_stop_duration if duration_sec < 0.0 else duration_sec
	if dur <= 0.0:
		return
	Engine.time_scale = hit_stop_time_scale
	var tree := get_tree()
	if tree:
		tree.create_timer(dur, true, false, true).timeout.connect(func():
			Engine.time_scale = 1.0
		)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


## Toggles the aim cursor visibility on/off
func toggle_aim_cursor() -> bool:
	enable_aim_cursor = not enable_aim_cursor
	if _aim_trajectory:
		_aim_trajectory.show_cursor = enable_aim_cursor
	print("[Crane] Aim cursor toggled: ", enable_aim_cursor)
	return enable_aim_cursor


## Sets the aim cursor enabled state
func set_aim_cursor_enabled(enabled: bool) -> void:
	enable_aim_cursor = enabled
	if _aim_trajectory:
		_aim_trajectory.show_cursor = enabled
