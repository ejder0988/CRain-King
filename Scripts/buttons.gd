extends Node2D
class_name ButtonsController

## ==============================================================================
## ButtonsController
## ==============================================================================
## 1. ESC Menüsü & Ses/Müzik Kontrolleri:
##    - ESC tuşuna bir kez basıldığında (tek basış) ses ve müzik menüsü açılır/kapanır.
##    - Menü açıkken SoundKeyA ('A') ile genel sesler tek seferde açılır/kapanır.
##    - Menü açıkken MusicKeyD ('D') ile müzik tek seferde açılır/kapanır.
##    - Ses ve müzik simgelerine veya SoundKeyA / MusicKeyD tuşlarına fareyle de tıklanabilir.
##    - Menü açıkken vinç kulesi ve arabası hareket etmez.
##
## 2. ESC Basılı Tutarak Oyundan Çıkma:
##    - ESC basılı tutulduğunda ekranın üst kısmında BEYAZ bir progress bar dolar.
##    - Oyundan atacağını hissettirmek için ekran kenarları kararır ve bar titrer.
##    - Süre dolduğunda oyun kapatılır (get_tree().quit()).
##    - Erken bırakılırsa (kısa basışsa) ESC menüsü açılır; uzun basılıp bırakılırsa iptal edilir.
##
## 3. R Basılı Tutarak Oyunu Yeniden Başlatma:
##    - R tuşuna basılı tutulduğunda yukarıdan FARKLI (Neon Camgöbeği) bir bar dolar.
##    - Süre dolduğunda oyun yeniden başlar (get_tree().reload_current_scene()).
##
## 4. Öğretici Butonları:
##    - Q ve E birleşiktir: Birine basılırsa ikisi de 3-5s sonra birlikte kapanır.
##    - A ve D birleşiktir: Vinç arabasındaki A ve D tuşları 3-5s sonra kapanır.
##    - Space basıldığında 3-5s sonra kapanır.
##    - SADECE SHIFT KALICIDIR: Shift asla yok olmaz, taş üretim rehberi olarak kalır.
## ==============================================================================

# Global durum bayrağı: Diğer scriptlerin (ör. crane.gd) menü açıkken hareketi durdurması için
static var is_esc_menu_open: bool = false

# ------------------------------------------------------------------------------
# 1. INSPECTOR AYARLARI
# ------------------------------------------------------------------------------
@export_group("ESC Menüsü (Sound & Music Settings)")
## ESC menüsü başlangıçta açık olsun mu? (Varsayılan: false)
@export var esc_menu_open_at_start: bool = false
## SoundKeyA Sprite2D referansı
@export var sound_key_a_sprite: Sprite2D
## MusicKeyD Sprite2D referansı
@export var music_key_d_sprite: Sprite2D

@export_group("Basılı Tutma Ayarları (Hold to Quit & Restart)")
## Oyundan çıkmak için ESC tuşunu basılı tutma süresi (saniye)
@export var esc_quit_hold_time: float = 1.8
## ESC tek basış (menü açma/kapatma) eşik süresi (saniye)
@export var esc_tap_threshold: float = 0.28
## Oyundan çıkış tam ekran ince barının yüksekliği (piksel)
@export var esc_bar_height: float = 6.0
## Oyunu yeniden başlatmak için R tuşunu basılı tutma süresi (saniye)
@export var r_restart_hold_time: float = 1.4
## Oyun yeniden başladığında R tuşunun algılanması için beklenecek gecikme süresi (saniye)
@export var r_restart_startup_delay: float = 1.0

@export_group("Öğretici Yok Olma Ayarları (Tutorial Settings)")
## Butona ilk basıldıktan kaç saniye sonra kaybolmaya başlayacak (3 ile 5 saniye arası)
@export_range(1.0, 10.0, 0.5) var disappear_delay: float = 4.0
## Kaybolurken yumuşak kararma süresi (saniye)
@export var fade_duration: float = 0.6
## Basıldığında butonun hafif aşağı kayma mesafesi (piksel)
@export var press_offset_y: float = 0.0

@export_group("Tıklanılmış Sprite'lar (Pressed Sprites)")
## Q tuşuna basıldığında gösterilecek sprite (Boşsa Buttons.png'den otomatik alınır)
@export var q_pressed_texture: Texture2D
## E tuşuna basıldığında gösterilecek sprite (Boşsa Buttons.png'den otomatik alınır)
@export var e_pressed_texture: Texture2D
## A tuşuna basıldığında gösterilecek sprite (Boşsa Buttons.png'den otomatik alınır)
@export var a_pressed_texture: Texture2D
## D tuşuna basıldığında gösterilecek sprite (Boşsa Buttons.png'den otomatik alınır)
@export var d_pressed_texture: Texture2D
## Space tuşuna basıldığında gösterilecek sprite (Boşsa Buttons.png'den otomatik alınır)
@export var space_pressed_texture: Texture2D
## Shift tuşuna basıldığında gösterilecek sprite (Shift kalıcıdır)
@export var shift_pressed_texture: Texture2D
## Esc tuşuna basıldığında gösterilecek sprite (Boşsa Buttons.png'den otomatik alınır)
@export var esc_pressed_texture: Texture2D
## Sound butonuna tıklandığında gösterilecek sprite (Muted Speaker)
@export var sound_pressed_texture: Texture2D
## Music butonuna tıklandığında gösterilecek sprite (Muted Music Note)
@export var music_pressed_texture: Texture2D

@export_group("Normal / Bırakılmış Sprite'lar (Unpressed Sprites - İsteğe Bağlı)")
@export var q_normal_texture: Texture2D
@export var e_normal_texture: Texture2D
@export var a_normal_texture: Texture2D
@export var d_normal_texture: Texture2D
@export var space_normal_texture: Texture2D
@export var shift_normal_texture: Texture2D
@export var esc_normal_texture: Texture2D
@export var sound_normal_texture: Texture2D
@export var music_normal_texture: Texture2D

@export_group("Buton Düğüm Referansları (Node References)")
@export var q_sprite: Sprite2D
@export var e_sprite: Sprite2D
@export var a_sprite: Sprite2D
@export var d_sprite: Sprite2D
@export var space_sprite: Sprite2D
@export var shift_sprite: Sprite2D
@export var esc_sprite: Sprite2D
@export var sound_sprite: Sprite2D
@export var music_sprite: Sprite2D
## Vinç üstündeki ilave öğretici A ve D sprite'ları
@export var extra_a_sprites: Array[Sprite2D] = []
@export var extra_d_sprites: Array[Sprite2D] = []

# ------------------------------------------------------------------------------
# 2. SABİTLER - Buttons.png Atlas Koordinatları (Varsayılan Yedek)
# ------------------------------------------------------------------------------
const BUTTONS_SHEET_PATH := "res://Sprites/Buttons.png"

# Normal / Bırakılmış çerçeveler
const RECT_SHIFT_NORMAL := Rect2(1, 5, 30, 22)
const RECT_ESC_NORMAL := Rect2(66, 5, 28, 22)
const RECT_Q_NORMAL := Rect2(7, 35, 18, 22)
const RECT_SOUND_NORMAL := Rect2(71, 35, 18, 22)
const RECT_E_NORMAL := Rect2(7, 67, 18, 22)
const RECT_MUSIC_NORMAL := Rect2(71, 67, 18, 22)
const RECT_SPACE_NORMAL := Rect2(1, 96, 46, 14)
const RECT_D_NORMAL := Rect2(3, 113, 11, 14)
const RECT_A_NORMAL := Rect2(35, 113, 11, 14)

# Basılmış / Tıklanılmış çerçeveler
const RECT_SHIFT_PRESSED := Rect2(33, 8, 30, 19)
const RECT_ESC_PRESSED := Rect2(98, 8, 28, 19)
const RECT_Q_PRESSED := Rect2(39, 38, 18, 19)
const RECT_SOUND_PRESSED := Rect2(103, 38, 18, 19)
const RECT_E_PRESSED := Rect2(39, 70, 18, 19)
const RECT_MUSIC_PRESSED := Rect2(103, 70, 18, 19)
const RECT_SPACE_PRESSED := Rect2(49, 98, 46, 12)
const RECT_D_PRESSED := Rect2(19, 115, 11, 12)
const RECT_A_PRESSED := Rect2(51, 115, 11, 12)

# ------------------------------------------------------------------------------
# 3. İÇ DURUM DEĞİŞKENLERİ
# ------------------------------------------------------------------------------
var _buttons_sheet: Texture2D

# Sadece vinç kulesindeki öğretici A ve D listesi (SoundKeyA/MusicKeyD hariç!)
var _tutorial_a_nodes: Array[Sprite2D] = []
var _tutorial_d_nodes: Array[Sprite2D] = []

# Düğüm başına orijinal normal dokular ve pozisyonlar
var _original_textures: Dictionary = {}
var _original_positions: Dictionary = {}

# Öğretici Zamanlayıcıları
var _qe_triggered: bool = false
var _qe_timer: float = 0.0
var _qe_faded: bool = false

var _ad_triggered: bool = false
var _ad_timer: float = 0.0
var _ad_faded: bool = false

var _space_triggered: bool = false
var _space_timer: float = 0.0
var _space_faded: bool = false

# ESC & R Basılı Tutma Takibi
var _esc_held_duration: float = 0.0
var _esc_was_down: bool = false
var _esc_handled_quit: bool = false

var _r_held_duration: float = 0.0
var _r_was_down: bool = false
var _r_handled_restart: bool = false

# Fare ile basılı tutulan buton adı
var _mouse_held_btn: String = ""

# Shift Fabrika Yükseltme Badge & Red Animasyonu
var _shift_price_panel: PanelContainer = null
var _shift_price_label: Label = null
var _original_shift_pos: Vector2 = Vector2.ZERO
var _original_price_pos: Vector2 = Vector2.ZERO
var _shift_shake_tween: Tween = null
var _prev_shift_down: bool = false
var _prev_mouse_shift_down: bool = false

# Ses Durumları
var _sound_muted: bool = false
var _music_muted: bool = false

# UI Katmanı ve Progress Barlar
var _ui_canvas: CanvasLayer
var _screen_overlay: ColorRect
var _bar_root_control: Control
var _quit_container: Control
var _quit_bar: ProgressBar
var _quit_text_box: VBoxContainer
var _quit_title: Label
var _quit_subtitle: Label

var _restart_container: VBoxContainer
var _restart_bar: ProgressBar
var _restart_title: Label
var _restart_subtitle: Label
var _r_startup_delay_timer: float = 1.0

# ------------------------------------------------------------------------------
# 4. _READY VE BAŞLATMA
# ------------------------------------------------------------------------------
func _ready() -> void:
	add_to_group("buttons")
	_r_startup_delay_timer = r_restart_startup_delay
	if ResourceLoader.exists(BUTTONS_SHEET_PATH):
		_buttons_sheet = load(BUTTONS_SHEET_PATH)

	_setup_audio_buses()
	_resolve_node_references()
	_setup_textures_and_cache()
	_setup_ui_bars()

	if shift_sprite:
		_original_shift_pos = shift_sprite.position
		_setup_shift_price_badge()

	# Ensure MoneyHUD exists in scene
	if is_inside_tree() and not get_tree().get_first_node_in_group("money_hud"):
		var hud_script: GDScript = load("res://Scripts/money_hud.gd") as GDScript
		if hud_script:
			var hud: Node = hud_script.new()
			hud.name = "MoneyHUD"
			var parent_node: Node = get_parent() if get_parent() else self
			parent_node.add_child.call_deferred(hud)

	# ESC Menüsünün başlangıç durumunu ayarla
	ButtonsController.is_esc_menu_open = esc_menu_open_at_start
	_apply_esc_menu_visibility(esc_menu_open_at_start, false)
	_apply_audio_state()
	_update_sound_visuals()
	_update_music_visuals()


func _setup_audio_buses() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var sfx_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")

	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var music_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_idx, "Music")
		AudioServer.set_bus_send(music_idx, "Master")


func _resolve_node_references() -> void:
	if not q_sprite:
		q_sprite = get_node_or_null("Q") as Sprite2D
	if not e_sprite:
		e_sprite = get_node_or_null("E") as Sprite2D
	if not shift_sprite:
		shift_sprite = get_node_or_null("Shift") as Sprite2D
	if not space_sprite:
		space_sprite = get_node_or_null("Space") as Sprite2D
	if not esc_sprite:
		esc_sprite = get_node_or_null("Esc") as Sprite2D
	if not sound_sprite:
		sound_sprite = get_node_or_null("Sound") as Sprite2D
	if not music_sprite:
		music_sprite = get_node_or_null("Music") as Sprite2D
	if not sound_key_a_sprite:
		sound_key_a_sprite = get_node_or_null("SoundKeyA") as Sprite2D
	if not music_key_d_sprite:
		music_key_d_sprite = get_node_or_null("MusicKeyD") as Sprite2D

	# Vinç kulesindeki öğretici A düğümü
	if not a_sprite:
		a_sprite = get_node_or_null("../Crane/TrolleyPivot/A") as Sprite2D
	if not a_sprite:
		a_sprite = get_node_or_null("A") as Sprite2D

	# Vinç kulesindeki öğretici D düğümü
	if not d_sprite:
		d_sprite = get_node_or_null("../Crane/TrolleyPivot/D") as Sprite2D
	if not d_sprite:
		d_sprite = get_node_or_null("D") as Sprite2D

	# Öğretici A listesi (SoundKeyA bilerek EKLENMEZ!)
	_collect_node(_tutorial_a_nodes, a_sprite)
	_collect_node(_tutorial_a_nodes, get_node_or_null("../Crane/TrolleyPivot/A") as Sprite2D)
	for s in extra_a_sprites:
		_collect_node(_tutorial_a_nodes, s)

	# Öğretici D listesi (MusicKeyD bilerek EKLENMEZ!)
	_collect_node(_tutorial_d_nodes, d_sprite)
	_collect_node(_tutorial_d_nodes, get_node_or_null("../Crane/TrolleyPivot/D") as Sprite2D)
	for s in extra_d_sprites:
		_collect_node(_tutorial_d_nodes, s)


func _collect_node(list: Array[Sprite2D], node: Sprite2D) -> void:
	if node != null and is_instance_valid(node) and not list.has(node):
		list.append(node)


func _setup_textures_and_cache() -> void:
	# Pressed dokularını ayarla (atanmamışsa Buttons.png'den oluştur)
	q_pressed_texture = _ensure_atlas(q_pressed_texture, RECT_Q_PRESSED)
	e_pressed_texture = _ensure_atlas(e_pressed_texture, RECT_E_PRESSED)
	a_pressed_texture = _ensure_atlas(a_pressed_texture, RECT_A_PRESSED)
	d_pressed_texture = _ensure_atlas(d_pressed_texture, RECT_D_PRESSED)
	space_pressed_texture = _ensure_atlas(space_pressed_texture, RECT_SPACE_PRESSED)
	shift_pressed_texture = _ensure_atlas(shift_pressed_texture, RECT_SHIFT_PRESSED)
	esc_pressed_texture = _ensure_atlas(esc_pressed_texture, RECT_ESC_PRESSED)
	sound_pressed_texture = _ensure_atlas(sound_pressed_texture, RECT_SOUND_PRESSED)
	music_pressed_texture = _ensure_atlas(music_pressed_texture, RECT_MUSIC_PRESSED)

	# Normal dokuları ayarla ve önbelleğe al
	_cache_sprite(q_sprite, q_normal_texture, RECT_Q_NORMAL)
	_cache_sprite(e_sprite, e_normal_texture, RECT_E_NORMAL)
	_cache_sprite(shift_sprite, shift_normal_texture, RECT_SHIFT_NORMAL)
	_cache_sprite(space_sprite, space_normal_texture, RECT_SPACE_NORMAL)
	_cache_sprite(esc_sprite, esc_normal_texture, RECT_ESC_NORMAL)
	_cache_sprite(sound_sprite, sound_normal_texture, RECT_SOUND_NORMAL)
	_cache_sprite(music_sprite, music_normal_texture, RECT_MUSIC_NORMAL)
	_cache_sprite(sound_key_a_sprite, a_normal_texture, RECT_A_NORMAL)
	_cache_sprite(music_key_d_sprite, d_normal_texture, RECT_D_NORMAL)

	for s in _tutorial_a_nodes:
		_cache_sprite(s, a_normal_texture, RECT_A_NORMAL)
	for s in _tutorial_d_nodes:
		_cache_sprite(s, d_normal_texture, RECT_D_NORMAL)


func _ensure_atlas(existing: Texture2D, region: Rect2) -> Texture2D:
	if existing != null:
		return existing
	if _buttons_sheet != null:
		var at := AtlasTexture.new()
		at.atlas = _buttons_sheet
		at.region = region
		return at
	return null


func _cache_sprite(s: Sprite2D, custom_normal: Texture2D, fallback_region: Rect2) -> void:
	if not s or not is_instance_valid(s):
		return
	_original_positions[s] = s.position
	if custom_normal != null:
		s.texture = custom_normal
		_original_textures[s] = custom_normal
	elif s.texture != null:
		_original_textures[s] = s.texture
	else:
		var at := _ensure_atlas(null, fallback_region)
		s.texture = at
		_original_textures[s] = at


# ------------------------------------------------------------------------------
# 5. UI BARS (ESC ÇIKIŞ BARI & R YENİDEN BAŞLATMA BARI)
# ------------------------------------------------------------------------------
func _setup_ui_bars() -> void:
	_ui_canvas = CanvasLayer.new()
	_ui_canvas.name = "HoldActionCanvasLayer"
	_ui_canvas.layer = 125
	add_child(_ui_canvas)

	# Tam ekran kararma katmanı (Cinematic Vignette)
	_screen_overlay = ColorRect.new()
	_screen_overlay.name = "ScreenOverlay"
	_screen_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_overlay.color = Color(0, 0, 0, 0.0)
	_ui_canvas.add_child(_screen_overlay)

	# Üst orta bar kapsayıcısı
	_bar_root_control = Control.new()
	_bar_root_control.name = "BarRootControl"
	_bar_root_control.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar_root_control.offset_left = 0.0
	_bar_root_control.offset_right = 0.0
	_bar_root_control.offset_top = 0.0
	_bar_root_control.offset_bottom = 160.0
	_bar_root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_canvas.add_child(_bar_root_control)

	# 1. ESC Oyundan Çıkış Barı (TAM EKRAN EN ÜSTTE İNCE BEYAZ BAR)
	_quit_container = Control.new()
	_quit_container.name = "QuitContainer"
	_quit_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_quit_container.anchor_left = 0.0
	_quit_container.anchor_right = 1.0
	_quit_container.anchor_top = 0.0
	_quit_container.anchor_bottom = 0.0
	_quit_container.offset_left = 0.0
	_quit_container.offset_right = 0.0
	_quit_container.offset_top = 0.0
	_quit_container.offset_bottom = 80.0
	_quit_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quit_container.visible = false
	_quit_container.modulate.a = 0.0
	_bar_root_control.add_child(_quit_container)

	_quit_bar = ProgressBar.new()
	_quit_bar.name = "QuitProgressBar"
	_quit_bar.show_percentage = false
	_quit_bar.min_value = 0.0
	_quit_bar.max_value = 100.0
	_quit_bar.value = 0.0
	_quit_bar.anchor_left = 0.0
	_quit_bar.anchor_right = 1.0
	_quit_bar.anchor_top = 0.0
	_quit_bar.anchor_bottom = 0.0
	_quit_bar.offset_left = 0.0
	_quit_bar.offset_right = 0.0
	_quit_bar.offset_top = 0.0
	_quit_bar.offset_bottom = esc_bar_height
	_quit_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Arka plan: Ekranın en üstünde çok hafif yarı saydam koyu zemin
	var quit_bg_style := StyleBoxFlat.new()
	quit_bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.50)
	quit_bg_style.border_width_bottom = 1
	quit_bg_style.border_color = Color(1.0, 1.0, 1.0, 0.15)
	_quit_bar.add_theme_stylebox_override("background", quit_bg_style)

	# Dolgu: Saf parlak beyaz ince bar
	var quit_fill_style := StyleBoxFlat.new()
	quit_fill_style.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	_quit_bar.add_theme_stylebox_override("fill", quit_fill_style)

	_quit_container.add_child(_quit_bar)

	# İnce barın hemen altındaki bilgilendirici metinler
	_quit_text_box = VBoxContainer.new()
	_quit_text_box.name = "QuitTextBox"
	_quit_text_box.anchor_left = 0.5
	_quit_text_box.anchor_right = 0.5
	_quit_text_box.anchor_top = 0.0
	_quit_text_box.anchor_bottom = 0.0
	_quit_text_box.offset_left = -260.0
	_quit_text_box.offset_right = 260.0
	_quit_text_box.offset_top = esc_bar_height + 4.0
	_quit_text_box.offset_bottom = esc_bar_height + 56.0
	_quit_text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_quit_text_box.add_theme_constant_override("separation", 2)
	_quit_text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quit_container.add_child(_quit_text_box)

	_quit_title = Label.new()
	_quit_title.name = "TitleLabel"
	_quit_title.text = "OYUNDAN ÇIKILIYOR"
	_quit_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quit_title.add_theme_font_size_override("font_size", 16)
	_quit_title.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38, 1.0))
	_quit_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_quit_title.add_theme_constant_override("outline_size", 4)
	_quit_text_box.add_child(_quit_title)

	_quit_subtitle = Label.new()
	_quit_subtitle.name = "SubtitleLabel"
	_quit_subtitle.text = "[ESC] Tuşunu basılı tutun"
	_quit_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quit_subtitle.add_theme_font_size_override("font_size", 12)
	_quit_subtitle.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96, 0.88))
	_quit_subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_quit_subtitle.add_theme_constant_override("outline_size", 3)
	_quit_text_box.add_child(_quit_subtitle)

	# 2. R Oyunu Yeniden Başlatma Barı (NEON CAMGÖBEĞİ DOLGU)
	_restart_container = _build_action_bar_container(
		"RestartContainer",
		"OYUN YENİDEN BAŞLATILIYOR",
		"[R] Tuşunu basılı tutun",
		Color(0.25, 0.88, 1.0, 1.0), # Neon Cyan bar
		Color(0.35, 0.90, 1.0, 1.0) # Başlık camgöbeği
	)
	_bar_root_control.add_child(_restart_container)
	_restart_bar = _restart_container.get_node("ProgressBar") as ProgressBar
	_restart_title = _restart_container.get_node("TitleLabel") as Label
	_restart_subtitle = _restart_container.get_node("SubtitleLabel") as Label


func _build_action_bar_container(container_name: String, title_text: String, sub_text: String, fill_color: Color, title_color: Color) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.name = container_name
	vbox.custom_minimum_size = Vector2(560, 80)
	vbox.position = Vector2(960 - 280, 26)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	vbox.visible = false
	vbox.modulate.a = 0.0

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", title_color)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title)

	var pbar := ProgressBar.new()
	pbar.name = "ProgressBar"
	pbar.show_percentage = false
	pbar.min_value = 0.0
	pbar.max_value = 100.0
	pbar.value = 0.0
	pbar.custom_minimum_size = Vector2(520, 16)
	pbar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Arka plan stili
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.08, 0.12, 0.90)
	bg_style.set_corner_radius_all(6)
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(1.0, 1.0, 1.0, 0.30)
	pbar.add_theme_stylebox_override("background", bg_style)

	# Dolgu stili
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(5)
	pbar.add_theme_stylebox_override("fill", fill_style)

	vbox.add_child(pbar)

	var subtitle := Label.new()
	subtitle.name = "SubtitleLabel"
	subtitle.text = sub_text
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.90, 0.92, 0.95, 0.85))
	subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	subtitle.add_theme_constant_override("outline_size", 3)
	vbox.add_child(subtitle)

	return vbox


# ------------------------------------------------------------------------------
# 6. HER KARE GİRİŞ VE SÜREÇ KONTROLÜ
# ------------------------------------------------------------------------------
func _process(delta: float) -> void:
	_handle_esc_hold_and_tap(delta)
	_handle_r_hold_restart(delta)
	_check_tutorial_inputs()
	_process_tutorial_timers(delta)


func _handle_esc_hold_and_tap(delta: float) -> void:
	if _esc_handled_quit:
		return

	var esc_down: bool = Input.is_key_pressed(KEY_ESCAPE) or _mouse_held_btn == "Esc"

	# ESC basılı tutuluyor
	if esc_down:
		_esc_held_duration += delta

		# Basılı tutma eşiğini geçtiyse Barı göster ve doldur
		if _esc_held_duration >= esc_tap_threshold:
			var hold_window: float = esc_quit_hold_time - esc_tap_threshold
			var ratio: float = clamp((_esc_held_duration - esc_tap_threshold) / hold_window, 0.0, 1.0)

			_quit_container.visible = true
			_quit_container.modulate.a = lerp(_quit_container.modulate.a, 1.0, 0.25)
			_quit_bar.value = ratio * 100.0
			_quit_subtitle.text = "Oyundan çıkmak için [ESC] basılı tutun (%d%%)" % int(ratio * 100.0)

			# Oyundan çıkacağını hissettiren görsel efektler
			var overlay_alpha: float = clamp(ratio * 0.75, 0.0, 0.80)
			_screen_overlay.color = Color(0.12, 0.0, 0.02, overlay_alpha)

			# %65'i geçince metin titremesi ve gerilim efekti
			var screen_w := get_viewport_rect().size.x if is_inside_tree() else 1920.0
			var base_x := screen_w * 0.5 - 260.0
			var base_y := esc_bar_height + 4.0
			if ratio > 0.65:
				var shake_mag: float = (ratio - 0.65) * 14.0
				var time_ms: float = Time.get_ticks_msec()
				if _quit_text_box:
					_quit_text_box.position.x = base_x + sin(time_ms * 0.08) * shake_mag
					_quit_text_box.position.y = base_y + cos(time_ms * 0.09) * (shake_mag * 0.4)
			else:
				if _quit_text_box:
					_quit_text_box.position = Vector2(base_x, base_y)

			# %100 DOLDU: OYUNDAN AT (QUIT)
			if ratio >= 1.0:
				_esc_handled_quit = true
				_screen_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
				print("[Buttons] ESC ile oyundan çıkılıyor...")
				get_tree().quit()
				return

		_update_node_visual(esc_sprite, true, esc_pressed_texture)
	else:
		# ESC bırakıldı
		if _esc_was_down:
			# Eğer bırakılan süre tap eşiğinden kısaysa: TEK BASIŞ -> ESC MENÜSÜNÜ AÇ/KAPA
			if _esc_held_duration < esc_tap_threshold:
				toggle_esc_menu()
			# Uzun basılı tutulup bırakıldıysa: Çıkış İptal edildi, menü durumu değişmez

			_esc_held_duration = 0.0
			var screen_w := get_viewport_rect().size.x if is_inside_tree() else 1920.0
			var base_x := screen_w * 0.5 - 260.0
			var base_y := esc_bar_height + 4.0
			if _quit_text_box:
				_quit_text_box.position = Vector2(base_x, base_y)

			# Barı ve kararmayı yumuşakça sıfırla
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(_quit_container, "modulate:a", 0.0, 0.2)
			tw.tween_property(_screen_overlay, "color:a", 0.0, 0.25)
			tw.set_parallel(false)
			tw.tween_callback(func():
				_quit_container.visible = false
				_quit_bar.value = 0.0
			)

		_update_node_visual(esc_sprite, false, esc_pressed_texture)

	_esc_was_down = esc_down


func _handle_r_hold_restart(delta: float) -> void:
	if _r_handled_restart:
		return

	# Yeniden başlatma sonrası 1 saniyelik bekleme/güvenlik gecikmesi
	if _r_startup_delay_timer > 0.0:
		_r_startup_delay_timer -= delta
		_r_held_duration = 0.0
		if _restart_container:
			_restart_container.visible = false
			_restart_bar.value = 0.0
		return

	var r_down: bool = Input.is_key_pressed(KEY_R)

	if r_down:
		_r_held_duration += delta

		if _r_held_duration >= 0.15:
			var ratio: float = clamp((_r_held_duration - 0.15) / (r_restart_hold_time - 0.15), 0.0, 1.0)

			_restart_container.visible = true
			_restart_container.modulate.a = lerp(_restart_container.modulate.a, 1.0, 0.25)
			_restart_bar.value = ratio * 100.0
			_restart_subtitle.text = "Oyunu yeniden başlatmak için [R] basılı tutun (%d%%)" % int(ratio * 100.0)

			var overlay_alpha: float = clamp(ratio * 0.55, 0.0, 0.60)
			_screen_overlay.color = Color(0.0, 0.05, 0.10, overlay_alpha)

			# %100 DOLDU: OYUNU YENİDEN BAŞLAT
			if ratio >= 1.0:
				_r_handled_restart = true
				_screen_overlay.color = Color(0.2, 0.8, 1.0, 0.9)
				print("[Buttons] R tuşu ile oyun yeniden başlatılıyor...")
				get_tree().reload_current_scene()
				return
	else:
		if _r_was_down:
			_r_held_duration = 0.0
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(_restart_container, "modulate:a", 0.0, 0.2)
			tw.tween_property(_screen_overlay, "color:a", 0.0, 0.25)
			tw.set_parallel(false)
			tw.tween_callback(func():
				_restart_container.visible = false
				_restart_bar.value = 0.0
			)

	_r_was_down = r_down


# ------------------------------------------------------------------------------
# 7. ESC MENÜSÜ (SES & MÜZİK AÇ / KAPA)
# ------------------------------------------------------------------------------
func toggle_esc_menu() -> void:
	ButtonsController.is_esc_menu_open = not ButtonsController.is_esc_menu_open
	print("[ButtonsController] ESC Menüsü: ", "AÇIK" if ButtonsController.is_esc_menu_open else "KAPALI")
	_apply_esc_menu_visibility(ButtonsController.is_esc_menu_open, true)


func _apply_esc_menu_visibility(is_open: bool, animate: bool) -> void:
	var menu_nodes: Array[Sprite2D] = [sound_sprite, sound_key_a_sprite, music_sprite, music_key_d_sprite]

	# Notify MoneyHUD to smoothly slide down when ESC menu is open, and up when closed
	if is_inside_tree():
		var hud = get_tree().get_first_node_in_group("money_hud")
		if hud and hud.has_method("set_descended"):
			hud.set_descended(is_open)

	if not animate:
		for s in menu_nodes:
			if s and is_instance_valid(s):
				s.visible = is_open
				s.modulate.a = 1.0 if is_open else 0.0
		return

	var tw := create_tween()
	tw.set_parallel(true)

	if is_open:
		for s in menu_nodes:
			if s and is_instance_valid(s):
				s.visible = true
				tw.tween_property(s, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		for s in menu_nodes:
			if s and is_instance_valid(s):
				tw.tween_property(s, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.set_parallel(false)
		tw.tween_callback(func():
			if not ButtonsController.is_esc_menu_open:
				for s in menu_nodes:
					if s and is_instance_valid(s):
						s.visible = false
		)


func _unhandled_input(event: InputEvent) -> void:
	# ESC menüsü açıkken A ve D tuşları doğrudan Ses ve Müzik aç/kapa yapar
	if ButtonsController.is_esc_menu_open and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A or event.physical_keycode == KEY_A:
			get_viewport().set_input_as_handled()
			_toggle_sound()
			return
		elif event.keycode == KEY_D or event.physical_keycode == KEY_D:
			get_viewport().set_input_as_handled()
			_toggle_music()
			return

	# Fare tıklaması kontrolü
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_mouse_click()
		else:
			_mouse_held_btn = ""


func _handle_mouse_click() -> void:
	# Esc tıklandı
	if _is_mouse_over(esc_sprite):
		_mouse_held_btn = "Esc"
		return

	# ESC Menüsü düğmeleri
	if ButtonsController.is_esc_menu_open:
		if _is_mouse_over(sound_sprite) or _is_mouse_over(sound_key_a_sprite):
			_toggle_sound()
			return
		if _is_mouse_over(music_sprite) or _is_mouse_over(music_key_d_sprite):
			_toggle_music()
			return

	# Öğretici düğmeleri
	if _is_mouse_over(q_sprite):
		_mouse_held_btn = "Q"
		return
	if _is_mouse_over(e_sprite):
		_mouse_held_btn = "E"
		return
	if _is_mouse_over(space_sprite):
		_mouse_held_btn = "Space"
		return
	if _is_mouse_over(shift_sprite):
		_mouse_held_btn = "Shift"
		return

	for s in _tutorial_a_nodes:
		if _is_mouse_over(s):
			_mouse_held_btn = "A"
			return
	for s in _tutorial_d_nodes:
		if _is_mouse_over(s):
			_mouse_held_btn = "D"
			return


func _toggle_sound() -> void:
	_sound_muted = not _sound_muted
	print("[ButtonsController] Genel Sesler: ", "KAPALI (MUTED)" if _sound_muted else "AÇIK (ON)")
	_apply_audio_state()
	_update_sound_visuals()
	_flash_key_sprite(sound_key_a_sprite, a_pressed_texture)


func _toggle_music() -> void:
	_music_muted = not _music_muted
	print("[ButtonsController] Müzik: ", "KAPALI (MUTED)" if _music_muted else "AÇIK (ON)")
	_apply_audio_state()
	_update_music_visuals()
	_flash_key_sprite(music_key_d_sprite, d_pressed_texture)


func _update_sound_visuals() -> void:
	if sound_sprite and is_instance_valid(sound_sprite):
		if _sound_muted and sound_pressed_texture:
			sound_sprite.texture = sound_pressed_texture
		else:
			sound_sprite.texture = _original_textures.get(sound_sprite, sound_normal_texture)


func _update_music_visuals() -> void:
	if music_sprite and is_instance_valid(music_sprite):
		if _music_muted and music_pressed_texture:
			music_sprite.texture = music_pressed_texture
		else:
			music_sprite.texture = _original_textures.get(music_sprite, music_normal_texture)


func _flash_key_sprite(s: Sprite2D, pressed_tex: Texture2D) -> void:
	if not s or not is_instance_valid(s) or not pressed_tex:
		return
	s.texture = pressed_tex
	var tw := create_tween()
	tw.tween_interval(0.14)
	tw.tween_callback(func():
		if is_instance_valid(s):
			s.texture = _original_textures.get(s, null)
	)


func _apply_audio_state() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	var sfx_idx := AudioServer.get_bus_index("SFX")
	var music_idx := AudioServer.get_bus_index("Music")

	if sfx_idx >= 0:
		AudioServer.set_bus_mute(sfx_idx, _sound_muted)
	elif master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, _sound_muted)

	if music_idx >= 0:
		AudioServer.set_bus_mute(music_idx, _music_muted)

	# Sahnedeki AudioStreamPlayer'ları doğru veriyollarına yönlendir
	_sync_audio_stream_players()


func _sync_audio_stream_players() -> void:
	var root := get_tree().current_scene
	if not root:
		return
	_assign_buses_recursive(root)


func _assign_buses_recursive(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		var node_name_lower := node.name.to_lower()
		if node.is_in_group("music") or "music" in node_name_lower or "bgm" in node_name_lower:
			if node.bus == "Master":
				node.bus = "Music"
		else:
			if node.bus == "Master":
				node.bus = "SFX"

	for child in node.get_children():
		_assign_buses_recursive(child)


func _is_mouse_over(s: Sprite2D) -> bool:
	if not s or not is_instance_valid(s) or not s.is_visible_in_tree() or s.modulate.a <= 0.05:
		return false
	var tex := s.texture
	if not tex:
		return false
	var local_m := s.to_local(s.get_global_mouse_position())
	var sz := tex.get_size()
	var rect := Rect2(-sz * 0.5 if s.centered else Vector2.ZERO, sz)
	return rect.has_point(local_m)


# ------------------------------------------------------------------------------
# 8. ÖĞRETİCİ BUTONLARI (Q/E, A/D, SPACE, SHIFT)
# ------------------------------------------------------------------------------
func _check_tutorial_inputs() -> void:
	# ESC menüsü açıkken vinç kulesi öğretici girişleri çalışmaz
	if ButtonsController.is_esc_menu_open:
		return

	# 1. Q tuşu
	var q_active: bool = (
		Input.is_key_pressed(KEY_Q)
		or (InputMap.has_action("crane_turn_left") and Input.is_action_pressed("crane_turn_left"))
		or _mouse_held_btn == "Q"
	)

	# 2. E tuşu
	var e_active: bool = (
		Input.is_key_pressed(KEY_E)
		or (InputMap.has_action("crane_turn_right") and Input.is_action_pressed("crane_turn_right"))
		or _mouse_held_btn == "E"
	)

	# 3. A tuşu (sadece vinç arabası)
	var a_active: bool = (
		Input.is_key_pressed(KEY_A)
		or Input.is_key_pressed(KEY_LEFT)
		or (InputMap.has_action("move_left") and Input.is_action_pressed("move_left"))
		or _mouse_held_btn == "A"
	)

	# 4. D tuşu (sadece vinç arabası)
	var d_active: bool = (
		Input.is_key_pressed(KEY_D)
		or Input.is_key_pressed(KEY_RIGHT)
		or (InputMap.has_action("move_right") and Input.is_action_pressed("move_right"))
		or _mouse_held_btn == "D"
	)

	# 5. Space tuşu
	var space_active: bool = (
		Input.is_key_pressed(KEY_SPACE)
		or Input.is_key_pressed(KEY_DOWN)
		or (InputMap.has_action("rope_down") and Input.is_action_pressed("rope_down"))
		or (InputMap.has_action("ui_accept") and Input.is_action_pressed("ui_accept"))
		or _mouse_held_btn == "Space"
	)

	# 6. Shift tuşu (Kalıcı buton - Fabrika Yükseltme)
	var shift_active: bool = (
		Input.is_key_pressed(KEY_SHIFT)
		or _mouse_held_btn == "Shift"
	)
	var shift_just_pressed: bool = (
		(Input.is_key_pressed(KEY_SHIFT) and not _prev_shift_down)
		or (_mouse_held_btn == "Shift" and not _prev_mouse_shift_down)
	)
	_prev_shift_down = Input.is_key_pressed(KEY_SHIFT)
	_prev_mouse_shift_down = (_mouse_held_btn == "Shift")

	if shift_just_pressed:
		var tree := get_tree()
		if tree:
			var factory = tree.get_first_node_in_group("factory")
			if factory and factory.has_method("try_upgrade_factory"):
				factory.try_upgrade_factory()

	# --- Tetikleme Kontrolleri (Zamanlayıcıları Başlat) ---
	if (q_active or e_active) and not _qe_triggered:
		_qe_triggered = true
		_qe_timer = disappear_delay

	if (a_active or d_active) and not _ad_triggered:
		_ad_triggered = true
		_ad_timer = disappear_delay

	if space_active and not _space_triggered:
		_space_triggered = true
		_space_timer = disappear_delay

	# DİKKAT: SHIFT ASLA TETİKLENMEZ VE ASLA YOK OLMAZ! ("sadece shift butonu kalacak")

	# --- Görsel Durum Güncellemeleri ---
	_update_node_visual(q_sprite, q_active, q_pressed_texture)
	_update_node_visual(e_sprite, e_active, e_pressed_texture)
	_update_node_visual(space_sprite, space_active, space_pressed_texture)
	_update_node_visual(shift_sprite, shift_active, shift_pressed_texture)

	for s in _tutorial_a_nodes:
		_update_node_visual(s, a_active, a_pressed_texture)
	for s in _tutorial_d_nodes:
		_update_node_visual(s, d_active, d_pressed_texture)


func _update_node_visual(s: Sprite2D, is_active: bool, pressed_tex: Texture2D) -> void:
	if not s or not is_instance_valid(s) or not s.visible:
		return

	var normal_tex: Texture2D = _original_textures.get(s, null)
	var base_pos: Vector2 = _original_positions.get(s, s.position)

	if is_active:
		if pressed_tex != null and s.texture != pressed_tex:
			s.texture = pressed_tex
		if press_offset_y != 0.0:
			s.position.y = base_pos.y + press_offset_y
	else:
		if normal_tex != null and s.texture != normal_tex:
			s.texture = normal_tex
		if press_offset_y != 0.0:
			s.position.y = base_pos.y


func _process_tutorial_timers(delta: float) -> void:
	# Q ve E Birleşik Kapanma
	if _qe_triggered and not _qe_faded:
		_qe_timer -= delta
		if _qe_timer <= 0.0:
			_qe_faded = true
			_fade_out([q_sprite, e_sprite])

	# A ve D Birleşik Kapanma (sadece vinç üstündeki öğretici A ve D)
	if _ad_triggered and not _ad_faded:
		_ad_timer -= delta
		if _ad_timer <= 0.0:
			_ad_faded = true
			var targets: Array[Sprite2D] = []
			targets.append_array(_tutorial_a_nodes)
			targets.append_array(_tutorial_d_nodes)
			_fade_out(targets)

	# Space Kapanma
	if _space_triggered and not _space_faded:
		_space_timer -= delta
		if _space_timer <= 0.0:
			_space_faded = true
			_fade_out([space_sprite])


func _fade_out(nodes: Array) -> void:
	var valid_nodes: Array[CanvasItem] = []
	for node in nodes:
		if node != null and is_instance_valid(node) and node is CanvasItem and node.visible:
			valid_nodes.append(node)

	if valid_nodes.is_empty():
		return

	var tw := create_tween()
	tw.set_parallel(true)
	for node in valid_nodes:
		tw.tween_property(node, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tw.set_parallel(false)
	tw.tween_callback(func():
		for node in valid_nodes:
			if is_instance_valid(node):
				node.visible = false
	)


# ------------------------------------------------------------------------------
# 9. SHIFT FABRİKA YÜKSELTME ROZETİ VE REDDETME (REJECTION SHAKE) ANİMASYONU
# ------------------------------------------------------------------------------
func _setup_shift_price_badge() -> void:
	if not shift_sprite:
		return

	_shift_price_panel = PanelContainer.new()
	_shift_price_panel.name = "ShiftPriceBadge"
	_shift_price_panel.custom_minimum_size = Vector2(76.0, 28.0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.09, 0.16, 0.92)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(1.0, 0.82, 0.25, 0.85)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 6
	panel_style.content_margin_right = 6
	panel_style.content_margin_top = 2
	panel_style.content_margin_bottom = 2
	_shift_price_panel.add_theme_stylebox_override("panel", panel_style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 4)
	_shift_price_panel.add_child(hbox)

	var icon_label := Label.new()
	icon_label.text = "▲"
	icon_label.add_theme_font_size_override("font_size", 11)
	icon_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	hbox.add_child(icon_label)

	_shift_price_label = Label.new()
	_shift_price_label.name = "PriceLabel"
	_shift_price_label.text = "10$"
	_shift_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shift_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shift_price_label.add_theme_font_size_override("font_size", 14)
	_shift_price_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3, 1.0))
	_shift_price_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_shift_price_label.add_theme_constant_override("outline_size", 3)
	hbox.add_child(_shift_price_label)

	add_child(_shift_price_panel)

	# Shift butonunun hemen üzerinde konumlandır
	_original_price_pos = Vector2(
		_original_shift_pos.x - 38.0,
		_original_shift_pos.y - 62.0
	)
	_shift_price_panel.position = _original_price_pos

	# Badge'e tıklandığında da yükseltme denemesini tetikle
	_shift_price_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var tree := get_tree()
			if tree:
				var factory = tree.get_first_node_in_group("factory")
				if factory and factory.has_method("try_upgrade_factory"):
					factory.try_upgrade_factory()
	)

	# GameManager para değişimi sinyaline bağlan
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("money_changed"):
		if not gm.money_changed.is_connected(_on_game_manager_money_changed):
			gm.money_changed.connect(_on_game_manager_money_changed)

	# Fiyatı fabrikadan çekerek başlat
	var tree := get_tree()
	if tree:
		var factory = tree.get_first_node_in_group("factory")
		if factory and factory.has_method("get_upgrade_cost"):
			update_shift_upgrade_price(factory.get_upgrade_cost(), factory.current_level >= factory.max_level)
		else:
			update_shift_upgrade_price(10, false)


## Fabrika seviye fiyatını günceller
func update_shift_upgrade_price(cost: int, is_max: bool) -> void:
	if not _shift_price_label:
		return

	if is_max:
		_shift_price_label.text = "MAX"
		_shift_price_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	else:
		_shift_price_label.text = "%d$" % cost
		var gm = get_node_or_null("/root/GameManager")
		var current_money: int = gm.get_money() if gm and gm.has_method("get_money") else 0
		if current_money >= cost:
			_shift_price_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
		else:
			_shift_price_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.85))


func _on_game_manager_money_changed(_new_money: int) -> void:
	var tree := get_tree()
	if tree:
		var factory = tree.get_first_node_in_group("factory")
		if factory and factory.has_method("get_upgrade_cost"):
			update_shift_upgrade_price(factory.get_upgrade_cost(), factory.current_level >= factory.max_level)


## Yükseltme başarısız olduğunda (para yetersiz veya max seviye):
## Buton kırmızıya döner ve reddedilmiş gibi iki yana sallanır
func play_shift_rejection_shake() -> void:
	if not shift_sprite:
		return

	if _shift_shake_tween and _shift_shake_tween.is_valid():
		_shift_shake_tween.kill()

	# Pozisyonları ve renkleri sıfırla
	shift_sprite.position = _original_shift_pos
	if _shift_price_panel:
		_shift_price_panel.position = _original_price_pos

	# Kırmızı reddetme flaşı
	shift_sprite.modulate = Color(1.0, 0.22, 0.22, 1.0)
	if _shift_price_panel:
		_shift_price_panel.modulate = Color(1.0, 0.3, 0.3, 1.0)

	_shift_shake_tween = create_tween()
	var shake_offsets: Array[float] = [-9.0, 9.0, -7.0, 7.0, -4.0, 4.0, -2.0, 2.0, 0.0]
	var step_time: float = 0.035

	for offset in shake_offsets:
		_shift_shake_tween.tween_property(shift_sprite, "position:x", _original_shift_pos.x + offset, step_time)
		if _shift_price_panel:
			_shift_shake_tween.parallel().tween_property(_shift_price_panel, "position:x", _original_price_pos.x + offset, step_time)

	# Rengi yumuşakça orijinal haline döndür
	_shift_shake_tween.tween_property(shift_sprite, "modulate", Color.WHITE, 0.16)
	if _shift_price_panel:
		_shift_shake_tween.parallel().tween_property(_shift_price_panel, "modulate", Color.WHITE, 0.16)
