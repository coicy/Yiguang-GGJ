class_name MovementController
extends Node
## Owns physics movement and jump feel. Universal feel values are @export here;
## per-form stats (speed, jump, gravity, glide) come from the current FormDefinition.

@export_group("Movement")
@export var acceleration: float = 1200.0
@export var friction: float = 800.0

@export_group("Jump & Gravity")
@export var gravity: float = 1200.0
@export var coyote_time: float = 0.10
@export var jump_buffer: float = 0.15
@export var jump_cut_multiplier: float = 0.5

@export_group("Vine")
@export var vine_tangent_acceleration: float = 900.0

var body: CharacterBody2D
var form: FormDefinition
var resources: ResourceController

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _rooted: bool = false
var _movement_locked: bool = false
var _vine_anchor: Node2D
var _vine_length: float = 0.0


func setup(
	p_body: CharacterBody2D,
	p_form: FormDefinition,
	p_resources: ResourceController = null
) -> void:
	body = p_body
	form = p_form
	resources = p_resources


func set_form(p_form: FormDefinition) -> void:
	form = p_form


func request_jump() -> void:
	if _rooted or _movement_locked:
		return
	_jump_buffer_timer = jump_buffer


func release_jump() -> void:
	if body == null or form == null:
		return
	if body.velocity.y < 0.0:
		body.velocity.y *= jump_cut_multiplier


func tick(delta: float, move_dir: float, jump_held: bool) -> void:
	if body == null or form == null:
		return

	_coyote_timer -= delta
	_jump_buffer_timer -= delta

	if body.is_on_floor():
		_coyote_timer = coyote_time

	if not body.is_on_floor():
		body.velocity.y += gravity * form.gravity_scale * delta
		body.velocity.y = minf(body.velocity.y, form.max_fall_speed)

	if jump_held and form.can_glide and body.velocity.y > 0.0:
		body.velocity.y = minf(body.velocity.y, form.glide_fall_speed)

	if not _rooted and not _movement_locked and _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_perform_jump()

	var speed_scale := resources.speed_multiplier() if resources != null else 1.0
	if _rooted:
		body.velocity.x = 0.0
	elif not _movement_locked and move_dir != 0.0:
		body.velocity.x = move_toward(body.velocity.x, move_dir * form.move_speed * speed_scale, acceleration * delta)
	else:
		body.velocity.x = move_toward(body.velocity.x, 0.0, friction * delta)
	_apply_vine_motion(move_dir, delta)

	body.move_and_slide()
	_enforce_vine_length()

	if body.is_on_ceiling() and body.velocity.y < 0.0:
		body.velocity.y = 0.0

	if body.is_on_floor():
		body.velocity.y = 0.0


func _perform_jump() -> void:
	body.velocity.y = form.jump_force
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0


func set_rooted(rooted: bool) -> void:
	_rooted = rooted
	if rooted:
		body.velocity.x = 0.0
		_jump_buffer_timer = 0.0


func set_movement_locked(locked: bool) -> void:
	_movement_locked = locked
	if locked:
		_jump_buffer_timer = 0.0


func apply_wind(force: float, delta: float) -> void:
	if body == null or _rooted:
		return
	body.velocity.x += force * delta


func attach_vine(anchor: Node2D, length: float) -> void:
	_vine_anchor = anchor
	_vine_length = maxf(1.0, length)


func detach_vine() -> void:
	_vine_anchor = null
	_vine_length = 0.0


func is_vine_attached() -> bool:
	return _vine_anchor != null and is_instance_valid(_vine_anchor)


func _apply_vine_motion(move_dir: float, delta: float) -> void:
	if not is_vine_attached():
		return
	var radial := body.global_position - _vine_anchor.global_position
	if radial.is_zero_approx():
		return
	var radial_normal := radial.normalized()
	var outward_speed := body.velocity.dot(radial_normal)
	if outward_speed > 0.0:
		body.velocity -= radial_normal * outward_speed
	var tangent := Vector2(-radial_normal.y, radial_normal.x)
	body.velocity += tangent * move_dir * vine_tangent_acceleration * delta


func _enforce_vine_length() -> void:
	if not is_vine_attached():
		return
	var radial := body.global_position - _vine_anchor.global_position
	if radial.length() <= _vine_length or radial.is_zero_approx():
		return
	var radial_normal := radial.normalized()
	body.global_position = _vine_anchor.global_position + radial_normal * _vine_length
	var outward_speed := body.velocity.dot(radial_normal)
	if outward_speed > 0.0:
		body.velocity -= radial_normal * outward_speed


func is_on_floor() -> bool:
	return body != null and body.is_on_floor()


func velocity() -> Vector2:
	return body.velocity if body != null else Vector2.ZERO


func coyote_remaining() -> float:
	return maxf(_coyote_timer, 0.0)


func jump_buffer_remaining() -> float:
	return maxf(_jump_buffer_timer, 0.0)
