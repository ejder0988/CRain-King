extends RigidBody2D
class_name EventRock

## EventRock: Rare, high-energy diamond fuel rock produced by Factory or game events.
## 1. Disappears (disintegrates) if not picked up / used by the crane within 5 seconds.
## 2. When grabbed by the crane's payload, it is consumed as rocket fuel, granting
##    a 10-15s high-speed rocket-guided boost with dual cyan thruster flames!
## 3. Does NOT block water particles (flows freely like houses and rocks).

signal expired()
signal consumed()

@export_group("Event Rock Settings")
## Lifetime in seconds before this rock disintegrates if unused (Default: 5.0s)
@export var lifetime: float = 5.0
## Enable visual countdown ring indicator around the rock
@export var show_countdown_ring: bool = true
## Cyan / electric blue theme color
@export var theme_color: Color = Color(0.0, 0.95, 1.0, 1.0)
## Warning color when time is nearly exhausted
@export var warning_color: Color = Color(1.0, 0.35, 0.2, 1.0)

var time_remaining: float = 5.0
var is_consumed: bool = false
var is_expired: bool = false
var is_grabbed: bool = false

var _pulse_tween: Tween = null
var _original_sprite_scale: Vector2 = Vector2.ONE
var _flash_timer: float = 0.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")


func _ready() -> void:
	add_to_group("rock")
	add_to_group("event_rock")
	add_to_group("cargo")
	add_to_group("grabbable")
	set_meta("is_event_rock", true)

	time_remaining = lifetime

	if sprite:
		_original_sprite_scale = sprite.scale

	contact_monitor = true
	max_contacts_reported = 4

	_register_water_exception()
	_start_subtle_glow()


func _register_water_exception() -> void:
	var tree := get_tree()
	if not tree:
		return
	var fluid = tree.get_first_node_in_group("fluid_water")
	if fluid and fluid.has_method("add_collision_exception"):
		fluid.add_collision_exception(self)


func _start_subtle_glow() -> void:
	if not sprite:
		return
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(sprite, "scale", _original_sprite_scale * 1.12, 0.35).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(sprite, "scale", _original_sprite_scale, 0.35).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	if is_consumed or is_expired:
		return

	# Only count down when sitting in the world (not yet picked up by crane)
	if not is_grabbed:
		time_remaining -= delta
		queue_redraw()

		# Urgent flashing pulse during final 2 seconds
		if time_remaining <= 2.0 and sprite:
			_flash_timer += delta * (14.0 if time_remaining <= 1.0 else 8.0)
			var flash: float = (sin(_flash_timer) + 1.0) * 0.5
			sprite.modulate = Color.WHITE.lerp(warning_color, flash * 0.85)

		if time_remaining <= 0.0:
			time_remaining = 0.0
			disintegrate()


func _draw() -> void:
	if not show_countdown_ring or is_consumed or is_expired or is_grabbed:
		return

	var progress: float = clampf(time_remaining / lifetime, 0.0, 1.0)
	var radius: float = 34.0
	var ring_col: Color = warning_color.lerp(theme_color, clampf(progress * 1.5, 0.0, 1.0))
	ring_col.a = 0.85

	# Background faint circle
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(ring_col.r, ring_col.g, ring_col.b, 0.22), 2.0, true)

	# Active countdown arc (draining clockwise)
	var start_angle: float = -PI * 0.5
	var end_angle: float = start_angle + TAU * progress
	if progress > 0.01:
		draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 32, ring_col, 3.2, true)


## Called when the 5-second timer runs out without being picked up
func disintegrate() -> void:
	if is_expired or is_consumed:
		return
	is_expired = true
	expired.emit()

	# Remove from groups and disable collisions immediately
	remove_from_group("rock")
	remove_from_group("event_rock")
	remove_from_group("cargo")
	remove_from_group("grabbable")
	set_deferred("freeze", true)
	collision_layer = 0
	collision_mask = 0

	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	print("[EventRock] Süre doldu! (5s içinde kullanılmadı) Event Rock yok oldu.")

	# Disintegration puff / pop tween
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", scale * 1.5, 0.18)
	tw.tween_property(self, "modulate", Color(0.2, 0.9, 1.0, 0.0), 0.22)
	tw.chain().tween_callback(queue_free)


## Consumes the rock when grabbed by crane payload, triggering rocket boost
func consume() -> void:
	if is_consumed or is_expired:
		return
	is_consumed = true
	consumed.emit()

	remove_from_group("rock")
	remove_from_group("event_rock")
	remove_from_group("cargo")
	remove_from_group("grabbable")
	set_deferred("freeze", true)
	collision_layer = 0
	collision_mask = 0

	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	print("[EventRock] Crane payload tarafından alındı! Yakıt olarak tüketiliyor.")

	# Fast pop into payload
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", scale * 0.1, 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(queue_free)
