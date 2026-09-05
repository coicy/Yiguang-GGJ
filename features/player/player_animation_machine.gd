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

@export_range(0.0, 100.0, 1.0) var combat_step_stop_speed: float = 32.0
@export_range(0.0, 0.2, 0.01) var locomotion_mix_duration: float = 0.06

var _visual: SpineCharacterVisual
var _locomotion_state: StringName = StateMachine.STATE_IDLE
var _animation_state: StringName = &""
var _return_state: StringName = STATE_IDLE
var _facing: float = 1.0
var _skill_playing: bool = false
var _dead: bool = false
var _ground_attack: bool = false
var _landing_recovery: bool = false
var _combat_horizontal_speed: float = 0.0


func set_visual(visual: SpineCharacterVisual) -> void:
	if _visual != null and _visual.animation_completed.is_connected(_on_animation_completed):
		_visual.animation_completed.disconnect(_on_animation_completed)
	_visual = visual
	_animation_state = &""
	_skill_playing = false
	if _visual == null:
		_ground_attack = false
		_landing_recovery = false
		_combat_horizontal_speed = 0.0
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
	if _landing_recovery and _is_grounded(state):
		return
	if _ground_attack and _is_grounded(state):
		_sync_locomotion()
		return
	if state == StateMachine.STATE_JUMP and not _is_airborne(previous):
		_play_with_fallback(STATE_JUMP_START, false)
		return
	if _is_grounded(state) and _is_airborne(previous):
		_play_with_fallback(STATE_JUMP_END, false)
		return
	_sync_locomotion()


func begin_combat() -> void:
	# Keep ongoing walk/up/down tracks; airborne attacks skip a remaining takeoff clip.
	var leave_takeoff := _animation_state == STATE_JUMP_START and _is_airborne(_locomotion_state)
	if not _skill_playing and not leave_takeoff:
		return
	_skill_playing = false
	if _visual != null and not _dead:
		_sync_locomotion()


func set_combat_context(ground_attack: bool, landing_recovery: bool, horizontal_speed: float = 0.0) -> void:
	var context_changed := ground_attack != _ground_attack or landing_recovery != _landing_recovery
	var landing_started := landing_recovery and not _landing_recovery
	_ground_attack = ground_attack
	_landing_recovery = landing_recovery
	_combat_horizontal_speed = absf(horizontal_speed)
	if _visual == null or _dead:
		return
	if landing_recovery:
		_skill_playing = false
		if landing_started:
			_play_with_fallback(STATE_JUMP_END, false)
		return
	if ground_attack or context_changed:
		_sync_locomotion()


func play_skill(restart: bool = false) -> bool:
	if _visual == null or _dead or (_skill_playing and not restart) or not _visual.has_animation(STATE_SKILL):
		return false
	_return_state = _animation_for_locomotion(_locomotion_state)
	_skill_playing = _play(STATE_SKILL, false, restart)
	return _skill_playing


func play_death() -> bool:
	if _visual == null or _dead:
		return false
	_dead = true
	_skill_playing = false
	_ground_attack = false
	_landing_recovery = false
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
	if _landing_recovery and _is_grounded(_locomotion_state):
		_play_with_fallback(STATE_JUMP_END, false, force)
		return
	if _ground_attack and _is_grounded(_locomotion_state):
		# The final walking step follows physical braking, then the feet plant.
		target = STATE_MOVE if _combat_horizontal_speed > combat_step_stop_speed else STATE_IDLE
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
	if not previous.is_empty() and animation_name != STATE_DEATH:
		var track: Object = _visual.spine_sprite.get_animation_state().get_track(0)
		if track != null:
			track.set_mix_duration(locomotion_mix_duration)
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
