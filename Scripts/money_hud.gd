extends CanvasLayer
class_name MoneyHUD

## MoneyHUD:
## Displays the player's currency in the top-left of the screen with an animated spinning gold coin.
## Starts at 0$.
## When the ESC menu opens, smoothly descends downwards to prevent overlapping with sound/music controls.
## When the ESC menu closes, smoothly ascends back to the top.

signal money_displayed(amount: int)

@export_group("Layout Settings")
## Normal top-left position when ESC menu is closed
@export var normal_pos: Vector2 = Vector2(138.0, 20.0)
## Descended position when ESC menu is opened
@export var descended_pos: Vector2 = Vector2(138.0, 118.0)
## Animation transition duration (seconds)
@export var slide_duration: float = 0.32

var _panel: PanelContainer = null
var _coin_sprite: AnimatedSprite2D = null
var _money_label: Label = null
var _slide_tween: Tween = null
var _label_pop_tween: Tween = null
var _is_descended: bool = false
var _last_esc_open_state: bool = false


func _ready() -> void:
	layer = 12
	add_to_group("money_hud")
	_build_ui()
	_connect_signals()

	# Initialize with current money from GameManager
	var gm = get_node_or_null("/root/GameManager")
	var initial_amount: int = gm.get_money() if gm and gm.has_method("get_money") else 0
	_update_money_display(initial_amount, false)


func _build_ui() -> void:
	# 1. Main Panel Container
	_panel = PanelContainer.new()
	_panel.name = "MoneyPanel"
	_panel.position = normal_pos
	_panel.custom_minimum_size = Vector2(110.0, 42.0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.14, 0.88)
	panel_style.border_width_bottom = 2
	panel_style.border_width_top = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_color = Color(1.0, 0.82, 0.2, 0.85)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 4
	panel_style.content_margin_bottom = 4
	panel_style.shadow_size = 4
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	_panel.add_theme_stylebox_override("panel", panel_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# 2. Coin AnimatedSprite2D Container
	var coin_box := Control.new()
	coin_box.custom_minimum_size = Vector2(28.0, 28.0)

	_coin_sprite = AnimatedSprite2D.new()
	_coin_sprite.name = "CoinSprite"
	_coin_sprite.position = Vector2(14.0, 14.0)
	_coin_sprite.scale = Vector2(1.85, 1.85)

	# Build spinning coin frames from Sprites/coin.png
	var coin_tex: Texture2D = preload("res://Sprites/coin.png")
	var frames := SpriteFrames.new()
	frames.add_animation("spin")
	frames.set_animation_speed("spin", 9.0)
	frames.set_animation_loop("spin", true)
	for i in range(8):
		var atlas := AtlasTexture.new()
		atlas.atlas = coin_tex
		atlas.region = Rect2(i * 16, 0, 16, 16)
		frames.add_frame("spin", atlas)

	_coin_sprite.sprite_frames = frames
	_coin_sprite.play("spin")
	coin_box.add_child(_coin_sprite)
	hbox.add_child(coin_box)

	# 3. Currency Label
	_money_label = Label.new()
	_money_label.name = "MoneyLabel"
	_money_label.text = "0$"
	_money_label.add_theme_font_size_override("font_size", 18)
	_money_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money_label.pivot_offset = Vector2(20.0, 12.0)
	hbox.add_child(_money_label)

	_panel.add_child(hbox)
	add_child(_panel)


func _connect_signals() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("money_changed"):
		gm.money_changed.connect(_on_money_changed)


func _process(_delta: float) -> void:
	# Continuously track ESC menu status from ButtonsController
	var esc_open: bool = ButtonsController.is_esc_menu_open
	if esc_open != _last_esc_open_state:
		_last_esc_open_state = esc_open
		set_descended(esc_open)


func _on_money_changed(new_amount: int) -> void:
	_update_money_display(new_amount, true)


func _update_money_display(amount: int, animate_pop: bool) -> void:
	if not _money_label:
		return

	_money_label.text = "%d$" % amount
	money_displayed.emit(amount)

	if animate_pop:
		if _label_pop_tween and _label_pop_tween.is_valid():
			_label_pop_tween.kill()

		_label_pop_tween = create_tween()
		_label_pop_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_label_pop_tween.tween_property(_money_label, "scale", Vector2(1.35, 1.35), 0.12)
		_label_pop_tween.tween_property(_money_label, "scale", Vector2.ONE, 0.16)


## Smoothly descends when ESC menu is open, or ascends back when closed
func set_descended(descend: bool) -> void:
	if not _panel or _is_descended == descend:
		return
	_is_descended = descend

	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()

	var target_y: float = descended_pos.y if descend else normal_pos.y
	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(_panel, "position:y", target_y, slide_duration)


## Sel sonrası uçan coinlerin hedef alacağı ekran koordinatını döndürür
func get_coin_target_global_pos() -> Vector2:
	if _coin_sprite and is_instance_valid(_coin_sprite):
		return _coin_sprite.global_position
	if _panel and is_instance_valid(_panel):
		return _panel.global_position + Vector2(28.0, 21.0)
	return normal_pos + Vector2(28.0, 21.0)


## Coin ulaştığında ikon ve etiket üzerinde parıltılı hafif bir zıplama efekti yapar
func pulse_coin_collected() -> void:
	if _coin_sprite and is_instance_valid(_coin_sprite):
		var ct := create_tween()
		ct.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ct.tween_property(_coin_sprite, "scale", Vector2(2.3, 2.3), 0.08)
		ct.tween_property(_coin_sprite, "scale", Vector2(1.85, 1.85), 0.12)


## Sol üstte duran para/coin panelini tamamen arkaplana alır ve gizler
func send_to_background(hide_panel: bool = true) -> void:
	layer = 0
	if _panel and is_instance_valid(_panel):
		if hide_panel:
			_panel.visible = false
		else:
			_panel.modulate.a = 0.25


