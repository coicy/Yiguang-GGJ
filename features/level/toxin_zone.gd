class_name ToxinZone
extends Area2D


signal actor_entered(actor: Node2D)
signal actor_exited(actor: Node2D)


var _actors_inside: Array[Node2D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func is_actor_inside(actor: Node2D) -> bool:
	return _actors_inside.has(actor)


func _on_body_entered(actor: Node2D) -> void:
	if _actors_inside.has(actor):
		return

	_actors_inside.append(actor)
	actor_entered.emit(actor)


func _on_body_exited(actor: Node2D) -> void:
	if not _actors_inside.erase(actor):
		return

	actor_exited.emit(actor)
