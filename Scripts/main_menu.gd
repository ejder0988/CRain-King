extends Control

## Main menu controller managing entrance animation and smooth transition to menu items.

@export_group("Transition Settings")
@export var transition_duration: float = 0.6  ## Duration of smooth fade transition to menu items

@onready var entrance_node: Control = _find_entrance_node()
@onready var animation_player: AnimationPlayer = _find_animation_player()
@onready var menu_items: Control = _find_menu_items()


func _find_entrance_node() -> Control:
	if has_node("Entrance"):
		return get_node("Entrance") as Control
	elif has_node("Enterance"):
		return get_node("Enterance") as Control
	return null


func _find_animation_player() -> AnimationPlayer:
	if has_node("Entrance/AnimationPlayer"):
		return get_node("Entrance/AnimationPlayer") as AnimationPlayer
	elif has_node("Enterance/AnimationPlayer"):
		return get_node("Enterance/AnimationPlayer") as AnimationPlayer
	return null


func _find_menu_items() -> Control:
	if has_node("MenuItems"):
		return get_node("MenuItems") as Control
	elif has_node("CanvasLayer"):
		return get_node("CanvasLayer") as Control
	return null


func _ready() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var already_played: bool = false
	if gm and "has_entrance_played" in gm:
		already_played = gm.has_entrance_played

	if already_played:
		_show_menu_directly()
	else:
		_play_entrance_sequence()


func _show_menu_directly() -> void:
	# Hide entrance immediately so menu items are seen directly without delay
	if entrance_node:
		entrance_node.visible = false
	if menu_items:
		menu_items.visible = true
		menu_items.modulate = Color(1, 1, 1, 1)


func _play_entrance_sequence() -> void:
	# Mark as played in GameManager so subsequent visits bypass the entrance
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and "has_entrance_played" in gm:
		gm.has_entrance_played = true

	if entrance_node:
		entrance_node.visible = true
		entrance_node.modulate = Color(1, 1, 1, 1)
		entrance_node.mouse_filter = Control.MOUSE_FILTER_STOP

	if menu_items:
		menu_items.visible = true

	if animation_player:
		if animation_player.has_animation("start"):
			animation_player.play("start")
			if not animation_player.animation_finished.is_connected(_on_entrance_animation_finished):
				animation_player.animation_finished.connect(_on_entrance_animation_finished)
		elif animation_player.has_animation("Fade"):
			animation_player.play("Fade")
			if not animation_player.animation_finished.is_connected(_on_entrance_animation_finished):
				animation_player.animation_finished.connect(_on_entrance_animation_finished)
		else:
			_transition_to_menu_items()
	else:
		_transition_to_menu_items()


func _on_entrance_animation_finished(_anim_name: StringName) -> void:
	_transition_to_menu_items()


func _transition_to_menu_items() -> void:
	if not entrance_node:
		if menu_items:
			menu_items.visible = true
			menu_items.modulate = Color(1, 1, 1, 1)
		return

	if menu_items:
		menu_items.visible = true

	# Allow immediate interaction with menu items as transition starts
	entrance_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Smooth transition to reveal menu items seamlessly
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(entrance_node, "modulate:a", 0.0, transition_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if menu_items:
		tween.tween_property(menu_items, "modulate:a", 1.0, transition_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	tween.chain().tween_callback(func():
		if entrance_node:
			entrance_node.visible = false
			entrance_node.modulate.a = 1.0
	)
