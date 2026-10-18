extends Node2D
class_name GameController

## ==============================================================================
## GameController
## ==============================================================================
## Oyun sahnesi (game.tscn) ana denetleyicisi.
## 1. Oyun başladığında arka plan müziğini (Game Music) kesintisiz bir döngüde (loop) başlatır.
## 2. Müziği ESC menüsündeki ses ve müzik kontrollerine tam uyumlu şekilde "Music" kanalına bağlar.
## 3. Ses dosyası MP3, OGG veya WAV fark etmeksizin hem motor içi loop ayarını yapar,
##    hem de parça bittiğinde anında baştan başlatarak kesintisiz döngü sağlar.
## ==============================================================================

@export_group("Game Background Music")
## Oyun sahnesi başladığında sürekli döngüde (loop) çalacak arka plan müziği.
## Buraya dilediğiniz ses dosyasını (.mp3, .ogg, .wav) atayabilirsiniz.
@export var game_music: AudioStream = null

## Müziğin ses seviyesi (dB)
@export var game_music_volume_db: float = -4.0

## Müziğin yönlendirileceği ses kanalı (ESC menüsünden açıp kapatabilmek için 'Music' kanalı kullanılır)
@export var game_music_bus: String = "Music"

## Sahne ilk açıldığında müziğin yumuşakça yükselerek başlama süresi (saniye)
@export var fade_in_duration: float = 0.8

## Sahne yeniden başlatılırken veya çıkılırken müziğin yumuşakça kısılma süresi (saniye)
@export var fade_out_duration: float = 0.5

@export_group("Scene Intro Transition (Water Settle)")
## Su parçacıklarının (200 damla) yere düşüp sakinleşmesi için siyah perde arkasında bekleme süresi (minimum 0.5s)
@export var intro_wait_delay: float = 0.65
## Siyah perdenin açılarak oyun sahnesini pürüzsüzce gösterme süresi (saniye)
@export var intro_fade_duration: float = 0.7
## Sahne açılışında pürüzsüz siyah perde kullanılsın mı?
@export var enable_intro_curtain: bool = true

@export_group("Flood Cycle Timings")
## Sel döngüsünün açık hava hazırlık süresi (Varsayılan: 30 saniye)
@export var flood_cycle_interval: float = 30.0

## 1. Yağmur (DOWNPOUR) süresi (saniye, Varsayılan: 8.0s)
@export var first_rain_duration: float = 8.0

## 1. Yağmur sesinin gecikme süresi (saniye - Y tuşundaki gibi önce yağmur ekranda sağda görünür, sonra ses başlar)
@export var first_rain_audio_delay: float = 2.5

## 1. Yağmur yumuşak geçiş süresi (saniye, Varsayılan: 3.5s)
@export var first_rain_transition: float = 3.5

## 2. Yağmur (NIGHT_STORM) yumuşak geçiş süresi (saniye, Varsayılan: 3.0s)
@export var second_rain_transition: float = 3.0

## 2. Yağmur başladığında suların sağ havuza çekilme süresi (DRAWBACK - saniye, Varsayılan: 2.0s)
@export var drawback_duration: float = 2.0

@export_group("Tsunami Waves Configuration")
## İlk tsunamide gelecek temel dalga sayısı (1 veya daha fazla)
@export_range(1, 10, 1) var initial_wave_count: int = 1

## Her yeni tsunami felaketinde (her döngüde) dalga sayısına kaç dalga ekleneceği
@export_range(0, 5, 1) var wave_count_increment_per_tsunami: int = 1

## Bir tsunamide oluşabilecek maksimum dalga sayısı sınırı
@export_range(1, 20, 1) var max_waves_per_tsunami: int = 5

## Çoklu dalgalar arasındaki geri çekilme / yeniden toparlanma süresi (saniye)
@export var multi_wave_recoil_duration: float = 2.0

## Tsunami dalgasının geriden gelip duvara vurma süresi (SURGE - saniye, Varsayılan: 2.5s)
@export var surge_wave_duration: float = 2.5

## Tsunami vuruşundan sonra suların sağ havuza doğal geri çekilme süresi (BACKWASH - saniye, Varsayılan: 3.0s)
@export var backwash_duration: float = 3.0

## Sel ve yağmur başlamadan kaç saniye önce sağdaki kırmızı uyarının yanıp sönmeye başlayacağı (saniye)
@export var warning_lead_time: float = 6.0

## Ekranın sağındaki ince kırmızı uyarı çizgisinin genişliği (piksel, Varsayılan: 15px)
@export var warning_line_width: float = 15.0

## Sel vuruşundan kaç saniye sonra evlerin hayatta kalma durumu kontrol edilip para ödülü verileceği (saniye)
@export var post_surge_evaluation_delay: float = 3.5

## Geriye dönük uyumluluk için eski değişken
@export var rain_duration_before_surge: float = 8.0:
	get: return first_rain_duration
	set(v): first_rain_duration = v

## Sel döngüsü sistemi aktif olsun mu?
@export var enable_flood_cycle: bool = true

@export_group("Flood Water & Surge Physics")
## İlk tsunamide suya eklenecek temel parçacık sayısı
@export var flood_base_water_amount: int = 60

## Her tsunami geçildiğinde yeni tsunami için eklenen su miktarının artış oranı (%20 için 0.20)
@export_range(0.0, 2.0, 0.05) var tsunami_water_growth_rate: float = 0.20

## (Geriye dönük uyumluluk) Her yeni sel döngüsünde su miktarının ne kadar artacağı
@export var flood_water_increment_per_cycle: int = 22

## Suların sol tarafa (evlere doğru) vurma itme kuvveti
@export var flood_surge_force: float = 1450.0

## Tsunami itme açısı (Derece cinsinden: 45.0 = sola ve yukarı 45° çapraz itme)
@export_range(0.0, 90.0, 1.0) var tsunami_push_angle_degrees: float = 45.0

## Dalga sol tarafa vururken yukarı doğru verilme açısı/bileşeni (-Y yönü)
@export_range(0.0, 1.0, 0.05) var flood_surge_upward_bias: float = 0.35

@export_group("Ambient Loop Audio")
## Arka planda sürekli çalan genel okyanus dalgaları döngü sesi (Loop)
@export var ocean_ambient_sound: AudioStream = preload("res://Sounds/10 Minute Timer -  Ocean Waves at  Sunset.mp3")
## Okyanus dalga sesi seviyesi (dB)
@export var ocean_ambient_volume_db: float = -12.0
## Arka planda sürekli çalan genel rüzgar teması döngü sesi (Loop)
@export var wind_ambient_sound: AudioStream = preload("res://Sounds/Wind theme.wav")
## Rüzgar sesi seviyesi (dB)
@export var wind_ambient_volume_db: float = -14.0
## Ambiyans ses kanalı (Master veya Music/SFX)
@export var ambient_bus: String = "Master"

@export_group("Tsunami & Flood Audio")
## Tsunami yaklaşırken veya kırmızı uyarı sırasında çalan alarm sesi
@export var tsunami_alarm_sound: AudioStream = preload("res://Sounds/Alarm.wav")
## Tsunami alarm sesi seviyesi (dB)
@export var tsunami_alarm_volume_db: float = -3.0
## Tsunami bitip savuşturulduğunda / tehlike geçtiğinde çalan alarm sesi
@export var tsunami_end_alarm_sound: AudioStream = preload("res://Sounds/Araba alarmı.wav")
## Tsunami bitiş alarmı ses seviyesi (dB)
@export var tsunami_end_alarm_volume_db: float = -4.0
## Tsunami dalgasının duvara ve kıyıya şiddetle vurma / çarpma sesi
@export var tsunami_impact_sound: AudioStream = preload("res://Sounds/Gerilme ve çarpma Tsunamii.wav")
## Tsunami çarpma sesi seviyesi (dB)
@export var tsunami_impact_volume_db: float = 3.0
## Geriye dönük uyumluluk için eski sel vuruş sesi (varsayılan: tsunami_impact_sound)
@export var flood_surge_sound: AudioStream = null

@export_group("Flood Reward & Multiplier")
## Ayakta kalan her ev / kat başına verilecek temel para ödülü
@export var base_reward_per_house: int = 50

## Çarpan olarak toplam kat seviyesi mi (true) yoksa ayakta kalan ev sayısı mı (false) kullanılsın
@export var use_floor_levels_as_multiplier: bool = true

@export_group("Meteor & Volcano Event")
## Volkan patlamasının başlaması için geçilmesi gereken minimum tsunami sayısı (Varsayılan: 2 tsunami)
@export var min_tsunamis_before_volcano: int = 2

## Kaç dalgada bir volkanın burst animasyonu oynatıp meteor fırlatacağı (Varsayılan: her 2 dalgada bir)
@export var meteor_wave_interval: int = 2

## Yanardağ patlaması öncesindeki deprem sallanma süresi (Daha kısa: Varsayılan 1.5s)
@export var earthquake_duration: float = 1.5

## Yanardağ patlaması öncesindeki deprem sallanma şiddeti (Daha az: Varsayılan 12.0px)
@export var earthquake_intensity: float = 12.0

## Meteorun düşebileceği alanın minimum X koordinatı (Kullanıcı tarafından belirlenir)
@export var meteor_landing_min_x: float = 430.0

## Meteorun düşebileceği alanın maksimum X koordinatı (Kullanıcı tarafından belirlenir)
@export var meteor_landing_max_x: float = 850.0

## Meteorun yere çakılacağı zemin seviyesi Y koordinatı
@export var meteor_landing_y: float = 890.0

## İsteğe bağlı görsel alan belirleyici CollisionShape2D (Eğer atanırsa sınırları iniş alanı olarak kullanılır)
@export var meteor_landing_zone_shape: CollisionShape2D = null

## Fırlatılacak meteor sahnesi (Varsayılan: event_rock.tscn)
@export var event_rock_scene: PackedScene = preload("res://Scenes/event_rock.tscn")

## Volkan burst patlama sesi (Varsayılan: thunder-explosion.wav)
@export var volcano_burst_sound: AudioStream = preload("res://Sounds/Rain/thunder-explosion.wav")

@export_group("Game Finish & Victory")
## StoneWall maksimum seviyeye ulaştığında çalacak zafer/kazanma sesi
@export var win_sound: AudioStream = preload("res://Sounds/win_sound.wav")
## Kazanma sesi seviyesi (dB)
@export var win_sound_volume_db: float = 2.0
## Kazanma ses kanalı
@export var win_sound_bus: String = "Master"

enum FloodState {
	COUNTDOWN,   ## 30 saniyelik açık hava hazırlık süreci
	WARNING,     ## Kırmızı uyarının yanıp söndüğü son saniyeler (son 6 sn)
	FIRST_RAIN,  ## 1. Yağmur (DOWNPOUR, 8.0 sn - 3.5 sn yumuşak geçişle)
	SECOND_RAIN, ## 2. Yağmur (NIGHT_STORM, 3.0 sn geçiş) & Suyun Sağa Çekilmesi (DRAWBACK, 2.0 sn)
	SURGE,       ## Geriden gelen hareketli dev tsunami dalgası (ROLLING_WAVE, 2.5 sn)
	BACKWASH,    ## Dalga vuruşu sonrası suların sağa doğal geri çekilmesi (3.0 sn)
	EVALUATING   ## Vuruş sonrası evlerin hayatta kalma kontrolü ve ödül
}

const RAIN = FloodState.FIRST_RAIN

var _flood_state: FloodState = FloodState.COUNTDOWN
var _cycle_timer: float = 0.0
var _current_flood_cycle: int = 0
var _is_warning_flashing: bool = false
var _warning_flash_timer: float = 0.0
var _is_urgent_warning: bool = false

# Multi-wave tracking in the current tsunami cycle
var _total_waves_in_current_tsunami: int = 1
var _current_wave_index: int = 1
var _total_surged_waves_count: int = 0
var _completed_tsunamis_count: int = 0
var _waves_after_volcano_unlocked: int = 0
var _initial_volcano_triggered: bool = false

# Volcano reference
@onready var volcano: AnimatedSprite2D = get_node_or_null("volcano") as AnimatedSprite2D

# UI Nodes
var _flood_ui_layer: CanvasLayer = null
var _warning_gradient_rect: TextureRect = null
var _warning_panel: PanelContainer = null
var _warning_title_lbl: Label = null
var _warning_subtitle_lbl: Label = null
var _warning_status_lbl: Label = null
var _warning_icon: Label = null
var _reward_panel: PanelContainer = null
var _reward_title_lbl: Label = null
var _reward_subtitle_lbl: Label = null
var _reward_amount_lbl: Label = null
var _reward_tween: Tween = null
var _warning_tween: Tween = null

# Audio
var _surge_audio_player: AudioStreamPlayer = null
var _ocean_player: AudioStreamPlayer = null
var _wind_player: AudioStreamPlayer = null
var _alarm_player: AudioStreamPlayer = null
var _alarm_end_player: AudioStreamPlayer = null

@onready var _music_player: AudioStreamPlayer = get_node_or_null("GameMusicPlayer") as AudioStreamPlayer

var _intro_canvas: CanvasLayer = null
var _intro_curtain: ColorRect = null

# Finish & Victory
var _is_game_finished: bool = false
var _win_player: AudioStreamPlayer = null
@onready var _finish_canvas: CanvasLayer = get_node_or_null("CanvasLayer") as CanvasLayer
@onready var _finish_rect: ColorRect = get_node_or_null("CanvasLayer/finish") as ColorRect
@onready var _finish_anim: AnimationPlayer = get_node_or_null("CanvasLayer/finish/AnimationPlayer") as AnimationPlayer
@onready var _stone_wall: StoneWall = get_node_or_null("StoneWall") as StoneWall


func _ready() -> void:
	add_to_group("game_controller")
	_setup_intro_curtain()
	_setup_audio()
	_setup_ambient_audio()
	_setup_tsunami_audio()
	_setup_flood_audio()
	_setup_flood_ui()
	_setup_volcano()
	_setup_finish_system()
	set_water_pushboxes_enabled(false)

	if enable_intro_curtain:
		var start_delay := maxf(intro_wait_delay + intro_fade_duration, 0.8)
		get_tree().create_timer(start_delay).timeout.connect(func():
			_cycle_timer = 0.0
			_flood_state = FloodState.COUNTDOWN
		)
	else:
		_cycle_timer = 0.0
		_flood_state = FloodState.COUNTDOWN


func _setup_intro_curtain() -> void:
	if not enable_intro_curtain:
		return

	# Tam ekran en üst katmanda (layer 128) siyah perde oluştur
	_intro_canvas = CanvasLayer.new()
	_intro_canvas.name = "SceneIntroCurtainCanvas"
	_intro_canvas.layer = 128
	_intro_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_intro_canvas)

	_intro_curtain = ColorRect.new()
	_intro_curtain.name = "IntroCurtain"
	_intro_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_curtain.color = Color(0.0, 0.0, 0.0, 1.0)
	_intro_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro_canvas.add_child(_intro_curtain)

	# Su parçacıklarının yere düşüp oturması için en az 0.5 saniye bekle
	var delay: float = maxf(intro_wait_delay, 0.5)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(_intro_curtain, "modulate:a", 0.0, intro_fade_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if _intro_curtain and is_instance_valid(_intro_curtain):
			_intro_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _intro_canvas and is_instance_valid(_intro_canvas):
			_intro_canvas.queue_free()
	)


func _setup_audio() -> void:
	# "Music" ses kanalı mevcut değilse otomatik oluştur
	_ensure_music_bus()

	# Sahne ağacında GameMusicPlayer yoksa dinamik oluştur
	if not _music_player:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "GameMusicPlayer"
		add_child(_music_player)

	# Kanal ataması
	if AudioServer.get_bus_index(game_music_bus) != -1:
		_music_player.bus = game_music_bus
	elif AudioServer.get_bus_index("Music") != -1:
		_music_player.bus = "Music"
	else:
		_music_player.bus = "Master"

	_music_player.volume_db = game_music_volume_db

	if not _music_player.finished.is_connected(_on_music_finished):
		_music_player.finished.connect(_on_music_finished)

	# 1. Öncelik: Inspector'dan game_music atanmışsa onu kullan
	# 2. Öncelik: GameMusicPlayer düğümünün stream'ine bir dosya atanmışsa onu al
	if game_music == null and _music_player.stream != null:
		game_music = _music_player.stream
	elif game_music == null:
		# 3. Öncelik: Sounds klasöründe varsayılan isimli bir müzik dosyası varsa otomatik tespit et
		var candidates: Array[String] = [
			"res://Sounds/GameMusic.mp3",
			"res://Sounds/GameMusic.ogg",
			"res://Sounds/GameMusic.wav",
			"res://Sounds/game_music.mp3",
			"res://Sounds/game_music.ogg",
			"res://Sounds/game_music.wav"
		]
		for path in candidates:
			if ResourceLoader.exists(path):
				game_music = load(path) as AudioStream
				break

	if game_music:
		if enable_intro_curtain and intro_wait_delay > 0.0:
			var delay_sec: float = maxf(intro_wait_delay - 0.1, 0.4)
			var music_delay := get_tree().create_timer(delay_sec, true, false, true)
			music_delay.timeout.connect(func():
				if is_instance_valid(self):
					_play_game_music()
			)
		else:
			_play_game_music()


func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var music_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_idx, "Music")
		AudioServer.set_bus_send(music_idx, "Master")


## Müziği stream döngü ayarlarıyla birlikte başlatır
func _play_game_music() -> void:
	if not _music_player or not game_music:
		return

	# Stream formatına göre loop özelliğini aktif et
	if game_music is AudioStreamMP3:
		(game_music as AudioStreamMP3).loop = true
	elif game_music is AudioStreamOggVorbis:
		(game_music as AudioStreamOggVorbis).loop = true
	elif game_music is AudioStreamWAV:
		var wav := game_music as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if wav.loop_end <= 0 and wav.data.size() > 0:
			var bytes_per_sample: int = 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
			var channels: int = 2 if wav.stereo else 1
			var frame_size: int = max(1, bytes_per_sample * channels)
			wav.loop_end = wav.data.size() / frame_size

	_music_player.stream = game_music

	# Yumuşak ses yükselmesi (Fade-in)
	if fade_in_duration > 0.0:
		_music_player.volume_db = -80.0
		_music_player.play()
		var tw := create_tween()
		tw.tween_property(_music_player, "volume_db", game_music_volume_db, fade_in_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_music_player.volume_db = game_music_volume_db
		_music_player.play()

	print("[GameController] Oyun arka plan müziği döngüde başlatıldı: ", game_music.resource_path if game_music.resource_path != "" else "assigned stream")


func _on_music_finished() -> void:
	# Dosya sona erdiğinde anında baştan başlatarak kesintisiz döngü sağlar
	if _music_player and is_instance_valid(_music_player) and game_music:
		_music_player.play()


## Çalışma anında (runtime) yeni bir müzik atamak veya değiştirmek için fonksiyon
func set_game_music(stream: AudioStream) -> void:
	game_music = stream
	if is_inside_tree() and _music_player:
		_play_game_music()


## Sahneden çıkıldığında müziği temizle
func _exit_tree() -> void:
	if _music_player and is_instance_valid(_music_player):
		_music_player.stop()


func _process(delta: float) -> void:
	if _is_game_finished:
		return
	_process_flood_cycle(delta)
	_process_warning_flash(delta)


# ==============================================================================
# FLOOD CYCLE LOGIC & TIMERS
# ==============================================================================
func _process_flood_cycle(delta: float) -> void:
	if not enable_flood_cycle:
		return

	# Eğer şehir canı 0 olduysa (tüm evler yıkıldıysa) döngüyü durdur
	var hm := _find_houses_manager()
	if hm and hm.has_method("get_total_health") and hm.get_total_health() <= 0:
		_hide_warning_ui()
		return

	match _flood_state:
		FloodState.COUNTDOWN:
			_cycle_timer += delta
			var time_left: float = flood_cycle_interval - _cycle_timer
			if time_left <= warning_lead_time:
				_flood_state = FloodState.WARNING
				_show_warning_ui(false)
				_update_warning_ui(time_left, false)

		FloodState.WARNING:
			_cycle_timer += delta
			var time_left: float = maxf(flood_cycle_interval - _cycle_timer, 0.0)
			_update_warning_ui(time_left, false)
			# 30 saniye doldu! 1. Yağmur (DOWNPOUR) aşamasını başlat
			if _cycle_timer >= flood_cycle_interval:
				_cycle_timer = 0.0
				_start_first_rain_phase()

		FloodState.FIRST_RAIN:
			_cycle_timer += delta
			var time_left_to_surge: float = maxf((first_rain_duration - _cycle_timer) + drawback_duration, 0.0)
			_update_warning_ui(time_left_to_surge, true)
			# 1. Yağmur süresi (8.0s) doldu! 2. Yağmur (NIGHT_STORM) ve DRAWBACK aşamasına geç
			if _cycle_timer >= first_rain_duration:
				_cycle_timer = 0.0
				_start_second_rain_and_drawback()

		FloodState.SECOND_RAIN:
			_cycle_timer += delta
			var time_left_to_surge: float = maxf(drawback_duration - _cycle_timer, 0.0)
			_update_warning_ui(time_left_to_surge, true)
			# Sular geriye çekildi (2.0s)! Dev tsunami dalgasını geriden başlat
			if _cycle_timer >= drawback_duration:
				_cycle_timer = 0.0
				_trigger_flood_surge()

		FloodState.SURGE:
			_cycle_timer += delta
			# Dalga tuğla duvara vurdu ve süre doldu (2.5s)! Doğal geri çekilme (BACKWASH) başlat
			if _cycle_timer >= surge_wave_duration:
				_cycle_timer = 0.0
				_on_wave_completed()
				_start_backwash_phase()

		FloodState.BACKWASH:
			_cycle_timer += delta
			var current_backwash_target: float = backwash_duration if _current_wave_index >= _total_waves_in_current_tsunami else multi_wave_recoil_duration
			# Geri çekilme süresi doldu!
			if _cycle_timer >= current_backwash_target:
				_cycle_timer = 0.0
				if _current_wave_index < _total_waves_in_current_tsunami:
					# Sıradaki dalgayı başlat!
					_current_wave_index += 1
					print("[FloodCycle] 🌊 Art arda gelen dalga! Dalga %d/%d vuruyor!" % [_current_wave_index, _total_waves_in_current_tsunami])
					_trigger_flood_surge()
				else:
					# Tüm dalgalar tamamlandı! Evlerin hayatta kalma kontrolü ve ödül
					_evaluate_flood_survival_and_reward()

		FloodState.EVALUATING:
			_cycle_timer += delta
			# Ödül ve evlerden fırlayan coin uçuş animasyonlarının ardından bir sonraki döngüye geç
			if _cycle_timer >= 3.2:
				_cycle_timer = 0.0
				_flood_state = FloodState.COUNTDOWN

				# 2 tsunami geçildikten sonra volkan patlaması ve meteor olayı başlar
				if _completed_tsunamis_count >= min_tsunamis_before_volcano and not _initial_volcano_triggered:
					_initial_volcano_triggered = true
					print("[Volcano] 🌋 2 tsunami başarıyla geçildi! Yanardağ patlaması ve ilk meteor inişi başlıyor!")
					get_tree().create_timer(0.6).timeout.connect(trigger_volcano_meteor_event)



func _process_warning_flash(delta: float) -> void:
	if not _is_warning_flashing:
		return
	_warning_flash_timer += delta
	var speed: float = 12.0 if _is_urgent_warning else 6.0
	var pulse: float = (sin(_warning_flash_timer * speed) + 1.0) * 0.5

	# Sağ taraftaki ince kırmızı çizgi uyarısının nabız atışı
	if _warning_gradient_rect and _warning_gradient_rect.visible:
		var min_a: float = 0.25 if not _is_urgent_warning else 0.45
		_warning_gradient_rect.modulate.a = lerpf(min_a, 1.0, pulse)


## 1. Yağmur Aşaması: Downpour Y tuşu sekansındaki gibi ekranın sağından (bir kısmından) yavaşça süpürerek ve ses gecikmesiyle girer
func _start_first_rain_phase() -> void:
	_flood_state = FloodState.FIRST_RAIN
	_show_warning_ui(true)
	_play_tsunami_alarm()
	set_water_pushboxes_enabled(true)

	# Her yeni tsunamide dalga sayısını kademeli olarak hesapla (kullanıcı tarafından ayarlanabilir)
	_total_waves_in_current_tsunami = clampi(
		initial_wave_count + (_current_flood_cycle * wave_count_increment_per_tsunami),
		1,
		max_waves_per_tsunami
	)
	_current_wave_index = 0

	var ws := _find_weather_system()
	if ws:
		# Y tuşundaki gibi sağdan (ekranın bir kısmından) giren ve ses gecikmeli süpürme:
		if ws.has_method("start_flood_first_rain"):
			ws.start_flood_first_rain(first_rain_duration, first_rain_audio_delay)
		elif ws.has_method("start_sweeping_rain"):
			ws.start_sweeping_rain(WeatherSystem.WeatherType.DOWNPOUR, first_rain_duration, first_rain_audio_delay)
		else:
			ws.set_weather(WeatherSystem.WeatherType.DOWNPOUR, first_rain_transition)

	# Yağmur aşaması boyunca sağdaki genişletilmiş havuzda (X > 1920) suyun yavaş yavaş yükselip dev bir rezervuar oluşturmasını sağla
	# Her tsunami geçildiğinde yeni tsunami için eklenen su miktarı %20 artar:
	var total_rain_water: int = int(round(float(flood_base_water_amount) * pow(1.0 + tsunami_water_growth_rate, float(_current_flood_cycle))))
	var fw: FluidWater = _find_fluid_water()
	if fw:
		if fw.has_method("start_rain_reservoir_fill"):
			fw.start_rain_reservoir_fill(total_rain_water, first_rain_duration)
		elif fw.has_method("start_water_accumulation"):
			fw.start_water_accumulation(total_rain_water, first_rain_duration)

	print("[FloodCycle] 1. Yağmur (Downpour) başladı! Bu tsunamide toplam %d dalga vuracak! Rezervuar: %d damla (Tsunami #%d, +%%%.0f artış)" % [_total_waves_in_current_tsunami, total_rain_water, _current_flood_cycle + 1, tsunami_water_growth_rate * 100.0])


## 2. Yağmur Aşaması & Su Çekilmesi: 1. yağmur bittiğinde Night Storm (3.0s geçiş) başlar ve sular sağa çekilir (2.0s)
func _start_second_rain_and_drawback() -> void:
	_flood_state = FloodState.SECOND_RAIN

	var ws := _find_weather_system()
	if ws:
		if ws.has_method("start_flood_second_rain"):
			ws.start_flood_second_rain(second_rain_transition)
		else:
			ws.set_weather(WeatherSystem.WeatherType.NIGHT_STORM, second_rain_transition)

	var fw: FluidWater = _find_fluid_water()
	if fw:
		if fw.has_method("start_tsunami_drawback"):
			fw.start_tsunami_drawback(drawback_duration)

	print("[FloodCycle] 2. Yağmur (Night Storm) başladı! Sular sağ havuza çekiliyor (DRAWBACK: %.1fs)!" % drawback_duration)


## 3. Tsunami Dalgası (SURGE): İkinci yağmur eşliğinde geriden gelen hareketli dalga cephesi (2.5s)
func _trigger_flood_surge() -> void:
	_flood_state = FloodState.SURGE
	if _current_wave_index == 0:
		_current_wave_index = 1
		_current_flood_cycle += 1

	set_water_pushboxes_enabled(true)
	_play_surge_sound()

	var ws := _find_weather_system()
	if ws:
		ws.strike()

	# Geriden gelen hareketli tsunami dalgası (ASLA kalıcı su eklenmez! fw.max_particles arttırılmaz!)
	var fw: FluidWater = _find_fluid_water()
	if fw:
		if "tsunami_push_angle_degrees" in fw:
			fw.tsunami_push_angle_degrees = tsunami_push_angle_degrees
		if "tsunami_push_force" in fw and flood_surge_force > 0.0:
			fw.tsunami_push_force = flood_surge_force
		if fw.has_method("start_rolling_wave"):
			fw.start_rolling_wave(surge_wave_duration, _current_flood_cycle)
		elif fw.has_method("start_controlled_surge"):
			fw.start_controlled_surge(surge_wave_duration, _current_flood_cycle)

	print("[FloodCycle] ★ GERİDEN GELEN TSUNAMİ DALGASI BAŞLADI! Dalga: %d/%d | Tsunami Seviyesi: #%d" % [_current_wave_index, _total_waves_in_current_tsunami, _current_flood_cycle])


## 4. Geri Çekilme Aşaması (BACKWASH): Dalga duvara vurduktan sonra suların sağ havuza doğal geri çekilmesi
func _start_backwash_phase() -> void:
	_flood_state = FloodState.BACKWASH

	var current_backwash: float = backwash_duration if _current_wave_index >= _total_waves_in_current_tsunami else multi_wave_recoil_duration
	var fw: FluidWater = _find_fluid_water()
	if fw:
		if fw.has_method("start_tsunami_backwash"):
			fw.start_tsunami_backwash(current_backwash)

	print("[FloodCycle] Dalga %d/%d vurdu! Sular sağ havuza geri çekiliyor (Süre: %.1fs)." % [_current_wave_index, _total_waves_in_current_tsunami, current_backwash])


# ==============================================================================
# VOLCANO & METEOR EVENT (BURST & LANDING)
# ==============================================================================
func _setup_volcano() -> void:
	if not volcano:
		volcano = get_node_or_null("volcano") as AnimatedSprite2D
	if volcano:
		volcano.visible = false
		if not volcano.animation_finished.is_connected(_on_volcano_animation_finished):
			volcano.animation_finished.connect(_on_volcano_animation_finished)
		if volcano.sprite_frames and volcano.sprite_frames.has_animation("default"):
			volcano.play("default")
		print("[Volcano] 🌋 Volcano AnimatedSprite2D hazırlandı ve gizlendi (hide).")


func _on_volcano_animation_finished() -> void:
	if volcano and volcano.animation == "burst":
		volcano.visible = false
		if volcano.sprite_frames and volcano.sprite_frames.has_animation("default"):
			volcano.play("default")
		print("[Volcano] 🌋 Burst animasyonu bitti, volkan gizlendi (hide).")

		# Sonrasında event rock yukarıdan ekran dışından çok hızlı bir şekilde düşecek ve yere çarpacak
		_spawn_sky_event_rock()


func _on_wave_completed() -> void:
	_total_surged_waves_count += 1
	print("[FloodCycle] 🌊 Dalga tamamlandı! (Bu tsunamide: %d/%d | Toplam vurulan dalga: %d | Geçilen tsunami: %d/%d)" % [
		_current_wave_index, _total_waves_in_current_tsunami, _total_surged_waves_count, _completed_tsunamis_count, min_tsunamis_before_volcano
	])

	# Volkan patlaması sadece 2 tsunami geçildikten sonra başlayacak
	if _completed_tsunamis_count >= min_tsunamis_before_volcano:
		_waves_after_volcano_unlocked += 1
		if _waves_after_volcano_unlocked % max(meteor_wave_interval, 1) == 0:
			trigger_volcano_meteor_event()
	else:
		print("[Volcano] 🌋 Volkan henüz aktif değil (Geçilen tsunami: %d/%d). 2 tsunami geçildikten sonra başlayacak." % [
			_completed_tsunamis_count, min_tsunamis_before_volcano
		])


## Yanardağ patlaması dizisi:
## 1. Adım: Deprem sallanması başlar (daha az ve daha kısa). Volkan bu sırada gizlidir.
## 2. Adım: Sallanma tamamen biter, ardından volkan görünür olur ve "burst" animasyonu oynar (ses efekti ile).
## 3. Adım: Volkan animasyonu biter bitmez gizlenir ve event rock yukarıdan ekran dışından hızla düşmeye başlar.
func trigger_volcano_meteor_event() -> void:
	print("[Volcano] ★ 1. AŞAMA: Deprem sallanması başladı (Daha kısa ve hafif: %.1fs, %.1fpx)!" % [earthquake_duration, earthquake_intensity])

	if not volcano:
		volcano = get_node_or_null("volcano") as AnimatedSprite2D
	if volcano:
		volcano.visible = false

	# 1. DEPREM: Ekran hafif ve kısa süreli sallanır (daha az ve daha kısa)
	trigger_earthquake_screen_shake(earthquake_duration, earthquake_intensity)

	# 2. CRANE: Dağ/kara parçaları da depremle birlikte orantılı sallanır
	var crane := _find_crane()
	if crane and crane.has_method("trigger_earthquake_shake"):
		crane.trigger_earthquake_shake(earthquake_duration, earthquake_intensity * 0.7)

	# Deprem sallanması bittikten sonra volkan animasyonu başlayacak
	get_tree().create_timer(earthquake_duration).timeout.connect(_start_volcano_burst_phase)


## Deprem bittikten sonra çağrılır: Volkan animasyonu oynar
func _start_volcano_burst_phase() -> void:
	print("[Volcano] ★ 2. AŞAMA: Deprem bitti! Volkan patlaması ve burst animasyonu başlıyor!")

	# Volkan patlama sesi
	if volcano_burst_sound:
		var burst_player := AudioStreamPlayer2D.new()
		burst_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		burst_player.stream = volcano_burst_sound
		burst_player.volume_db = 4.0
		burst_player.global_position = volcano.global_position if volcano else Vector2(1096, 332)
		add_child(burst_player)
		burst_player.play()
		burst_player.finished.connect(burst_player.queue_free)

	# Volkan AnimatedSprite2D görünür yap ve burst animasyonu oynat
	if not volcano:
		volcano = get_node_or_null("volcano") as AnimatedSprite2D
	if volcano:
		if not volcano.animation_finished.is_connected(_on_volcano_animation_finished):
			volcano.animation_finished.connect(_on_volcano_animation_finished)
		volcano.visible = true
		if volcano.sprite_frames and volcano.sprite_frames.has_animation("burst"):
			volcano.play("burst")
		else:
			# Eğer burst animasyonu yoksa doğrudan meteoru düşür
			_on_volcano_animation_finished()
	else:
		# Sahne içinde volcano düğümü yoksa doğrudan meteoru düşür
		_spawn_sky_event_rock()


## Yanardağ patlaması depremi: Ekranı sallar, deprem bittiğinde pürüzsüzce eski merkezine (ZERO) döner
func trigger_earthquake_screen_shake(duration: float = -1.0, intensity: float = -1.0) -> void:
	if duration <= 0.0:
		duration = earthquake_duration
	if intensity <= 0.0:
		intensity = earthquake_intensity

	var viewport := get_viewport()
	if not viewport:
		return
	var cam: Camera2D = viewport.get_camera_2d()
	if cam and is_instance_valid(cam):
		var tw := cam.create_tween()
		var steps: int = int(duration / 0.06)
		var step_dur: float = duration / float(max(steps, 1))
		for i in range(steps):
			var progress: float = float(i) / float(steps)
			# Zamanla sönümlenen gerçekçi deprem eğrisi
			var damp: float = pow(1.0 - progress, 0.72)
			var shake_offset := Vector2(
				randf_range(-intensity, intensity) * damp,
				randf_range(-intensity * 0.85, intensity * 0.85) * damp
			)
			tw.tween_property(cam, "offset", shake_offset, step_dur).set_trans(Tween.TRANS_SINE)
		# Deprem bitince pürüzsüzce eski merkezine (ZERO) dön
		tw.tween_property(cam, "offset", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_SINE)
	else:
		# Fallback if no active Camera2D: shake root scene
		var root_scene := get_tree().current_scene
		if root_scene:
			var tw := root_scene.create_tween()
			var steps: int = int(duration / 0.06)
			var step_dur: float = duration / float(max(steps, 1))
			for i in range(steps):
				var progress: float = float(i) / float(steps)
				var damp: float = pow(1.0 - progress, 0.72)
				var shake_offset := Vector2(
					randf_range(-intensity * 0.6, intensity * 0.6) * damp,
					randf_range(-intensity * 0.5, intensity * 0.5) * damp
				)
				tw.tween_property(root_scene, "position", shake_offset, step_dur).set_trans(Tween.TRANS_SINE)
			tw.tween_property(root_scene, "position", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_SINE)


func _find_crane() -> Node:
	var tree := get_tree()
	if not tree:
		return null
	var c = tree.get_first_node_in_group("crane")
	if c and is_instance_valid(c):
		return c
	if tree.current_scene:
		c = tree.current_scene.find_child("Crane", true, false)
		if c:
			return c
	return null


## Kullanıcının belirlediği iniş alanı içinde rastgele X pozisyonu döner
func get_random_meteor_landing_x() -> float:
	if meteor_landing_zone_shape and is_instance_valid(meteor_landing_zone_shape):
		var shape = meteor_landing_zone_shape.shape
		if shape is RectangleShape2D:
			var half_w: float = shape.size.x * 0.5 * absf(meteor_landing_zone_shape.global_scale.x)
			return meteor_landing_zone_shape.global_position.x + randf_range(-half_w, half_w)
		elif shape is CircleShape2D:
			var r: float = shape.radius * absf(meteor_landing_zone_shape.global_scale.x)
			return meteor_landing_zone_shape.global_position.x + randf_range(-r, r)

	var min_x: float = minf(meteor_landing_min_x, meteor_landing_max_x)
	var max_x: float = maxf(meteor_landing_min_x, meteor_landing_max_x)
	return randf_range(min_x, max_x)


## Event rock yukarıdan ekran dışından çok hızlı bir şekilde düşer ve yere çarpar
func _spawn_sky_event_rock() -> Node:
	var rock_scene: PackedScene = event_rock_scene
	if not rock_scene and ResourceLoader.exists("res://Scenes/event_rock.tscn"):
		rock_scene = load("res://Scenes/event_rock.tscn")
	if not rock_scene:
		push_error("[Game] event_rock.tscn sahnesi bulunamadı!")
		return null

	var meteor: Node = rock_scene.instantiate()
	add_child(meteor)

	# Su ile çarpışma istisnası ekle
	var fw := _find_fluid_water()
	if fw and fw.has_method("add_collision_exception"):
		fw.add_collision_exception(meteor)

	var target_x: float = get_random_meteor_landing_x()
	var target_pos := Vector2(target_x, meteor_landing_y)

	# Yukarıdan ekran dışından çok hızlı iniş (-180 Y'den başlar, ~0.48 saniyede yere çakılır)
	if meteor.has_method("drop_from_sky"):
		meteor.drop_from_sky(target_pos, -180.0, 0.48)
	elif meteor.has_method("launch_as_meteor"):
		meteor.launch_as_meteor(Vector2(target_x, -180.0), target_pos, 0.0, 0.48)
	elif meteor.has_method("launch_arc"):
		meteor.launch_arc(Vector2(target_x, -180.0), target_pos, 0.0, 0.48)

	print("[Meteor] ☄️ Event rock yukarıdan ekran dışından hızla düşüyor! Hedef İniş: %s" % str(target_pos))
	return meteor


## Volkandan fırlayan meteoru sahneye ekler ve iniş arkını başlatır (Geriye dönük uyumluluk)
func _spawn_volcano_meteor(_start_pos: Vector2 = Vector2.ZERO, _target_pos: Vector2 = Vector2.ZERO) -> Node:
	return _spawn_sky_event_rock()


## Geriye dönük uyumluluk takma adı
func _start_rain_phase() -> void:
	_start_first_rain_phase()


func _evaluate_flood_survival_and_reward() -> void:
	_flood_state = FloodState.EVALUATING
	_stop_tsunami_alarm()
	_hide_warning_ui()
	set_water_pushboxes_enabled(false)
	_play_tsunami_end_alarm()
	_completed_tsunamis_count += 1
	print("[FloodCycle] 🏆 Tsunami #%d başarıyla savuşturuldu/geçildi! (Toplam Geçilen Tsunami: %d / Volkan için Gereken: %d)" % [
		_current_flood_cycle, _completed_tsunamis_count, min_tsunamis_before_volcano
	])

	var hm := _find_houses_manager()
	var standing_houses_list: Array[StaticBody2D] = []
	if hm and hm.has_method("get_standing_houses"):
		standing_houses_list = hm.get_standing_houses()

	var standing_houses: int = standing_houses_list.size() if not standing_houses_list.is_empty() else (hm.get_standing_houses_count() if hm and hm.has_method("get_standing_houses_count") else 0)
	var total_levels: int = hm.get_total_health() if hm and hm.has_method("get_total_health") else 0

	# Yağmuru dindir ve gökyüzünü temizle
	var ws := _find_weather_system()
	if ws:
		ws.set_weather(WeatherSystem.WeatherType.CLEAR, 2.5)

	# Suları sakinleştir (dalgalar ve taşan sular silinmez, yerinde kalır)
	var fw: FluidWater = _find_fluid_water()
	if fw and fw.has_method("calm_and_cleanup_post_surge"):
		fw.calm_and_cleanup_post_surge()

	# Evler hala ayaktaysa çarpan kadar para ver, evlerden coinleri fırlat ve UI'ı göster
	if standing_houses > 0 and total_levels > 0:
		var multiplier: int = total_levels if use_floor_levels_as_multiplier else standing_houses
		var earned_money: int = multiplier * base_reward_per_house

		# Ödül bilgilendirme panelini göster
		_show_reward_ui(standing_houses, multiplier, earned_money)

		# Her ayakta kalan evden coinleri fırlatarak sol üstteki Money HUD'a smooth bir tween ile uçur
		_spawn_flying_coins_from_houses(standing_houses_list, earned_money)
		print("[FloodCycle] Sel savuşturuldu! Ayakta kalan evler: %d | Çarpan: x%d | Kazanılan Para: +%d$" % [standing_houses, multiplier, earned_money])
	else:
		print("[FloodCycle] Tüm evler yıkıldı! Sel savuşturulamadı.")


## Ayakta kalan evlerden altın coinler fırlatır ve sol üstteki Money HUD'a pürüzsüz kavisli bir uçuşla gönderir
func _spawn_flying_coins_from_houses(houses: Array[StaticBody2D], total_earned: int) -> void:
	if houses.is_empty() or total_earned <= 0:
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("add_money") and total_earned > 0:
			gm.add_money(total_earned)
		return

	# CanvasLayer güvencesi (UI katmanında en önde görünsün)
	_setup_flood_ui()
	var container_layer: CanvasLayer = _flood_ui_layer

	# Sol üstteki Money HUD hedefi
	var hud_target_pos: Vector2 = Vector2(166.0, 42.0)
	var hud: MoneyHUD = null
	var hud_found = get_tree().get_first_node_in_group("money_hud")
	if hud_found is MoneyHUD:
		hud = hud_found
		if hud.has_method("get_coin_target_global_pos"):
			hud_target_pos = hud.get_coin_target_global_pos()

	# Her evden 2-3 adet coin fırlat
	var coins_per_house: int = 3
	var total_coin_count: int = houses.size() * coins_per_house
	var amount_per_coin: int = maxi(1, int(round(float(total_earned) / float(total_coin_count))))
	var remaining_reward: int = total_earned
	var coin_index: int = 0

	# Coin sprite texture hazırla
	var coin_tex: Texture2D = preload("res://Sprites/coin.png")
	var coin_frames := SpriteFrames.new()
	coin_frames.add_animation("spin")
	coin_frames.set_animation_speed("spin", 12.0)
	coin_frames.set_animation_loop("spin", true)
	for i in range(8):
		var atlas := AtlasTexture.new()
		atlas.atlas = coin_tex
		atlas.region = Rect2(i * 16, 0, 16, 16)
		coin_frames.add_frame("spin", atlas)

	var vp_canvas_transform: Transform2D = get_viewport().get_canvas_transform()

	for h in houses:
		if not is_instance_valid(h):
			continue

		# Evin çatı seviyesini dünya koordinatından ekran koordinatına çevir
		var house_world_pos: Vector2 = h.global_position
		if h.has_node("CollisionShape2D"):
			var col := h.get_node("CollisionShape2D") as CollisionShape2D
			if col and col.shape is RectangleShape2D:
				var r := col.shape as RectangleShape2D
				# Evin üst/çatı kısmından fırlat
				house_world_pos.y -= r.size.y * 0.45 * h.global_scale.y

		var house_screen_pos: Vector2 = vp_canvas_transform * house_world_pos

		for c_idx in range(coins_per_house):
			coin_index += 1
			var is_last_coin: bool = (coin_index == total_coin_count)
			var coin_val: int = remaining_reward if is_last_coin else amount_per_coin
			remaining_reward -= coin_val

			# Coin görseli
			var coin := AnimatedSprite2D.new()
			coin.sprite_frames = coin_frames
			coin.play("spin")
			coin.position = house_screen_pos
			coin.scale = Vector2(2.4, 2.4)
			coin.modulate = Color(1.2, 1.2, 1.1, 0.0) # Hafif parlak altın tonu
			container_layer.add_child(coin)

			# Uçuş fiziği ve kavis kontrol noktaları
			# 1. Faz: Evin üstüne doğru küçük bir fırlama / pop efekti
			var pop_offset := Vector2(randf_range(-35.0, 35.0), randf_range(-55.0, -95.0))
			var pop_peak := house_screen_pos + pop_offset
			var launch_delay := 0.08 * float(coin_index)

			# Kavis için bezier kontrol noktası (yukarı doğru yay çizer)
			var arc_control_point := Vector2(
				lerpf(pop_peak.x, hud_target_pos.x, 0.4) + randf_range(-40.0, 40.0),
				mini(int(pop_peak.y), int(hud_target_pos.y)) - randf_range(50.0, 100.0)
			)

			var flight_tween := create_tween()
			flight_tween.tween_interval(launch_delay)

			# Başlangıç belirme ve yukarı zıplama
			flight_tween.parallel().tween_property(coin, "modulate:a", 1.0, 0.15)
			flight_tween.parallel().tween_property(coin, "scale", Vector2(2.8, 2.8), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			flight_tween.tween_property(coin, "position", pop_peak, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

			# 2. Faz: Kavisli bezier hareketi ile sol üstteki paraya uçuş
			var flight_duration: float = randf_range(0.65, 0.85)
			flight_tween.tween_method(
				_update_coin_bezier_pos.bind(coin, pop_peak, arc_control_point, hud_target_pos),
				0.0,
				1.0,
				flight_duration
			).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

			# Uçarken hafif küçülüp para ikonunun içine girmesi
			flight_tween.parallel().tween_property(coin, "scale", Vector2(1.85, 1.85), flight_duration)

			# 3. Faz: Hedefe varış, HUD uyarısı ve paranın eklenmesi
			flight_tween.tween_callback(
				_on_flying_coin_arrived.bind(coin, coin_val)
			)


func _update_coin_bezier_pos(progress: float, coin: Node2D, p0: Vector2, p1: Vector2, p2: Vector2) -> void:
	if not is_instance_valid(coin):
		return
	var inv := 1.0 - progress
	coin.position = (inv * inv * p0) + (2.0 * inv * progress * p1) + (progress * progress * p2)


func _on_flying_coin_arrived(coin: Node2D, coin_val: int) -> void:
	if not is_instance_valid(coin):
		return
	# HUD'a küçük bir zıplama darbesi ver
	var hud_current = get_tree().get_first_node_in_group("money_hud")
	if hud_current and hud_current.has_method("pulse_coin_collected"):
		hud_current.pulse_coin_collected()

	# Parayı GameManager'a ekle
	var gm_inst = get_node_or_null("/root/GameManager")
	if gm_inst and gm_inst.has_method("add_money") and coin_val > 0:
		gm_inst.add_money(coin_val)

	# Coin için yok olma parıltısı
	var pop_out := create_tween()
	pop_out.parallel().tween_property(coin, "scale", Vector2(3.2, 3.2), 0.1)
	pop_out.parallel().tween_property(coin, "modulate:a", 0.0, 0.1)
	pop_out.tween_callback(coin.queue_free)




# ==============================================================================
# FLOOD UI (RED WARNING & REWARD NOTIFICATION)
# ==============================================================================
func _setup_flood_ui() -> void:
	if _flood_ui_layer:
		return

	_flood_ui_layer = CanvasLayer.new()
	_flood_ui_layer.name = "FloodUILayer"
	_flood_ui_layer.layer = 95
	add_child(_flood_ui_layer)

	# 1. Ekranın Sağ Tarafında İnce Kırmızı Çizgi Uyarısı (Örn: 15px)
	_warning_gradient_rect = TextureRect.new()
	_warning_gradient_rect.name = "WarningGradientEdge"
	_warning_gradient_rect.anchor_left = 1.0
	_warning_gradient_rect.anchor_right = 1.0
	_warning_gradient_rect.anchor_top = 0.0
	_warning_gradient_rect.anchor_bottom = 1.0
	_warning_gradient_rect.offset_left = -warning_line_width
	_warning_gradient_rect.offset_right = 0.0
	_warning_gradient_rect.offset_top = 0.0
	_warning_gradient_rect.offset_bottom = 0.0
	_warning_gradient_rect.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_warning_gradient_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	_warning_gradient_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_warning_gradient_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_warning_gradient_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_gradient_rect.visible = false

	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.05, 0.05, 0.0))
	grad.add_point(0.35, Color(1.0, 0.05, 0.08, 0.45))
	grad.set_color(1, Color(1.0, 0.0, 0.02, 0.95))

	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.0, 0.5)
	grad_tex.fill_to = Vector2(1.0, 0.5)
	grad_tex.width = 64
	grad_tex.height = 32
	_warning_gradient_rect.texture = grad_tex
	_flood_ui_layer.add_child(_warning_gradient_rect)

	# 2. Üst Ortada Beliren Sel Savuşturma ve Çarpan Para Ödülü Paneli
	_reward_panel = PanelContainer.new()
	_reward_panel.name = "FloodRewardPanel"
	_reward_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_reward_panel.offset_left = -260.0
	_reward_panel.offset_right = 260.0
	_reward_panel.offset_top = 40.0
	_reward_panel.offset_bottom = 160.0
	_reward_panel.custom_minimum_size = Vector2(520.0, 115.0)
	_reward_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_panel.visible = false
	_reward_panel.modulate.a = 0.0

	var rew_style := StyleBoxFlat.new()
	rew_style.bg_color = Color(0.04, 0.08, 0.16, 0.94)
	rew_style.set_border_width_all(2)
	rew_style.border_color = Color(0.2, 0.85, 0.55, 0.95)
	rew_style.set_corner_radius_all(12)
	rew_style.content_margin_left = 20
	rew_style.content_margin_right = 20
	rew_style.content_margin_top = 10
	rew_style.content_margin_bottom = 10
	rew_style.shadow_size = 14
	rew_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	_reward_panel.add_theme_stylebox_override("panel", rew_style)

	var rew_vbox := VBoxContainer.new()
	rew_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rew_vbox.add_theme_constant_override("separation", 4)

	_reward_title_lbl = Label.new()
	_reward_title_lbl.text = "🌊 SEL SAVUŞTURULDU!"
	_reward_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_title_lbl.add_theme_font_size_override("font_size", 21)
	_reward_title_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))

	_reward_subtitle_lbl = Label.new()
	_reward_subtitle_lbl.text = "🏠 Ayakta Kalan Evler: 3  |  Kat Çarpanı: x3"
	_reward_subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_subtitle_lbl.add_theme_font_size_override("font_size", 14)
	_reward_subtitle_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))

	_reward_amount_lbl = Label.new()
	_reward_amount_lbl.text = "+150$"
	_reward_amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_amount_lbl.add_theme_font_size_override("font_size", 26)
	_reward_amount_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))

	rew_vbox.add_child(_reward_title_lbl)
	rew_vbox.add_child(_reward_subtitle_lbl)
	rew_vbox.add_child(_reward_amount_lbl)

	_reward_panel.add_child(rew_vbox)
	_flood_ui_layer.add_child(_reward_panel)


func _show_warning_ui(is_urgent: bool) -> void:
	if not _flood_ui_layer:
		_setup_flood_ui()
	_is_urgent_warning = is_urgent
	_is_warning_flashing = true
	_warning_flash_timer = 0.0

	# Sağ taraftaki ince kırmızı çizgi uyarısını yumuşakça aç
	if _warning_gradient_rect:
		_warning_gradient_rect.offset_left = -warning_line_width
		_warning_gradient_rect.visible = true
		_warning_gradient_rect.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_warning_gradient_rect, "modulate:a", 1.0, 0.25)


func _update_warning_ui(_time_left: float, _is_rain_phase: bool = false, _phase_tag: String = "") -> void:
	# Uyarı kutuları kaldırıldığı için metin güncellemesine gerek yok
	pass


func _hide_warning_ui() -> void:
	_is_warning_flashing = false
	if _warning_gradient_rect and _warning_gradient_rect.visible:
		var tw := create_tween()
		tw.tween_property(_warning_gradient_rect, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func():
			if is_instance_valid(_warning_gradient_rect) and not _is_warning_flashing:
				_warning_gradient_rect.visible = false
		)


func _show_reward_ui(standing_houses: int, multiplier: int, earned_money: int) -> void:
	if not _reward_panel:
		return

	_reward_title_lbl.text = "🌊 SEL SAVUŞTURULDU!"
	_reward_subtitle_lbl.text = "🏠 Ayakta Kalan Evler: %d  |  Kat Çarpanı: x%d" % [standing_houses, multiplier]
	_reward_amount_lbl.text = "+%d$" % earned_money

	if _reward_tween and _reward_tween.is_valid():
		_reward_tween.kill()

	_reward_panel.visible = true
	_reward_panel.modulate.a = 0.0
	_reward_panel.position.y = -130.0

	_reward_tween = create_tween()
	_reward_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reward_tween.tween_property(_reward_panel, "position:y", 40.0, 0.45)
	_reward_tween.parallel().tween_property(_reward_panel, "modulate:a", 1.0, 0.35)

	# 3.2 saniye boyunca ekranda tut
	_reward_tween.tween_interval(3.2)

	# Yukarı kayıp pürüzsüzce kaybol
	_reward_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_reward_tween.tween_property(_reward_panel, "position:y", -130.0, 0.4)
	_reward_tween.parallel().tween_property(_reward_panel, "modulate:a", 0.0, 0.35)
	_reward_tween.tween_callback(func():
		if is_instance_valid(_reward_panel):
			_reward_panel.visible = false
	)


# ==============================================================================
# AUDIO & NODE DISCOVERY
# ==============================================================================
func _setup_ambient_audio() -> void:
	# 1. Genel Okyanus Dalgası Döngü Sesi (Ocean Ambient Player)
	if not _ocean_player:
		_ocean_player = AudioStreamPlayer.new()
		_ocean_player.name = "OceanAmbientPlayer"
		_ocean_player.bus = ambient_bus if AudioServer.get_bus_index(ambient_bus) != -1 else "Master"
		_ocean_player.volume_db = ocean_ambient_volume_db
		add_child(_ocean_player)

	if ocean_ambient_sound and _ocean_player:
		_ocean_player.stream = ocean_ambient_sound
		# Kesintisiz loop ayarı
		if ocean_ambient_sound is AudioStreamWAV:
			var wav := ocean_ambient_sound as AudioStreamWAV
			if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif ocean_ambient_sound is AudioStreamMP3:
			(ocean_ambient_sound as AudioStreamMP3).loop = true

		if not _ocean_player.finished.is_connected(_ocean_player.play):
			_ocean_player.finished.connect(_ocean_player.play)

		_ocean_player.play()

	# 2. Genel Rüzgar Teması Döngü Sesi (Wind Ambient Player)
	if not _wind_player:
		_wind_player = AudioStreamPlayer.new()
		_wind_player.name = "WindAmbientPlayer"
		_wind_player.bus = ambient_bus if AudioServer.get_bus_index(ambient_bus) != -1 else "Master"
		_wind_player.volume_db = wind_ambient_volume_db
		add_child(_wind_player)

	if wind_ambient_sound and _wind_player:
		_wind_player.stream = wind_ambient_sound
		# Kesintisiz loop ayarı
		if wind_ambient_sound is AudioStreamWAV:
			var wav := wind_ambient_sound as AudioStreamWAV
			if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif wind_ambient_sound is AudioStreamMP3:
			(wind_ambient_sound as AudioStreamMP3).loop = true

		if not _wind_player.finished.is_connected(_wind_player.play):
			_wind_player.finished.connect(_wind_player.play)

		_wind_player.play()


func _setup_tsunami_audio() -> void:
	var sfx_bus: String = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"

	# Tsunami Başlangıç Alarm Oynatıcı
	if not _alarm_player:
		_alarm_player = AudioStreamPlayer.new()
		_alarm_player.name = "TsunamiAlarmAudioPlayer"
		_alarm_player.bus = sfx_bus
		_alarm_player.volume_db = tsunami_alarm_volume_db
		add_child(_alarm_player)

	if tsunami_alarm_sound and _alarm_player:
		_alarm_player.stream = tsunami_alarm_sound

	# Tsunami Bitiş / Güvenli Alarm Oynatıcı
	if not _alarm_end_player:
		_alarm_end_player = AudioStreamPlayer.new()
		_alarm_end_player.name = "TsunamiEndAlarmAudioPlayer"
		_alarm_end_player.bus = sfx_bus
		_alarm_end_player.volume_db = tsunami_end_alarm_volume_db
		add_child(_alarm_end_player)

	if tsunami_end_alarm_sound and _alarm_end_player:
		_alarm_end_player.stream = tsunami_end_alarm_sound


func _play_tsunami_alarm() -> void:
	if not _alarm_player:
		_setup_tsunami_audio()
	if _alarm_player and _alarm_player.stream:
		_alarm_player.volume_db = tsunami_alarm_volume_db
		_alarm_player.play()
	set_water_pushboxes_enabled(true)


func _stop_tsunami_alarm() -> void:
	if _alarm_player and _alarm_player.playing:
		_alarm_player.stop()
	set_water_pushboxes_enabled(false)


func set_water_pushboxes_enabled(active: bool) -> void:
	var pushboxes := get_tree().get_nodes_in_group("water_pushbox")
	for pb in pushboxes:
		if is_instance_valid(pb) and "enabled" in pb:
			pb.enabled = active
	print("[Game] Tsunami Su İtme Kutuları (PushBox) %s yapıldı. (Adet: %d)" % ["AKTİF EDİLDİ" if active else "KAPATILDI", pushboxes.size()])


func _play_tsunami_end_alarm() -> void:
	if not _alarm_end_player:
		_setup_tsunami_audio()
	if _alarm_end_player and _alarm_end_player.stream:
		_alarm_end_player.volume_db = tsunami_end_alarm_volume_db
		_alarm_end_player.play()


func _setup_flood_audio() -> void:
	if not _surge_audio_player:
		_surge_audio_player = AudioStreamPlayer.new()
		_surge_audio_player.name = "FloodSurgeAudioPlayer"
		_surge_audio_player.bus = "Master"
		_surge_audio_player.volume_db = tsunami_impact_volume_db
		add_child(_surge_audio_player)

	# 1. Öncelik: tsunami_impact_sound ("Gerilme ve çarpma Tsunamii.wav")
	# 2. Öncelik: flood_surge_sound
	var target_impact_sound: AudioStream = tsunami_impact_sound
	if target_impact_sound == null:
		target_impact_sound = flood_surge_sound
	if target_impact_sound == null:
		if ResourceLoader.exists("res://Sounds/Gerilme ve çarpma Tsunamii.wav"):
			target_impact_sound = load("res://Sounds/Gerilme ve çarpma Tsunamii.wav")
		elif ResourceLoader.exists("res://Sounds/Rain/thunder-explosion.wav"):
			target_impact_sound = load("res://Sounds/Rain/thunder-explosion.wav")

	if target_impact_sound and _surge_audio_player:
		_surge_audio_player.stream = target_impact_sound
		_surge_audio_player.volume_db = tsunami_impact_volume_db


func _play_surge_sound() -> void:
	if not _surge_audio_player:
		_setup_flood_audio()
	if _surge_audio_player and _surge_audio_player.stream:
		_surge_audio_player.volume_db = tsunami_impact_volume_db
		_surge_audio_player.play()


func _find_weather_system() -> WeatherSystem:
	var tree := get_tree()
	if not tree:
		return null
	var node = tree.get_first_node_in_group("weather_system")
	if node is WeatherSystem:
		return node
	return tree.root.find_child("WeatherSystem", true, false) as WeatherSystem


func _find_fluid_water() -> FluidWater:
	var tree := get_tree()
	if not tree:
		return null
	var node = tree.get_first_node_in_group("fluid_water")
	if node is FluidWater:
		return node
	return tree.root.find_child("FluidWater", true, false) as FluidWater


func _find_houses_manager() -> HousesManager:
	var tree := get_tree()
	if not tree:
		return null
	var node = tree.get_first_node_in_group("houses_manager")
	if node is HousesManager:
		return node
	return tree.root.find_child("Houses", true, false) as HousesManager


## Debug amaçlı sel döngüsünü veya aşamalarını anında tetikler (T tuşu)
func trigger_debug_flood() -> void:
	match _flood_state:
		FloodState.FIRST_RAIN:
			print("[FloodCycle] Debug 'T': 1. Yağmur atlandı, 2. Yağmur (Night Storm) ve DRAWBACK başlatılıyor!")
			_cycle_timer = 0.0
			_start_second_rain_and_drawback()
		FloodState.SECOND_RAIN:
			print("[FloodCycle] Debug 'T': Drawback atlandı, dev tsunami dalgası (SURGE) hemen başlatılıyor!")
			_cycle_timer = 0.0
			_trigger_flood_surge()
		FloodState.SURGE:
			print("[FloodCycle] Debug 'T': Dalga süresi atlandı, BACKWASH (geri çekilme) başlatılıyor!")
			_cycle_timer = 0.0
			_start_backwash_phase()
		FloodState.BACKWASH:
			print("[FloodCycle] Debug 'T': Geri çekilme atlandı, ödül ve değerlendirme başlatılıyor!")
			_cycle_timer = 0.0
			_evaluate_flood_survival_and_reward()
		_:
			# COUNTDOWN veya WARNING aşamasındaysa:
			print("[FloodCycle] Debug 'T': Hazırlık süresi atlandı, 1. Yağmur (DOWNPOUR) başlatılıyor!")
			_cycle_timer = 0.0
			_start_first_rain_phase()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var gm = get_node_or_null("/root/GameManager")
	var is_debug: bool = gm and gm.debug_mode
	if is_debug and event.keycode == KEY_T:
		get_viewport().set_input_as_handled()
		trigger_debug_flood()


# ==============================================================================
# GAME FINISH & VICTORY SEQUENCE
# ==============================================================================
func _setup_finish_system() -> void:
	# 1. Kazanma ses çalarını hazırla
	_win_player = AudioStreamPlayer.new()
	_win_player.name = "WinSoundPlayer"
	_win_player.bus = win_sound_bus
	_win_player.volume_db = win_sound_volume_db
	if win_sound:
		_win_player.stream = win_sound
	elif ResourceLoader.exists("res://Sounds/win_sound.wav"):
		_win_player.stream = load("res://Sounds/win_sound.wav")
	add_child(_win_player)

	# 2. CanvasLayer ve finish ColorRect ayarları
	if _finish_canvas:
		_finish_canvas.layer = 105
	if _finish_rect:
		_finish_rect.visible = false

	# 3. AnimationPlayer sinyal bağlantısı
	if _finish_anim:
		_finish_anim.stop()
		if not _finish_anim.animation_finished.is_connected(_on_finish_animation_finished):
			_finish_anim.animation_finished.connect(_on_finish_animation_finished)

	# 4. StoneWall referansı ve sinyalleri
	var wall: StoneWall = _stone_wall
	if not wall:
		wall = find_child("StoneWall", true, false) as StoneWall
	if not wall:
		wall = get_tree().get_first_node_in_group("stone_wall") as StoneWall
	if wall:
		if not wall.wall_completed.is_connected(_on_stone_wall_completed):
			wall.wall_completed.connect(_on_stone_wall_completed)
		if not wall.stage_changed.is_connected(_on_stone_wall_stage_changed):
			wall.stage_changed.connect(_on_stone_wall_stage_changed)


func _on_stone_wall_stage_changed(new_stage: int, max_stages: int) -> void:
	if new_stage >= max_stages:
		_on_stone_wall_completed()


func _on_stone_wall_completed() -> void:
	if _is_game_finished:
		return
	_is_game_finished = true
	print("[GameController] Stone wall değeri MAX oldu! Oyun bitti, kazanma sekansı başlatılıyor...")
	_start_finish_sequence()


func _start_finish_sequence() -> void:
	# 1. Sol üstte duran coin HUD'ını arkaplana al / gizle
	var money_hud = get_tree().get_first_node_in_group("money_hud")
	if money_hud:
		if money_hud.has_method("send_to_background"):
			money_hud.send_to_background(true)
		else:
			money_hud.layer = 0

	# 2. Arka plan müziğini ve ambiyans seslerini pürüzsüzce sustur
	if _music_player and _music_player.playing:
		var music_tw := create_tween()
		music_tw.tween_property(_music_player, "volume_db", -80.0, 0.35)
		music_tw.tween_callback(_music_player.stop)

	if _ocean_player and _ocean_player.playing:
		_ocean_player.stop()
	if _wind_player and _wind_player.playing:
		_wind_player.stop()
	if _alarm_player and _alarm_player.playing:
		_alarm_player.stop()
	if _alarm_end_player and _alarm_end_player.playing:
		_alarm_end_player.stop()
	if _surge_audio_player and _surge_audio_player.playing:
		_surge_audio_player.stop()

	# 3. Kazanma sesini çal
	if _win_player:
		_win_player.play()

	# 4. CanvasLayer içindeki finish sahnesini görünür yap ve AnimationPlayer'ı oynat
	if _finish_canvas:
		_finish_canvas.layer = 105
	if _finish_rect:
		_finish_rect.visible = true

	if _finish_anim:
		_finish_anim.play("start")
	else:
		# Yedek güvence: Eğer animation player yoksa 3.5s sonra sahneyi yeniden başlat
		get_tree().create_timer(3.5).timeout.connect(_restart_game_after_finish)


func _on_finish_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"start" or anim_name == "start":
		print("[GameController] Finish animasyonu bitti! Oyun hemen yeniden başlatılıyor...")
		_restart_game_after_finish()


func _restart_game_after_finish() -> void:
	# GameManager para miktarını temizle / sıfırla
	var gm = get_node_or_null("/root/GameManager")
	if gm and "money" in gm:
		gm.money = 0
		if gm.has_signal("money_changed"):
			gm.money_changed.emit(0)

	# Oyunu hemen yeniden başlat
	get_tree().change_scene_to_file("res://Scenes/game.tscn")
