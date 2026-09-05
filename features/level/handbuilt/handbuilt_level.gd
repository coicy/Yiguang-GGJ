class_name HandbuiltLevel
extends Node2D
## Lifecycle owner for scenes assembled by hand in the Godot editor.

@onready var _player: Player = %Player
@onready var _spawn_point: SpawnPoint = %SpawnPoint
@onready var _camera: Camera2D = %Camera2D
@onready var _phantom_camera: PhantomCamera2D = %PhantomCamera2D
@onready var _camera_bounds: CameraBounds = %CameraBounds

var _respawn_position := Vector2.ZERO


func _ready() -> void:
	_respawn_position = _spawn_point.global_position
	_player.global_position = _respawn_position
	_configure_camera()
	_connect_hazards()
	_connect_checkpoints()
	_connect_toxin_zones()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
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
	if actor != _player:
		return
	_player.cancel_actions()
	_player.global_position = _respawn_position
	_player.velocity = Vector2.ZERO


func _on_checkpoint_reached(actor: Node2D, position: Vector2) -> void:
	if actor == _player:
		_respawn_position = position


func _on_toxin_zone_entered(actor: Node2D, zone: ToxinZone) -> void:
	if actor == _player:
		_player.enter_toxin(zone)


func _on_toxin_zone_exited(actor: Node2D, zone: ToxinZone) -> void:
	if actor == _player:
		_player.exit_toxin(zone)
