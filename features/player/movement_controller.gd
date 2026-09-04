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

var body: CharacterBody2D
var form: FormDefinition

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0


func setup(p_body: CharacterBody2D, p_form: FormDefinition) -> void:
	body = p_body
	form = p_form


func set_form(p_form: FormDefinition) -> void:
	form = p_form


func request_jump() -> void:
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

	if jump_held and form.glide_enabled and body.velocity.y > 0.0:
		body.velocity.y = minf(body.velocity.y, form.glide_fall_speed)

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_perform_jump()

	if move_dir != 0.0:
		body.velocity.x = move_toward(body.velocity.x, move_dir * form.move_speed, acceleration * delta)
	else:
		body.velocity.x = move_toward(body.velocity.x, 0.0, friction * delta)

	body.move_and_slide()

	if body.is_on_ceiling() and body.velocity.y < 0.0:
		body.velocity.y = 0.0

	if body.is_on_floor():
		body.velocity.y = 0.0


func _perform_jump() -> void:
	body.velocity.y = form.jump_force
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0


func is_on_floor() -> bool:
	return body != null and body.is_on_floor()


func velocity() -> Vector2:
	return body.velocity if body != null else Vector2.ZERO


func coyote_remaining() -> float:
	return maxf(_coyote_timer, 0.0)


func jump_buffer_remaining() -> float:
	return maxf(_jump_buffer_timer, 0.0)
