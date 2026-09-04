class_name Checkpoint
extends Area2D


signal checkpoint_reached(position: Vector2)


var _is_activated := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func activate(actor: Node2D) -> bool:
	if not is_instance_valid(actor) or _is_activated:
		return false

	_is_activated = true
	checkpoint_reached.emit(get_checkpoint_position())
	return true


func get_checkpoint_position() -> Vector2:
	return global_position


func _on_body_entered(actor: Node2D) -> void:
	activate(actor)
