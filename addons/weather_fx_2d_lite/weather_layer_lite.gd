class_name WeatherLayerLite
extends ColorRect
## Optional helper: put a weather preset on any ColorRect and keep `aspect` correct.
## Set `preset` to a .tres from presets/, or call transition_to() to fade out and swap.

@export var preset: ShaderMaterial:
	set(v):
		preset = v
		if is_inside_tree():
			_apply()

var _mat: ShaderMaterial

func _ready() -> void:
	color = Color(1, 1, 1, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_update_aspect)
	_apply()

func _apply() -> void:
	if preset == null:
		material = null
		_mat = null
		return
	_mat = preset.duplicate()
	material = _mat
	_update_aspect()

func _update_aspect() -> void:
	if _mat and size.y > 0.0:
		_mat.set_shader_parameter("aspect", size.x / size.y)

## Fade the old preset out, then swap in the new one, over `time` seconds.
func transition_to(next: ShaderMaterial, time := 1.5) -> void:
	if _mat == null or not _has_param(_mat, "intensity"):
		preset = next
		return
	var tw := create_tween()
	tw.tween_property(_mat, "shader_parameter/intensity", 0.0, time * 0.5)
	tw.tween_callback(func():
		preset = next
		if _mat and next != null and _has_param(_mat, "intensity"):
			var target_intensity: float = float(next.get_shader_parameter("intensity"))
			_mat.set_shader_parameter("intensity", 0.0)
			var tw_in := create_tween()
			tw_in.tween_property(_mat, "shader_parameter/intensity", target_intensity, time * 0.5)
	)

func _has_param(m: ShaderMaterial, n: String) -> bool:
	if not m or not m.shader:
		return false
	for p in m.shader.get_shader_uniform_list():
		if p.name == n:
			return true
	return false
