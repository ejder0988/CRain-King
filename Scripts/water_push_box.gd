@tool
class_name WaterPushBox
extends Area2D

## WaterPushBox
## Bu alana temas eden veya içine giren her su parçacığı belirlenen yönde ve kuvvetle itilir.
## Godot 2D editöründe CollisionShape2D tutamaçlarını sürükleyerek boyutunu değiştirebilir,
## sahne üzerinde istediğiniz konuma taşıyabilir ve döndürebilirsiniz.
## İtme yönü, kuvveti, hedef hızı ve tüm fiziksel değerleri Inspector üzerinden anlık ayarlanabilir.

signal water_pushed(pos: Vector2, direction: Vector2)

@export_group("Push Direction & Angle")
## İtme kutusunu aktif veya pasif yapar
@export var enabled: bool = true:
	set(val):
		enabled = val
		queue_redraw()

@export_group("Tsunami & Activation Settings")
## Tsunami olmasa bile bu kutunun sürekli suyu itmesini sağlar.
## - Açık (true): Tsunami olsun ya da olmasın bu kutu her zaman suyu iter.
## - Kapalı (false - varsayılan): Kutu sadece tsunami felaketi sırasında aktifleşir ve suyu iter.
@export var push_without_tsunami: bool = false:
	set(val):
		push_without_tsunami = val
		if not Engine.is_editor_hint():
			if push_without_tsunami:
				enabled = true
		queue_redraw()

## Yön belirleme modu:
## - Açık (true): İtme yönü kutunun sahnedeki kendi dönüş açısına (Rotation) göre otomatik alınır.
## - Kapalı (false): Aşağıdaki push_angle_degrees veya push_direction değerleri kullanılır.
@export var use_node_rotation: bool = false:
	set(val):
		use_node_rotation = val
		queue_redraw()

## Derece cinsinden itme açısı (0° = Sağa, 90° = Aşağı, 180° = Sola, 270°/-90° = Yukarı, 45° = Çapraz Sağ-Aşağı vb.)
@export_range(-360.0, 360.0, 1.0) var push_angle_degrees: float = 0.0:
	set(val):
		push_angle_degrees = val
		if not use_node_rotation:
			push_direction = Vector2.RIGHT.rotated(deg_to_rad(val)).normalized()
		queue_redraw()

## Doğrudan vektör olarak itme yönü (Örn: Vector2(1, 0) = Sağa, Vector2(0, -1) = Yukarı, Vector2(-1, 0) = Sola)
@export var push_direction: Vector2 = Vector2.RIGHT:
	set(val):
		if val.length_squared() > 0.0001:
			push_direction = val.normalized()
			var deg := rad_to_deg(push_direction.angle())
			if absf(deg - push_angle_degrees) > 0.1:
				push_angle_degrees = deg
		else:
			push_direction = Vector2.RIGHT
		queue_redraw()


@export_group("Push Physics & Force Settings")
## Su parçacıklarına uygulanan sürekli itme kuvveti (Kuvvet modu / acceleration)
@export var push_force: float = 2200.0

## Suyun bu alanda ulaşması hedeflenen doğrusal hız (px/s)
@export var target_speed: float = 400.0

## Hız takviyesini (Velocity Boost) etkinleştirir (Suyun hızını anında hedef yöne ve hıza büker)
@export var apply_velocity_boost: bool = true

## Suyun hızının belirlenen yöne ne kadar keskin/yumuşak uyarlanacağı (0.05 = Yumuşak akıntı, 0.25 = Güçlü akıntı, 1.0 = Anında)
@export_range(0.01, 1.0, 0.01) var velocity_blend: float = 0.25

## İtme yönünün tersine giden suyun ters hızını anında sıfırlar (Örn: Yerçekimiyle aşağı düşen su yukarı itiliyorsa düşüşü hemen keser)
@export var cancel_opposing_velocity: bool = true

## Suyun bu kutu içinde veya çıkışında ulaşabileceği maksimum hız tavanı (px/s)
@export var max_exit_speed: float = 750.0

## Kutuya giren durgun/uyuyan suları anında uyandırıp harekete geçirir
@export var wake_sleeping_water: bool = true


@export_group("Rigid Body Physics")
## Alana giren normal RigidBody2D nesnelerini de bu yönde iter mi?
@export var push_affects_rigid_bodies: bool = true

## Normal RigidBody2D nesnelerine uygulanacak itme kuvveti
@export var rigid_body_force: float = 1200.0


@export_group("Visuals & Debug")
## Oyun çalışırken de ekranda mavi su akıntısı kutusunun ve yön oklarının görünmesini sağlar
@export var show_in_game: bool = false:
	set(val):
		show_in_game = val
		queue_redraw()

## Kutu dolgu ve sınır rengi (Yarı saydam su akıntısı efekti)
@export var debug_color: Color = Color(0.15, 0.65, 1.0, 0.28):
	set(val):
		debug_color = val
		queue_redraw()

## Yönü gösteren okların rengi
@export var arrow_color: Color = Color(1.0, 1.0, 1.0, 0.85):
	set(val):
		arrow_color = val
		queue_redraw()

## Kutu içinde çizilecek yön oku sayısı (1 ile 7 arası)
@export_range(1, 7, 1) var arrow_count: int = 3:
	set(val):
		arrow_count = val
		queue_redraw()

## Kutu içinde yön oklarının boyutu (piksel)
@export_range(10.0, 100.0, 1.0) var arrow_size: float = 30.0:
	set(val):
		arrow_size = val
		queue_redraw()


@export_group("Stats & Debug")
## Bu itme kutusu tarafından itilen parçacık sayısı (debug/istatistik)
@export var push_count: int = 0

var _collision_shape: CollisionShape2D = null
var _cached_global_aabb: Rect2 = Rect2()
var _has_aabb: bool = false
var _overlapping_rigid_bodies: Array[RigidBody2D] = []


func _ready() -> void:
	add_to_group("water_pushbox")
	_find_shape()
	update_cached_bounds()

	# Normal Godot RigidBody2D nesneleri için bağlantılar
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	# Varsayılan olarak kutular sadece tsunami sırasında çalışır:
	# Eğer push_without_tsunami açık ise oyun başında da aktif kalır, kapalı ise tsunami gelene kadar devre dışıdır.
	if not Engine.is_editor_hint():
		if push_without_tsunami:
			enabled = true
		else:
			enabled = false


## Kutunun anlık olarak suyu itip itmeyeceğini kontrol eder
func is_push_active() -> bool:
	if push_without_tsunami:
		return true
	return enabled


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


## Global uzaydaki nihai itme yönünü döndürür (Birim vektör / Normalized)
func get_effective_push_direction() -> Vector2:
	if use_node_rotation:
		return global_transform.x.normalized()
	return push_direction.normalized() if push_direction.length_squared() > 0.0001 else Vector2.RIGHT


## Bounding box'ı (AABB) günceller (Binlerce parçacık kontrolünü O(1) düzeyinde hızlandırır)
func update_cached_bounds() -> void:
	if not _collision_shape or not _collision_shape.shape:
		_find_shape()

	if _collision_shape and _collision_shape.shape:
		var s := _collision_shape.shape
		var gt: Transform2D = _collision_shape.global_transform

		if s is RectangleShape2D:
			var half: Vector2 = (s as RectangleShape2D).size * 0.5
			var c1: Vector2 = gt * Vector2(-half.x, -half.y)
			var c2: Vector2 = gt * Vector2(half.x, -half.y)
			var c3: Vector2 = gt * Vector2(half.x, half.y)
			var c4: Vector2 = gt * Vector2(-half.x, half.y)
			var min_x := minf(minf(c1.x, c2.x), minf(c3.x, c4.x))
			var min_y := minf(minf(c1.y, c2.y), minf(c3.y, c4.y))
			var max_x := maxf(maxf(c1.x, c2.x), maxf(c3.x, c4.x))
			var max_y := maxf(maxf(c1.y, c2.y), maxf(c3.y, c4.y))
			_cached_global_aabb = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
			_has_aabb = true
		elif s is CircleShape2D:
			var global_pos := gt.origin
			var g_scale: Vector2 = gt.get_scale().abs()
			var r: float = (s as CircleShape2D).radius * maxf(g_scale.x, g_scale.y)
			_cached_global_aabb = Rect2(global_pos - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
			_has_aabb = true
		elif s is CapsuleShape2D:
			var cap := s as CapsuleShape2D
			var half_h: float = maxf(0.0, (cap.height * 0.5) - cap.radius)
			var pt_top: Vector2 = gt * Vector2(0.0, -half_h)
			var pt_bot: Vector2 = gt * Vector2(0.0, half_h)
			var g_scale: Vector2 = gt.get_scale().abs()
			var r: float = cap.radius * maxf(g_scale.x, g_scale.y)
			var min_x := minf(pt_top.x, pt_bot.x) - r
			var min_y := minf(pt_top.y, pt_bot.y) - r
			var max_x := maxf(pt_top.x, pt_bot.x) + r
			var max_y := maxf(pt_top.y, pt_bot.y) + r
			_cached_global_aabb = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
			_has_aabb = true
		else:
			_has_aabb = false
	else:
		_has_aabb = false


func get_global_aabb() -> Rect2:
	if not _has_aabb:
		update_cached_bounds()
	return _cached_global_aabb


## Belirtilen global koordinatın bu pushbox içinde olup olmadığını doğrular
func contains_point(point: Vector2) -> bool:
	if not is_push_active():
		return false

	if not _collision_shape or not _collision_shape.shape:
		_find_shape()
		if not _collision_shape or not _collision_shape.shape:
			return false

	# Ultra hızlı AABB broadphase elemesi
	if _has_aabb and not _cached_global_aabb.has_point(point):
		return false

	# Şeklin yerel koordinat uzayında kesin çarpışma testi (dönüş ve ölçek dahil)
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
	if body is RigidBody2D and not _overlapping_rigid_bodies.has(body):
		_overlapping_rigid_bodies.append(body)


func _on_body_exited(body: Node2D) -> void:
	if body is RigidBody2D:
		_overlapping_rigid_bodies.erase(body)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if _collision_shape and _collision_shape.shape:
			update_cached_bounds()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not is_push_active() or not push_affects_rigid_bodies or _overlapping_rigid_bodies.is_empty():
		return

	var dir: Vector2 = get_effective_push_direction()
	var force_vec: Vector2 = dir * rigid_body_force
	for i in range(_overlapping_rigid_bodies.size() - 1, -1, -1):
		var body: RigidBody2D = _overlapping_rigid_bodies[i]
		if is_instance_valid(body):
			body.apply_central_force(force_vec)
		else:
			_overlapping_rigid_bodies.remove_at(i)


func _draw() -> void:
	if not Engine.is_editor_hint() and not show_in_game:
		return

	if not _collision_shape:
		_find_shape()

	if not _collision_shape or not _collision_shape.shape:
		return

	var s := _collision_shape.shape
	var offset: Vector2 = _collision_shape.position
	var border_color := Color(debug_color.r, debug_color.g, debug_color.b, minf(1.0, debug_color.a * 2.5 + 0.3))

	var s_scale: Vector2 = _collision_shape.scale.abs()
	var shape_size := Vector2(80.0, 80.0)

	if s is RectangleShape2D:
		var sz: Vector2 = (s as RectangleShape2D).size * s_scale
		shape_size = sz
		var rect := Rect2(offset - sz * 0.5, sz)
		draw_rect(rect, debug_color, true)
		draw_rect(rect, border_color, false, 2.0)
	elif s is CircleShape2D:
		var r: float = (s as CircleShape2D).radius * maxf(s_scale.x, s_scale.y)
		shape_size = Vector2(r * 2.0, r * 2.0)
		draw_circle(offset, r, debug_color)
		draw_arc(offset, r, 0, TAU, 32, border_color, 2.0)
	elif s is CapsuleShape2D:
		var cap := s as CapsuleShape2D
		var sz := Vector2(cap.radius * 2.0 * s_scale.x, cap.height * s_scale.y)
		shape_size = sz
		var rect := Rect2(offset - sz * 0.5, sz)
		draw_rect(rect, debug_color, true)
		draw_rect(rect, border_color, false, 2.0)

	_draw_push_arrows(offset, shape_size)


func _draw_push_arrows(center_pos: Vector2, bounds_size: Vector2) -> void:
	if arrow_count <= 0:
		return

	var eff_dir := get_effective_push_direction()
	# Bu node'un yerel uzayındaki yön vektörü
	var local_dir: Vector2 = (global_transform.affine_inverse().basis_xform(eff_dir)).normalized()
	if local_dir.length_squared() < 0.0001:
		local_dir = Vector2.RIGHT

	var perp := Vector2(-local_dir.y, local_dir.x)
	var arrow_len: float = clampf(arrow_size, 10.0, minf(bounds_size.x, bounds_size.y) * 0.8)

	if arrow_count == 1:
		_draw_arrow(center_pos, local_dir, arrow_len, arrow_color)
	else:
		var usable_span: float = minf(bounds_size.x, bounds_size.y) * 0.65
		for i in range(arrow_count):
			var t: float = (float(i) / float(arrow_count - 1)) - 0.5
			var pt: Vector2 = center_pos + perp * (t * usable_span)
			_draw_arrow(pt, local_dir, arrow_len, arrow_color)


func _draw_arrow(pos: Vector2, dir: Vector2, length: float, color: Color) -> void:
	var half_len: float = length * 0.5
	var start_pt := pos - dir * half_len
	var end_pt := pos + dir * half_len
	draw_line(start_pt, end_pt, color, 3.0)

	var wing_len: float = length * 0.38
	var wing_angle: float = deg_to_rad(32.0)
	var wing1 := end_pt - dir.rotated(wing_angle) * wing_len
	var wing2 := end_pt - dir.rotated(-wing_angle) * wing_len
	draw_line(end_pt, wing1, color, 3.0)
	draw_line(end_pt, wing2, color, 3.0)
