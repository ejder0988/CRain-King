extends RigidBody2D
class_name Rock

## Rock: Heavy stone cargo produced by the Factory.
## Can be picked up by the Crane and deposited onto the StoneWall to build flood defenses.

@export var is_spawned_animated: bool = true

func _ready() -> void:
	add_to_group("rock")
	add_to_group("cargo")
	add_to_group("grabbable")
	contact_monitor = true
	max_contacts_reported = 4
	collision_layer = 1
	collision_mask = 1

	if is_spawned_animated:
		_play_spawn_effect()


func _play_spawn_effect() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		var target_scale := sprite.scale
		sprite.scale = target_scale * 0.2
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", target_scale, 0.3)
