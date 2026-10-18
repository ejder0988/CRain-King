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

@onready var _music_player: AudioStreamPlayer = get_node_or_null("GameMusicPlayer") as AudioStreamPlayer


func _ready() -> void:
	add_to_group("game_controller")
	_setup_audio()


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
