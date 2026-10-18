extends RigidBody2D
class_name UpgradeRock

## UpgradeRock: Enderpearl rock produced by Factory with 30% probability.
## When thrown or delivered to a house, upgrades the house level by 1 (up to max level 5).
## Single-use: consumed upon upgrading a house.

signal house_upgraded(house: Node2D, new_level: int)

var is_consumed: bool = false
var _pulse_tween: Tween = null

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")


func _ready() -> void:
	add_to_group("rock")
	add_to_group("upgrade_rock")
	add_to_group("cargo")
	add_to_group("grabbable")
	set_meta("is_upgrade_rock", true)

	contact_monitor = true
	max_contacts_reported = 4
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_start_subtle_glow()


func _start_subtle_glow() -> void:
	if not sprite:
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(sprite, "scale", sprite.scale * 1.08, 0.4).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(sprite, "scale", sprite.scale, 0.4).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node) -> void:
	if is_consumed:
		return
	var house := _find_house_node(body)
	if house and is_instance_valid(house):
		consume_for_house(house)


func _find_house_node(node: Node) -> Node2D:
	if not node:
		return null
	if node.is_in_group("house") and node is Node2D:
		return node as Node2D
	var p := node.get_parent()
	if p and p.is_in_group("house") and p is Node2D:
		return p as Node2D
	return null


## Upgrades target house and consumes this upgrade rock (single-use)
func consume_for_house(house: Node2D) -> bool:
	if is_consumed:
		return false
	if not house or not is_instance_valid(house):
		return false
	if ("is_destroyed" in house and house.is_destroyed) or ("current_level" in house and "max_level" in house and house.current_level >= house.max_level):
		return false

	is_consumed = true
	set_deferred("freeze", true)
	remove_from_group("rock")
	remove_from_group("upgrade_rock")
	remove_from_group("cargo")
	remove_from_group("grabbable")

	# Upgrade the house!
	var success: bool = house.upgrade()
	if not success:
		is_consumed = false
		set_deferred("freeze", false)
		add_to_group("rock")
		add_to_group("upgrade_rock")
		add_to_group("cargo")
		add_to_group("grabbable")
		return false

	house_upgraded.emit(house, house.current_level)
	print("[UpgradeRock] Enderpearl ", house.name, " evini yükseltti! (Lv.", house.current_level, "/", house.max_level, ")")

	_play_consume_effect()
	return true


func _play_consume_effect() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", scale * 1.45, 0.16)
	tw.tween_property(self, "modulate", Color(1.5, 2.5, 2.0, 0.0), 0.22)
	tw.chain().tween_callback(func():
		queue_free()
	)
