class_name ToxinZone
extends Area2D


signal actor_entered(actor: Node2D)
signal actor_exited(actor: Node2D)
signal actor_absorption_started(actor: Node2D)
signal actor_absorption_stopped(actor: Node2D)

@export var zone_size := Vector2(128.0, 64.0):
	set(value):
		zone_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		if is_inside_tree():
			call_deferred("_sync_zone_size")

var _actors_inside: Array[Node2D] = []
var _absorbing_actors: Array[Node2D] = []


func _ready() -> void:
	add_to_group(&"handbuilt_toxin_zones")
	_sync_zone_size()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _sync_zone_size() -> void:
	var collision := %CollisionShape2D as CollisionShape2D
	if collision.shape != null and not collision.shape.resource_local_to_scene:
		collision.shape = collision.shape.duplicate(true)
	var rectangle := collision.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision.shape = rectangle
	rectangle.size = zone_size
	collision.position = Vector2.ZERO
	var fog := %PoisonFog.get_node("Fog") as ColorRect
	fog.position = zone_size * -0.5
	fog.size = zone_size


func is_actor_inside(actor: Node2D) -> bool:
	return _actors_inside.has(actor)


func _physics_process(_delta: float) -> void:
	for actor: Node2D in _actors_inside.duplicate():
		if not is_instance_valid(actor):
			_actors_inside.erase(actor)
			_absorbing_actors.erase(actor)
			continue
		var absorbing := _is_absorbing(actor)
		if absorbing and not _absorbing_actors.has(actor):
			_absorbing_actors.append(actor)
			actor_absorption_started.emit(actor)
		elif not absorbing and _absorbing_actors.has(actor):
			_absorbing_actors.erase(actor)
			actor_absorption_stopped.emit(actor)


func _on_body_entered(actor: Node2D) -> void:
	if _actors_inside.has(actor):
		return

	_actors_inside.append(actor)
	actor_entered.emit(actor)


func _on_body_exited(actor: Node2D) -> void:
	if not _actors_inside.has(actor):
		return

	_actors_inside.erase(actor)
	if _absorbing_actors.has(actor):
		_absorbing_actors.erase(actor)
		actor_absorption_stopped.emit(actor)
	actor_exited.emit(actor)


func _is_absorbing(actor: Node2D) -> bool:
	return actor.has_method(&"is_absorbing_resource") and actor.call(&"is_absorbing_resource") == true
