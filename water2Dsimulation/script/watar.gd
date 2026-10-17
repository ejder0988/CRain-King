extends Node2D

var pointer: bool = true
var attrForce: float = 500

func _draw() -> void:
	draw_colored_polygon($map/CollisionPolygon2D.polygon, Color.BLACK)

func _ready() -> void:
	get_tree().paused = false

func _process(_delta: float) -> void:
	if (InputMap.has_action("ui_reset") and Input.is_action_just_pressed("ui_reset")) or Input.is_physical_key_pressed(KEY_R):
		get_tree().paused = true
		get_tree().reload_current_scene()
		return
	if ((InputMap.has_action("ui_visible") and Input.is_action_just_pressed("ui_visible")) or (Input.is_physical_key_pressed(KEY_V) and not Input.is_key_pressed(KEY_CTRL))) and has_node("Label3"):
		$Label3.visible = not $Label3.visible
	if ((InputMap.has_action("ui_pointer") and Input.is_action_just_pressed("ui_pointer")) or Input.is_physical_key_pressed(KEY_P)) and has_node("UI/pointer"):
		pointer = not pointer
		$UI/pointer.global_position = get_global_mouse_position()
		$UI/pointer.visible = pointer
		if pointer:
			$UI/pointer.process_mode = Node.PROCESS_MODE_INHERIT
		else:
			$UI/pointer.process_mode = Node.PROCESS_MODE_DISABLED

	if has_node("UI/Icon"):
		$UI/Icon.global_position = get_global_mouse_position()
		$UI/Icon.visible = (not pointer) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var dropCount: int = 0
	for wg in get_tree().get_nodes_in_group("waterGenerator"):
		dropCount += wg.objects.size()
	if has_node("Label2"):
		$Label2.text = "FPS: %s, drop count: %s, node count: %s" % [Engine.get_frames_per_second(), dropCount, get_tree().get_node_count()]



func _on_line_edit_text_changed(new_text: String) -> void:
	if new_text.is_valid_float():
		attrForce = int(new_text)


func _on_line_edit_text_submitted(new_text: String) -> void:
	if new_text.is_valid_float():
		attrForce = int(new_text)
		$LineEdit.release_focus()
