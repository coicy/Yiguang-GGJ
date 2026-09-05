@tool
class_name MechanismMotion
extends Node
## One editor-wired action that moves one or more MoveableCube targets in sync.

enum MotionMode {
	TRANSLATE,
	ROTATE_CLOCKWISE,
}

@export var motion_mode: MotionMode = MotionMode.TRANSLATE
@export_node_path("MoveableCube") var targets: Array[NodePath] = []
@export var destination_offset := Vector2.ZERO
@export var pivot_global := Vector2.ZERO
@export_range(-360.0, 360.0, 1.0) var rotation_degrees: float = 90.0

var _is_activated := false


func activate() -> bool:
	if Engine.is_editor_hint() or _is_activated:
		return false
	var cubes := _resolve_targets()
	if cubes.is_empty():
		return false
	_is_activated = true
	match motion_mode:
		MotionMode.ROTATE_CLOCKWISE:
			var duration := 0.0
			for cube: MoveableCube in cubes:
				duration = maxf(duration, cube.get_rotation_duration(pivot_global, rotation_degrees))
			for cube: MoveableCube in cubes:
				cube.rotate_clockwise_about(pivot_global, rotation_degrees, duration)
		_:
			for cube: MoveableCube in cubes:
				cube.move_top_left_to(cube.global_position + destination_offset)
	return true


func reset_platform() -> void:
	_is_activated = false
	for cube: MoveableCube in _resolve_targets():
		cube.reset_platform()


func is_activated() -> bool:
	return _is_activated


func _resolve_targets() -> Array[MoveableCube]:
	var result: Array[MoveableCube] = []
	for target_path: NodePath in targets:
		var cube := get_node_or_null(target_path) as MoveableCube
		if cube != null:
			result.append(cube)
	return result
