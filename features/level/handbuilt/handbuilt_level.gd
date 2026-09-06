class_name HandbuiltLevel
extends Node2D
## Lifecycle owner for scenes assembled by hand in the Godot editor.

signal run_stats_changed(seconds: int, retries: int)
signal checkpoint_registered()
signal completion_changed(completed: bool)

@export_enum("Left:-1", "Right:1") var spawn_camera_direction: int = 1
@export var level_id: StringName = &"level_01"
@export_node_path("Area2D") var completion_button_path: NodePath

@onready var _player: Player = %Player
@onready var _spawn_point: SpawnPoint = %SpawnPoint
@onready var _camera: Camera2D = %Camera2D
@onready var _phantom_camera: PhantomCamera2D = %PhantomCamera2D
@onready var _camera_bounds: CameraBounds = %CameraBounds
@onready var _hud: MainLevelHud = get_node_or_null("%MainLevelHud") as MainLevelHud
@onready var _completion_overlay: CompletionOverlay = get_node_or_null("%CompletionOverlay") as CompletionOverlay
@onready var _framing: ForwardCameraFraming = get_node_or_null("%ForwardCameraFraming") as ForwardCameraFraming

var _respawn_position := Vector2.ZERO
var _respawn_camera_direction: float = 1.0
var _elapsed_seconds: float = 0.0
var _retry_count: int = 0
var _completed: bool = false
var _restarting: bool = false


func _ready() -> void:
	_ensure_event_bus()
	_respawn_position = _spawn_point.global_position
	_respawn_camera_direction = float(spawn_camera_direction)
	_player.global_position = _respawn_position
	_player.reset_physics_interpolation()
	_configure_camera()
	_connect_hazards()
	_connect_checkpoints()
	_connect_toxin_zones()
	_bind_hud()
	_bind_completion()


func _process(delta: float) -> void:
	if _completed:
		return
	var previous_seconds: int = int(_elapsed_seconds)
	_elapsed_seconds += delta
	if int(_elapsed_seconds) != previous_seconds:
		run_stats_changed.emit(int(_elapsed_seconds), _retry_count)


func elapsed_time() -> float:
	return _elapsed_seconds


func death_count() -> int:
	return _retry_count


func is_completed() -> bool:
	return _completed


func _bind_completion() -> void:
	if _completion_overlay != null:
		_completion_overlay.restart_requested.connect(_request_restart)
	if completion_button_path.is_empty():
		return
	var button := get_node_or_null(completion_button_path) as TriggerButton
	if button == null or _completion_overlay == null:
		push_error("The completion button and overlay must both exist for %s." % level_id)
		return
	button.pressed.connect(_on_completion_button_pressed)


func _on_completion_button_pressed(_button: TriggerButton, actor: Node2D) -> void:
	if _completed or _restarting or actor != _player:
		return
	_completed = true
	completion_changed.emit(true)
	# Finish the button's other listeners before freezing physics and mechanisms.
	_show_completion.call_deferred()


func _show_completion() -> void:
	if _restarting:
		return
	_player.cancel_actions()
	_player.velocity = Vector2.ZERO
	_completion_overlay.show_completion(_elapsed_seconds, _retry_count)
	get_tree().paused = true
	GlobalSignalBus.level_completed.emit(level_id)


func _bind_hud() -> void:
	if _hud == null:
		return
	_hud.bind_player(_player)
	_hud.set_run_stats(int(_elapsed_seconds), _retry_count)
	run_stats_changed.connect(_hud.set_run_stats)
	checkpoint_registered.connect(_hud.show_message.bind("检查点已记录 · 失误后从这里继续"))


func _ensure_event_bus() -> void:
	for child: Node in get_children():
		if child is LevelEventBus:
			return
	var event_bus := LevelEventBus.new()
	event_bus.name = &"LevelEventBus"
	add_child(event_bus)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_request_restart()


func _request_restart() -> void:
	if _restarting:
		return
	_restarting = true
	_restart_current_scene.call_deferred()


func _restart_current_scene() -> void:
	# Unpause first: the app entry may pause its new scene again for the menu.
	get_tree().paused = false
	get_tree().reload_current_scene()


func _configure_camera() -> void:
	var bounds := _camera_bounds.get_world_rect()
	_phantom_camera.set_follow_target(_player)
	_camera.limit_left = int(bounds.position.x)
	_camera.limit_top = int(bounds.position.y)
	_camera.limit_right = int(bounds.end.x)
	_camera.limit_bottom = int(bounds.end.y)
	_phantom_camera.limit_left = int(bounds.position.x)
	_phantom_camera.limit_top = int(bounds.position.y)
	_phantom_camera.limit_right = int(bounds.end.x)
	_phantom_camera.limit_bottom = int(bounds.end.y)
	if _framing != null:
		_framing.reset_for_respawn(_respawn_camera_direction)


func _connect_hazards() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"handbuilt_hazards"):
		if node.has_signal(&"actor_killed") and not node.is_connected(&"actor_killed", _on_actor_killed):
			node.connect(&"actor_killed", _on_actor_killed)


func _connect_checkpoints() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"handbuilt_checkpoints"):
		if node.has_signal(&"actor_checkpoint_reached") and not node.is_connected(&"actor_checkpoint_reached", _on_checkpoint_reached):
			node.connect(&"actor_checkpoint_reached", _on_checkpoint_reached)


func _connect_toxin_zones() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"handbuilt_toxin_zones"):
		var zone := node as ToxinZone
		if zone == null:
			continue
		var entered_handler := _on_toxin_zone_entered.bind(zone)
		var exited_handler := _on_toxin_zone_exited.bind(zone)
		if not zone.actor_entered.is_connected(entered_handler):
			zone.actor_entered.connect(entered_handler)
		if not zone.actor_exited.is_connected(exited_handler):
			zone.actor_exited.connect(exited_handler)


func _on_actor_killed(actor: Node2D) -> void:
	if _completed or actor != _player:
		return
	_player.cancel_actions()
	_player.global_position = _respawn_position
	_player.velocity = Vector2.ZERO
	_player.reset_physics_interpolation()
	if _framing != null:
		_framing.reset_for_respawn(_respawn_camera_direction)
	_retry_count += 1
	run_stats_changed.emit(int(_elapsed_seconds), _retry_count)
	if _hud != null:
		_hud.show_message("已返回重生点 · 再试一次")


func _on_checkpoint_reached(actor: Node2D, position: Vector2) -> void:
	if not _completed and actor == _player and not _respawn_position.is_equal_approx(position):
		_respawn_position = position
		if _framing != null:
			_respawn_camera_direction = _framing.get_facing_direction()
		checkpoint_registered.emit()


func _on_toxin_zone_entered(actor: Node2D, zone: ToxinZone) -> void:
	if not _completed and actor == _player:
		_player.enter_toxin(zone)


func _on_toxin_zone_exited(actor: Node2D, zone: ToxinZone) -> void:
	if not _completed and actor == _player:
		_player.exit_toxin(zone)
