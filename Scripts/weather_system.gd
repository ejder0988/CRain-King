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
@export var current_weather: WeatherType = WeatherType.CLEAR:
	set(v):
		current_weather = v
		if is_inside_tree():
			_apply_weather_state(current_weather, 1.2)

@export var weather_transition_time: float = 1.2  ## Duration of smooth fade between weather modes

@export_group("Weather Audio Files")
## Audio file (.wav, .mp3, .ogg) for daytime Downpour rain
@export var downpour_audio: AudioStream

## Audio file (.wav, .mp3, .ogg) for heavy Night Storm rain
@export var night_storm_audio: AudioStream

## Audio file (.wav, .mp3, .ogg) for lightning strike / thunder
@export var lightning_audio: AudioStream

@export_group("Weather Audio Settings")
@export var max_rain_volume_db: float = 0.0        ## Target volume (dB) for full rain audio
@export var max_lightning_volume_db: float = 2.0   ## Target volume (dB) for lightning strike
@export var audio_fade_time: float = 2.5           ## Default fade in/out duration for audio
@export var rain_audio_start_delay: float = 2.8    ## Delay before rain audio begins when sweeping in

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

@export_group("Rain Splash Settings")
@export var splash_y: float = 0.94                   ## Ground impact line in screen UV space (0.0=top, 1.0=bottom, 0.94=rail line)
@export var splash_depth: float = 0.065              ## Vertical scale of splash droplets and ground ripples
@export var downpour_splash_amount: float = 0.65      ## Splash density and intensity for Downpour
@export var night_storm_splash_amount: float = 0.85   ## Splash density and intensity for Night Storm

@export_group("Ground Collision Impact")
## Target collision node for raindrops to hit (defaults to GroundCollions in the current scene)
@export var ground_collision_target: NodePath = NodePath("../GroundCollions")
## Enable collision detection so raindrops hit and splash directly on the front ground layer
@export var enable_ground_collision: bool = true
## Multiplier for splash bounce droplet height and splash visibility on collision
@export_range(0.5, 3.0, 0.1) var collision_bounce_intensity: float = 1.45
## Optional second collision node (e.g. StoneWall) to also receive rain splashes
@export var extra_collision_target: NodePath = NodePath("../StoneWall")

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
@onready var downpour_player: AudioStreamPlayer = get_node_or_null("DownpourAudioPlayer")
@onready var night_storm_player: AudioStreamPlayer = get_node_or_null("NightStormAudioPlayer")
@onready var lightning_player: AudioStreamPlayer = get_node_or_null("LightningAudioPlayer")

# ==============================================================================
# INTERNAL STATE
# ==============================================================================
var _strike_timer: float = 2.5
var _lightning_tween: Tween
var _tint_tween: Tween
var _hint_fade_tween: Tween
var _sweep_tween: Tween
var _storm_sequence_tween: Tween
var _downpour_audio_tween: Tween
var _night_storm_audio_tween: Tween
var _audio_delay_tween: Tween
var _rain_transition_tween: Tween
var _ground_height_texture: ImageTexture = null


func _ready() -> void:
	add_to_group("weather_system")
	# Ensure proper layer ordering (rendered over world)
	layer = 10
	visible = true
	
	_setup_internal_nodes()
	build_ground_collision_profile()
	call_deferred("build_ground_collision_profile")
	_apply_weather_state(current_weather, 0.0)
	_strike_timer = randf_range(2.0, 3.5)
	print("[WeatherSystem] Ready! Weather mode: ", current_weather, " (0: Night Storm, 1: Downpour, 2: Clear)")

	# Auto-load existing sound files from Sounds/Rain if not explicitly assigned
	if not downpour_audio and ResourceLoader.exists("res://Sounds/Rain/light-rain-loop.wav"):
		downpour_audio = load("res://Sounds/Rain/light-rain-loop.wav")
	if not night_storm_audio and ResourceLoader.exists("res://Sounds/Rain/heavy-rain-drops.wav"):
		night_storm_audio = load("res://Sounds/Rain/heavy-rain-drops.wav")
	if not lightning_audio and ResourceLoader.exists("res://Sounds/Rain/thunder-explosion.wav"):
		lightning_audio = load("res://Sounds/Rain/thunder-explosion.wav")

	_prepare_audio_stream(downpour_audio)
	_prepare_audio_stream(night_storm_audio)

	if downpour_player and downpour_audio:
		downpour_player.stream = downpour_audio
	if night_storm_player and night_storm_audio:
		night_storm_player.stream = night_storm_audio
	if lightning_player and lightning_audio:
		lightning_player.stream = lightning_audio

	# Register with GameManager autoload if present
	if is_inside_tree():
		var gm = get_tree().root.get_node_or_null("GameManager")
		if gm and gm.has_method("register_weather_system"):
			gm.register_weather_system(self)
	
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

	if not downpour_player:
		downpour_player = AudioStreamPlayer.new()
		downpour_player.name = "DownpourAudioPlayer"
		downpour_player.bus = "Master"
		add_child(downpour_player)

	if not night_storm_player:
		night_storm_player = AudioStreamPlayer.new()
		night_storm_player.name = "NightStormAudioPlayer"
		night_storm_player.bus = "Master"
		add_child(night_storm_player)

	if not lightning_player:
		lightning_player = AudioStreamPlayer.new()
		lightning_player.name = "LightningAudioPlayer"
		lightning_player.bus = "Master"
		add_child(lightning_player)


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
			KEY_Y:
				get_viewport().set_input_as_handled()
				var gm = get_node_or_null("/root/GameManager")
				if gm and gm.has_method("start_storm_sequence"):
					gm.start_storm_sequence()
				else:
					run_full_storm_sequence()
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
	visible = true
	if _sweep_tween and _sweep_tween.is_valid():
		_sweep_tween.kill()
	if _audio_delay_tween and _audio_delay_tween.is_valid():
		_audio_delay_tween.kill()
	if _rain_transition_tween and _rain_transition_tween.is_valid():
		_rain_transition_tween.kill()

	current_weather = type
	_apply_weather_state(current_weather, transition_time)
	_play_rain_audio(current_weather, transition_time)

	# When manually switching or settling weather, ensure full-screen coverage
	if rain_layer and rain_layer.material and type != WeatherType.CLEAR:
		var mat := rain_layer.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("right_to_left_progress", 1.0)
	weather_changed.emit(current_weather)
	_update_hint_text()
	var mode_name := "Night Storm"
	if type == WeatherType.DOWNPOUR:
		mode_name = "Downpour"
	elif type == WeatherType.CLEAR:
		mode_name = "Clear"
	print("[WeatherSystem] Weather changed to: ", mode_name)


## Starts rain entering from the right side of the screen and spreading across to the left very slowly.
func start_sweeping_rain(type: WeatherType = WeatherType.DOWNPOUR, sweep_duration: float = 20.0, audio_delay: float = -1.0) -> void:
	visible = true
	if _sweep_tween and _sweep_tween.is_valid():
		_sweep_tween.kill()
	if _audio_delay_tween and _audio_delay_tween.is_valid():
		_audio_delay_tween.kill()
	if _rain_transition_tween and _rain_transition_tween.is_valid():
		_rain_transition_tween.kill()

	current_weather = type
	weather_changed.emit(current_weather)
	_update_hint_text()

	var target_preset: ShaderMaterial = PRESET_DOWNPOUR
	var target_tint: Color = downpour_tint
	var splash_amt: float = downpour_splash_amount
	if type == WeatherType.NIGHT_STORM:
		target_preset = PRESET_NIGHT_STORM
		target_tint = night_storm_tint
		splash_amt = night_storm_splash_amount

	# Set up rain layer with sweep starting at 0.0 (right side)
	rain_layer.preset = target_preset
	var mat := rain_layer.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("right_to_left_progress", 0.0)
		mat.set_shader_parameter("splash_amount", splash_amt)
		mat.set_shader_parameter("splash_y", splash_y)
		mat.set_shader_parameter("splash_depth", splash_depth)
		mat.set_shader_parameter("alpha_mult", 1.0)

	# Smoothly fade in atmospheric tint as storm moves in
	_transition_tint(target_tint, sweep_duration)

	# Start rain audio with delay so rain becomes visible on screen first
	var delay: float = audio_delay if audio_delay >= 0.0 else rain_audio_start_delay
	if delay > 0.0:
		_audio_delay_tween = create_tween()
		_audio_delay_tween.tween_interval(delay)
		_audio_delay_tween.tween_callback(func():
			_play_rain_audio(type, audio_fade_time)
		)
	else:
		_play_rain_audio(type, audio_fade_time)

	# Tween the storm sweep progress from 0.0 to 1.0 (right to left very slowly)
	_sweep_tween = create_tween()
	if mat:
		_sweep_tween.tween_property(mat, "shader_parameter/right_to_left_progress", 1.0, sweep_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Flood Cycle 1st Rain: Y tuşu sekansındaki gibi ekranın sağından (bir kısmından)
## yavaşça giren, sola doğru süpüren ve gecikmeli sesle başlayan Downpour yağmuru
func start_flood_first_rain(duration: float = 8.0, audio_delay: float = -1.0) -> void:
	var delay: float = audio_delay if audio_delay >= 0.0 else rain_audio_start_delay
	start_sweeping_rain(WeatherType.DOWNPOUR, duration, delay)
	print("[WeatherSystem] 1. Yağmur (Downpour) Y tuşu sekansındaki gibi sağdan (ekranın bir kısmından) süpürerek başladı. Süre: %.1fs | Ses Gecikmesi: %.1fs" % [duration, delay])


## Flood Cycle 2nd Rain: Transitions smoothly into Night Storm (3.0s)
func start_flood_second_rain(transition_time: float = 3.0) -> void:
	lightning_enabled = true
	set_weather(WeatherType.NIGHT_STORM, transition_time)
	print("[WeatherSystem] 2. Yağmur (Night Storm) başladı. Geçiş süresi: %.1fs" % transition_time)


## Flood Cycle: Starts downpour entering from right edge (over the water pool) for the flood accumulation duration
func start_flood_downpour(duration: float = 4.0) -> void:
	start_sweeping_rain(WeatherType.DOWNPOUR, duration, 0.0)
	print("[WeatherSystem] Sel yağmuru (Downpour) sağ havuzdan batıya doğru başladı. Süre: %.1fs" % duration)


## Flood Cycle: Transitions immediately into dramatic Night Storm with lightning strike as the tsunami wave strikes
func trigger_flood_tsunami_storm() -> void:
	lightning_enabled = true
	set_weather(WeatherType.NIGHT_STORM, 0.8)
	strike()
	print("[WeatherSystem] Tsunami vuruşu! Night Storm ve şimşek çakması devreye girdi!")


## Runs the complete storm lifecycle:
## 1. Downpour starts on right and sweeps across screen (sweep_time).
## 2. Downpour holds across full screen (downpour_hold_time).
## 3. Transitions into Night Storm with lightning (night_storm_time).
## 4. Eases back to Downpour: Sky brightens, lightning stops, heavy drops ease to gentle downpour (downpour_exit_time).
## 5. Downpour smoothly fades away into Clear sky with gradual audio fadeout (fadeout_time).
func run_full_storm_sequence(
	sweep_time: float = 20.0,
	downpour_hold_time: float = 8.0,
	night_storm_time: float = 16.0,
	downpour_exit_time: float = 7.0,
	fadeout_time: float = 7.0,
	on_completed: Callable = Callable()
) -> void:
	visible = true
	if _storm_sequence_tween and _storm_sequence_tween.is_valid():
		_storm_sequence_tween.kill()

	# Phase 1: Downpour enters from right and spreads across screen
	print("[WeatherSystem] Storm Sequence: Phase 1 - Downpour sweeping in from the right...")
	start_sweeping_rain(WeatherType.DOWNPOUR, sweep_time, rain_audio_start_delay)

	_storm_sequence_tween = create_tween()
	_storm_sequence_tween.tween_interval(sweep_time)

	# Phase 2: Downpour covers full screen
	_storm_sequence_tween.tween_callback(func():
		print("[WeatherSystem] Storm Sequence: Phase 2 - Full downpour active...")
	)
	_storm_sequence_tween.tween_interval(downpour_hold_time)

	# Phase 3: Night Storm arrives with dark tint and lightning
	_storm_sequence_tween.tween_callback(func():
		print("[WeatherSystem] Storm Sequence: Phase 3 - Night Storm arriving with lightning...")
		lightning_enabled = true
		set_weather(WeatherType.NIGHT_STORM, 3.0)
	)
	_storm_sequence_tween.tween_interval(night_storm_time)

	# Phase 4: Storm eases back to Downpour (sky brightens, lightning ceases, rain sound eases)
	_storm_sequence_tween.tween_callback(func():
		print("[WeatherSystem] Storm Sequence: Phase 4 - Storm easing, transitioning back to Downpour...")
		lightning_enabled = false
		set_weather(WeatherType.DOWNPOUR, 3.0)
	)
	_storm_sequence_tween.tween_interval(downpour_exit_time)

	# Phase 5: Downpour gently fades out back to Clear sky
	_storm_sequence_tween.tween_callback(func():
		print("[WeatherSystem] Storm Sequence: Phase 5 - Rain gradually dying down, fading smoothly to Clear sky...")
		set_weather(WeatherType.CLEAR, fadeout_time)
	)
	_storm_sequence_tween.tween_interval(fadeout_time)

	# Phase 6: Completion callback
	_storm_sequence_tween.tween_callback(func():
		lightning_enabled = true
		if downpour_player:
			downpour_player.stop()
			downpour_player.volume_db = max_rain_volume_db
		if night_storm_player:
			night_storm_player.stop()
			night_storm_player.volume_db = max_rain_volume_db
		print("[WeatherSystem] Storm Sequence: Finished smoothly.")
		if on_completed.is_valid():
			on_completed.call()
	)


func _apply_weather_state(type: WeatherType, trans_time: float) -> void:
	if not is_inside_tree() or not rain_layer or not lightning_layer:
		return

	match type:
		WeatherType.NIGHT_STORM:
			_transition_rain(PRESET_NIGHT_STORM, trans_time, night_storm_splash_amount, splash_y)
			_prepare_lightning_layer()
			_transition_tint(night_storm_tint, trans_time)
			_reset_strike_timer()

		WeatherType.DOWNPOUR:
			_transition_rain(PRESET_DOWNPOUR, trans_time, downpour_splash_amount, splash_y)
			_prepare_lightning_layer()
			_transition_tint(downpour_tint, trans_time)

		WeatherType.CLEAR:
			_transition_rain(null, trans_time, 0.0, splash_y)
			_transition_tint(clear_tint, trans_time)


func _transition_rain(preset: ShaderMaterial, trans_time: float, splash_amt: float, target_splash_y: float) -> void:
	if _rain_transition_tween and _rain_transition_tween.is_valid():
		_rain_transition_tween.kill()

	if trans_time <= 0.0:
		rain_layer.preset = preset
		_configure_rain_material(splash_amt, target_splash_y)
		return

	if preset == null:
		# Smoothly fade out rain shader completely to clear (no popping)
		var mat := rain_layer.material as ShaderMaterial
		if mat:
			_rain_transition_tween = create_tween()
			_rain_transition_tween.set_parallel(true)
			_rain_transition_tween.tween_property(mat, "shader_parameter/intensity", 0.0, trans_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_rain_transition_tween.tween_property(mat, "shader_parameter/splash_amount", 0.0, trans_time * 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_rain_transition_tween.tween_property(mat, "shader_parameter/alpha_mult", 0.0, trans_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_rain_transition_tween.set_parallel(false)
			_rain_transition_tween.tween_callback(func():
				rain_layer.preset = null
			)
		else:
			rain_layer.preset = null
	else:
		_morph_rain_parameters(preset, trans_time, splash_amt, target_splash_y)


func _morph_rain_parameters(target_preset: ShaderMaterial, trans_time: float, splash_amt: float, target_splash_y: float) -> void:
	if not rain_layer or not target_preset:
		return

	# If there's no existing material, apply preset directly
	if rain_layer.preset == null or rain_layer.material == null:
		rain_layer.preset = target_preset
		_configure_rain_material(splash_amt, target_splash_y)
		return

	var mat := rain_layer.material as ShaderMaterial
	if not mat:
		rain_layer.preset = target_preset
		_configure_rain_material(splash_amt, target_splash_y)
		return

	# Smoothly morph all shader parameters without stopping the rain
	_rain_transition_tween = create_tween()
	_rain_transition_tween.set_parallel(true)

	var t_intensity = target_preset.get_shader_parameter("intensity")
	var t_wind = target_preset.get_shader_parameter("wind")
	var t_fall_speed = target_preset.get_shader_parameter("fall_speed")
	var t_rain_color = target_preset.get_shader_parameter("rain_color")
	var t_mist_color = target_preset.get_shader_parameter("mist_color")
	var t_mist = target_preset.get_shader_parameter("mist")
	var t_alpha_mult = target_preset.get_shader_parameter("alpha_mult")

	if t_intensity != null:
		_rain_transition_tween.tween_property(mat, "shader_parameter/intensity", t_intensity, trans_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if t_wind != null:
		_rain_transition_tween.tween_property(mat, "shader_parameter/wind", t_wind, trans_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if t_fall_speed != null:
		_rain_transition_tween.tween_property(mat, "shader_parameter/fall_speed", t_fall_speed, trans_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if t_rain_color != null:
		_rain_transition_tween.tween_property(mat, "shader_parameter/rain_color", t_rain_color, trans_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if t_mist_color != null:
		_rain_transition_tween.tween_property(mat, "shader_parameter/mist_color", t_mist_color, trans_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if t_mist != null:
		_rain_transition_tween.tween_property(mat, "shader_parameter/mist", t_mist, trans_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if t_alpha_mult != null:
		_rain_transition_tween.tween_property(mat, "shader_parameter/alpha_mult", t_alpha_mult, trans_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_rain_transition_tween.tween_property(mat, "shader_parameter/splash_amount", splash_amt, trans_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mat.set_shader_parameter("splash_y", target_splash_y)
	mat.set_shader_parameter("splash_depth", splash_depth)
	mat.set_shader_parameter("right_to_left_progress", 1.0)


func _configure_rain_material(splash_amt: float, s_y: float) -> void:
	var mat := rain_layer.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("splash_amount", splash_amt)
		mat.set_shader_parameter("splash_y", s_y)
		mat.set_shader_parameter("splash_depth", splash_depth)


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
	_play_lightning_sound()
	lightning_struck.emit(bolt_x)


# ==============================================================================
# AUDIO PLAYBACK & CROSSFADE LOGIC
# ==============================================================================
func _prepare_audio_stream(stream: AudioStream) -> void:
	if not stream:
		return
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if wav.loop_end <= wav.loop_begin:
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
	elif "loop" in stream:
		stream.set("loop", true)


func _sync_audio_from_gamemanager() -> void:
	if not is_inside_tree():
		return
	var gm = get_tree().root.get_node_or_null("GameManager")
	if gm:
		if not downpour_audio and gm.get("downpour_audio"):
			downpour_audio = gm.downpour_audio
		if not night_storm_audio and gm.get("night_storm_audio"):
			night_storm_audio = gm.night_storm_audio
		if not lightning_audio and gm.get("lightning_audio"):
			lightning_audio = gm.lightning_audio
	_prepare_audio_stream(downpour_audio)
	_prepare_audio_stream(night_storm_audio)


func _get_player_tween(player: AudioStreamPlayer) -> Tween:
	if player == downpour_player:
		return _downpour_audio_tween
	elif player == night_storm_player:
		return _night_storm_audio_tween
	return null


func _set_player_tween(player: AudioStreamPlayer, tw: Tween) -> void:
	if player == downpour_player:
		_downpour_audio_tween = tw
	elif player == night_storm_player:
		_night_storm_audio_tween = tw


func _play_rain_audio(type: WeatherType, fade_time: float) -> void:
	_sync_audio_from_gamemanager()

	match type:
		WeatherType.DOWNPOUR:
			var crossfade := clampf(fade_time, 1.5, 3.5)
			_fade_out_player(night_storm_player, crossfade)
			if downpour_audio and downpour_player:
				_fade_in_player(downpour_player, downpour_audio, crossfade)

		WeatherType.NIGHT_STORM:
			var crossfade := clampf(fade_time, 1.5, 3.5)
			_fade_out_player(downpour_player, crossfade)
			if night_storm_audio and night_storm_player:
				_fade_in_player(night_storm_player, night_storm_audio, crossfade)

		WeatherType.CLEAR:
			# Use fade_time so sound slowly and peacefully fades into true silence
			var clear_fade := fade_time if fade_time > 0.0 else audio_fade_time
			_fade_out_player(downpour_player, clear_fade)
			_fade_out_player(night_storm_player, clear_fade)


func _fade_in_player(player: AudioStreamPlayer, stream: AudioStream, fade_time: float) -> void:
	if not player or not stream:
		return

	var existing_tw := _get_player_tween(player)
	if existing_tw and existing_tw.is_valid():
		existing_tw.kill()

	_prepare_audio_stream(stream)
	if player.stream != stream:
		player.stream = stream

	if not player.playing:
		player.volume_db = -24.0
		player.play()

	var tw := create_tween()
	tw.tween_property(player, "volume_db", max_rain_volume_db, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_set_player_tween(player, tw)


func _fade_out_player(player: AudioStreamPlayer, fade_time: float) -> void:
	if not player or not player.playing:
		return

	var existing_tw := _get_player_tween(player)
	if existing_tw and existing_tw.is_valid():
		existing_tw.kill()

	var tw := create_tween()
	# Smoothly fade out down to -60 dB (complete inaudible silence) without abrupt cutoffs
	tw.tween_property(player, "volume_db", -60.0, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		player.stop()
		player.volume_db = max_rain_volume_db
	)
	_set_player_tween(player, tw)


func _play_lightning_sound() -> void:
	var stream: AudioStream = lightning_audio
	if not stream and is_inside_tree():
		var gm = get_tree().root.get_node_or_null("GameManager")
		if gm and gm.get("lightning_audio"):
			stream = gm.lightning_audio

	if stream and lightning_player:
		lightning_player.stream = stream
		lightning_player.volume_db = max_lightning_volume_db
		lightning_player.pitch_scale = randf_range(0.92, 1.08)
		lightning_player.play()


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

	hint_label.text = "Weather: %s  |  [Y] Storm Sequence  [1] Downpour  [2] Night Storm  [3] Clear  [L] Lightning" % name_str

	# Flash hint badge when switched
	if _hint_fade_tween and _hint_fade_tween.is_valid():
		_hint_fade_tween.kill()
	hint_badge.modulate.a = 1.0
	if hint_auto_hide_time > 0.0:
		var tw := create_tween()
		tw.tween_interval(hint_auto_hide_time)
		tw.tween_property(hint_badge, "modulate:a", 0.0, 1.2)
		_hint_fade_tween = tw
