extends CanvasLayer

## ==============================================================================
## BlackHoleTransition (Autoload Singleton)
## ==============================================================================
## Karadelik çöküşü ve seviye yeniden başlatma yumuşak geçiş yöneticisi.
## Wave projesindeki blackhole shader'ı ve görsel efekt mekaniği temel alınmıştır.
##
## 1. R tuşuna basılı tutulduğunda anında (direk) karadelik açılır ve ekranı çeker.
## 2. Basılı tutma süresi boyunca girdap, piksel blok kopuşu ve parçacıklar artar.
## 3. %90'da flaş patlaması, %100'de mutlak karanlık ekran oluşur.
## 4. Ekran siyahken sahne sıfırlanır (reload_current_scene).
## 5. Sahne yüklendikten sonra siyah ekrandan pürüzsüzce (smooth) normal oyuna geçilir.
## 6. Kaybetme ekranında R basıldığında veya yeniden başla dendiğinde kaybettin ekranı
##    hemen kapanır ve arkasında hemen karadelik açılır.
## ==============================================================================

const SHADER := preload("res://Shaders/blackhole.gdshader")
const DOT := preload("res://Textures/T_VFX_simple_1.png")

enum State {
	IDLE,           # Normal oyun ekranı, karadelik kapalı
	HOLDING,        # R tuşuna basılı tutuluyor, karadelik çekiyor
	AUTO_COLLAPSE,  # Otomatik çöküş (ör. UI restart butonuna basıldığında)
	BLACK_SCREEN,   # Çöküş bitti, ekran tamamen siyah, sahne yükleniyor
	REVEALING       # Siyah ekrandan normal oyuna yumuşak geçiş yapılıyor
}

@export var hold_duration: float = 1.4
@export var auto_duration: float = 1.4
@export var reveal_duration: float = 0.85
@export var center: Vector2 = Vector2(0.5, 0.5)

# Kamera & FOV dinamik parametreleri (Wave projesinden)
@export var cam_fov_max: float = 0.45
@export var cam_out_end: float = 0.18
@export var cam_in_end: float = 0.65

var state: State = State.IDLE

var _mat: ShaderMaterial
var _rect: ColorRect
var _flash: ColorRect
var _black_overlay: ColorRect
var _spiral: GPUParticles2D

var _start_ticks: int = 0
var _burst_done: bool = false
var _cancel_tween: Tween = null
var _auto_tween: Tween = null
var _reveal_tween: Tween = null
var _current_p: float = 0.0


func _ready() -> void:
	# Autoload olarak tüm sahnelerin üzerinde en üst katmanda çalışır
	layer = 140
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_ui()
	_build_spiral()


func _build_ui() -> void:
	# 1. Karadelik Shader ColorRect
	_rect = ColorRect.new()
	_rect.name = "BlackHoleRect"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("center", center)
	_mat.set_shader_parameter("intensity", 0.0)
	_mat.set_shader_parameter("swirl", 2.5)
	_mat.set_shader_parameter("anim_time", 0.0)
	_mat.set_shader_parameter("fov_widen", 0.0)
	_mat.set_shader_parameter("radius", 0.22)
	_mat.set_shader_parameter("spin_speed", 2.0)
	_mat.set_shader_parameter("block_count", 180.0)
	_mat.set_shader_parameter("disk_color", Color(1.0, 0.55, 0.2, 1.0))

	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)

	# 2. Çöküş anı beyaz flaş patlaması (%90 eşiğinde)
	_flash = ColorRect.new()
	_flash.name = "FlashOverlay"
	_flash.color = Color.WHITE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.visible = false
	add_child(_flash)

	# 3. Mutlak Siyah Perde (Sahne yeniden yüklenirken ve smooth reveal yapılırken)
	_black_overlay = ColorRect.new()
	_black_overlay.name = "BlackCurtain"
	_black_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	_black_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black_overlay.visible = false
	_black_overlay.modulate.a = 0.0
	add_child(_black_overlay)


func _build_spiral() -> void:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3(0, 0, 1)
	m.emission_ring_radius = 320.0
	m.emission_ring_inner_radius = 260.0
	m.emission_ring_height = 20.0
	m.direction = Vector3.ZERO
	m.spread = 180.0
	m.initial_velocity_min = 0.0
	m.initial_velocity_max = 20.0
	m.gravity = Vector3.ZERO
	m.orbit_velocity_min = 1.4
	m.orbit_velocity_max = 2.2
	m.radial_velocity_min = -60.0
	m.radial_velocity_max = -30.0
	m.scale_min = 0.3
	m.scale_max = 0.65
	m.color = Color(1.0, 0.55, 0.15)

	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = g
	m.color_ramp = ramp

	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_spiral = GPUParticles2D.new()
	_spiral.name = "BlackHoleSpiralParticles"
	_spiral.texture = DOT
	_spiral.material = add_mat
	_spiral.amount = 40
	_spiral.lifetime = 1.8
	_spiral.preprocess = 0.0
	_spiral.one_shot = false
	_spiral.local_coords = false
	_spiral.emitting = false
	_spiral.visibility_rect = Rect2(-600, -600, 1200, 1200)
	_spiral.z_index = 10
	_spiral.process_material = m
	_spiral.position = _center_screen()

	add_child(_spiral)


func _center_screen() -> Vector2:
	var vp := get_viewport()
	if vp:
		return vp.get_visible_rect().size * 0.5
	return Vector2(960, 540)


func _kill_tweens() -> void:
	if _cancel_tween and _cancel_tween.is_valid():
		_cancel_tween.kill()
		_cancel_tween = null
	if _auto_tween and _auto_tween.is_valid():
		_auto_tween.kill()
		_auto_tween = null
	if _reveal_tween and _reveal_tween.is_valid():
		_reveal_tween.kill()
		_reveal_tween = null


## R tuşuna basıldığı İLK KAREDE çağrılır: Karadelik anında (direk) ekranda belirir
func start_hold() -> void:
	if state == State.BLACK_SCREEN or state == State.REVEALING:
		return

	_kill_tweens()
	state = State.HOLDING
	_start_ticks = Time.get_ticks_msec()
	_burst_done = false
	_current_p = 0.05 # Anında görünür başlangıç

	_rect.visible = true
	_black_overlay.visible = false
	_black_overlay.modulate.a = 0.0
	_flash.visible = false

	_update_shader_parameters(0.05, 0.0)

	if is_instance_valid(_spiral):
		_spiral.position = _center_screen()
		_spiral.restart()
		_spiral.emitting = true


## R tuşu basılı tutulurken her kare ilerlemeyi günceller (0.0 -> 1.0)
func set_hold_progress(p: float, elapsed_sec: float) -> void:
	if state != State.HOLDING:
		return

	_current_p = clampf(p, 0.0, 1.0)
	_update_shader_parameters(_current_p, elapsed_sec)

	# %90'da flaş patlaması
	if _current_p >= 0.90 and not _burst_done:
		_burst_done = true
		_play_flash()

	# %100 doldu: ekran tamamen siyah ve sahneyi yeniden yükle
	if _current_p >= 1.0:
		finish_and_reload()


## R tuşu erken bırakılırsa çöküşü yumuşakça sıfırlar ve oyuna devam eder
func cancel_hold() -> void:
	if state != State.HOLDING:
		return

	state = State.IDLE
	if is_instance_valid(_spiral):
		_spiral.emitting = false

	_kill_tweens()
	_cancel_tween = create_tween()
	_cancel_tween.tween_method(
		func(val: float):
			_current_p = val
			if _mat:
				_mat.set_shader_parameter("intensity", val)
				_mat.set_shader_parameter("swirl", 2.5 + 5.0 * val),
		_current_p,
		0.0,
		0.25
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_cancel_tween.tween_callback(func():
		_rect.visible = false
		_reset_shader_parameters()
		if is_instance_valid(_spiral):
			_spiral.emitting = false
	)


## UI Yeniden Başla butonuna basıldığında veya kod ile tam çöküş istenildiğinde
func trigger_auto_collapse(on_collapsed: Callable = Callable()) -> void:
	if state == State.BLACK_SCREEN or state == State.AUTO_COLLAPSE:
		return

	_kill_tweens()
	state = State.AUTO_COLLAPSE
	_start_ticks = Time.get_ticks_msec()
	_burst_done = false
	_current_p = 0.05

	_rect.visible = true
	_black_overlay.visible = false
	_black_overlay.modulate.a = 0.0
	_flash.visible = false

	_update_shader_parameters(0.05, 0.0)

	if is_instance_valid(_spiral):
		_spiral.position = _center_screen()
		_spiral.restart()
		_spiral.emitting = true

	_auto_tween = create_tween()
	_auto_tween.tween_method(
		func(val: float):
			var elapsed := float(Time.get_ticks_msec() - _start_ticks) / 1000.0
			_current_p = val
			_update_shader_parameters(val, elapsed)
			if val >= 0.90 and not _burst_done:
				_burst_done = true
				_play_flash(),
		0.05,
		1.0,
		auto_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	_auto_tween.tween_callback(func():
		finish_and_reload(on_collapsed)
	)


## %100 Çöküş bitti: Ekran mutlak siyah olur, sahne yeniden yüklenir
func finish_and_reload(custom_reload_action: Callable = Callable()) -> void:
	if state == State.BLACK_SCREEN:
		return

	state = State.BLACK_SCREEN
	_current_p = 1.0

	# Ekranı tamamen siyah yap
	_rect.visible = true
	_update_shader_parameters(1.0, 2.0)
	_black_overlay.visible = true
	_black_overlay.modulate.a = 1.0
	_flash.visible = false

	if is_instance_valid(_spiral):
		_spiral.emitting = false

	print("[BlackHoleTransition] Karadelik çöküşü tamamlandı. Sahne yeniden yükleniyor...")
	if custom_reload_action.is_valid():
		custom_reload_action.call()
	else:
		_safe_reload_scene()

	_wait_for_scene_and_reveal()


## current_scene null olsa dahi sahneyi güvenle baştan yükler (Parameter current_scene is null hatasını önler)
func _safe_reload_scene() -> void:
	var tree := get_tree()
	if not tree:
		return

	var target_scene_path: String = ""

	# 1. Mevcut sahne tanımlıysa ve dosya yolu varsa
	if tree.current_scene and is_instance_valid(tree.current_scene):
		if not tree.current_scene.scene_file_path.is_empty():
			target_scene_path = tree.current_scene.scene_file_path

	# 2. current_scene null ise veya yolu boşsa, root altındaki ana sahneyi bul
	if target_scene_path.is_empty():
		for child in tree.root.get_children():
			if child != self and child.name != "GameManager" and child.name != "BlackHoleTransition":
				if not child.scene_file_path.is_empty():
					target_scene_path = child.scene_file_path
					break

	# 3. ProjectSettings üzerinden main_scene'i yükle
	if target_scene_path.is_empty():
		target_scene_path = ProjectSettings.get_setting("application/run/main_scene", "res://Scenes/game.tscn")

	# 4. Kesin yedek
	if target_scene_path.is_empty():
		target_scene_path = "res://Scenes/game.tscn"

	print("[BlackHoleTransition] Sahne güvenli şekilde yükleniyor: ", target_scene_path)
	var err := tree.change_scene_to_file(target_scene_path)
	if err != OK:
		printerr("[BlackHoleTransition] change_scene_to_file hatası: ", err)


## Yeni sahnenin hazır olmasını bekler ve pürüzsüz açılış efektini başlatır
func _wait_for_scene_and_reveal() -> void:
	var tree := get_tree()
	if not tree:
		return

	# change_scene_to_file ertelenmiş çalıştığı için yeni sahnenin hazır olması için bekle
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame

	play_smooth_reveal()


## Siyah ekrandan normal oyuna yumuşak geçiş yapar
func play_smooth_reveal() -> void:
	state = State.REVEALING

	# Shader'ı sıfırla, siyah kaplamayı en üstte tutarak yumuşakça şeffaflaştır
	_rect.visible = false
	_reset_shader_parameters()
	_black_overlay.visible = true
	_black_overlay.modulate.a = 1.0

	_kill_tweens()
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(_black_overlay, "modulate:a", 0.0, reveal_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_callback(func():
		_black_overlay.visible = false
		state = State.IDLE
		print("[BlackHoleTransition] Pürüzsüz geçiş tamamlandı. Normal oyun başladı.")
	)


func _play_flash() -> void:
	_flash.visible = true
	_flash.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_flash, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _flash.visible = false)


func _update_shader_parameters(p: float, elapsed: float) -> void:
	if not _mat:
		return
	_mat.set_shader_parameter("intensity", clampf(p, 0.0, 1.0))
	_mat.set_shader_parameter("swirl", 2.5 + 5.0 * p)
	_mat.set_shader_parameter("anim_time", elapsed)

	var fov_p := smoothstep(cam_out_end, cam_in_end, p)
	_mat.set_shader_parameter("fov_widen", cam_fov_max * fov_p)

	if is_instance_valid(_spiral):
		_spiral.position = _center_screen()


func _reset_shader_parameters() -> void:
	if not _mat:
		return
	_mat.set_shader_parameter("intensity", 0.0)
	_mat.set_shader_parameter("swirl", 2.5)
	_mat.set_shader_parameter("anim_time", 0.0)
	_mat.set_shader_parameter("fov_widen", 0.0)
