@tool
class_name MoveableCube
extends AnimatableBody2D
## A physics-synchronised whitebox block that moves to a data-defined footprint.

signal motion_started(cube: MoveableCube)
signal motion_completed(cube: MoveableCube)

@export var cube_size: Vector2 = Vector2(16.0, 16.0):
	set(value):
		cube_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_update_shape()
		_update_bottom_attachments()
		queue_redraw()

@export_range(1.0, 720.0, 1.0) var motion_speed: float = 160.0
@export_range(0.0, 0.5, 0.01) var startup_shake_duration: float = 0.14
@export_range(0.0, 8.0, 0.25) var startup_shake_distance: float = 2.0

@export_category("Artwork")
@export var art_texture: Texture2D:
	set(value):
		art_texture = value
		_sync_artwork()
@export_range(0.01, 8.0, 0.01) var art_scale_multiplier: float = 1.0:
	set(value):
		art_scale_multiplier = maxf(value, 0.01)
		_sync_artwork()
@export var art_offset := Vector2.ZERO:
	set(value):
		art_offset = value
		_sync_artwork()
@export_range(-360.0, 360.0, 1.0) var art_rotation_degrees: float = 0.0:
	set(value):
		art_rotation_degrees = value
		_sync_artwork()

enum MotionPhase { IDLE, STARTUP_SHAKE, MOVING }

var _start_transform := Transform2D.IDENTITY
var _target_transform := Transform2D.IDENTITY
var _start_size := Vector2.ONE
var _target_size := Vector2.ONE
var _motion_duration := 0.0
var _motion_elapsed := 0.0
var _startup_elapsed := 0.0
var _motion_phase := MotionPhase.IDLE
var _visual_offset := Vector2.ZERO
var _initial_transform := Transform2D.IDENTITY
var _initial_size := Vector2.ONE
var _bottom_attachments: Dictionary = {}

@onready var _collision_shape: CollisionShape2D = %CollisionShape2D
@onready var _artwork: Sprite2D = %Artwork


func _ready() -> void:
	sync_to_physics = true
	_make_collision_shape_unique()
	_update_shape()
	_initial_transform = global_transform
	_initial_size = cube_size
	_sync_artwork()
	queue_redraw()


func _physics_process(delta: float) -> void:
	match _motion_phase:
		MotionPhase.IDLE:
			return
		MotionPhase.STARTUP_SHAKE:
			_update_startup_shake(delta)
		MotionPhase.MOVING:
			_update_motion(delta)


func bind_bottom_attachment(attachment: Node2D) -> void:
	attachment.reparent(self, true)
	_bottom_attachments[attachment] = attachment.position - Vector2(0.0, cube_size.y)


func _update_bottom_attachments() -> void:
	for attachment: Node2D in _bottom_attachments:
		if is_instance_valid(attachment):
			attachment.position = (_bottom_attachments[attachment] as Vector2) + Vector2(0.0, cube_size.y)


func get_rect_motion_duration(target_rect: Rect2) -> float:
	return _estimate_motion_duration(_rect_target_transform(target_rect))


func _rect_target_transform(target_rect: Rect2) -> Transform2D:
	if cube_size.is_equal_approx(Vector2(target_rect.size.y, target_rect.size.x)) and not cube_size.is_equal_approx(target_rect.size):
		return Transform2D(PI * 0.5, target_rect.position + Vector2(target_rect.size.x, 0.0))
	return Transform2D(0.0, target_rect.position)


func move_to_rect(target_rect: Rect2, duration_override: float = -1.0) -> bool:
	var target_size := target_rect.size
	var rotation := 0.0
	var target_origin := target_rect.position
	if cube_size.is_equal_approx(Vector2(target_size.y, target_size.x)) and not cube_size.is_equal_approx(target_size):
		rotation = PI * 0.5
		target_size = cube_size
		# A +90 degree local rotation places the local origin on the target's top-right.
		target_origin += Vector2(target_rect.size.x, 0.0)
	var target := Transform2D(rotation, target_origin)
	var started := _begin_motion(target, target_size)
	if started and duration_override > 0.0:
		_motion_duration = maxf(_motion_duration, duration_override)
	return started


func move_top_left_to(target_position: Vector2) -> bool:
	var target := global_transform
	target.origin = target_position
	return _begin_motion(target, cube_size)


func get_rotation_duration(pivot: Vector2, degrees: float = 90.0) -> float:
	return _estimate_motion_duration(_rotation_target(pivot, degrees))


func rotate_clockwise_about(pivot: Vector2, degrees: float = 90.0, duration_override: float = -1.0) -> bool:
	var target := _rotation_target(pivot, degrees)
	var started := _begin_motion(target, cube_size)
	if started and duration_override > 0.0:
		_motion_duration = duration_override
	return started


func stop_at_target() -> void:
	if not is_moving():
		return
	global_transform = _target_transform
	cube_size = _target_size
	_visual_offset = Vector2.ZERO
	_motion_phase = MotionPhase.IDLE
	motion_completed.emit(self)


func reset_platform() -> void:
	_motion_phase = MotionPhase.IDLE
	_visual_offset = Vector2.ZERO
	global_transform = _initial_transform
	cube_size = _initial_size
	_sync_artwork()
	queue_redraw()


func get_world_rect() -> Rect2:
	var corners := PackedVector2Array([
		to_global(Vector2.ZERO),
		to_global(Vector2(cube_size.x, 0.0)),
		to_global(cube_size),
		to_global(Vector2(0.0, cube_size.y)),
	])
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for index: int in range(1, corners.size()):
		bounds = bounds.expand(corners[index])
	return bounds


func is_moving() -> bool:
	return _motion_phase != MotionPhase.IDLE


func _begin_motion(target: Transform2D, target_size: Vector2) -> bool:
	if is_moving() or (global_transform.is_equal_approx(target) and cube_size.is_equal_approx(target_size)):
		return false
	_start_transform = global_transform
	_target_transform = target
	_start_size = cube_size
	_target_size = target_size
	_motion_elapsed = 0.0
	_startup_elapsed = 0.0
	_motion_duration = maxf(_estimate_motion_duration(target), 0.01)
	_motion_phase = MotionPhase.STARTUP_SHAKE if startup_shake_duration > 0.0 else MotionPhase.MOVING
	motion_started.emit(self)
	queue_redraw()
	return true


func _update_startup_shake(delta: float) -> void:
	_startup_elapsed = minf(_startup_elapsed + delta, startup_shake_duration)
	var progress := _startup_elapsed / startup_shake_duration
	var envelope := 1.0 - progress
	_visual_offset = Vector2(sin(progress * TAU * 3.0) * startup_shake_distance * envelope, 0.0)
	queue_redraw()
	if progress >= 1.0:
		_visual_offset = Vector2.ZERO
		_motion_phase = MotionPhase.MOVING


func _update_motion(delta: float) -> void:
	_motion_elapsed = minf(_motion_elapsed + delta, _motion_duration)
	var progress := _motion_elapsed / _motion_duration
	var eased_progress := _smooth_step(progress)
	var next_transform := _start_transform.interpolate_with(_target_transform, eased_progress)
	var angle := angle_difference(_start_transform.get_rotation(), _target_transform.get_rotation())
	if not is_zero_approx(angle):
		var pivot := _motion_pivot(_start_transform.origin, _target_transform.origin, angle)
		next_transform.origin = pivot + (_start_transform.origin - pivot).rotated(angle * eased_progress)
	global_transform = next_transform
	cube_size = _start_size.lerp(_target_size, eased_progress)
	if progress >= 1.0:
		global_transform = _target_transform
		cube_size = _target_size
		_motion_phase = MotionPhase.IDLE
		motion_completed.emit(self)


func _estimate_motion_duration(target: Transform2D) -> float:
	var angle := angle_difference(global_rotation, target.get_rotation())
	var distance := global_position.distance_to(target.origin)
	if not is_zero_approx(angle):
		var pivot := _motion_pivot(global_position, target.origin, angle)
		distance = global_position.distance_to(pivot) * absf(angle)
	return maxf(distance / motion_speed, absf(angle) / deg_to_rad(motion_speed))


func _motion_pivot(start: Vector2, finish: Vector2, angle: float) -> Vector2:
	var chord := finish - start
	return (start + finish) * 0.5 + Vector2(-chord.y, chord.x) / (2.0 * tan(angle * 0.5))


func _rotation_target(pivot: Vector2, degrees: float) -> Transform2D:
	var angle := deg_to_rad(degrees)
	var target := global_transform.rotated_local(angle)
	target.origin = pivot + (global_position - pivot).rotated(angle)
	return target


func _smooth_step(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


func _update_shape() -> void:
	if not is_instance_valid(_collision_shape):
		return
	var shape := _collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		_collision_shape.shape = shape
	shape.size = cube_size
	_collision_shape.position = cube_size * 0.5
	_sync_artwork()


func _sync_artwork() -> void:
	if not is_instance_valid(_artwork):
		return
	_artwork.texture = art_texture
	_artwork.centered = false
	_artwork.position = art_offset + _visual_offset
	_artwork.scale = Vector2.ONE * art_scale_multiplier
	_artwork.rotation = deg_to_rad(art_rotation_degrees)
	_artwork.visible = art_texture != null


func _make_collision_shape_unique() -> void:
	if is_instance_valid(_collision_shape) and _collision_shape.shape != null:
		_collision_shape.shape = _collision_shape.shape.duplicate(true)


func _draw() -> void:
	if art_texture != null:
		return
	draw_set_transform(_visual_offset)
	draw_rect(Rect2(Vector2.ZERO, cube_size), Color("#567f64"))
	draw_rect(Rect2(Vector2.ZERO, cube_size), Color("#d5f0cf"), false, 2.0)
	draw_set_transform(Vector2.ZERO)
