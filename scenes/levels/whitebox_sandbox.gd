class_name WhiteboxSandbox
extends Node2D
## Full whitebox vertical slice and lifecycle owner.

signal checkpoint_changed(checkpoint_id: StringName)
signal completion_changed(completed: bool, seconds: float)

@export var level_id: StringName = &"whitebox_sandbox"

var _checkpoint_position: Vector2
var _checkpoint_id: StringName = &"start"
var _initial_snapshot: Dictionary = {}
var _checkpoint_snapshot: Dictionary = {}
var _is_completed: bool = false
var _elapsed: float = 0.0

@onready var _player: Player = %Player
@onready var _player_anchor: Marker2D = %PlayerAnchor
@onready var _switch_a: WhiteboxSwitch = %SwitchA
@onready var _exit_device: ExitDevice = %ExitDevice
@onready var _start_checkpoint: Checkpoint = %StartCheckpoint
@onready var _mid_checkpoint: Checkpoint = %MidCheckpoint
@onready var _course_checkpoint: Checkpoint = %CourseCheckpoint
@onready var _fall_hazard: Hazard = %FallHazard
@onready var _wind_hazard: Hazard = %WindHazard
@onready var _death_plane: Hazard = %DeathPlane
@onready var _high_switch: AbilitySwitch = %HighSwitch
@onready var _final_switch: AbilitySwitch = %FinalLowSwitch
@onready var _high_gate: WhiteboxGate = %HighGate
@onready var _exit_goal: ExitGoal = %ExitGoal
@onready var _course_toxin: ToxinZone = get_node("Course/ToxinSection/ToxinZone") as ToxinZone
@onready var _hud: GameHud = %GameHud
@onready var _completion_overlay: CompletionOverlay = %CompletionOverlay
@onready var _camera: Camera2D = %Camera2D


func _ready() -> void:
	_checkpoint_position = _player.global_position
	_start_checkpoint.checkpoint_reached.connect(_on_legacy_checkpoint_reached)
	_mid_checkpoint.checkpoint_reached.connect(_on_legacy_checkpoint_reached)
	_course_checkpoint.actor_checkpoint_reached.connect(_on_actor_checkpoint_reached)
	_fall_hazard.actor_killed.connect(_on_actor_killed)
	_wind_hazard.actor_killed.connect(_on_actor_killed)
	_death_plane.actor_killed.connect(_on_actor_killed)
	_course_toxin.actor_entered.connect(_on_toxin_entered)
	_course_toxin.actor_exited.connect(_on_toxin_exited)

	_exit_device.set_required_switches(1)
	_exit_device.register_switch(_switch_a)
	_high_gate.bind_switch(_high_switch)
	_exit_goal.set_required_switches([_high_switch, _final_switch])
	_exit_goal.player_completed.connect(_on_exit_player_completed)
	_exit_goal.locked_entered.connect(_on_exit_locked)

	_initial_snapshot = _make_snapshot(&"start", _player.global_position)
	_checkpoint_snapshot = _initial_snapshot.duplicate(true)
	_player_anchor.global_position = _checkpoint_position
	_hud.bind_player(_player, self)


func _process(delta: float) -> void:
	if not _is_completed:
		_elapsed += delta
	_camera.global_position = _player.global_position + Vector2(220.0, -260.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart_level()


func get_player() -> Player:
	return _player


func get_checkpoint_position() -> Vector2:
	return _checkpoint_position


func checkpoint_form_id() -> StringName:
	if _checkpoint_snapshot.is_empty():
		return &"sprout"
	var player_state: Dictionary = _checkpoint_snapshot.get("player", {})
	return StringName(player_state.get("form", &"sprout"))


func elapsed_time() -> float:
	return _elapsed


func is_completed() -> bool:
	return _is_completed


func activate_checkpoint_for_test(checkpoint_id: StringName) -> void:
	var checkpoint_position := _course_checkpoint.get_checkpoint_position()
	_checkpoint_snapshot = _make_snapshot(checkpoint_id, checkpoint_position)
	_checkpoint_id = checkpoint_id
	_checkpoint_position = checkpoint_position
	_player_anchor.global_position = checkpoint_position
	checkpoint_changed.emit(checkpoint_id)


func respawn_player() -> void:
	if _checkpoint_snapshot.is_empty():
		return
	_restore_checkpoint_snapshot()


func restart_level() -> void:
	_is_completed = false
	_elapsed = 0.0
	_reset_all_interactions()
	_checkpoint_id = &"start"
	_checkpoint_snapshot = _initial_snapshot.duplicate(true)
	_checkpoint_position = _initial_snapshot.get("position", _player.global_position)
	_player_anchor.global_position = _checkpoint_position
	_completion_overlay.hide_completion()
	_restore_checkpoint_snapshot()
	completion_changed.emit(false, 0.0)
	checkpoint_changed.emit(_checkpoint_id)


func reset_level() -> void:
	# Compatibility with the original sandbox contract; gameplay deaths use respawn_player().
	_is_completed = false
	_switch_a.deactivate()
	_player_anchor.global_position = _checkpoint_position
	_completion_overlay.hide_completion()


func complete_level() -> void:
	if _is_completed or not _all_required_switches_active():
		return
	var global_signal_bus: Node = get_node_or_null("/root/GlobalSignalBus")
	if global_signal_bus == null or not global_signal_bus.has_signal(&"level_completed"):
		return
	_is_completed = true
	_player.cancel_actions()
	_completion_overlay.show_completion(_elapsed)
	completion_changed.emit(true, _elapsed)
	global_signal_bus.emit_signal(&"level_completed", level_id)


func _make_snapshot(checkpoint_id: StringName, position: Vector2) -> Dictionary:
	var player_state := _player.capture_state()
	player_state["position"] = position
	player_state["velocity"] = Vector2.ZERO
	return {
		"id": checkpoint_id,
		"position": position,
		"player": player_state,
		"switches": {
			"high": _high_switch.is_active(),
			"final": _final_switch.is_active(),
		},
	}


func _restore_checkpoint_snapshot() -> void:
	var player_state: Dictionary = _checkpoint_snapshot.get("player", {})
	var switch_state: Dictionary = _checkpoint_snapshot.get("switches", {})
	_high_switch.restore_active(bool(switch_state.get("high", false)))
	_final_switch.restore_active(bool(switch_state.get("final", false)))
	if _high_switch.is_active():
		_high_gate.open()
	else:
		_high_gate.close()
	_player.restore_state(player_state)


func _reset_all_interactions() -> void:
	_switch_a.deactivate()
	_high_switch.restore_active(false)
	_final_switch.restore_active(false)
	_high_gate.close()
	_exit_goal.reset_completion()
	_start_checkpoint.reset_activation()
	_mid_checkpoint.reset_activation()
	_course_checkpoint.reset_activation()


func _all_required_switches_active() -> bool:
	# The legacy invisible switch keeps the original sandbox API testable; players can
	# only finish through the two physical course switches.
	return _switch_a.is_active() or (_high_switch.is_active() and _final_switch.is_active())


func _on_actor_checkpoint_reached(actor: Node2D, position: Vector2) -> void:
	if actor != _player:
		return
	_checkpoint_id = &"mid"
	_checkpoint_position = position
	_checkpoint_snapshot = _make_snapshot(_checkpoint_id, position)
	_player_anchor.global_position = position
	checkpoint_changed.emit(_checkpoint_id)


func _on_legacy_checkpoint_reached(position: Vector2) -> void:
	_checkpoint_position = position
	_player_anchor.global_position = position


func _on_actor_killed(actor: Node2D) -> void:
	if actor == _player:
		respawn_player()


func _on_toxin_entered(actor: Node2D) -> void:
	if actor == _player:
		_player.enter_toxin(_course_toxin)


func _on_toxin_exited(actor: Node2D) -> void:
	if actor == _player:
		_player.exit_toxin(_course_toxin)


func _on_exit_player_completed(player: Player) -> void:
	if player == _player:
		complete_level()


func _on_exit_locked(_player_actor: Player) -> void:
	_hud.show_message("出口锁定：先完成伸腿开关和幼芽低位开关")
