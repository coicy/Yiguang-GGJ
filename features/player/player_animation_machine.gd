class_name PlayerAnimationMachine
extends Node
## Presentation-only state machine that maps player logic to Spine clips.

const STATE_IDLE: StringName = &"idle"
const STATE_MOVE: StringName = &"move"
const STATE_JUMP_START: StringName = &"jump_start"
const STATE_JUMP_UP: StringName = &"jump_up"
const STATE_JUMP_DOWN: StringName = &"jump_down"
const STATE_JUMP_END: StringName = &"jump_end"
const STATE_SKILL: StringName = &"skill"
const STATE_DEATH: StringName = &"death"

signal animation_state_changed(previous: StringName, current: StringName)

var _visual: SpineCharacterVisual
var _locomotion_state: StringName = StateMachine.STATE_IDLE
var _animation_state: StringName = &""
var _return_state: StringName = STATE_IDLE
var _facing: float = 1.0
var _skill_playing: bool = false
var _dead: bool = false


func set_visual(visual: SpineCharacterVisual) -> void:
	if _visual != null and _visual.animation_completed.is_connected(_on_animation_completed):
		_visual.animation_completed.disconnect(_on_animation_completed)
	_visual = visual
	_animation_state = &""
	_skill_playing = false
	if _visual == null:
		return
	_visual.animation_completed.connect(_on_animation_completed)
	_visual.set_facing(_facing)
	if _dead:
		_play_with_fallback(STATE_DEATH, false, true)
	else:
		_sync_locomotion(true)


func set_locomotion_state(state: StringName) -> void:
	if state == _locomotion_state:
		return
	var previous := _locomotion_state
	_locomotion_state = state
	_return_state = _animation_for_locomotion(state)
	if _visual == null or _dead or _skill_playing:
		return
	if state == StateMachine.STATE_JUMP and not _is_airborne(previous):
		_play_with_fallback(STATE_JUMP_START, false)
		return
	if _is_grounded(state) and _is_airborne(previous):
		_play_with_fallback(STATE_JUMP_END, false)
		return
	_sync_locomotion()


func play_skill() -> bool:
	if _visual == null or _dead or _skill_playing or not _visual.has_animation(STATE_SKILL):
		return false
	_return_state = _animation_for_locomotion(_locomotion_state)
	_skill_playing = _play(STATE_SKILL, false)
	return _skill_playing


func play_death() -> bool:
	if _visual == null or _dead:
		return false
	_dead = true
	_skill_playing = false
	return _play_with_fallback(STATE_DEATH, false)


func revive() -> void:
	if not _dead:
		return
	_dead = false
	_sync_locomotion(true)


func set_facing(direction: float) -> void:
	if is_zero_approx(direction):
		return
	_facing = signf(direction)
	if _visual != null:
		_visual.set_facing(_facing)


func current_animation_state() -> StringName:
	return _animation_state


func is_dead() -> bool:
	return _dead


func _sync_locomotion(force: bool = false) -> void:
	var target := _animation_for_locomotion(_locomotion_state)
	_play_with_fallback(target, true, force)


func _animation_for_locomotion(state: StringName) -> StringName:
	match state:
		StateMachine.STATE_RUN:
			return STATE_MOVE
		StateMachine.STATE_JUMP:
			return STATE_JUMP_UP
		StateMachine.STATE_FALL, StateMachine.STATE_GLIDE:
			return STATE_JUMP_DOWN
		_:
			return STATE_IDLE


func _play_with_fallback(preferred: StringName, loop: bool, force: bool = false) -> bool:
	if _visual == null:
		return false
	var resolved := preferred
	if not _visual.has_animation(resolved):
		resolved = STATE_MOVE if _locomotion_state == StateMachine.STATE_RUN else STATE_IDLE
	if not _visual.has_animation(resolved):
		resolved = _visual.default_animation
	return _play(resolved, loop and _visual.looping_animations.has(resolved), force)


func _play(animation_name: StringName, loop: bool, force: bool = false) -> bool:
	if _visual == null or (not force and animation_name == _animation_state):
		return false
	if not _visual.play_animation(animation_name, loop):
		return false
	var previous := _animation_state
	_animation_state = animation_name
	animation_state_changed.emit(previous, _animation_state)
	return true


func _on_animation_completed(animation_name: StringName) -> void:
	if animation_name != _animation_state or _dead:
		return
	if animation_name == STATE_SKILL and _skill_playing:
		_skill_playing = false
		_play_with_fallback(_return_state, true)
	elif animation_name == STATE_JUMP_START:
		_sync_locomotion()
	elif animation_name == STATE_JUMP_END:
		_sync_locomotion()


func _is_airborne(state: StringName) -> bool:
	return state in [StateMachine.STATE_JUMP, StateMachine.STATE_FALL, StateMachine.STATE_GLIDE]


func _is_grounded(state: StringName) -> bool:
	return state == StateMachine.STATE_IDLE or state == StateMachine.STATE_RUN
