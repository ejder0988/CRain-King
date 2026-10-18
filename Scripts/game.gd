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

## Tsunami dalgasının geriden gelip duvara vurma süresi (SURGE - saniye, Varsayılan: 2.5s)
@export var surge_wave_duration: float = 2.5

## Tsunami vuruşundan sonra suların sağ havuza doğal geri çekilme süresi (BACKWASH - saniye, Varsayılan: 3.0s)
@export var backwash_duration: float = 3.0

## Sel ve yağmur başlamadan kaç saniye önce sağdaki kırmızı uyarının yanıp sönmeye başlayacağı (saniye)
@export var warning_lead_time: float = 6.0

## Sel vuruşundan kaç saniye sonra evlerin hayatta kalma durumu kontrol edilip para ödülü verileceği (saniye)
@export var post_surge_evaluation_delay: float = 3.5

## Geriye dönük uyumluluk için eski değişken
@export var rain_duration_before_surge: float = 8.0:
	get: return first_rain_duration
	set(v): first_rain_duration = v

## Sel döngüsü sistemi aktif olsun mu?
@export var enable_flood_cycle: bool = true

@export_group("Flood Water & Surge Physics")
## Her sel vuruşunda suya eklenecek temel parçacık sayısı (Kalıcı eklenmez, geçici takviyedir)
@export var flood_base_water_amount: int = 60

## Her yeni sel döngüsünde su miktarının ne kadar artacağı (Kademeli artış)
@export var flood_water_increment_per_cycle: int = 22

## Suların sol tarafa (evlere doğru) vurma itme kuvveti
@export var flood_surge_force: float = 1450.0

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

# UI Nodes
var _flood_ui_layer: CanvasLayer = null
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


func _ready() -> void:
	add_to_group("game_controller")
	_setup_intro_curtain()
	_setup_audio()
	_setup_ambient_audio()
	_setup_tsunami_audio()
	_setup_flood_audio()
	_setup_flood_ui()

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
				_start_backwash_phase()

		FloodState.BACKWASH:
			_cycle_timer += delta
			# Sular sağ havuza geri çekildi (3.0s)! Evlerin hayatta kalma kontrolü ve ödül
			if _cycle_timer >= backwash_duration:
				_cycle_timer = 0.0
				_evaluate_flood_survival_and_reward()

		FloodState.EVALUATING:
			_cycle_timer += delta
			# Ödül gösteriminin ardından bir sonraki 30 saniyelik döngüye geç
			if _cycle_timer >= 1.8:
				_cycle_timer = 0.0
				_flood_state = FloodState.COUNTDOWN


func _process_warning_flash(delta: float) -> void:
	if not _is_warning_flashing or not _warning_panel or not _warning_panel.visible:
		return
	_warning_flash_timer += delta
	var speed: float = 14.0 if _is_urgent_warning else 7.0
	var pulse: float = (sin(_warning_flash_timer * speed) + 1.0) * 0.5
	_warning_panel.modulate.a = lerpf(0.35, 1.0, pulse)
	_warning_panel.scale = Vector2.ONE * lerpf(0.97, 1.03, pulse)


## 1. Yağmur Aşaması: Downpour Y tuşu sekansındaki gibi ekranın sağından (bir kısmından) yavaşça süpürerek ve ses gecikmesiyle girer
func _start_first_rain_phase() -> void:
	_flood_state = FloodState.FIRST_RAIN
	_show_warning_ui(true)
	_play_tsunami_alarm()

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
	var total_rain_water: int = flood_base_water_amount + (_current_flood_cycle * flood_water_increment_per_cycle)
	var fw: FluidWater = _find_fluid_water()
	if fw:
		if fw.has_method("start_rain_reservoir_fill"):
			fw.start_rain_reservoir_fill(total_rain_water, first_rain_duration)
		elif fw.has_method("start_water_accumulation"):
			fw.start_water_accumulation(total_rain_water, first_rain_duration)

	print("[FloodCycle] 1. Yağmur (Downpour) başladı! Y tuşu sekansındaki gibi ekranın sağından süpürülerek geliyor. Süre: %.1fs | Rezervuar Takviyesi: %d damla" % [first_rain_duration, total_rain_water])


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
	_current_flood_cycle += 1
	_hide_warning_ui()
	_stop_tsunami_alarm()
	_play_surge_sound()

	var ws := _find_weather_system()
	if ws:
		ws.strike()

	# Geriden gelen hareketli tsunami dalgası (ASLA kalıcı su eklenmez! fw.max_particles arttırılmaz!)
	var fw: FluidWater = _find_fluid_water()
	if fw:
		if fw.has_method("start_rolling_wave"):
			fw.start_rolling_wave(surge_wave_duration, _current_flood_cycle)
		elif fw.has_method("start_controlled_surge"):
			fw.start_controlled_surge(surge_wave_duration, _current_flood_cycle)

	print("[FloodCycle] ★ GERİDEN GELEN TSUNAMİ DALGASI BAŞLADI! Döngü: #%d | Duvar Seviyesi: %d/24" % [_current_flood_cycle, _current_flood_cycle])


## 4. Geri Çekilme Aşaması (BACKWASH): Dalga duvara vurduktan sonra suların sağ havuza doğal geri çekilmesi (3.0s)
func _start_backwash_phase() -> void:
	_flood_state = FloodState.BACKWASH

	var fw: FluidWater = _find_fluid_water()
	if fw:
		if fw.has_method("start_tsunami_backwash"):
			fw.start_tsunami_backwash(backwash_duration)

	print("[FloodCycle] Dalga vurdu! Sular sağ havuza doğal şekilde geri çekiliyor (BACKWASH: %.1fs)." % backwash_duration)


## Geriye dönük uyumluluk takma adı
func _start_rain_phase() -> void:
	_start_first_rain_phase()


func _evaluate_flood_survival_and_reward() -> void:
	_flood_state = FloodState.EVALUATING
	_play_tsunami_end_alarm()

	var hm := _find_houses_manager()
	var standing_houses: int = hm.get_standing_houses_count() if hm and hm.has_method("get_standing_houses_count") else 0
	var total_levels: int = hm.get_total_health() if hm and hm.has_method("get_total_health") else 0

	# Yağmuru dindir ve gökyüzünü temizle
	var ws := _find_weather_system()
	if ws:
		ws.set_weather(WeatherSystem.WeatherType.CLEAR, 2.5)

	# Suları sakinleştir ve taşkın artıklarını temizle (havuz dengesini koru: ~160 parçacık)
	var fw: FluidWater = _find_fluid_water()
	if fw and fw.has_method("calm_and_cleanup_post_surge"):
		fw.calm_and_cleanup_post_surge(160)

	# Evler hala ayaktaysa çarpan kadar para ver ve UI'ı göster
	if standing_houses > 0 and total_levels > 0:
		var multiplier: int = total_levels if use_floor_levels_as_multiplier else standing_houses
		var earned_money: int = multiplier * base_reward_per_house

		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("add_money"):
			gm.add_money(earned_money)

		_show_reward_ui(standing_houses, multiplier, earned_money)
		print("[FloodCycle] Sel savuşturuldu! Ayakta kalan evler: %d | Çarpan: x%d | Kazanılan Para: +%d$" % [standing_houses, multiplier, earned_money])
	else:
		print("[FloodCycle] Tüm evler yıkıldı! Sel savuşturulamadı.")


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

	# 1. Sağ Taraftaki Kırmızı Yanıp Sönen Sel Uyarısı Paneli
	_warning_panel = PanelContainer.new()
	_warning_panel.name = "FloodWarningPanel"
	_warning_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_warning_panel.offset_left = -280.0
	_warning_panel.offset_right = -20.0
	_warning_panel.offset_top = -65.0
	_warning_panel.offset_bottom = 65.0
	_warning_panel.custom_minimum_size = Vector2(250.0, 95.0)
	_warning_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_panel.visible = false

	var warn_style := StyleBoxFlat.new()
	warn_style.bg_color = Color(0.12, 0.02, 0.04, 0.94)
	warn_style.set_border_width_all(2)
	warn_style.border_color = Color(1.0, 0.22, 0.22, 0.95)
	warn_style.set_corner_radius_all(10)
	warn_style.content_margin_left = 14
	warn_style.content_margin_right = 14
	warn_style.content_margin_top = 8
	warn_style.content_margin_bottom = 8
	warn_style.shadow_size = 12
	warn_style.shadow_color = Color(0.9, 0.0, 0.0, 0.45)
	_warning_panel.add_theme_stylebox_override("panel", warn_style)

	var warn_hbox := HBoxContainer.new()
	warn_hbox.add_theme_constant_override("separation", 10)
	warn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	_warning_icon = Label.new()
	_warning_icon.text = "⚠️"
	_warning_icon.add_theme_font_size_override("font_size", 28)
	warn_hbox.add_child(_warning_icon)

	var warn_vbox := VBoxContainer.new()
	warn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	_warning_title_lbl = Label.new()
	_warning_title_lbl.text = "SEL UYARISI!"
	_warning_title_lbl.add_theme_font_size_override("font_size", 16)
	_warning_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))

	_warning_subtitle_lbl = Label.new()
	_warning_subtitle_lbl.text = "Kalan Süre: 00:06"
	_warning_subtitle_lbl.add_theme_font_size_override("font_size", 13)
	_warning_subtitle_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))

	_warning_status_lbl = Label.new()
	_warning_status_lbl.text = "Taşkın Yaklaşıyor!"
	_warning_status_lbl.add_theme_font_size_override("font_size", 11)
	_warning_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))

	warn_vbox.add_child(_warning_title_lbl)
	warn_vbox.add_child(_warning_subtitle_lbl)
	warn_vbox.add_child(_warning_status_lbl)
	warn_hbox.add_child(warn_vbox)

	_warning_panel.add_child(warn_hbox)
	_flood_ui_layer.add_child(_warning_panel)

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
	if not _warning_panel:
		return
	_is_urgent_warning = is_urgent
	_is_warning_flashing = true
	_warning_panel.visible = true
	_warning_panel.pivot_offset = _warning_panel.size * 0.5


func _update_warning_ui(time_left: float, is_rain_phase: bool = false, _phase_tag: String = "") -> void:
	if not _warning_panel or not _warning_panel.visible:
		return
	if _warning_icon:
		_warning_icon.text = "⚠️"
	_warning_title_lbl.text = "SEL UYARISI!"
	_warning_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))

	var sec := int(ceil(time_left))
	_warning_subtitle_lbl.text = "Kalan Süre: 00:%02d" % sec
	_warning_subtitle_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))

	if is_rain_phase:
		_warning_status_lbl.text = "Tsunami Yaklaşıyor!"
		_warning_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	else:
		_warning_status_lbl.text = "Taşkın Yaklaşıyor!"
		_warning_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))


func _hide_warning_ui() -> void:
	_is_warning_flashing = false
	if _warning_panel:
		_warning_panel.visible = false
		_warning_panel.modulate.a = 1.0
		_warning_panel.scale = Vector2.ONE


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


func _stop_tsunami_alarm() -> void:
	if _alarm_player and _alarm_player.playing:
		_alarm_player.stop()


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
