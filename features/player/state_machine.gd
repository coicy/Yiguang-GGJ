class_name StateMachine
extends Node
## Owns locomotion state transitions only. Movement math lives in MovementController.

const STATE_IDLE: StringName = &"idle"
const STATE_RUN: StringName = &"run"
const STATE_JUMP: StringName = &"jump"
const STATE_FALL: StringName = &"fall"
const STATE_GLIDE: StringName = &"glide"

signal state_changed(previous: StringName, current: StringName)

var current_state: StringName = STATE_IDLE

var _body: CharacterBody2D
var _movement: MovementController
var _form_controller: FormController


func setup(body: CharacterBody2D, movement: MovementController, form_controller: FormController) -> void:
	_body = body
	_movement = movement
	_form_controller = form_controller


func tick(delta: float, move_dir: float, jump_held: bool) -> void:
	if _movement == null:
		return
	_movement.tick(delta, move_dir, jump_held)
	var target := _evaluate_target(move_dir, jump_held)
	if target != current_state:
		var previous := current_state
		current_state = target
		state_changed.emit(previous, current_state)


func _evaluate_target(move_dir: float, jump_held: bool) -> StringName:
	if _body.is_on_floor():
		return STATE_RUN if move_dir != 0.0 else STATE_IDLE

	var form := _form_controller.get_current()
	if not _movement.is_vine_attached() and jump_held and form.can_glide and _body.velocity.y > 0.0:
		return STATE_GLIDE
	if _body.velocity.y < 0.0:
		return STATE_JUMP
	return STATE_FALL
