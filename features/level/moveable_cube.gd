class_name MoveableCube
extends AnimatableBody2D
## A solid whitebox block whose visual and collision share one physics-synchronised transform.

signal motion_started(cube: MoveableCube)
signal motion_completed(cube: MoveableCube)

@export var cube_size: Vector2 = Vector2(16.0, 16.0):
	set(value):
		cube_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_update_shape()

@export_range(1.0, 720.0, 1.0) var motion_speed: float = 160.0

var _start_transform := Transform2D.IDENTITY
var _target_transform := Transform2D.IDENTITY
var _motion_duration: float = 0.0
var _motion_elapsed: float = 0.0
var _is_moving: bool = false
var _is_rotation_motion: bool = false
var _rotation_pivot := Vector2.ZERO
var _rotation_angle: float = 0.0

@onready var _collision_shape: CollisionShape2D = %CollisionShape2D


func _ready() -> void:
	sync_to_physics = true
	_make_collision_shape_unique()
	_update_shape()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _is_moving:
		return
	_motion_elapsed = minf(_motion_elapsed + delta, _motion_duration)
	var progress := _motion_elapsed / _motion_duration if _motion_duration > 0.0 else 1.0
	if _is_rotation_motion:
		var current_angle := _rotation_angle * progress
		global_transform = _start_transform.rotated_local(current_angle)
		global_transform.origin = _rotation_pivot + (_start_transform.origin - _rotation_pivot).rotated(current_angle)
	else:
		global_transform = _start_transform.interpolate_with(_target_transform, progress)
	if progress >= 1.0:
		global_transform = _target_transform
		_is_moving = false
		_is_rotation_motion = false
		motion_completed.emit(self)


func move_top_left_to(target_position: Vector2) -> bool:
	var target := global_transform
	target.origin = target_position
	return _begin_motion(target)


func get_rotation_duration(pivot: Vector2, degrees: float = 90.0) -> float:
	return _estimate_motion_duration(_rotation_target(pivot, degrees))


func rotate_clockwise_about(
	pivot: Vector2,
	degrees: float = 90.0,
	duration_override: float = -1.0
) -> bool:
	var started := _begin_motion(_rotation_target(pivot, degrees), duration_override)
	if started:
		_is_rotation_motion = true
		_rotation_pivot = pivot
		_rotation_angle = deg_to_rad(degrees)
	return started


func stop_at_target() -> void:
	if not _is_moving:
		return
	global_transform = _target_transform
	_is_moving = false
	_is_rotation_motion = false
	motion_completed.emit(self)


func is_moving() -> bool:
	return _is_moving


func _begin_motion(target: Transform2D, duration_override: float = -1.0) -> bool:
	if _is_moving or global_transform.is_equal_approx(target):
		return false
	_start_transform = global_transform
	_target_transform = target
	_motion_elapsed = 0.0
	_is_rotation_motion = false
	_motion_duration = duration_override if duration_override > 0.0 else _estimate_motion_duration(target)
	_motion_duration = maxf(_motion_duration, 0.01)
	_is_moving = true
	motion_started.emit(self)
	return true


func _rotation_target(pivot: Vector2, degrees: float) -> Transform2D:
	var angle := deg_to_rad(degrees)
	var target := global_transform.rotated_local(angle)
	target.origin = pivot + (global_position - pivot).rotated(angle)
	return target


func _estimate_motion_duration(target: Transform2D) -> float:
	return maxf(
		global_position.distance_to(target.origin) / motion_speed,
		absf(global_rotation - target.get_rotation()) / deg_to_rad(motion_speed)
	)


func _update_shape() -> void:
	if not is_instance_valid(_collision_shape):
		return
	var shape := _collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		_collision_shape.shape = shape
	shape.size = cube_size
	_collision_shape.position = cube_size * 0.5


func _make_collision_shape_unique() -> void:
	if is_instance_valid(_collision_shape) and _collision_shape.shape != null:
		_collision_shape.shape = _collision_shape.shape.duplicate(true)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, cube_size), Color("#567f64"))
	draw_rect(Rect2(Vector2.ZERO, cube_size), Color("#d5f0cf"), false, 2.0)
