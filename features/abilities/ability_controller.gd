class_name AbilityController
extends Node
## Owns mutually-exclusive held ability state. Vine behavior is added separately.

signal ability_state_changed(label: StringName)
signal feedback_requested(message: String)

var _player: Player
var _movement: MovementController
var _forms: FormController
var _leg_area: Area2D
var _rooted: bool = false
var _leg_extended: bool = false
var _primary_pressed: bool = false
var _secondary_pressed: bool = false


func setup(
	player: Player,
	movement: MovementController,
	forms: FormController,
	leg_area: Area2D
) -> void:
	_player = player
	_movement = movement
	_forms = forms
	_leg_area = leg_area
	_leg_area.monitoring = false


func tick() -> void:
	if (_rooted or _leg_extended) and (_player == null or not _player.is_on_floor()):
		cancel_all()


func set_primary_pressed(pressed: bool) -> void:
	if pressed and not _primary_pressed:
		try_root()
	elif not pressed and _primary_pressed:
		stop_primary()
	_primary_pressed = pressed


func set_secondary_pressed(pressed: bool) -> void:
	if pressed and not _secondary_pressed:
		try_extend_legs()
	elif not pressed and _secondary_pressed:
		stop_secondary()
	_secondary_pressed = pressed


func try_root() -> bool:
	if _forms == null or _movement == null or _player == null:
		return false
	var form := _forms.get_current()
	if form == null or not form.can_root or not _player.is_on_floor() or _leg_extended:
		feedback_requested.emit("人形体在地面上才能扎根")
		return false
	_rooted = true
	_movement.set_rooted(true)
	ability_state_changed.emit(&"rooted")
	return true


func try_extend_legs() -> bool:
	if _forms == null or _movement == null or _player == null:
		return false
	var form := _forms.get_current()
	if form == null or not form.can_extend_legs or not _player.is_on_floor() or _rooted:
		feedback_requested.emit("人形体在地面上才能伸腿")
		return false
	_leg_extended = true
	_leg_area.set_deferred("monitoring", true)
	_movement.set_movement_locked(true)
	ability_state_changed.emit(&"legs")
	return true


func stop_primary() -> void:
	if not _rooted:
		return
	_rooted = false
	_movement.set_rooted(false)
	ability_state_changed.emit(&"none")


func stop_secondary() -> void:
	if not _leg_extended:
		return
	_leg_extended = false
	_leg_area.set_deferred("monitoring", false)
	_movement.set_movement_locked(false)
	ability_state_changed.emit(&"none")


func cancel_all() -> void:
	stop_primary()
	stop_secondary()
	_primary_pressed = false
	_secondary_pressed = false


func is_rooted() -> bool:
	return _rooted


func is_leg_extended() -> bool:
	return _leg_extended


func is_vine_attached() -> bool:
	return false
