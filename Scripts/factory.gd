extends StaticBody2D
class_name Factory

## Factory:
## 1. 5 distinct visual sprites from factory.png, starting with Level 1 up to Level 5.
## 2. Upgrades up to 5 times (Level 1 to 5) via U key or upgrade().
## 3. Accepts raw Rock cargo from crane / rock pit, and enters active production (default 3s).
## 4. During production, a rich tween animation simulates industrial processing inside.
## 5. Upon completion, spawns Brick cargo (or 30% chance for Event Rock).
## 6. Does NOT block water particles (flows freely like houses).

signal factory_upgraded(new_level: int)
signal production_started()
signal production_finished()
signal brick_spawned(brick: RigidBody2D, level: int)
signal rock_spawned(rock: RigidBody2D, level: int) # For backwards compatibility

@export_group("Upgrade Settings")
## Maximum upgrade level
@export var max_level: int = 5
## Starting level (1 to 5)
@export var current_level: int = 1
## Key to upgrade factory (Default: KEY_SHIFT)
@export var upgrade_key: Key = KEY_SHIFT
## Alternative key to upgrade factory
@export var alt_upgrade_key: Key = KEY_U
## Upgrade cost for each level: Level 1->2 ($10), 2->3 ($25), 3->4 ($45), 4->5 ($80)
@export var level_upgrade_costs: Array[int] = [10, 25, 45, 80]

@export_group("Level Sprites")
## Visual sprite textures for each level (Level 1 to 5). Auto-sliced from factory.png if left empty.
@export var level_sprites: Array[Texture2D] = []

@export_group("Production Settings")
## Base production time in seconds (e.g. 3.0s)
@export var base_production_time: float = 3.0
## Production durations (in seconds) for each level (Level 1 to 5)
@export var level_production_times: Array[float] = [3.0, 2.4, 1.8, 1.3, 0.8]
## PackedScene of the Brick to spawn upon completion (Fabrika sadece tuğla üretir)
@export var brick_scene: PackedScene = preload("res://Scenes/brick.tscn")
## Global position where normal brick is spawned
@export var spawn_position: Vector2 = Vector2(383, 862)

@export_group("Factory Audio")
## Fabrika üretim yaparken aralıksız çalan ses (Looping machine/production sound)
@export var producing_loop_sound: AudioStream = null
## Üretim sırasındaki ses seviyesi (dB)
@export var producing_volume_db: float = -6.0
## Üretim tamamlandığında tuğla/taş çıktığında çalan ses (Spit brick / finished sound)
@export var produce_finished_sound: AudioStream = preload("res://Sounds/factory spit brick sounf effect.wav")
## Üretim bitiş sesi seviyesi (dB)
@export var produce_finished_volume_db: float = 0.0

@export_group("Pointer Settings")
## When true, the tutorial pointer bobs up and down; when false, it remains stationary in place
@export var enable_pointer_movement: bool = false

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var label: Label = get_node_or_null("Label")
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var pointer: Sprite2D = get_node_or_null("PointerSprite2D")

var is_producing: bool = false
var production_timer: float = 0.0
var production_count: int = 0
var _production_tween: Tween = null
var _original_sprite_scale: Vector2 = Vector2.ONE
var _original_sprite_pos: Vector2 = Vector2.ZERO
var _original_label_pos: Vector2 = Vector2.ZERO
var has_completed_first_rock_tutorial: bool = false
var _base_pointer_y: float = -340.0
var _producing_player: AudioStreamPlayer2D = null
var _produce_finished_player: AudioStreamPlayer2D = null

const LEVEL_REGIONS: Array[Rect2] = [
	Rect2(22, 26, 57, 67),  # Level 1: Single smokestack
	Rect2(118, 26, 57, 67), # Level 2: Dual smokestacks
	Rect2(214, 25, 57, 68), # Level 3: Triple smokestacks
	Rect2(310, 24, 57, 69), # Level 4: Quad smokestacks
	Rect2(406, 19, 57, 74)  # Level 5: 5 glowing green smokestacks
]


func _ready() -> void:
	add_to_group("factory")
	current_level = clampi(current_level, 1, max_level)

	if sprite:
		_original_sprite_scale = sprite.scale
		_original_sprite_pos = sprite.position
	if label:
		_original_label_pos = label.position

	if pointer:
		_base_pointer_y = pointer.position.y
		pointer.visible = false

	# Ensure factory does not block water particles
	_register_water_exception()

	_init_level_sprites()
	_apply_level_sprite()
	_update_label_text()
	_init_factory_audio()

	var drop_zone := get_node_or_null("DropZone") as Area2D
	if drop_zone and not drop_zone.body_entered.is_connected(_on_drop_zone_body_entered):
		drop_zone.body_entered.connect(_on_drop_zone_body_entered)

	print("[Factory] Ready! Initialized at Level ", current_level, "/", max_level, ". Feed rock to produce brick. Press 'U' to upgrade.")


func _on_drop_zone_body_entered(body: Node) -> void:
	if not is_instance_valid(body) or is_producing:
		return
	# Upgrade Rock (Enderpearl) ve Event Rock kesinlikle fabrikaya tekrar giremez
	if body.is_in_group("upgrade_rock") or body.get_meta("is_upgrade_rock", false) or body.is_in_group("event_rock") or body.get_meta("is_event_rock", false):
		if body is RigidBody2D:
			body.apply_central_impulse(Vector2(90.0, -45.0))
		return
	if body.is_in_group("rock") and not body.is_in_group("brick"):
		accept_rock(body)


func _process(delta: float) -> void:
	if enable_pointer_movement and pointer and pointer.visible:
		var time := Time.get_ticks_msec() / 1000.0
		pointer.position.y = _base_pointer_y + sin(time * 5.0) * 15.0

	if is_producing:
		production_timer -= delta

		# High-frequency industrial jitter on sprite during processing
		if sprite:
			sprite.position = _original_sprite_pos + Vector2(randf_range(-1.2, 1.2), randf_range(-0.8, 0.8))

		_update_label_text()

		if production_timer <= 0.0:
			_finish_production()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# Shift or U Key: Upgrade factory with money
	if event.keycode == KEY_SHIFT or event.physical_keycode == KEY_SHIFT or event.keycode == upgrade_key or (alt_upgrade_key != KEY_NONE and event.keycode == alt_upgrade_key):
		get_viewport().set_input_as_handled()
		try_upgrade_factory()


## Shows the tutorial pointer when the player picks up a rock for the first time
func show_first_rock_pointer() -> void:
	if has_completed_first_rock_tutorial:
		return
	if not pointer or not is_instance_valid(pointer):
		pointer = get_node_or_null("PointerSprite2D") as Sprite2D
	if pointer:
		pointer.visible = true


## Hides pointer temporarily if the player drops the rock before delivering
func hide_pointer_temporarily() -> void:
	if has_completed_first_rock_tutorial:
		return
	if pointer:
		pointer.visible = false


## Permanently disables the pointer after the first rock is delivered
func hide_pointer_permanently() -> void:
	has_completed_first_rock_tutorial = true
	if pointer:
		pointer.visible = false


## Attempts to feed a rock into the factory to begin brick production
func accept_rock(rock_body: Node2D) -> bool:
	if not is_instance_valid(rock_body):
		return false

	# Upgrade Rock (Enderpearl) ve Event Rock kesinlikle fabrikaya tekrar giremez
	if rock_body.is_in_group("upgrade_rock") or rock_body.get_meta("is_upgrade_rock", false) or rock_body.is_in_group("event_rock") or rock_body.get_meta("is_event_rock", false):
		print("[Factory] Upgrade Rock / Event Rock fabrikaya giremez! Bu taşlar özel amaçlıdır.")
		return false

	if is_producing:
		print("[Factory] Fabrika meşgul! Üretim devam ediyor.")
		_jiggle_label(Color(1.0, 0.4, 0.4))
		return false

	# First rock delivered: permanently hide factory pointer
	hide_pointer_permanently()

	# Detach from crane if currently held
	var tree := get_tree()
	if tree:
		var crane = tree.get_first_node_in_group("crane")
		if crane and "grabbed_body" in crane and crane.grabbed_body == rock_body:
			crane._release_cargo()

	# Freeze rock & disable collisions immediately
	if rock_body is RigidBody2D:
		rock_body.set_deferred("freeze", true)
		rock_body.collision_layer = 0
		rock_body.collision_mask = 0

	# Smooth suction tween pulling the rock into factory machinery
	var intake_target: Vector2 = global_position + Vector2(0.0, -10.0)
	var intake_tween := create_tween().set_parallel(true)
	intake_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	intake_tween.tween_property(rock_body, "global_position", intake_target, 0.28)
	intake_tween.tween_property(rock_body, "scale", rock_body.scale * 0.1, 0.28)
	intake_tween.tween_property(rock_body, "modulate:a", 0.0, 0.28)
	intake_tween.chain().tween_callback(func():
		if is_instance_valid(rock_body):
			rock_body.queue_free()
	)

	start_production()
	return true


## Starts the internal production processing cycle
func start_production() -> void:
	if is_producing:
		return

	is_producing = true
	production_timer = get_current_production_time()
	print("[Factory] Üretime başlandı! Süre: ", snapped(production_timer, 0.1), "s (Seviye ", current_level, ")")
	production_started.emit()

	_start_production_tween()
	_update_label_text()
	_play_producing_sound()


## Rhythmic squash, stretch, and piston rumble simulating active manufacturing inside
func _start_production_tween() -> void:
	if _production_tween and _production_tween.is_valid():
		_production_tween.kill()

	if not sprite:
		return

	_production_tween = create_tween().set_loops()
	# 1. Piston down-stroke (squash)
	_production_tween.tween_property(sprite, "scale", _original_sprite_scale * Vector2(1.09, 0.92), 0.14)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 2. Piston up-stroke (stretch)
	_production_tween.tween_property(sprite, "scale", _original_sprite_scale * Vector2(0.94, 1.07), 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 3. Recoil settle
	_production_tween.tween_property(sprite, "scale", _original_sprite_scale, 0.10)


## Finished production cycle: stops tween, triggers pop explosion, and spawns Brick or Event Rock
func _finish_production() -> void:
	is_producing = false
	production_timer = 0.0

	_stop_producing_sound()
	_play_produce_finished_sound()

	# Stop production animation and restore default transforms
	if _production_tween and _production_tween.is_valid():
		_production_tween.kill()
		_production_tween = null

	if sprite:
		sprite.position = _original_sprite_pos
		sprite.scale = _original_sprite_scale

		# Celebratory pop burst
		var burst := create_tween()
		burst.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		burst.tween_property(sprite, "scale", _original_sprite_scale * 1.25, 0.12)
		burst.tween_property(sprite, "scale", _original_sprite_scale, 0.22)

	if animation_player and animation_player.has_animation("popout"):
		animation_player.play("popout")

	# Fabrikadan daima SADECE Tuğla (Brick) düşer, başka hiçbir nesne çıkamaz!
	production_count += 1
	var spawned_product: RigidBody2D = _instantiate_brick()

	if spawned_product:
		var target_parent: Node = get_tree().current_scene
		if not target_parent:
			target_parent = owner if owner else get_parent()
		target_parent.add_child(spawned_product)

		# Ensure water exception on product
		var w = _find_fluid_water()
		if w and w.has_method("add_collision_exception"):
			w.add_collision_exception(spawned_product)

		spawned_product.global_position = spawn_position
		brick_spawned.emit(spawned_product, current_level)
		print("[Factory] TUĞLA (Brick) üretildi ve çıktı! Konum: ", spawn_position)
		rock_spawned.emit(spawned_product, current_level)

	production_finished.emit()
	_update_label_text()


func _instantiate_brick() -> RigidBody2D:
	if brick_scene:
		return brick_scene.instantiate() as RigidBody2D
	elif ResourceLoader.exists("res://Scenes/brick.tscn"):
		var bs := load("res://Scenes/brick.tscn") as PackedScene
		if bs:
			return bs.instantiate() as RigidBody2D
	return null






func get_upgrade_cost() -> int:
	var idx: int = current_level - 1
	if idx >= 0 and idx < level_upgrade_costs.size():
		return level_upgrade_costs[idx]
	return 0


func can_upgrade() -> bool:
	if current_level >= max_level:
		return false
	var cost: int = get_upgrade_cost()
	var gm = get_node_or_null("/root/GameManager")
	var current_money: int = gm.get_money() if gm and gm.has_method("get_money") else 0
	return current_money >= cost


## Attempts to upgrade the factory with money when Shift is pressed
func try_upgrade_factory() -> bool:
	if current_level >= max_level:
		print("[Factory] Duvar/Fabrika zaten maksimum seviyede (", max_level, ").")
		_trigger_rejection_feedback()
		return false

	var cost: int = get_upgrade_cost()
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.has_method("spend_money") or not gm.spend_money(cost):
		print("[Factory] Yükseltme için yeterli para yok! Gerekli: ", cost, "$, Mevcut: ", (gm.get_money() if gm else 0), "$")
		_trigger_rejection_feedback()
		return false

	# Deducted successfully! Upgrade factory
	var success := upgrade()
	if success:
		_notify_price_updated()
	return success


func _trigger_rejection_feedback() -> void:
	_jiggle_label(Color(1.0, 0.25, 0.25))
	var tree := get_tree()
	if tree:
		var buttons = tree.get_first_node_in_group("buttons")
		if buttons and buttons.has_method("play_shift_rejection_shake"):
			buttons.play_shift_rejection_shake()


func _notify_price_updated() -> void:
	var tree := get_tree()
	if tree:
		var buttons = tree.get_first_node_in_group("buttons")
		if buttons and buttons.has_method("update_shift_upgrade_price"):
			buttons.update_shift_upgrade_price(get_upgrade_cost(), current_level >= max_level)


## Upgrades the factory to the next level (up to max_level).
func upgrade() -> bool:
	if current_level >= max_level:
		print("[Factory] Duvar/Fabrika zaten maksimum seviyede (", max_level, ").")
		_jiggle_label(Color(1.0, 0.8, 0.2))
		return false

	current_level += 1
	var prod_time: float = get_current_production_time()
	print("[Factory] Yükseltildi! Seviye: ", current_level, "/", max_level, ". Yeni üretim süresi: ", prod_time, "s.")
	factory_upgraded.emit(current_level)

	_apply_level_sprite()
	_play_upgrade_effect()
	_update_label_text()
	_notify_price_updated()
	return true


func get_current_production_time() -> float:
	var idx: int = current_level - 1
	if idx >= 0 and idx < level_production_times.size():
		return level_production_times[idx]
	return base_production_time


func _init_level_sprites() -> void:
	if level_sprites.size() >= max_level:
		return
	var base_tex: Texture2D = load("res://Sprites/Background/factory.png")
	if not base_tex:
		return
	level_sprites.clear()
	for reg in LEVEL_REGIONS:
		var atlas := AtlasTexture.new()
		atlas.atlas = base_tex
		atlas.region = reg
		level_sprites.append(atlas)


func _apply_level_sprite() -> void:
	if not sprite:
		return
	var idx: int = current_level - 1
	if idx >= 0 and idx < level_sprites.size() and level_sprites[idx] != null:
		sprite.texture = level_sprites[idx]
		var reg: Rect2 = LEVEL_REGIONS[clampi(idx, 0, LEVEL_REGIONS.size() - 1)]
		var height_diff: float = reg.size.y - 67.0
		sprite.offset.y = -height_diff * 0.5


func _update_label_text() -> void:
	if not label:
		return

	if is_producing:
		label.text = "PRODUCING...\n[%.1fs]\nLv.%d/%d" % [maxf(production_timer, 0.0), current_level, max_level]
		label.modulate = Color(1.0, 0.85, 0.2)
	else:
		label.text = "FACTORY\n(Need Rock)\nLv.%d/%d" % [current_level, max_level]
		label.modulate = Color(0.9, 0.95, 1.0)


func _play_upgrade_effect() -> void:
	if sprite:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", _original_sprite_scale * 1.3, 0.25)
		tween.tween_property(sprite, "scale", _original_sprite_scale, 0.35)

	if label:
		var l_tween := create_tween()
		l_tween.tween_property(label, "modulate", Color(0.3, 1.0, 0.4), 0.15)
		l_tween.tween_property(label, "modulate", Color(1.0, 1.0, 1.0), 0.25)


func _jiggle_label(tint: Color) -> void:
	if not label:
		return
	var tween := create_tween()
	label.modulate = tint
	tween.tween_property(label, "position:x", _original_label_pos.x - 4.0, 0.04)
	tween.tween_property(label, "position:x", _original_label_pos.x + 4.0, 0.04)
	tween.tween_property(label, "position:x", _original_label_pos.x, 0.04)
	tween.tween_property(label, "modulate", Color(1.0, 1.0, 1.0), 0.15)


func _register_water_exception() -> void:
	# Keep factory collision layer 0 so water particles flow through
	collision_layer = 0
	collision_mask = 0
	var w = _find_fluid_water()
	if w and w.has_method("add_collision_exception"):
		w.add_collision_exception(self)


func _find_fluid_water() -> Node:
	var tree := get_tree()
	if not tree:
		return null
	var w = tree.get_first_node_in_group("fluid_water")
	if w:
		return w
	if tree.current_scene:
		w = tree.current_scene.find_child("FluidWater", true, false)
		if w:
			return w
	return null


# Backward-compatible spawn methods
func spawn_rock() -> RigidBody2D:
	if not is_producing:
		start_production()
	return null

func spawn_crate() -> RigidBody2D:
	return spawn_rock()


# ==============================================================================
# FACTORY AUDIO SYSTEM
# ==============================================================================
func _init_factory_audio() -> void:
	var sfx_bus: String = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"

	# 1. Üretim devam ederkenki döngü sesi oynatıcı (Looping AudioStreamPlayer2D)
	if not _producing_player:
		_producing_player = AudioStreamPlayer2D.new()
		_producing_player.name = "ProducingAudioPlayer"
		_producing_player.bus = sfx_bus
		_producing_player.volume_db = producing_volume_db
		_producing_player.max_distance = 2500.0
		_producing_player.attenuation = 1.0
		add_child(_producing_player)

	# 2. Üretim tamamlandığında fırlatma/bitiş sesi oynatıcı (AudioStreamPlayer2D)
	if not _produce_finished_player:
		_produce_finished_player = AudioStreamPlayer2D.new()
		_produce_finished_player.name = "ProduceFinishedAudioPlayer"
		_produce_finished_player.bus = sfx_bus
		_produce_finished_player.volume_db = produce_finished_volume_db
		_produce_finished_player.max_distance = 3000.0
		_produce_finished_player.attenuation = 1.0
		add_child(_produce_finished_player)

	if produce_finished_sound and _produce_finished_player:
		_produce_finished_player.stream = produce_finished_sound


func _play_producing_sound() -> void:
	if not _producing_player:
		return
	if producing_loop_sound:
		_producing_player.stream = producing_loop_sound
		_producing_player.volume_db = producing_volume_db
		# WAV veya MP3 loop ayarı desteği
		if producing_loop_sound is AudioStreamWAV:
			var wav := producing_loop_sound as AudioStreamWAV
			if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_producing_player.play()


func _stop_producing_sound() -> void:
	if _producing_player and _producing_player.playing:
		_producing_player.stop()


func _play_produce_finished_sound() -> void:
	if not _produce_finished_player:
		return
	if produce_finished_sound and _produce_finished_player.stream != produce_finished_sound:
		_produce_finished_player.stream = produce_finished_sound
	if _produce_finished_player.stream:
		_produce_finished_player.volume_db = produce_finished_volume_db
		_produce_finished_player.pitch_scale = randf_range(0.95, 1.05)
		_produce_finished_player.play()
