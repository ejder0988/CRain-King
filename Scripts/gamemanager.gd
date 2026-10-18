extends Node

## Global Game Manager autoload for persistent runtime state across scenes and weather management.
var has_entrance_played: bool = false

# Weather system reference and sequence state
var weather_system: WeatherSystem = null
var is_storm_sequence_running: bool = false

@export_group("Weather Sequence Timings")
## Duration (in seconds) for downpour to spread very slowly from the right edge across the entire screen
@export var rain_sweep_duration: float = 20.0

## Delay (in seconds) before rain audio starts fading in, allowing rain to appear on screen first
@export var rain_audio_delay: float = 2.8

## Duration (in seconds) downpour remains full-screen before transitioning to night storm
@export var downpour_hold_duration: float = 8.0

## Duration (in seconds) night storm stays active with lightning strikes
@export var night_storm_duration: float = 16.0

## Duration (in seconds) the storm eases back to downpour before clearing up
@export var downpour_exit_duration: float = 7.0

## Duration (in seconds) for the downpour to smoothly fade out to clear sky and silent audio
@export var storm_fadeout_duration: float = 7.0

@export_group("Weather Audio Files")
## Audio file (.wav, .mp3, .ogg) for daytime Downpour rain
@export var downpour_audio: AudioStream

## Audio file (.wav, .mp3, .ogg) for heavy Night Storm rain
@export var night_storm_audio: AudioStream

## Audio file (.wav, .mp3, .ogg) for lightning strike / thunder
@export var lightning_audio: AudioStream

signal storm_sequence_started
signal storm_sequence_finished
signal debug_mode_toggled(is_enabled: bool)
signal money_changed(new_amount: int)

@export_group("Economy Settings")
## Current player money / coins
@export var money: int = 0


@export_group("Debug Settings")
## Master switch to enable or disable all debug hotkeys and shortcuts across the game
@export var debug_mode: bool = false
## Hotkey to toggle debug_mode on and off (Flip-Flop)
@export var debug_toggle_key: Key = KEY_F6
## Hotkey to show or hide the debug panel while debug mode is active (Flip-Flop)
@export var debug_panel_toggle_key: Key = KEY_F7

# Debug UI Overlay nodes and tweens
var is_panel_visible: bool = false
var _debug_canvas: CanvasLayer = null
var _debug_root: Control = null
var _toast_panel: PanelContainer = null
var _toast_title_label: Label = null
var _toast_sub_label: Label = null
var _toast_tween: Tween = null
var _cheat_sheet_panel: PanelContainer = null
var _cheat_sheet_text: RichTextLabel = null
var _toggle_hide_btn: Button = null
var _mini_panel_btn: Button = null
var _keys_tween: Tween = null


func is_debug_active() -> bool:
	return debug_mode


func _ready() -> void:
	# Automatically detect and load sound files in Sounds/Rain/ if not explicitly assigned in inspector
	if not downpour_audio and ResourceLoader.exists("res://Sounds/Rain/light-rain-loop.wav"):
		downpour_audio = load("res://Sounds/Rain/light-rain-loop.wav")
	if not night_storm_audio and ResourceLoader.exists("res://Sounds/Rain/heavy-rain-drops.wav"):
		night_storm_audio = load("res://Sounds/Rain/heavy-rain-drops.wav")
	if not lightning_audio and ResourceLoader.exists("res://Sounds/Rain/thunder-explosion.wav"):
		lightning_audio = load("res://Sounds/Rain/thunder-explosion.wav")

	_setup_debug_ui()

	# Oyun başlarken tam ekran açılsın
	_apply_initial_fullscreen()


func _apply_initial_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# Bir frame sonra da teyit et
	call_deferred("_ensure_fullscreen")


func _ensure_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _setup_debug_ui() -> void:
	if _debug_canvas:
		return

	_debug_canvas = CanvasLayer.new()
	_debug_canvas.name = "DebugOverlayCanvas"
	_debug_canvas.layer = 125
	_debug_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_debug_canvas)

	_debug_root = Control.new()
	_debug_root.name = "DebugRoot"
	_debug_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_debug_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_canvas.add_child(_debug_root)

	# 1. Top Toast Notification Banner
	_toast_panel = PanelContainer.new()
	_toast_panel.name = "ToastBanner"
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.offset_left = -290.0
	_toast_panel.offset_right = 290.0
	_toast_panel.offset_top = 22.0
	_toast_panel.offset_bottom = 86.0
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	_toast_panel.modulate.a = 0.0

	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0.05, 0.08, 0.13, 0.94)
	toast_style.set_corner_radius_all(10)
	toast_style.set_border_width_all(2)
	toast_style.border_color = Color(0.18, 0.85, 0.45, 0.95)
	toast_style.content_margin_left = 24.0
	toast_style.content_margin_right = 24.0
	toast_style.content_margin_top = 10.0
	toast_style.content_margin_bottom = 10.0
	toast_style.shadow_size = 10
	toast_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	_toast_panel.add_theme_stylebox_override("panel", toast_style)

	var toast_vbox := VBoxContainer.new()
	toast_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	toast_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_toast_title_label = Label.new()
	_toast_title_label.text = "🛠️ DEBUG MODU ETKİNLEŞTİRİLDİ"
	_toast_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_title_label.add_theme_font_size_override("font_size", 17)
	_toast_title_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.55))

	_toast_sub_label = Label.new()
	_toast_sub_label.text = "Geliştirici kısayolları açıldı (F6: Kapat, F7: Paneli Gizle/Aç)"
	_toast_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_sub_label.add_theme_font_size_override("font_size", 12)
	_toast_sub_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))

	toast_vbox.add_child(_toast_title_label)
	toast_vbox.add_child(_toast_sub_label)
	_toast_panel.add_child(toast_vbox)
	_debug_root.add_child(_toast_panel)

	# Button styles for interactive hide/show buttons
	var hide_btn_style := StyleBoxFlat.new()
	hide_btn_style.bg_color = Color(0.12, 0.18, 0.28, 0.85)
	hide_btn_style.set_corner_radius_all(6)
	hide_btn_style.set_border_width_all(1)
	hide_btn_style.border_color = Color(0.35, 0.65, 0.95, 0.6)
	hide_btn_style.content_margin_left = 10.0
	hide_btn_style.content_margin_right = 10.0
	hide_btn_style.content_margin_top = 4.0
	hide_btn_style.content_margin_bottom = 4.0

	var hide_btn_hover := StyleBoxFlat.new()
	hide_btn_hover.bg_color = Color(0.2, 0.3, 0.45, 0.95)
	hide_btn_hover.set_corner_radius_all(6)
	hide_btn_hover.set_border_width_all(1)
	hide_btn_hover.border_color = Color(0.45, 0.8, 1.0, 0.9)
	hide_btn_hover.content_margin_left = 10.0
	hide_btn_hover.content_margin_right = 10.0
	hide_btn_hover.content_margin_top = 4.0
	hide_btn_hover.content_margin_bottom = 4.0

	# 2. Right-Hand Side Debug Keys Cheat-Sheet Panel
	_cheat_sheet_panel = PanelContainer.new()
	_cheat_sheet_panel.name = "CheatSheetPanel"
	_cheat_sheet_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_cheat_sheet_panel.offset_left = -470.0
	_cheat_sheet_panel.offset_right = -20.0
	_cheat_sheet_panel.offset_top = 20.0
	_cheat_sheet_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_cheat_sheet_panel.visible = false
	_cheat_sheet_panel.modulate.a = 0.0

	var sheet_style := StyleBoxFlat.new()
	sheet_style.bg_color = Color(0.04, 0.07, 0.12, 0.9)
	sheet_style.set_corner_radius_all(12)
	sheet_style.set_border_width_all(2)
	sheet_style.border_color = Color(0.25, 0.65, 0.95, 0.75)
	sheet_style.content_margin_left = 18.0
	sheet_style.content_margin_right = 18.0
	sheet_style.content_margin_top = 12.0
	sheet_style.content_margin_bottom = 12.0
	sheet_style.shadow_size = 14
	sheet_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	_cheat_sheet_panel.add_theme_stylebox_override("panel", sheet_style)

	var panel_vbox := VBoxContainer.new()
	panel_vbox.mouse_filter = Control.MOUSE_FILTER_PASS

	# Header bar with title and clickable close/hide button
	var header_hbox := HBoxContainer.new()
	header_hbox.mouse_filter = Control.MOUSE_FILTER_PASS

	var title_lbl := Label.new()
	title_lbl.text = "🛠️ DEBUG PANELİ"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.22, 0.94, 0.5))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	_toggle_hide_btn = Button.new()
	_toggle_hide_btn.text = "Gizle [—] (F7)"
	_toggle_hide_btn.tooltip_text = "Paneli gizlemek için tıklayın veya F7 tuşuna basın"
	_toggle_hide_btn.focus_mode = Control.FOCUS_NONE
	_toggle_hide_btn.add_theme_font_size_override("font_size", 11)
	_toggle_hide_btn.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	_toggle_hide_btn.add_theme_stylebox_override("normal", hide_btn_style)
	_toggle_hide_btn.add_theme_stylebox_override("hover", hide_btn_hover)
	_toggle_hide_btn.add_theme_stylebox_override("pressed", hide_btn_hover)
	_toggle_hide_btn.pressed.connect(_on_toggle_hide_button_pressed)
	header_hbox.add_child(_toggle_hide_btn)

	panel_vbox.add_child(header_hbox)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.add_theme_constant_override("separation", 10)
	panel_vbox.add_child(sep)

	_cheat_sheet_text = RichTextLabel.new()
	_cheat_sheet_text.bbcode_enabled = true
	_cheat_sheet_text.fit_content = true
	_cheat_sheet_text.scroll_active = false
	_cheat_sheet_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cheat_sheet_text.add_theme_font_size_override("normal_font_size", 13)
	_cheat_sheet_text.add_theme_font_size_override("bold_font_size", 14)
	_cheat_sheet_text.text = _get_cheat_sheet_bbcode()
	panel_vbox.add_child(_cheat_sheet_text)

	_cheat_sheet_panel.add_child(panel_vbox)
	_debug_root.add_child(_cheat_sheet_panel)

	# 3. Mini Collapsed Pill Button (shown when panel is hidden while debug mode is active)
	var mini_btn_style := StyleBoxFlat.new()
	mini_btn_style.bg_color = Color(0.06, 0.1, 0.16, 0.88)
	mini_btn_style.set_corner_radius_all(8)
	mini_btn_style.set_border_width_all(1)
	mini_btn_style.border_color = Color(0.2, 0.85, 0.5, 0.75)
	mini_btn_style.content_margin_left = 14.0
	mini_btn_style.content_margin_right = 14.0
	mini_btn_style.content_margin_top = 6.0
	mini_btn_style.content_margin_bottom = 6.0
	mini_btn_style.shadow_size = 6
	mini_btn_style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)

	_mini_panel_btn = Button.new()
	_mini_panel_btn.name = "MiniDebugPill"
	_mini_panel_btn.text = "🛠️ Debug Tuşları (F7)"
	_mini_panel_btn.tooltip_text = "Debug tuşları kılavuzunu açmak için tıklayın veya F7 tuşuna basın"
	_mini_panel_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mini_panel_btn.offset_left = -210.0
	_mini_panel_btn.offset_right = -20.0
	_mini_panel_btn.offset_top = 20.0
	_mini_panel_btn.offset_bottom = 56.0
	_mini_panel_btn.focus_mode = Control.FOCUS_NONE
	_mini_panel_btn.add_theme_font_size_override("font_size", 13)
	_mini_panel_btn.add_theme_color_override("font_color", Color(0.2, 0.95, 0.55))
	_mini_panel_btn.add_theme_stylebox_override("normal", mini_btn_style)
	_mini_panel_btn.add_theme_stylebox_override("hover", hide_btn_hover)
	_mini_panel_btn.add_theme_stylebox_override("pressed", hide_btn_hover)
	_mini_panel_btn.pressed.connect(_on_mini_panel_button_pressed)
	_mini_panel_btn.visible = false
	_mini_panel_btn.modulate.a = 0.0
	_debug_root.add_child(_mini_panel_btn)

	if debug_mode:
		_show_debug_feedback(true)


func _get_cheat_sheet_bbcode() -> String:
	return (
		"[color=#8899aa][i]Debug Aç/Kapa: [/i][b][color=#ffe082][F6][/color][/b]  |  [i]Paneli Gizle/Aç: [/i][b][color=#ffe082][F7][/color][/b][/color]\n\n" +
		"[b][color=#4fc3f7]── HAVA & DOĞA TESTLERİ ──[/color][/b]\n" +
		" [color=#ffe082][b][V / F8][/b][/color]  Yanardağ Patlaması, Deprem & Meteor\n" +
		" [color=#ffe082][b][Y][/b][/color]    Tam Fırtına Sekansını Başlat\n" +
		" [color=#ffe082][b][1][/b][/color]    Sağanak Yağış Modu (Gündüz)\n" +
		" [color=#ffe082][b][2][/b][/color]    Gece Fırtınası Modu\n" +
		" [color=#ffe082][b][3][/b][/color]    Açık / Güneşli Hava\n" +
		" [color=#ffe082][b][L / F][/b][/color] Yıldırım / Şimşek Düşür\n\n" +
		"[b][color=#81c784]── VİNÇ & DONANIM ──[/color][/b]\n" +
		" [color=#ffe082][b][K][/b][/color]    Vinç Roket Hızlandırma (Event Boost 15s)\n" +
		" [color=#ffe082][b][F8][/b][/color]   Test: Event Rock / Meteor Fırlat\n" +
		" [color=#ffe082][b][F9][/b][/color]   Test: Para Ekle (+50$)\n\n" +
		"[b][color=#ffb74d]── BİNALAR & SEVİYE SİSTEMİ ──[/color][/b]\n" +
		" [color=#ffe082][b][H][/b][/color]    Test: Ev Seviyesini Yükselt (+1 Kat)\n" +
		" [color=#ffe082][b][J][/b][/color]    Test: Eve Hasar Ver (-1 Kat Kır)\n" +
		" [color=#ffe082][b][N][/b][/color]    Test: Taş Duvarı Yükselt (+1 Kademe)\n" +
		" [color=#ffe082][b][M][/b][/color]    Test: Taş Duvarı Düşür (-1 Kademe)\n\n" +
		"[b][color=#64b5f6]── SU FİZİĞİ & SİMÜLASYONU ──[/color][/b]\n" +
		" [color=#ffe082][b][T][/b][/color]    Test: Sel / Taşkın Dalgasını Başlat\n" +
		" [color=#ffe082][b][G][/b][/color]    Su Patlaması Ekle (150 Damla)\n" +
		" [color=#ffe082][b][P][/b][/color]    Su Fare İmleci Etkileşimi (İtme/Çekme)\n" +
		" [color=#ffe082][b][F10][/b][/color]  Tsunami Sıvı Su Oranını Değiştir (%0 / %10 / %20 / %30 / %50 / %100 - Yağmur sabittir)\n\n" +
		"[b][color=#b0bec5]── OYUN KONTROLLERİ ──[/color][/b]\n" +
		" [color=#e0e0e0][b][Q / E][/b][/color]    Vinç Kulesi Dönüşü\n" +
		" [color=#e0e0e0][b][A / D][/b][/color]    Vinç Arabası İleri / Geri\n" +
		" [color=#e0e0e0][b][SPACE][/b][/color]  Payload İndir / Kaldır / Bırak\n" +
		" [color=#e0e0e0][b][SHIFT][/b][/color]  Fabrikayı Yükselt (Satın Al)\n" +
		" [color=#e0e0e0][b][F11][/b][/color]    Tam Ekran / Pencere Modu\n" +
		" [color=#e0e0e0][b][ESC][/b][/color]    Ses/Müzik Menüsü (Basılı Tut: Çık)"
	)


func toggle_debug_mode(force_state: Variant = null) -> void:
	if force_state != null:
		debug_mode = bool(force_state)
	else:
		debug_mode = not debug_mode

	debug_mode_toggled.emit(debug_mode)
	print("[GameManager] Debug modu değiştirildi: ", "AÇIK (ENABLED)" if debug_mode else "KAPALI (DISABLED)")
	_show_debug_feedback(debug_mode)


func toggle_panel_visibility() -> void:
	if not debug_mode:
		# If debug mode was off, pressing F7 turns debug mode ON and opens the panel
		toggle_debug_mode(true)
		return

	set_panel_visibility(not is_panel_visible)


func set_panel_visibility(show_panel: bool, animate: bool = true) -> void:
	is_panel_visible = show_panel

	if _keys_tween and _keys_tween.is_valid():
		_keys_tween.kill()

	if show_panel:
		if _mini_panel_btn:
			_mini_panel_btn.visible = false

		_cheat_sheet_panel.visible = true
		if animate:
			_cheat_sheet_panel.modulate.a = 0.0
			_cheat_sheet_panel.offset_right = 30.0
			_cheat_sheet_panel.offset_left = 30.0 - 450.0

			_keys_tween = create_tween()
			_keys_tween.set_parallel(true)
			_keys_tween.tween_property(_cheat_sheet_panel, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_keys_tween.tween_property(_cheat_sheet_panel, "offset_right", -20.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_keys_tween.tween_property(_cheat_sheet_panel, "offset_left", -470.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_cheat_sheet_panel.modulate.a = 1.0
			_cheat_sheet_panel.offset_right = -20.0
			_cheat_sheet_panel.offset_left = -470.0
	else:
		if animate:
			_keys_tween = create_tween()
			_keys_tween.set_parallel(true)
			_keys_tween.tween_property(_cheat_sheet_panel, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_keys_tween.tween_property(_cheat_sheet_panel, "offset_right", 30.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_keys_tween.tween_property(_cheat_sheet_panel, "offset_left", 30.0 - 450.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_keys_tween.chain().tween_callback(func():
				_cheat_sheet_panel.visible = false
				if debug_mode and _mini_panel_btn:
					_mini_panel_btn.visible = true
					_mini_panel_btn.modulate.a = 0.0
					var tw_mini := create_tween()
					tw_mini.tween_property(_mini_panel_btn, "modulate:a", 1.0, 0.2)
			)
		else:
			_cheat_sheet_panel.visible = false
			if debug_mode and _mini_panel_btn:
				_mini_panel_btn.visible = true
				_mini_panel_btn.modulate.a = 1.0


func _on_toggle_hide_button_pressed() -> void:
	set_panel_visibility(false, true)


func _on_mini_panel_button_pressed() -> void:
	set_panel_visibility(true, true)


func _show_debug_feedback(is_active: bool) -> void:
	if not _debug_root:
		return

	# 1. Update Toast Banner
	if is_active:
		_toast_title_label.text = "🛠️ DEBUG MODU ETKİNLEŞTİRİLDİ"
		_toast_title_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.55))
		_toast_sub_label.text = "Geliştirici kısayolları açıldı (F6: Kapat, F7: Paneli Gizle/Aç)"
		var toast_style: StyleBoxFlat = _toast_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if toast_style:
			toast_style.border_color = Color(0.18, 0.85, 0.45, 0.95)
	else:
		_toast_title_label.text = "🔒 DEBUG MODU KAPATILDI"
		_toast_title_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
		_toast_sub_label.text = "Tüm test kısayolları devre dışı bırakıldı (Açmak için F6)"
		var toast_style: StyleBoxFlat = _toast_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if toast_style:
			toast_style.border_color = Color(0.92, 0.32, 0.32, 0.95)

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_panel.visible = true
	_toast_panel.modulate.a = 0.0
	_toast_panel.offset_top = 8.0

	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(_toast_panel, "offset_top", 22.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(3.2 if is_active else 1.6)
	_toast_tween.chain().tween_property(_toast_panel, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_toast_tween.tween_callback(func(): _toast_panel.visible = false)

	# 2. Update and Animate Cheat Sheet Panel
	if is_active:
		set_panel_visibility(true, true)
	else:
		set_panel_visibility(false, true)
		if _mini_panel_btn:
			_mini_panel_btn.visible = false


## Özel bildirim afişi (Toast) göstermek için yardımcı fonksiyon
func show_custom_toast(title: String, subtitle: String, border_color: Color = Color(0.2, 0.85, 0.5), duration: float = 2.5) -> void:
	if not _debug_root or not _toast_panel or not _toast_title_label or not _toast_sub_label:
		return

	_toast_title_label.text = title
	_toast_title_label.add_theme_color_override("font_color", border_color)
	_toast_sub_label.text = subtitle

	var toast_style: StyleBoxFlat = _toast_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if toast_style:
		toast_style.border_color = border_color

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_panel.visible = true
	_toast_panel.modulate.a = 0.0
	_toast_panel.offset_top = 8.0

	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(_toast_panel, "offset_top", 22.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(duration)
	_toast_tween.chain().tween_property(_toast_panel, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_toast_tween.tween_callback(func(): _toast_panel.visible = false)

func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		# Tam ekrandan pencere moduna geç (Ekranı küçült)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var screen_size := DisplayServer.screen_get_size()
		var win_size := Vector2i(1280, 720)
		if screen_size.x >= 1920 and screen_size.y >= 1080:
			win_size = Vector2i(1600, 900)
		DisplayServer.window_set_size(win_size)
		var center_pos := (screen_size - win_size) / 2
		DisplayServer.window_set_position(center_pos)
		print("[Display] F11: Ekran küçültüldü (Pencere Modu: %dx%d)" % [win_size.x, win_size.y])
	else:
		# Pencere modundan tam ekran moduna geç (Ekranı büyült)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		print("[Display] F11: Ekran büyütüldü (Tam Ekran Modu)")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# F11 Tuşu: Ekranı büyült / küçült (Tam Ekran / Pencere Modu)
		if event.keycode == KEY_F11 or event.physical_keycode == KEY_F11:
			get_viewport().set_input_as_handled()
			toggle_fullscreen()
			return


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# F11 Key yedek kontrolü
		if event.keycode == KEY_F11 or event.physical_keycode == KEY_F11:
			get_viewport().set_input_as_handled()
			toggle_fullscreen()
			return

		# F6 Key: Flip-flop toggle debug mode
		if event.keycode == debug_toggle_key or event.keycode == KEY_F6:
			get_viewport().set_input_as_handled()
			toggle_debug_mode()
			return

		# F7 Key: Toggle debug panel visibility (Hide / Show)
		if event.keycode == debug_panel_toggle_key or event.keycode == KEY_F7:
			get_viewport().set_input_as_handled()
			toggle_panel_visibility()
			return

		# Debug key: Press Y to trigger the storm sequence (only if debug_mode is enabled)
		if debug_mode and event.keycode == KEY_Y:
			get_viewport().set_input_as_handled()
			start_storm_sequence()

		# Debug key: Press T to trigger the flood sequence immediately (only if debug_mode is enabled)
		if debug_mode and event.keycode == KEY_T:
			get_viewport().set_input_as_handled()
			trigger_debug_flood()

		# Debug key: Press N to upgrade Stone Wall (+1 stage) (only if debug_mode is enabled)
		if debug_mode and event.keycode == KEY_N:
			get_viewport().set_input_as_handled()
			debug_upgrade_wall()

		# Debug key: Press M to downgrade Stone Wall (-1 stage) (only if debug_mode is enabled)
		if debug_mode and event.keycode == KEY_M:
			get_viewport().set_input_as_handled()
			debug_downgrade_wall()

		# Debug key: Press V or F8 to trigger volcano burst, earthquake and meteor landing (only if debug_mode is enabled)
		if debug_mode and (event.keycode == KEY_V or event.keycode == KEY_F8):
			get_viewport().set_input_as_handled()
			_spawn_debug_event_rock()

		# Debug key: Press F9 to add money (+50$) (only if debug_mode is enabled)
		if debug_mode and event.keycode == KEY_F9:
			get_viewport().set_input_as_handled()
			add_money(50)


## Debug F6 aktifken T tuşu ile sel döngüsünü / dalgasını test eder
func trigger_debug_flood() -> void:
	var tree := get_tree()
	if not tree:
		return
	var game_ctrl = tree.get_first_node_in_group("game_controller")
	if game_ctrl and game_ctrl.has_method("trigger_debug_flood"):
		game_ctrl.trigger_debug_flood()
		return
	if tree.current_scene and tree.current_scene.has_method("trigger_debug_flood"):
		tree.current_scene.trigger_debug_flood()


## Debug F6 aktifken N tuşu ile StoneWall seviyesini 1 artırır (+1 stage)
func debug_upgrade_wall() -> void:
	var tree := get_tree()
	if not tree:
		return
	var wall = tree.get_first_node_in_group("stone_wall")
	if not wall and tree.current_scene:
		wall = tree.current_scene.find_child("StoneWall", true, false)
	if wall and wall.has_method("debug_upgrade_wall"):
		wall.debug_upgrade_wall()


## Debug F6 aktifken M tuşu ile StoneWall seviyesini 1 düşürür (-1 stage)
func debug_downgrade_wall() -> void:
	var tree := get_tree()
	if not tree:
		return
	var wall = tree.get_first_node_in_group("stone_wall")
	if not wall and tree.current_scene:
		wall = tree.current_scene.find_child("StoneWall", true, false)
	if wall and wall.has_method("debug_downgrade_wall"):
		wall.debug_downgrade_wall()


func get_money() -> int:
	return money


func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	money_changed.emit(money)
	print("[GameManager] Para eklendi: +", amount, "$. Toplam Bakiye: ", money, "$")


func spend_money(amount: int) -> bool:
	if amount <= 0:
		return true
	if money < amount:
		print("[GameManager] Yetersiz bakiye! İstenen: ", amount, "$, Mevcut: ", money, "$")
		return false
	money -= amount
	money_changed.emit(money)
	print("[GameManager] Para harcandı: -", amount, "$. Kalan Bakiye: ", money, "$")
	return true


func _spawn_debug_event_rock() -> void:
	var tree := get_tree()
	if not tree:
		return

	var game_ctrl = tree.get_first_node_in_group("game_controller")
	if game_ctrl and game_ctrl.has_method("trigger_volcano_meteor_event"):
		game_ctrl.trigger_volcano_meteor_event()
		print("[GameManager] Debug [V / F8]: Yanardağ Patlaması, Büyük Deprem ve Meteor Tetiklendi!")
		return



	# Fallback direct spawn
	var scene_path := "res://Scenes/event_rock.tscn"
	if ResourceLoader.exists(scene_path):
		var rock_scene := load(scene_path) as PackedScene
		if rock_scene:
			var rock := rock_scene.instantiate() as RigidBody2D
			rock.global_position = Vector2(383, 862)
			var target_parent: Node = tree.current_scene if tree.current_scene else tree.root
			target_parent.add_child(rock)
			print("[GameManager] Debug F8: Event Rock sahneye doğrudan eklendi. Konum: ", rock.global_position)


## Registers the active WeatherSystem instance from the scene.
func register_weather_system(ws: WeatherSystem) -> void:
	weather_system = ws
	print("[GameManager] WeatherSystem registered successfully.")


## Retrieves the active WeatherSystem, searching the scene tree if necessary.
func get_weather_system() -> WeatherSystem:
	if weather_system and is_instance_valid(weather_system) and weather_system.is_inside_tree():
		return weather_system
	if not is_inside_tree():
		return null
	var root := get_tree().root
	var found = root.find_child("WeatherSystem", true, false)
	if found is WeatherSystem:
		weather_system = found
		return weather_system
	return null


## Starts the requested storm sequence:
## 1. Downpour starts on the right side and very slowly spreads across the entire screen.
## 2. Downpour holds across the full screen for a short duration.
## 3. Night storm arrives with dynamic lightning and dark atmospheric tint.
## 4. Night storm stays for a duration.
## 5. Storm finishes and smoothly fades out back to clear sky.
func start_storm_sequence() -> void:
	var ws := get_weather_system()
	if not ws:
		print("[GameManager] Cannot start storm sequence: WeatherSystem not found in current scene.")
		return

	is_storm_sequence_running = true
	storm_sequence_started.emit()
	print("[GameManager] Starting storm sequence via 'Y' key (sweep duration: ", rain_sweep_duration, "s, audio delay: ", rain_audio_delay, "s)...")

	ws.rain_audio_start_delay = rain_audio_delay
	ws.run_full_storm_sequence(
		rain_sweep_duration,
		downpour_hold_duration,
		night_storm_duration,
		downpour_exit_duration,
		storm_fadeout_duration,
		Callable(self, "_on_storm_sequence_finished")
	)


func _on_storm_sequence_finished() -> void:
	is_storm_sequence_running = false
	storm_sequence_finished.emit()
	print("[GameManager] Storm sequence finished. Sky returned to clear.")


## Cancels any running storm sequence and immediately returns to clear weather.
func stop_storm_sequence() -> void:
	is_storm_sequence_running = false
	var ws := get_weather_system()
	if ws:
		ws.set_weather(WeatherSystem.WeatherType.CLEAR, 1.0)
