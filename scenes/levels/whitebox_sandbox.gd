class_name WhiteboxSandbox
extends Node2D

@export var level_id: StringName = &"whitebox_sandbox"

var _checkpoint_position: Vector2
var _is_completed: bool = false

@onready var _player_anchor: Marker2D = %PlayerAnchor
@onready var _switch_a: WhiteboxSwitch = %SwitchA
@onready var _exit_device: ExitDevice = %ExitDevice
@onready var _start_checkpoint: Checkpoint = %StartCheckpoint
@onready var _fall_hazard: Hazard = %FallHazard


func _ready() -> void:
	_checkpoint_position = _start_checkpoint.get_checkpoint_position()
	_start_checkpoint.checkpoint_reached.connect(_on_checkpoint_reached)
	_fall_hazard.actor_killed.connect(_on_actor_killed)
	_exit_device.set_required_switches(1)
	_exit_device.register_switch(_switch_a)
	_player_anchor.global_position = _checkpoint_position


func reset_level() -> void:
	_is_completed = false
	_switch_a.deactivate()
	_player_anchor.global_position = _checkpoint_position


func complete_level() -> void:
	if _is_completed or not _exit_device.is_open():
		return

	var global_signal_bus: Node = get_node_or_null("/root/GlobalSignalBus")
	if global_signal_bus == null or not global_signal_bus.has_signal(&"level_completed"):
		return

	_is_completed = true
	global_signal_bus.emit_signal(&"level_completed", level_id)


func get_checkpoint_position() -> Vector2:
	return _checkpoint_position


func _on_checkpoint_reached(position: Vector2) -> void:
	_checkpoint_position = position


func _on_actor_killed(_actor: Node2D) -> void:
	reset_level()
