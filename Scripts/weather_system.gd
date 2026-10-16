class_name WeatherSystem
extends CanvasLayer
## Comprehensive 2D Weather System for President Crane Total Rescue.
## Manages heavy rain (downpour, night storm) and lightning strikes.

signal weather_changed(new_weather: WeatherType)
signal lightning_struck(bolt_x: float)

enum WeatherType {
	NIGHT_STORM,  ## Heavy stormy rain + dark atmospheric tint + dynamic lightning strikes
	DOWNPOUR,     ## Dense torrential daytime rain
	CLEAR         ## Clear sky (no rain, no lightning)
}

const PRESET_DOWNPOUR := preload("res://addons/weather_fx_2d_lite/presets/rain_heavy__downpour.tres")
const PRESET_NIGHT_STORM := preload("res://addons/weather_fx_2d_lite/presets/rain_heavy__night_storm.tres")
const PRESET_LIGHTNING := preload("res://addons/weather_fx_2d_lite/presets/lightning_flash__single_strike.tres")

# ==============================================================================
# EXPORT PARAMETERS
# ==============================================================================
@export_group("Weather Settings")
@export var current_weather: WeatherType = WeatherType.NIGHT_STORM:
	set(v):
		current_weather = v
		if is_inside_tree():
			_apply_weather_state(current_weather, 1.2)

@export var weather_transition_time: float = 1.2  ## Duration of smooth fade between weather modes

@export_group("Lightning Strike Settings")
@export var lightning_enabled: bool = true        ## Allow lightning strikes
@export var auto_lightning: bool = true           ## Periodically strike in Night Storm mode
@export var min_strike_interval: float = 4.0      ## Minimum seconds between strikes
@export var max_strike_interval: float = 8.5      ## Maximum seconds between strikes
@export var strike_duration: float = 0.95         ## Duration of a single lightning flash (seconds)

@export_group("Atmosphere Tint")
@export var night_storm_tint: Color = Color(0.07, 0.10, 0.20, 0.60)
@export var downpour_tint: Color = Color(0.18, 0.22, 0.30, 0.22)
@export var clear_tint: Color = Color(1.0, 1.0, 1.0, 0.0)

@export_group("Controls & Debug UI")
@export var enable_hotkeys: bool = true           ## 1: Downpour, 2: Night Storm, 3: Clear, L: Strike
@export var show_debug_hint: bool = true          ## Display small controls badge on start
@export var hint_auto_hide_time: float = 7.0      ## Seconds before hint disappears (0 = never)

# ==============================================================================
# NODE REFERENCES
# ==============================================================================
@onready var atmosphere_tint: ColorRect = get_node_or_null("AtmosphereTint")
@onready var rain_layer: WeatherLayerLite = get_node_or_null("RainLayer")
@onready var lightning_layer: WeatherLayerLite = get_node_or_null("LightningLayer")
@onready var hint_label: Label = get_node_or_null("UI/HintBadge/HintLabel")
@onready var hint_badge: Control = get_node_or_null("UI/HintBadge")

# ==============================================================================
# INTERNAL STATE
# ==============================================================================
var _strike_timer: float = 2.5
var _lightning_tween: Tween
var _tint_tween: Tween
var _hint_fade_tween: Tween


func _ready() -> void:
	# Ensure proper layer ordering (rendered over world)
	layer = 10
	
	_setup_internal_nodes()
	_apply_weather_state(current_weather, 0.0)
	_strike_timer = randf_range(2.0, 3.5)
	print("[WeatherSystem] Ready! Weather mode: ", current_weather, " (0: Night Storm, 1: Downpour, 2: Clear)")
	
	if show_debug_hint and hint_badge:
		_update_hint_text()
		if hint_auto_hide_time > 0.0:
			var tw := create_tween()
			tw.tween_interval(hint_auto_hide_time)
			tw.tween_property(hint_badge, "modulate:a", 0.0, 1.5)
			_hint_fade_tween = tw


func _setup_internal_nodes() -> void:
	# Fallback creation if not present in scene
	if not atmosphere_tint:
		atmosphere_tint = ColorRect.new()
		atmosphere_tint.name = "AtmosphereTint"
		atmosphere_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		atmosphere_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		atmosphere_tint.color = clear_tint
		add_child(atmosphere_tint)

	if not rain_layer:
		rain_layer = WeatherLayerLite.new()
		rain_layer.name = "RainLayer"
		rain_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		rain_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rain_layer)

	if not lightning_layer:
		lightning_layer = WeatherLayerLite.new()
		lightning_layer.name = "LightningLayer"
		lightning_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		lightning_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lightning_layer)


func _process(delta: float) -> void:
	# Handle periodic lightning in Night Storm mode
	if current_weather == WeatherType.NIGHT_STORM and lightning_enabled and auto_lightning:
		_strike_timer -= delta
		if _strike_timer <= 0.0:
			_reset_strike_timer()
			strike()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_hotkeys:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				set_weather(WeatherType.DOWNPOUR)
			KEY_2:
				set_weather(WeatherType.NIGHT_STORM)
			KEY_3:
				set_weather(WeatherType.CLEAR)
			KEY_L, KEY_F:
				strike()


# ==============================================================================
# WEATHER TRANSITIONS & STATE MANAGEMENT
# ==============================================================================
## Change weather with an optional transition duration.
func set_weather(type: WeatherType, transition_time: float = -1.0) -> void:
	if transition_time < 0.0:
		transition_time = weather_transition_time
	current_weather = type
	_apply_weather_state(current_weather, transition_time)
	weather_changed.emit(current_weather)
	_update_hint_text()
	var mode_name := "Night Storm"
	if type == WeatherType.DOWNPOUR:
		mode_name = "Downpour"
	elif type == WeatherType.CLEAR:
		mode_name = "Clear"
	print("[WeatherSystem] Weather changed to: ", mode_name)


func _apply_weather_state(type: WeatherType, trans_time: float) -> void:
	if not is_inside_tree() or not rain_layer or not lightning_layer:
		return

	match type:
		WeatherType.NIGHT_STORM:
			_transition_rain(PRESET_NIGHT_STORM, trans_time, 0.6, 0.94)
			_prepare_lightning_layer()
			_transition_tint(night_storm_tint, trans_time)
			_reset_strike_timer()

		WeatherType.DOWNPOUR:
			_transition_rain(PRESET_DOWNPOUR, trans_time, 0.5, 0.94)
			_prepare_lightning_layer()
			_transition_tint(downpour_tint, trans_time)

		WeatherType.CLEAR:
			_transition_rain(null, trans_time, 0.0, 0.94)
			_transition_tint(clear_tint, trans_time)


func _transition_rain(preset: ShaderMaterial, trans_time: float, splash_amt: float, splash_y: float) -> void:
	if trans_time <= 0.0:
		rain_layer.preset = preset
		_configure_rain_material(splash_amt, splash_y)
	else:
		rain_layer.transition_to(preset, trans_time)
		# After transition, configure ground splashes
		get_tree().create_timer(trans_time * 0.5).timeout.connect(func():
			_configure_rain_material(splash_amt, splash_y)
		)


func _configure_rain_material(splash_amt: float, splash_y: float) -> void:
	var mat := rain_layer.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("splash_amount", splash_amt)
		mat.set_shader_parameter("splash_y", splash_y)


func _prepare_lightning_layer() -> void:
	if lightning_layer.preset != PRESET_LIGHTNING:
		lightning_layer.preset = PRESET_LIGHTNING
	var mat := lightning_layer.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("progress", 0.0)


func _transition_tint(target_col: Color, trans_time: float) -> void:
	if not atmosphere_tint:
		return
	if _tint_tween and _tint_tween.is_valid():
		_tint_tween.kill()

	if trans_time <= 0.0:
		atmosphere_tint.color = target_col
	else:
		_tint_tween = create_tween()
		_tint_tween.tween_property(atmosphere_tint, "color", target_col, trans_time)


# ==============================================================================
# LIGHTNING STRIKE LOGIC
# ==============================================================================
## Triggers a single lightning strike at bolt_x (0.0 to 1.0, or -1 for random).
func strike(bolt_x: float = -1.0, duration: float = -1.0) -> void:
	if not lightning_enabled or not lightning_layer:
		return

	if lightning_layer.preset != PRESET_LIGHTNING:
		lightning_layer.preset = PRESET_LIGHTNING

	var mat := lightning_layer.material as ShaderMaterial
	if not mat:
		return

	if duration <= 0.0:
		duration = strike_duration

	if bolt_x < 0.0:
		bolt_x = randf_range(0.15, 0.85)

	mat.set_shader_parameter("bolt_x", bolt_x)
	mat.set_shader_parameter("progress", 0.0)

	if _lightning_tween and _lightning_tween.is_valid():
		_lightning_tween.kill()

	_lightning_tween = create_tween()
	_lightning_tween.tween_property(mat, "shader_parameter/progress", 1.0, duration)
	_lightning_tween.tween_callback(func():
		mat.set_shader_parameter("progress", 0.0)
	)

	print("[WeatherSystem] Lightning strike at X: ", snappedf(bolt_x, 0.01))
	lightning_struck.emit(bolt_x)


func _reset_strike_timer() -> void:
	_strike_timer = randf_range(min_strike_interval, max_strike_interval)


# ==============================================================================
# HINT UI HELPER
# ==============================================================================
func _update_hint_text() -> void:
	if not hint_label or not hint_badge:
		return

	var name_str := "Night Storm"
	match current_weather:
		WeatherType.DOWNPOUR:
			name_str = "Downpour"
		WeatherType.CLEAR:
			name_str = "Clear"

	hint_label.text = "Weather: %s  |  [1] Downpour  [2] Night Storm  [3] Clear  [L] Lightning" % name_str

	# Flash hint badge when switched
	if _hint_fade_tween and _hint_fade_tween.is_valid():
		_hint_fade_tween.kill()
	hint_badge.modulate.a = 1.0
	if hint_auto_hide_time > 0.0:
		var tw := create_tween()
		tw.tween_interval(hint_auto_hide_time)
		tw.tween_property(hint_badge, "modulate:a", 0.0, 1.2)
		_hint_fade_tween = tw
