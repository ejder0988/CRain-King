@tool
class_name WaterKillBox
extends Area2D

## WaterKillBox
## Bu alana temas eden veya içine giren her su parçacığı anında yok edilir.
## Godot 2D editöründe CollisionShape2D tutamaçlarını sürükleyerek boyutunu değiştirebilir,
## sahne üzerinde istediğiniz konuma taşıyabilirsiniz.

@export var enabled: bool = true:
	set(val):
		enabled = val
		queue_redraw()

## Editörde ve hata ayıklamada killbox alanını gösteren renk
@export var debug_color: Color = Color(1.0, 0.2, 0.2, 0.35):
	set(val):
		debug_color = val
		queue_redraw()

## Oyun çalışırken de kırmızı killbox kutusunun ekranda görünür olmasını sağlar
@export var show_in_game: bool = false:
	set(val):
		show_in_game = val
		queue_redraw()

## Bu killbox tarafından yok edilen toplam su damlası sayısı (istatistik/debug)
@export var kill_count: int = 0

## Su damlası yok edildiğinde tetiklenen sinyal
signal water_destroyed(pos: Vector2)

var _collision_shape: CollisionShape2D = null
var _cached_global_aabb: Rect2 = Rect2()
var _has_aabb: bool = false


func _ready() -> void:
	add_to_group("water_killbox")
	_find_shape()
	update_cached_bounds()

	# Normal Godot Node olan su nesneleri (RigidBody2D, Area2D vb.) için bağlantılar
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		update_cached_bounds()
		queue_redraw()


func _find_shape() -> void:
	_collision_shape = null
	for child in get_children():
		if child is CollisionShape2D and child.shape:
			_collision_shape = child
			if not child.shape.changed.is_connected(_on_shape_changed):
				child.shape.changed.connect(_on_shape_changed)
			break


func _on_shape_changed() -> void:
	update_cached_bounds()
	queue_redraw()


## Bounding box'ı (AABB) günceller (Binlerce parçacık kontrolünü O(1) düzeyinde hızlandırır)
func update_cached_bounds() -> void:
	if not _collision_shape or not _collision_shape.shape:
		_find_shape()

	if _collision_shape and _collision_shape.shape:
		var s := _collision_shape.shape
		var global_pos := _collision_shape.global_position
		var g_scale: Vector2 = _collision_shape.global_scale.abs()

		if s is RectangleShape2D:
			var half: Vector2 = (s as RectangleShape2D).size * 0.5 * g_scale
			_cached_global_aabb = Rect2(global_pos - half, half * 2.0)
			_has_aabb = true
		elif s is CircleShape2D:
			var r: float = (s as CircleShape2D).radius * maxf(g_scale.x, g_scale.y)
			_cached_global_aabb = Rect2(global_pos - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
			_has_aabb = true
		elif s is CapsuleShape2D:
			var cap := s as CapsuleShape2D
			var r: float = cap.radius * maxf(g_scale.x, g_scale.y)
			var h: float = cap.height * maxf(g_scale.x, g_scale.y)
			_cached_global_aabb = Rect2(global_pos - Vector2(r, h * 0.5), Vector2(r * 2.0, h))
			_has_aabb = true
		else:
			_has_aabb = false
	else:
		_has_aabb = false


func get_global_aabb() -> Rect2:
	if not _has_aabb:
		update_cached_bounds()
	return _cached_global_aabb


## Belirtilen global koordinatın bu killbox içinde olup olmadığını doğrular
func contains_point(point: Vector2) -> bool:
	if not enabled:
		return false

	if not _collision_shape or not _collision_shape.shape:
		_find_shape()
		if not _collision_shape or not _collision_shape.shape:
			return false

	# Ultra hızlı AABB elemesi
	if _has_aabb and not _cached_global_aabb.has_point(point):
		return false

	# Şeklin yerel koordinat uzayında kesin çarpışma testi
	var local_pt: Vector2 = _collision_shape.global_transform.affine_inverse() * point
	var s := _collision_shape.shape

	if s is RectangleShape2D:
		var half_size: Vector2 = (s as RectangleShape2D).size * 0.5
		return absf(local_pt.x) <= half_size.x and absf(local_pt.y) <= half_size.y
	elif s is CircleShape2D:
		var radius: float = (s as CircleShape2D).radius
		return local_pt.length_squared() <= (radius * radius)
	elif s is CapsuleShape2D:
		var cap := s as CapsuleShape2D
		var half_h: float = maxf(0.0, (cap.height * 0.5) - cap.radius)
		var clamped_y: float = clampf(local_pt.y, -half_h, half_h)
		return (local_pt - Vector2(0.0, clamped_y)).length_squared() <= (cap.radius * cap.radius)

	return false


func _on_body_entered(body: Node2D) -> void:
	if not enabled or not is_instance_valid(body):
		return
	if _is_water_node(body):
		kill_count += 1
		water_destroyed.emit(body.global_position)
		body.queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not enabled or not is_instance_valid(area):
		return
	if _is_water_node(area):
		kill_count += 1
		water_destroyed.emit(area.global_position)
		area.queue_free()


func _is_water_node(node: Node) -> bool:
	if node.is_in_group("water") or node.is_in_group("fluid_water"):
		return true
	var n_name := node.name.to_lower()
	return n_name.contains("water") or n_name.contains("drop") or n_name.contains("damla")


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		# Editörde tutamaçlar çekildiğinde anlık çizim tazeleme
		if _collision_shape and _collision_shape.shape:
			update_cached_bounds()


func _draw() -> void:
	if Engine.is_editor_hint() or show_in_game:
		if not _collision_shape:
			_find_shape()
		if _collision_shape and _collision_shape.shape:
			var s := _collision_shape.shape
			var offset: Vector2 = _collision_shape.position
			var border_color := Color(debug_color.r, debug_color.g, debug_color.b, minf(1.0, debug_color.a * 2.5 + 0.3))

			if s is RectangleShape2D:
				var sz: Vector2 = (s as RectangleShape2D).size
				var rect := Rect2(offset - sz * 0.5, sz)
				draw_rect(rect, debug_color, true)
				draw_rect(rect, border_color, false, 2.0)
			elif s is CircleShape2D:
				var r: float = (s as CircleShape2D).radius
				draw_circle(offset, r, debug_color)
				draw_arc(offset, r, 0, TAU, 32, border_color, 2.0)
			elif s is CapsuleShape2D:
				var cap := s as CapsuleShape2D
				var sz := Vector2(cap.radius * 2.0, cap.height)
				var rect := Rect2(offset - sz * 0.5, sz)
				draw_rect(rect, debug_color, true)
				draw_rect(rect, border_color, false, 2.0)
