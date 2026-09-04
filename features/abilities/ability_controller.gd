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
var _vine_anchor: Node2D


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
		var form := _forms.get_current() if _forms != null else null
		if form != null and form.can_use_vine:
			try_attach_vine()
		else:
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


func try_attach_vine() -> bool:
	if _forms == null or _movement == null or _player == null:
		return false
	var form := _forms.get_current()
	if form == null or not form.can_use_vine or _rooted or _leg_extended:
		return false
	var nearest := _nearest_visible_anchor(300.0)
	if nearest == null:
		feedback_requested.emit("附近没有可连接的藤蔓锚点")
		return false
	_vine_anchor = nearest
	_movement.attach_vine(nearest, _player.global_position.distance_to(nearest.global_position))
	ability_state_changed.emit(&"vine")
	return true


func stop_primary() -> void:
	var changed := false
	if _rooted:
		_rooted = false
		_movement.set_rooted(false)
		changed = true
	if _vine_anchor != null:
		_vine_anchor = null
		_movement.detach_vine()
		changed = true
	if changed:
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
	return _vine_anchor != null and is_instance_valid(_vine_anchor)


func get_vine_anchor() -> Node2D:
	return _vine_anchor if is_vine_attached() else null


func _nearest_visible_anchor(max_range: float) -> Node2D:
	var nearest: Node2D
	var nearest_distance := max_range
	for candidate_node: Node in _player.get_tree().get_nodes_in_group("vine_anchor"):
		var candidate := candidate_node as Node2D
		if candidate == null:
			continue
		var distance := _player.global_position.distance_to(candidate.global_position)
		if distance > nearest_distance or not _has_clear_path(candidate):
			continue
		nearest = candidate
		nearest_distance = distance
	return nearest


func _has_clear_path(candidate: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(
		_player.global_position,
		candidate.global_position,
		1
	)
	query.exclude = [_player.get_rid()]
	var hit := _player.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return candidate is CollisionObject2D and hit.get("collider") == candidate
