@tool
extends StaticBody2D
class_name House

## House (Ev Sistemi):
## 1. flip_x: Inspector üzerinden Sprite2D'nin yatay yönünü (flip x) seçmeyi sağlar.
## 2. level_sprites: 5 adet ev sprite'ı için ayrılmış Texture2D slotları.
## 3. Level 1'den başlar; yükseltildikçe (upgrade) collision yukarı doğru 2 katına/katlarına çıkar ve sonraki level sprite'ına geçer.
## 4. Evlerin seviyeleri toplamı oyuncunun canıdır; evlerin canı biterse oyun biter (Game Over).
## 5. Kırılma Mekaniği:
##    - Seviye 1 ise: Önce Sprite2D gizlenir/kapanır, ardından AnimatedSprite2D zemin seviyesinde kırılma animasyonunu oynatır.
##    - Seviye 2 veya daha fazla ise: Çatı katından başlayarak kırılır; bir önceki seviyeye ve sprite'ına geçer,
##      AnimatedSprite2D ise kırılan çatı katının Y pozisyonunda (yukarıda) kırılma animasyonunu oynatır.

signal level_changed(new_level: int, max_level: int)
signal floor_broken(house: Node2D, broken_floor: int, remaining_level: int)
signal house_destroyed(house: Node2D)

@export_group("Visual Settings")
## Sprite2D ve AnimatedSprite2D'yi yatay olarak ters çevir (Flip X yönü)
@export var flip_x: bool = false:
	set(val):
		flip_x = val
		_apply_flip()

@export_group("House Levels & Sprites")
## 5 Adet ev sprite'ı (Seviye 1'den 5'e). Sprite'larınızı buraya sürükleyip bırakabilirsiniz.
@export var level_sprites: Array[Texture2D] = [null, null, null, null, null]:
	set(val):
		level_sprites = val
		_update_level_state()

## Maksimum ev seviyesi (Varsayılan: 5)
@export var max_level: int = 5

## Evin başlangıç ve anlık seviyesi / canı (1 - 5)
@export_range(1, 5) var current_level: int = 1:
	set(val):
		var limit := max_level if max_level > 0 else 5
		current_level = clampi(val, 1, limit)
		_update_level_state()

## Her katın piksel yüksekliği (0 ise otomatik olarak sprite veya collision'dan ölçülür)
@export var floor_height: float = 0.0

## Seviye başına collision yükseklik çarpanı (Varsayılan: 1.0 -> Level 2'de 2 katına çıkar)
@export var collision_height_multiplier: float = 1.0

@export_group("Breaking Animation")
## AnimatedSprite2D üzerinde oynatılacak kırılma animasyonu ismi
@export var break_animation_name: String = "destroy"

@export_group("Debug / Test Keys")
## Test için evi yükseltme tuşu (Varsayılan: H)
@export var test_upgrade_key: Key = KEY_H
## Test için eve hasar verme / kat kırma tuşu (Varsayılan: J)
@export var test_damage_key: Key = KEY_J

@export_group("UI & Feedback")
## Evin üzerinde seviye göstergesini göster
@export var show_level_label: bool = true

@export_group("Pointer Settings")
## When true, the tutorial pointer bobs up and down; when false, it remains stationary
@export var enable_pointer_movement: bool = false

@export_group("Submersion / Flood Destruction")
## Evin su altında kesintisiz kalması gereken süre (3.0 saniye - bütün collisionlara tam temas gerektirir)
@export var submerge_hold_time: float = 3.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var pointer_sprite: Sprite2D = get_node_or_null("PointerSprite2D")

var _base_collision_size: Vector2 = Vector2.ZERO
var _base_collision_pos: Vector2 = Vector2.ZERO
var _base_sprite_height: float = 0.0
var _base_anim_pos: Vector2 = Vector2.ZERO
var _base_scene_texture: Texture2D = null
var _base_pointer_pos: Vector2 = Vector2.ZERO
var _floor_col_nodes: Array[CollisionShape2D] = []

var is_breaking: bool = false
var is_destroyed: bool = false
var _level_label: Label = null
var _countdown_label: Label = null
var _last_displayed_sec: int = -1
var _current_submerge_time: float = 0.0
var _cached_water: FluidWater = null


func _exit_tree() -> void:
	if _countdown_label and is_instance_valid(_countdown_label):
		_countdown_label.queue_free()
		_countdown_label = null


func _get_sprite() -> Sprite2D:
	if sprite and is_instance_valid(sprite):
		return sprite
	return get_node_or_null("Sprite2D") as Sprite2D


func _get_anim_sprite() -> AnimatedSprite2D:
	if anim_sprite and is_instance_valid(anim_sprite):
		return anim_sprite
	return get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _get_col_shape() -> CollisionShape2D:
	if collision_shape and is_instance_valid(collision_shape):
		return collision_shape
	return get_node_or_null("CollisionShape2D") as CollisionShape2D


func _get_pointer_sprite() -> Sprite2D:
	if pointer_sprite and is_instance_valid(pointer_sprite):
		return pointer_sprite
	return get_node_or_null("PointerSprite2D") as Sprite2D


func _ready() -> void:
	add_to_group("house")
	_cache_base_dimensions()
	_apply_flip()
	_update_level_state()

	var p := _get_pointer_sprite()
	if p:
		if _base_pointer_pos == Vector2.ZERO:
			_base_pointer_pos = p.position
		p.visible = false
		update_pointer_position()

	if Engine.is_editor_hint():
		return

	var a := _get_anim_sprite()
	if a:
		a.visible = false
		a.stop()
		a.frame = 0

	var s := _get_sprite()
	if s:
		s.visible = true

	if show_level_label:
		_create_or_update_label()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not enable_pointer_movement:
		return
	var p := _get_pointer_sprite()
	if p and p.visible:
		var time := Time.get_ticks_msec() / 1000.0
		var height_diff: float = float(current_level - 1) * 11.0
		var s := _get_sprite()
		if s and s.texture and _base_sprite_height > 0.0:
			height_diff = s.texture.get_size().y - _base_sprite_height
		p.position.y = (_base_pointer_pos.y - height_diff) + sin(time * 5.0) * 2.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_destroyed or is_breaking:
		_reset_submerge_countdown()
		return

	var water := _find_fluid_water()
	if not water:
		_reset_submerge_countdown()
		return

	# Evin tabanından en üst çatısına kadar olan toplam alanı ve kat alanları
	var full_house_rect: Rect2 = get_global_collision_rect()
	var floor_rects: Array[Rect2] = get_floor_collision_rects()

	# Suların collision'ı evlerin collision'larını %100 içine alıyor mu?
	var is_100_percent_submerged: bool = false
	if water.has_method("is_house_100_percent_submerged"):
		is_100_percent_submerged = water.is_house_100_percent_submerged(full_house_rect, floor_rects)
	elif water.has_method("are_all_floor_collisions_touched"):
		is_100_percent_submerged = water.are_all_floor_collisions_touched(floor_rects)
	else:
		is_100_percent_submerged = water.get_rect_submersion_ratio(full_house_rect) >= 0.90

	if is_100_percent_submerged:
		_current_submerge_time += delta
		_update_countdown_display(_current_submerge_time)

		# 3 saniye bu durumda kalındığında kırılacak
		if _current_submerge_time >= submerge_hold_time:
			_reset_submerge_countdown()
			print("[House] %s suların collision'ı evi 100%% içine alarak 3 saniye durdu, kırılıyor! (Seviye: %d)" % [name, current_level])
			destroy_house()
	else:
		# Dalga gelip giderse veya su seviyesi %100'ün altına düşerse sayaç HER SEFERİNDE SIFIRLANIR
		_reset_submerge_countdown()


## Evin tüm aktif katlarını (tabandan en üst kata) kapsayan dünya Rect2 sınırlarını döndürür
func _get_global_collision_rect() -> Rect2:
	_cache_base_dimensions()
	var floor_h: float = get_floor_height()
	var total_h: float = float(current_level) * floor_h
	var s: Vector2 = Vector2(_base_collision_size.x, total_h) * global_scale.abs()
	var bottom_y: float = _base_collision_pos.y + (_base_collision_size.y * 0.5)
	var center_local := Vector2(_base_collision_pos.x, bottom_y - (total_h * 0.5))
	var world_center: Vector2 = to_global(center_local)
	var top_left: Vector2 = world_center - (s * 0.5)
	return Rect2(top_left, s)


## Public alias for _get_global_collision_rect
func get_global_collision_rect() -> Rect2:
	return _get_global_collision_rect()


## Evin tüm aktif katlarının Y pozisyonlarındaki dünya Rect2 sınırlarını döndürür
func get_floor_collision_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for i in range(current_level):
		if i < _floor_col_nodes.size():
			var col := _floor_col_nodes[i]
			if col and is_instance_valid(col) and col.shape is RectangleShape2D:
				var rect_shape := col.shape as RectangleShape2D
				var s: Vector2 = rect_shape.size * global_scale.abs()
				var world_pos: Vector2 = to_global(col.position)
				var top_left: Vector2 = world_pos - (s * 0.5)
				rects.append(Rect2(top_left, s))

	if rects.is_empty():
		rects.append(_get_global_collision_rect())
	return rects


func _find_fluid_water() -> FluidWater:
	if _cached_water and is_instance_valid(_cached_water):
		return _cached_water
	var tree := get_tree()
	if not tree:
		return null
	var water = tree.get_first_node_in_group("fluid_water") as FluidWater
	if water:
		_cached_water = water
		return _cached_water
	var root := tree.current_scene
	if root:
		var node := root.get_node_or_null("FluidWater") as FluidWater
		if node:
			_cached_water = node
			return _cached_water
	return null


func _cache_base_dimensions() -> void:
	var col := _get_col_shape()
	if col and col.shape is RectangleShape2D:
		var rect := col.shape as RectangleShape2D
		if _base_collision_size == Vector2.ZERO:
			_base_collision_size = rect.size
			_base_collision_pos = col.position

	var a := _get_anim_sprite()
	if a and _base_anim_pos == Vector2.ZERO:
		_base_anim_pos = a.position

	var s := _get_sprite()
	if s and s.texture:
		if _base_scene_texture == null:
			_base_scene_texture = s.texture
		if _base_sprite_height <= 0.0:
			_base_sprite_height = s.texture.get_size().y

	var p := _get_pointer_sprite()
	if p and (_base_pointer_pos == Vector2.ZERO or _base_pointer_pos.y == 0.0):
		_base_pointer_pos = p.position


func _apply_flip() -> void:
	var s := _get_sprite()
	if s:
		s.flip_h = flip_x
	var a := _get_anim_sprite()
	if a:
		a.flip_h = flip_x


func _update_level_state() -> void:
	_apply_flip()
	_apply_level_sprite()
	_update_collision()
	update_pointer_position()
	if not Engine.is_editor_hint() and show_level_label:
		_create_or_update_label()


## Calculates and updates the pointer Y position based on current house level
func update_pointer_position() -> void:
	var p := _get_pointer_sprite()
	if not p:
		return
	if _base_pointer_pos == Vector2.ZERO or _base_pointer_pos.y == 0.0:
		_base_pointer_pos = p.position

	var height_diff: float = float(current_level - 1) * 11.0
	var s := _get_sprite()
	if s and s.texture and _base_sprite_height > 0.0:
		height_diff = s.texture.get_size().y - _base_sprite_height

	p.position.x = _base_pointer_pos.x
	p.position.y = _base_pointer_pos.y - height_diff


## Sets the pointer visibility (active when crane payload carries upgrade rock)
func set_pointer_visible(show: bool) -> void:
	var p := _get_pointer_sprite()
	if not p:
		return
	if is_destroyed or current_level <= 0 or current_level >= max_level:
		p.visible = false
		return
	update_pointer_position()
	p.visible = show


## Belirlenen level sprite'ını uygular ve taban hizasını (ground baseline) korur
func _apply_level_sprite() -> void:
	var s := _get_sprite()
	if not s:
		return

	if _base_scene_texture == null and s.texture != null:
		_base_scene_texture = s.texture
	if _base_sprite_height <= 0.0 and s.texture != null:
		_base_sprite_height = s.texture.get_size().y

	var idx: int = current_level - 1
	var target_tex: Texture2D = null
	if idx >= 0 and idx < level_sprites.size() and level_sprites[idx] != null:
		target_tex = level_sprites[idx]
	elif idx == 0 and _base_scene_texture != null:
		target_tex = _base_scene_texture

	if target_tex:
		s.texture = target_tex

	# Eğer sprite boyutu temel sprite'tan daha uzunsa, tabanın zeminde sabit kalması için offset.y yukarı kaydırılır
	if s.texture and _base_sprite_height > 0.0:
		var tex_h: float = s.texture.get_size().y
		var diff_h: float = tex_h - _base_sprite_height
		s.offset.y = -diff_h * 0.5


## Evin her seviyesi kadar Y pozisyonunda collision shape ekler ve günceller
func _update_collision() -> void:
	_cache_base_dimensions()
	var base_col := _get_col_shape()
	if not base_col or not (base_col.shape is RectangleShape2D):
		return

	if not _floor_col_nodes.has(base_col):
		_floor_col_nodes.append(base_col)
		for child in get_children():
			if child != base_col and child is CollisionShape2D and child.name.begins_with("FloorCollision_"):
				if not _floor_col_nodes.has(child):
					_floor_col_nodes.append(child)

	var floor_h: float = get_floor_height()
	if not base_col.shape.resource_local_to_scene:
		base_col.shape = base_col.shape.duplicate()
	(base_col.shape as RectangleShape2D).size = Vector2(_base_collision_size.x, floor_h)
	base_col.position = _base_collision_pos

	# Seviyeler kadar (2..current_level) Y pozisyonunda ayrı collision shape'ler ekle
	while _floor_col_nodes.size() < current_level:
		var new_col := CollisionShape2D.new()
		new_col.name = "FloorCollision_%d" % (_floor_col_nodes.size() + 1)
		var new_shape := RectangleShape2D.new()
		new_shape.size = Vector2(_base_collision_size.x, floor_h)
		new_col.shape = new_shape
		add_child(new_col)
		_floor_col_nodes.append(new_col)

	# Seviyeler kadar Y pozisyonlarını ata ve aktif yap, fazla olanları devre dışı bırak
	for i in range(_floor_col_nodes.size()):
		var c := _floor_col_nodes[i]
		if i < current_level:
			c.visible = true
			c.disabled = false
			c.position = Vector2(_base_collision_pos.x, _base_collision_pos.y - float(i) * floor_h)
			if c.shape is RectangleShape2D:
				(c.shape as RectangleShape2D).size = Vector2(_base_collision_size.x, floor_h)
		else:
			c.visible = false
			c.disabled = true


## Kat yüksekliğini hesaplar (AnimatedSprite2D kırılma ve kat collision pozisyonları için)
func get_floor_height() -> float:
	if floor_height > 0.0:
		return floor_height
	if _base_collision_size.y > 0.0:
		return _base_collision_size.y
	return 11.0


## 3 saniyelik kırmızı sayaç Label'ını oluşturur (3, 2, 1)
func _create_countdown_label() -> void:
	if _countdown_label and is_instance_valid(_countdown_label):
		return

	_countdown_label = Label.new()
	_countdown_label.name = "SubmergeCountdownLabel"
	_countdown_label.top_level = true
	_countdown_label.z_index = 25
	_countdown_label.visible = false
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.custom_minimum_size = Vector2(80, 50)
	_countdown_label.size = Vector2(80, 50)

	# Label styling: Parlak kırmızı, kalın siyah kenarlık (outline)
	_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15, 1.0))
	_countdown_label.add_theme_color_override("font_outline_color", Color(0.04, 0.0, 0.0, 1.0))
	_countdown_label.add_theme_constant_override("outline_size", 10)
	_countdown_label.add_theme_font_size_override("font_size", 36)

	add_child(_countdown_label)
	update_countdown_label_position()


## Sayacın dünya koordinatlarındaki pozisyonunu evin çatısının hemen üzerine hizalar
func update_countdown_label_position() -> void:
	if not _countdown_label or not is_instance_valid(_countdown_label):
		return
	var house_rect: Rect2 = get_global_collision_rect()
	var center_x: float = house_rect.get_center().x
	var roof_y: float = house_rect.position.y
	_countdown_label.global_position = Vector2(center_x - (_countdown_label.size.x * 0.5), roof_y - 52.0)


## Sualtı kırmızı sayacını günceller: 3 -> 2 -> 1
func _update_countdown_display(elapsed_time: float) -> void:
	if not _countdown_label or not is_instance_valid(_countdown_label):
		_create_countdown_label()

	update_countdown_label_position()

	var remaining: float = submerge_hold_time - elapsed_time
	var display_sec: int = clampi(int(ceilf(remaining)), 1, 3)

	if not _countdown_label.visible or _last_displayed_sec != display_sec:
		_last_displayed_sec = display_sec
		_countdown_label.text = str(display_sec)
		_countdown_label.visible = true

		# Sayı her değiştiğinde (3 -> 2 -> 1) dikkat çekici pop/pulse animasyonu
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_countdown_label.pivot_offset = _countdown_label.size * 0.5
		_countdown_label.scale = Vector2(1.4, 1.4)
		tw.tween_property(_countdown_label, "scale", Vector2.ONE, 0.18)


## Su çekildiğinde veya dalga geçtiğinde sayacı derhal sıfırlar ve gizler
func _reset_submerge_countdown() -> void:
	_current_submerge_time = 0.0
	_last_displayed_sec = -1
	if _countdown_label and is_instance_valid(_countdown_label):
		_countdown_label.visible = false
		_countdown_label.text = ""


## Evi bir üst seviyeye yükseltir
func upgrade() -> bool:
	if current_level >= max_level or is_destroyed:
		return false
	current_level += 1
	_update_level_state()
	level_changed.emit(current_level, max_level)
	print("[House] ", name, " yükseltildi! Yeni seviye: Lv.", current_level, "/", max_level)
	_play_upgrade_bounce()
	return true


func _play_upgrade_bounce() -> void:
	var s := _get_sprite()
	if s:
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector2(1.2, 0.85), 0.1)
		tw.tween_property(s, "scale", Vector2.ONE, 0.15)


## Hasar alma / kat kırılma mekaniği:
## Level 1 ise: Sprite2D kapanır, AnimatedSprite2D zemin seviyesinde oynatılır ve ev yıkılır.
## Level >= 2 ise: Çatı katından başlar, bir önceki seviyeye/sprite'a geçer ve AnimatedSprite2D çatı seviyesinde oynatılır.
func take_damage() -> bool:
	if is_destroyed or is_breaking:
		return false

	if current_level > 1:
		_break_roof_floor()
		return true
	else:
		_collapse_level_1()
		return true


## Alias for take_damage
func damage() -> bool:
	return take_damage()


## Evin su altında kaldığında veya hasarla patlamasını / yıkılmasını tetikler
func destroy_house(force_total_collapse: bool = false) -> void:
	if is_destroyed or is_breaking:
		return
	print("[House] ", name, " su altında kalarak yıkılıyor! (Mevcut Seviye: ", current_level, ")")
	if force_total_collapse:
		_collapse_level_1()
	else:
		take_damage()


## Seviye 2 ve üzeri için çatı katından başlayarak kırma
func _break_roof_floor() -> void:
	is_breaking = true
	var broken_floor: int = current_level
	var new_lvl: int = current_level - 1

	# Bir önceki seviyeye ve sprite'ına geç
	current_level = new_lvl
	_apply_level_sprite()
	_update_collision()
	level_changed.emit(current_level, max_level)

	var s := _get_sprite()
	if s:
		s.visible = true

	var a := _get_anim_sprite()
	if a:
		# AnimatedSprite2D'yi kırılan katın Y yüksekliğine yerleştir
		var f_height := get_floor_height()
		var roof_offset_y: float = -float(broken_floor - 1) * f_height
		a.position = _base_anim_pos + Vector2(0.0, roof_offset_y)
		a.visible = true
		a.frame = 0

		var anim_name := _find_break_animation(a)
		if not anim_name.is_empty():
			a.play(anim_name)
			if not a.animation_finished.is_connected(_on_roof_break_finished):
				a.animation_finished.connect(_on_roof_break_finished.bind(broken_floor), CONNECT_ONE_SHOT)
		else:
			_play_fallback_floor_break(broken_floor)
	else:
		is_breaking = false
		floor_broken.emit(self, broken_floor, current_level)

	print("[House] ", name, " çatı katı yıkıldı! (Kırılan Kat: ", broken_floor, " -> Kalan Seviye: ", current_level, ")")


func _on_roof_break_finished(broken_floor: int) -> void:
	var a := _get_anim_sprite()
	if a and is_instance_valid(a):
		a.visible = false
	is_breaking = false
	floor_broken.emit(self, broken_floor, current_level)


## Seviye 1 için tam yıkılma (Önce Sprite2D kapanır, sonra kırılma animasyonu oynatılır)
func _collapse_level_1() -> void:
	_reset_submerge_countdown()
	is_breaking = true
	is_destroyed = true
	current_level = 0
	level_changed.emit(0, max_level)

	# 1. İlk başta Sprite2D kapatılır
	var s := _get_sprite()
	if s:
		s.visible = false

	var p := _get_pointer_sprite()
	if p:
		p.visible = false

	if _level_label and is_instance_valid(_level_label):
		_level_label.visible = false

	# 2. AnimatedSprite2D zemin seviyesinde kırılma animasyonunu oynatır
	var a := _get_anim_sprite()
	if a:
		a.position = _base_anim_pos
		a.visible = true
		a.frame = 0

		var anim_name := _find_break_animation(a)
		if not anim_name.is_empty():
			a.play(anim_name)
			if not a.animation_finished.is_connected(_finish_collapse):
				a.animation_finished.connect(_finish_collapse, CONNECT_ONE_SHOT)
		else:
			_play_fallback_base_break()
	else:
		_finish_collapse()

	print("[House] ", name, " 1. seviyede yıkılıyor (Sprite2D kapandı, kırılma animasyonu oynatılıyor)...")


func _finish_collapse() -> void:
	var a := _get_anim_sprite()
	if a and is_instance_valid(a):
		a.visible = false
	is_breaking = false
	print("Ev tamamen yıkıldı: ", name)
	house_destroyed.emit(self)
	queue_free()


func _play_fallback_floor_break(broken_floor: int) -> void:
	var a := _get_anim_sprite()
	if not a:
		_on_roof_break_finished(broken_floor)
		return
	var tw := create_tween()
	tw.tween_property(a, "modulate:a", 0.0, 0.6)
	tw.tween_callback(_on_roof_break_finished.bind(broken_floor))


func _play_fallback_base_break() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(_finish_collapse)


func _find_break_animation(a: AnimatedSprite2D) -> String:
	if not a or not a.sprite_frames:
		return ""
	var frames := a.sprite_frames
	var candidates: Array[String] = [
		break_animation_name,
		"destroy",
		"break",
		"kırılma",
		"kirilma",
		"collapse"
	]
	for c in candidates:
		if frames.has_animation(c):
			return c
	var all_anims := frames.get_animation_names()
	for anim in all_anims:
		if anim != "default" and anim != "idle":
			return anim
	if all_anims.size() > 0:
		return all_anims[0]
	return ""


## Ev sınırlarını (bounding box) döndürür
func get_bounds() -> Dictionary:
	var col := _get_col_shape()
	var s := _get_sprite()
	var pos := global_position
	var width: float = 22.0 * global_scale.x
	var height: float = 17.0 * global_scale.y

	if col and col.shape is RectangleShape2D:
		var rect := col.shape as RectangleShape2D
		width = rect.size.x * global_scale.x
		height = rect.size.y * global_scale.y
		var center_pos := col.global_position
		return {
			"left": center_pos.x - (width * 0.5),
			"right": center_pos.x + (width * 0.5),
			"top": center_pos.y - (height * 0.5),
			"bottom": center_pos.y + (height * 0.5),
			"width": width,
			"height": height
		}
	elif s and s.texture:
		var tex_size := s.texture.get_size()
		width = tex_size.x * global_scale.x * s.scale.x
		height = tex_size.y * global_scale.y * s.scale.y
		var center_pos := s.global_position + s.offset * global_scale
		return {
			"left": center_pos.x - (width * 0.5),
			"right": center_pos.x + (width * 0.5),
			"top": center_pos.y - (height * 0.5),
			"bottom": center_pos.y + (height * 0.5),
			"width": width,
			"height": height
		}

	var half_w := width * 0.5
	var half_h := height * 0.5
	return {
		"left": pos.x - half_w,
		"right": pos.x + half_w,
		"top": pos.y - half_h,
		"bottom": pos.y + half_h,
		"width": width,
		"height": height
	}


func _create_or_update_label() -> void:
	if not _level_label or not is_instance_valid(_level_label):
		_level_label = get_node_or_null("LevelLabel") as Label
		if not _level_label:
			_level_label = Label.new()
			_level_label.name = "LevelLabel"
			_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_level_label.add_theme_font_size_override("font_size", 10)
			add_child(_level_label)

	_level_label.text = "Lv.%d" % current_level
	_level_label.modulate = Color(1.0, 0.9, 0.4, 0.95)

	var col := _get_col_shape()
	var top_y: float = -12.0
	if col and col.shape is RectangleShape2D:
		var rect := col.shape as RectangleShape2D
		top_y = col.position.y - (rect.size.y * 0.5) - 12.0
	else:
		top_y = -float(current_level) * get_floor_height() - 12.0

	_level_label.position = Vector2(-20.0, top_y)
	_level_label.size = Vector2(40.0, 14.0)
	_level_label.visible = show_level_label and (current_level > 0)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var gm = get_node_or_null("/root/GameManager")
	if not (gm and gm.debug_mode):
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if test_upgrade_key != KEY_NONE and event.keycode == test_upgrade_key:
		get_viewport().set_input_as_handled()
		upgrade()
	elif test_damage_key != KEY_NONE and event.keycode == test_damage_key:
		get_viewport().set_input_as_handled()
		take_damage()
