extends Control
class_name MainMenuController

## ==============================================================================
## MainMenuController
## ==============================================================================
## 1. Giriş (Entrance) animasyonu oynatılır.
## 2. Entrance bittikten sonra yanıp sönen "PRESS ANY BUTTON" yazısı çıkar.
## 3. Herhangi bir tuşa basıldığında / tıklandığında Story paneli açılır:
##    - İkon (Story/Icon) en küçükten (scale = 0) orijinal boyutuna ulaşır.
##    - İlk texture yüklenir ve inverse shader'ın cutoff parametresi 0'dan 0.5'e yavaşça yükselir.
## 4. Sonrasında her tıklanışta:
##    - Script üzerindeki story_textures dizisinden sıradaki texture gelir.
##    - Shader cutoff parametresi anında 0'a çekilir ve tekrar yavaşça 0.5'e çıkar.
##    - Her tıklamada story_sounds dizisinden (veya default_click_sound) ses çalınır.
## 5. Tüm story_textures bitince doğrudan oyun sahnesi (game.tscn) başlar.
## ==============================================================================

enum MenuState {
	ENTRANCE,
	PRESS_ANY_BUTTON,
	STORY,
	TRANSITIONING
}

@export_group("Scene Navigation")
## Path to the main game scene to launch when story completes
@export_file("*.tscn") var game_scene_path: String = "res://Scenes/game.tscn"
## Duration of the smooth fade transition to the game scene
@export var scene_fade_duration: float = 0.4

@export_group("Entrance & Prompt Settings")
## Text displayed when entrance finishes
@export var press_any_button_text: String = "PRESS ANY BUTTON TO CONTINUE"
## Pulsing speed of the 'Press Any Button' prompt
@export var prompt_pulse_duration: float = 0.75
## Allow skipping entrance animation by pressing any button/clicking (Default: false)
@export var allow_skip_entrance: bool = false

@export_group("Story Settings")
## Story textures that will change on each click / press (Inspectorden dilediğiniz kadar texture ekleyebilirsiniz)
@export var story_textures: Array[Texture2D] = []
## Duration for the icon to scale from 0 to its full size when story opens
@export var icon_grow_duration: float = 0.6
## Name of the shader parameter to animate on the icon material
@export var shader_param_name: String = "cutoff"
## Starting value of the shader parameter (hidden)
@export var shader_param_min: float = 0.0
## Target value of the shader parameter (fully revealed)
@export var shader_param_max: float = 0.5
## Duration for the shader cutoff to slowly transition from 0.0 to 0.5
@export var shader_reveal_duration: float = 1.8
## Keep the diamond outline visible over the story icon
@export var show_diamond_outline_in_story: bool = true

@export_group("Menu Music")
## Ana menüde sürekli döngüde (loop) çalacak müzik dosyası. Dilediğiniz ses dosyasını (.mp3, .ogg, .wav) buraya atayabilirsiniz.
@export var menu_music: AudioStream = null
## Menü arka plan müziğinin ses seviyesi (dB)
@export var menu_music_volume_db: float = 0.0
## Müziğin yönlendirileceği ses bus'ı (örn: "Music" veya "Master")
@export var menu_music_bus: String = "Master"
## Sahne geçişinde (oyun sahnesine başlarken) müziğin yumuşakça kısılıp durdurulması
@export var fade_out_music_on_exit: bool = true

@export_group("Story Audio")
## Array of sounds played on each click/advance (Element 0 = Click 1, Element 1 = Click 2, etc.)
@export var story_sounds: Array[AudioStream] = []
## Fallback sound played on click if story_sounds is empty or doesn't have an item for the current step
@export var default_click_sound: AudioStream = null
## Sound played when pressing any button to enter the story panel
@export var enter_story_sound: AudioStream = null

# Node referansları
@onready var story_node: ColorRect = get_node_or_null("Story") as ColorRect
@onready var story_icon: Sprite2D = get_node_or_null("Story/Icon") as Sprite2D
@onready var story_diamond: Sprite2D = get_node_or_null("Story/Icon/Diamond") as Sprite2D
@onready var entrance_node: ColorRect = get_node_or_null("Entrance") as ColorRect
@onready var entrance_anim: AnimationPlayer = get_node_or_null("Entrance/AnimationPlayer") as AnimationPlayer

# İç durum değişkenleri
var _current_state: MenuState = MenuState.ENTRANCE
var _story_index: int = 0
var _original_icon_scale: Vector2 = Vector2.ONE
var _original_icon_texture: Texture2D = null
var _story_material: ShaderMaterial = null
var _cutoff_tween: Tween = null
var _grow_tween: Tween = null
var _prompt_tween: Tween = null
var _prompt_label: Label = null
var _audio_player: AudioStreamPlayer = null
var _music_player: AudioStreamPlayer = null
var _last_input_time: float = 0.0
var _is_transitioning: bool = false
var _is_revealing: bool = false


func _ready() -> void:
	_setup_audio()
	_setup_nodes_and_materials()
	_setup_prompt_ui()
	_start_entrance()


func _setup_audio() -> void:
	# SFX Audio Player (Tıklama ve panel açılış sesleri)
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "MenuAudioPlayer"
	if AudioServer.get_bus_index("SFX") != -1:
		_audio_player.bus = "SFX"
	else:
		_audio_player.bus = "Master"
	add_child(_audio_player)

	# Dedicated Loop Music Player (Sadece Main Menu'ye özel arka plan müziği)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MenuMusicPlayer"
	if AudioServer.get_bus_index(menu_music_bus) != -1:
		_music_player.bus = menu_music_bus
	elif AudioServer.get_bus_index("Music") != -1:
		_music_player.bus = "Music"
	else:
		_music_player.bus = "Master"
	_music_player.volume_db = menu_music_volume_db
	add_child(_music_player)

	_music_player.finished.connect(_on_music_finished)
	_play_menu_music()


func _setup_nodes_and_materials() -> void:
	# Orijinal ikon boyutunu ve dokusunu kaydet
	if story_icon:
		_original_icon_scale = story_icon.scale
		_original_icon_texture = story_icon.texture

		# Story ikonunun materyalini unique yap (Entrance ile çakışmasın)
		if story_icon.material:
			_story_material = story_icon.material.duplicate() as ShaderMaterial
			story_icon.material = _story_material
			_story_material.set_shader_parameter(shader_param_name, shader_param_min)

	# Story arka plan ColorRect materyalini unique yap ve tam opak hale getir
	if story_node:
		story_node.visible = false
		story_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if story_node.material:
			var s_mat := story_node.material.duplicate() as ShaderMaterial
			story_node.material = s_mat
			if s_mat.get_shader_parameter("scale") != null:
				s_mat.set_shader_parameter("scale", 1.0)

	if entrance_node:
		entrance_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if story_diamond:
		story_diamond.visible = show_diamond_outline_in_story


func _setup_prompt_ui() -> void:
	# 'PRESS ANY BUTTON' metin etiketi
	_prompt_label = Label.new()
	_prompt_label.name = "PressAnyButtonPrompt"
	_prompt_label.text = press_any_button_text
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Ekranın alt-orta kısmında konumlandır
	_prompt_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt_label.offset_left = 0.0
	_prompt_label.offset_right = 0.0
	_prompt_label.offset_top = -140.0
	_prompt_label.offset_bottom = -90.0

	_prompt_label.add_theme_font_size_override("font_size", 22)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_prompt_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_prompt_label.add_theme_constant_override("outline_size", 4)
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label.visible = false
	_prompt_label.modulate.a = 0.0

	add_child(_prompt_label)


func _start_entrance() -> void:
	_current_state = MenuState.ENTRANCE

	if story_node:
		story_node.visible = false

	if entrance_node:
		entrance_node.visible = true
		entrance_node.modulate = Color(1, 1, 1, 1)

	if entrance_anim:
		if entrance_anim.has_animation("start"):
			entrance_anim.play("start")
			if not entrance_anim.animation_finished.is_connected(_on_entrance_finished):
				entrance_anim.animation_finished.connect(_on_entrance_finished)
		elif entrance_anim.has_animation("Fade"):
			entrance_anim.play("Fade")
			if not entrance_anim.animation_finished.is_connected(_on_entrance_finished):
				entrance_anim.animation_finished.connect(_on_entrance_finished)
		else:
			_on_entrance_finished("")
	else:
		_on_entrance_finished("")


func _on_entrance_finished(_anim_name: StringName) -> void:
	if _current_state != MenuState.ENTRANCE:
		return

	_current_state = MenuState.PRESS_ANY_BUTTON

	# 'PRESS ANY BUTTON' yazısını göster ve yumuşak yanıp sönme (pulse) başlat
	if _prompt_label:
		_prompt_label.visible = true
		_prompt_label.modulate.a = 0.2
		if _prompt_tween and _prompt_tween.is_valid():
			_prompt_tween.kill()

		_prompt_tween = create_tween().set_loops()
		_prompt_tween.tween_property(_prompt_label, "modulate:a", 1.0, prompt_pulse_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_prompt_tween.tween_property(_prompt_label, "modulate:a", 0.25, prompt_pulse_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _skip_entrance() -> void:
	if not allow_skip_entrance or _current_state != MenuState.ENTRANCE:
		return

	if entrance_anim and entrance_anim.is_playing():
		entrance_anim.stop()

	_on_entrance_finished("")


## Story panelini açar ve ikon büyüme & ilk shader reveal animasyonunu başlatır
func _open_story_panel() -> void:
	if _current_state != MenuState.PRESS_ANY_BUTTON:
		return

	_current_state = MenuState.STORY

	# Prompt yazısını durdur ve gizle
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
		_prompt_tween = null
	if _prompt_label:
		_prompt_label.visible = false

	# Story'ye giriş sesi
	if enter_story_sound:
		_play_sound(enter_story_sound)
	elif default_click_sound:
		_play_sound(default_click_sound)

	# Entrance'ı gizle, Story'yi aç
	if entrance_node:
		entrance_node.visible = false

	if story_node:
		story_node.visible = true
		story_node.modulate.a = 1.0

	if story_diamond:
		story_diamond.visible = show_diamond_outline_in_story

	# 1. İkon en küçükten (0) şu anki boyutuna doğru büyür
	if story_icon:
		story_icon.visible = true
		story_icon.scale = Vector2.ZERO

		if _grow_tween and _grow_tween.is_valid():
			_grow_tween.kill()
		_grow_tween = create_tween()
		_grow_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_grow_tween.tween_property(story_icon, "scale", _original_icon_scale, icon_grow_duration)

	# İlk texture'ı yükle
	_story_index = 0
	_apply_current_story_texture()

	# 3. Shader parametresini 0'dan 0.5'e yavaşça getir
	_start_shader_reveal()


## Sıradaki story dokusunu story ikonuna uygular
func _apply_current_story_texture() -> void:
	if not story_icon:
		return

	if _story_index < story_textures.size() and story_textures[_story_index] != null:
		story_icon.texture = story_textures[_story_index]
	elif _original_icon_texture:
		story_icon.texture = _original_icon_texture


## Shader parametresini anında 0'a çeker ve yavaşça 0.5'e ulaştırır
func _start_shader_reveal() -> void:
	if _cutoff_tween and _cutoff_tween.is_valid():
		_cutoff_tween.kill()
		_cutoff_tween = null

	_is_revealing = true

	if _story_material:
		_story_material.set_shader_parameter(shader_param_name, shader_param_min)

		_cutoff_tween = create_tween()
		_cutoff_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_cutoff_tween.tween_method(
			func(val: float):
				if _story_material:
					_story_material.set_shader_parameter(shader_param_name, val),
			shader_param_min,
			shader_param_max,
			shader_reveal_duration
		)
		_cutoff_tween.tween_callback(func():
			_is_revealing = false
			if _story_material:
				_story_material.set_shader_parameter(shader_param_name, shader_param_max)
		)
	else:
		_is_revealing = false


## Shader parametresi 0.5 (shader_param_max) hedefine ulaşıp reveal animasyonu bitti mi kontrolü
func is_story_reveal_completed() -> bool:
	if _is_revealing:
		return false
	if _grow_tween and _grow_tween.is_valid() and _grow_tween.is_running():
		return false
	if _cutoff_tween and _cutoff_tween.is_valid() and _cutoff_tween.is_running():
		return false
	if _story_material:
		var current_val = _story_material.get_shader_parameter(shader_param_name)
		if current_val != null and current_val is float:
			if current_val < (shader_param_max - 0.005):
				return false
	return true


## Her tıklamada bir sonraki texture'a geçer veya oyun sahnesini başlatır
func _advance_story() -> void:
	if _current_state != MenuState.STORY:
		return

	# 2- Shader parameter 0.5 olmadan geçme tuşuna basılırsa geçilemez, önce o bitmesi gerek
	if not is_story_reveal_completed():
		return

	# Yanlışlıkla peş peşe aşırı hızlı tıklamayı önleme eşiği
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_input_time < 0.12:
		return
	_last_input_time = now

	# 5. Her bir tıklamada ilgili sesi çal
	_play_click_sound(_story_index)

	_story_index += 1

	# Eğer gösterilecek yeni bir texture varsa
	if _story_index < story_textures.size():
		# Yeni dokuyu yükle
		_apply_current_story_texture()
		# Shader anında 0'dan başlayıp 0.5'e yavaşça ilerler
		_start_shader_reveal()
	else:
		# 4. Tüm texture'lar bittiğinde doğrudan game scene başlasın
		_transition_to_game_scene()


func _play_click_sound(step_index: int) -> void:
	var sound_stream: AudioStream = null

	if step_index >= 0 and step_index < story_sounds.size() and story_sounds[step_index] != null:
		sound_stream = story_sounds[step_index]
	elif default_click_sound != null:
		sound_stream = default_click_sound

	if sound_stream:
		_play_sound(sound_stream)


func _play_sound(stream: AudioStream) -> void:
	if not _audio_player or not stream:
		return
	_audio_player.stream = stream
	_audio_player.play()


## Ana menü arka plan müziğini kesintisiz döngüde (loop) başlatır
func _play_menu_music() -> void:
	if not _music_player:
		return

	# Eğer inspector'dan atanmamışsa ve varsayılan dosya mevcutsa otomatik yükle
	if menu_music == null and ResourceLoader.exists("res://Sounds/Açılış EkranıLoopu.mp3"):
		menu_music = load("res://Sounds/Açılış EkranıLoopu.mp3") as AudioStream

	if not menu_music:
		return

	# Dosya türüne göre stream loop bayraklarını etkinleştir
	if menu_music is AudioStreamMP3:
		(menu_music as AudioStreamMP3).loop = true
	elif menu_music is AudioStreamOggVorbis:
		(menu_music as AudioStreamOggVorbis).loop = true
	elif menu_music is AudioStreamWAV:
		var wav := menu_music as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if wav.loop_end <= 0 and wav.data.size() > 0:
			var bytes_per_sample: int = 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
			var channels: int = 2 if wav.stereo else 1
			var frame_size: int = max(1, bytes_per_sample * channels)
			wav.loop_end = wav.data.size() / frame_size

	_music_player.stream = menu_music
	_music_player.volume_db = menu_music_volume_db
	_music_player.play()


func _on_music_finished() -> void:
	# Ses dosyası kendi içinde loop etmese bile bitince anında baştan başlatarak kesintisiz döngü sağlar
	if not _is_transitioning and _music_player and is_instance_valid(_music_player) and menu_music:
		_music_player.play()


## Çalışma anında (runtime) yeni bir menü müziği atamak istenirse
func set_menu_music(stream: AudioStream) -> void:
	menu_music = stream
	if is_inside_tree() and _music_player:
		_play_menu_music()


## Sahneden çıkıldığında müziği kesin olarak durdur (sadece main menüde çalması garanti olsun)
func _exit_tree() -> void:
	if _music_player and is_instance_valid(_music_player):
		_music_player.stop()


## Tüm story bittiğinde doğrudan game.tscn sahnesini başlatır
func _transition_to_game_scene() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_current_state = MenuState.TRANSITIONING

	print("[MainMenu] Hikaye tamamlandı! Oyun sahnesine geçiliyor: ", game_scene_path)

	# Yumuşak kararma ile sahne geçişi
	var fade := create_tween()
	fade.tween_property(self, "modulate", Color(0, 0, 0, 1), scene_fade_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Main menu müziğini sahne geçişi sırasında yumuşakça kıs (fade out)
	if fade_out_music_on_exit and _music_player and _music_player.playing:
		var music_fade := create_tween()
		music_fade.tween_property(_music_player, "volume_db", -80.0, scene_fade_duration)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	fade.tween_callback(func():
		if _music_player and is_instance_valid(_music_player):
			_music_player.stop()
		var err := get_tree().change_scene_to_file(game_scene_path)
		if err != OK:
			push_error("[MainMenu] Sahne yüklenemedi: %s (Hata kodu: %d)" % [game_scene_path, err])
	)


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	var is_trigger := false
	if event is InputEventKey and event.pressed and not event.echo:
		is_trigger = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_trigger = true
	elif event is InputEventJoypadButton and event.pressed:
		is_trigger = true

	if not is_trigger:
		return

	get_viewport().set_input_as_handled()

	match _current_state:
		MenuState.ENTRANCE:
			# 1- İlk entrance bitmeden klavyeden rastgele tuşa basıp geçilemez
			if allow_skip_entrance:
				_skip_entrance()
			else:
				return
		MenuState.PRESS_ANY_BUTTON:
			_open_story_panel()
		MenuState.STORY:
			# 2- Shader parameter 0.5 olmadan geçme tuşuna basılırsa geçemez, önce o bitmesi gerek
			if is_story_reveal_completed():
				_advance_story()
