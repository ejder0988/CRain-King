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


func _ready() -> void:
	# Automatically detect and load sound files in Sounds/Rain/ if not explicitly assigned in inspector
	if not downpour_audio and ResourceLoader.exists("res://Sounds/Rain/light-rain-loop.wav"):
		downpour_audio = load("res://Sounds/Rain/light-rain-loop.wav")
	if not night_storm_audio and ResourceLoader.exists("res://Sounds/Rain/heavy-rain-drops.wav"):
		night_storm_audio = load("res://Sounds/Rain/heavy-rain-drops.wav")
	if not lightning_audio and ResourceLoader.exists("res://Sounds/Rain/thunder-explosion.wav"):
		lightning_audio = load("res://Sounds/Rain/thunder-explosion.wav")


func _unhandled_input(event: InputEvent) -> void:
	# Test key: Press Y to trigger the storm sequence
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Y:
			get_viewport().set_input_as_handled()
			start_storm_sequence()


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
