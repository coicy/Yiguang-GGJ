class_name MovementController
extends Node
## Owns physics movement and jump feel. Universal feel values are @export here;
## per-form stats (speed, jump, gravity, glide) come from the current FormDefinition.

@export_group("Movement")
@export var acceleration: float = 1200.0
@export var friction: float = 800.0

@export_group("Wind")
@export var max_wind_speed: float = 480.0

@export_group("Leg Extension")
@export var leg_step_height: float = 72.0
@export var leg_push_acceleration: float = 1800.0

@export_group("Jump & Gravity")
@export var gravity: float = 1200.0
@export var coyote_time: float = 0.10
@export var jump_buffer: float = 0.15
@export var jump_cut_multiplier: float = 0.5

@export_group("Vine")
@export var vine_tangent_acceleration: float = 900.0
@export var vine_max_speed: float = 700.0
@export_range(30.0, 89.0, 1.0) var vine_max_swing_angle_degrees: float = 80.0

var body: CharacterBody2D
var form: FormDefinition
var resources: ResourceController

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _rooted: bool = false
var _movement_locked: bool = false
var _leg_extended: bool = false
var _leg_push_direction := Vector2.ZERO
var _leg_push_target_speed: float = 0.0
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
	if _rooted or _movement_locked or is_vine_attached():
		_jump_buffer_timer = 0.0
		return
	_jump_buffer_timer = jump_buffer


func release_jump() -> void:
	if body == null or form == null:
		return
	if is_vine_attached():
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

	var vine_attached := is_vine_attached()
	if vine_attached or not body.is_on_floor():
		body.velocity.y += gravity * form.gravity_scale * delta
		body.velocity.y = minf(body.velocity.y, form.max_fall_speed)

	if not vine_attached and jump_held and form.can_glide and body.velocity.y > 0.0:
		body.velocity.y = minf(body.velocity.y, form.glide_fall_speed)

	if not vine_attached and not _rooted and not _movement_locked and _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_perform_jump()

	var speed_scale := resources.speed_multiplier() if resources != null else 1.0
	if _rooted:
		body.velocity.x = 0.0
		_apply_leg_push(delta)
	elif vine_attached:
		_apply_vine_motion(move_dir, delta)
	elif not _movement_locked and move_dir != 0.0:
		body.velocity.x = move_toward(body.velocity.x, move_dir * form.move_speed * speed_scale, acceleration * delta)
	else:
		body.velocity.x = move_toward(body.velocity.x, 0.0, friction * delta)
	_try_leg_step(delta)

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
		body.velocity = Vector2.ZERO
		_jump_buffer_timer = 0.0


func set_movement_locked(locked: bool) -> void:
	_movement_locked = locked
	if locked:
		if body != null:
			body.velocity.x = 0.0
		_jump_buffer_timer = 0.0


func set_leg_extended(extended: bool) -> void:
	_leg_extended = extended


func set_leg_push(direction: Vector2, speed: float) -> void:
	_leg_push_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.ZERO
	_leg_push_target_speed = maxf(speed, 0.0)


func _apply_leg_push(delta: float) -> void:
	if _leg_push_direction.is_zero_approx() or _leg_push_target_speed <= 0.0:
		return
	var target_velocity := _leg_push_direction * _leg_push_target_speed
	body.velocity = body.velocity.move_toward(target_velocity, leg_push_acceleration * delta)


func apply_wind(force: float, delta: float) -> void:
	if body == null or _rooted:
		return
	var resistance := 1.0
	if form != null and form.can_glide and Input.is_action_pressed(&"jump") and body.velocity.y > 0.0:
		# Mature leaves resist part of the wind only while the player is gliding.
		resistance = 0.4
	var wind_target_speed := signf(force) * max_wind_speed * resistance
	body.velocity.x = move_toward(body.velocity.x, wind_target_speed, absf(force) * resistance * delta)


func attach_vine(anchor: Node2D, length: float) -> void:
	_vine_anchor = anchor
	_vine_length = maxf(1.0, length)
	_jump_buffer_timer = 0.0


func detach_vine() -> void:
	_vine_anchor = null
	_vine_length = 0.0


func is_vine_attached() -> bool:
	return _vine_anchor != null and is_instance_valid(_vine_anchor)


func _try_leg_step(delta: float) -> void:
	if not _leg_extended or not body.is_on_floor() or is_zero_approx(body.velocity.x):
		return
	var horizontal_motion := Vector2(body.velocity.x * delta, 0.0)
	if not body.test_move(body.global_transform, horizontal_motion):
		return

	var upward_motion := Vector2(0.0, -leg_step_height)
	if body.test_move(body.global_transform, upward_motion):
		return
	var raised_transform := body.global_transform
	raised_transform.origin += upward_motion
	if body.test_move(raised_transform, horizontal_motion):
		return

	var landing_transform := raised_transform
	landing_transform.origin += horizontal_motion
	var landing_collision := KinematicCollision2D.new()
	if not body.test_move(
		landing_transform,
		Vector2(0.0, leg_step_height + body.floor_snap_length),
		landing_collision
	):
		return
	if landing_collision.get_normal().dot(Vector2.UP) < 0.7:
		return
	var vertical_step := -leg_step_height + landing_collision.get_travel().y
	if vertical_step >= -1.0:
		return
	body.move_and_collide(Vector2(0.0, vertical_step))


func _apply_vine_motion(move_dir: float, delta: float) -> void:
	if not is_vine_attached():
		return
	var radial := body.global_position - _vine_anchor.global_position
	if radial.is_zero_approx():
		return
	var radial_normal := radial.normalized()
	# A taut vine only permits velocity along its tangent. Gravity has already
	# been applied above, so projecting here produces a real pendulum force.
	body.velocity -= radial_normal * body.velocity.dot(radial_normal)
	var tangent := Vector2(-radial_normal.y, radial_normal.x)
	if tangent.x < 0.0:
		tangent = -tangent
	body.velocity += tangent * move_dir * vine_tangent_acceleration * delta
	var tangent_speed := clampf(body.velocity.dot(tangent), -vine_max_speed, vine_max_speed)
	var swing_angle := atan2(radial.x, radial.y)
	tangent_speed = _stop_vine_at_angle_limit(tangent_speed, swing_angle)
	body.velocity = tangent * tangent_speed


func _enforce_vine_length() -> void:
	if not is_vine_attached():
		return
	var radial := body.global_position - _vine_anchor.global_position
	if radial.is_zero_approx():
		return
	var max_angle := deg_to_rad(vine_max_swing_angle_degrees)
	var swing_angle := atan2(radial.x, radial.y)
	var limited_angle := clampf(swing_angle, -max_angle, max_angle)
	var limited_radial := Vector2(sin(limited_angle), cos(limited_angle)) * _vine_length
	var correction := limited_radial - radial
	if not correction.is_zero_approx():
		# Enforce rope length and both high points without teleporting through walls.
		body.move_and_collide(correction)
		radial = body.global_position - _vine_anchor.global_position
		if radial.is_zero_approx():
			return
	var radial_normal := radial.normalized()
	var tangent := Vector2(-radial_normal.y, radial_normal.x)
	if tangent.x < 0.0:
		tangent = -tangent
	swing_angle = atan2(radial.x, radial.y)
	var tangent_speed := _stop_vine_at_angle_limit(body.velocity.dot(tangent), swing_angle)
	body.velocity = tangent * tangent_speed


func _stop_vine_at_angle_limit(tangent_speed: float, swing_angle: float) -> float:
	var max_angle := deg_to_rad(vine_max_swing_angle_degrees)
	if swing_angle >= max_angle and tangent_speed > 0.0:
		return 0.0
	if swing_angle <= -max_angle and tangent_speed < 0.0:
		return 0.0
	return tangent_speed


func is_on_floor() -> bool:
	return body != null and body.is_on_floor()


func velocity() -> Vector2:
	return body.velocity if body != null else Vector2.ZERO


func coyote_remaining() -> float:
	return maxf(_coyote_timer, 0.0)


func jump_buffer_remaining() -> float:
	return maxf(_jump_buffer_timer, 0.0)
