class_name Checkpoint
extends Area2D


signal checkpoint_reached(position: Vector2)
signal actor_checkpoint_reached(actor: Node2D, position: Vector2)


var _is_activated := false


func _ready() -> void:
	add_to_group(&"handbuilt_checkpoints")
	body_entered.connect(_on_body_entered)


func activate(actor: Node2D) -> bool:
	if not is_instance_valid(actor) or _is_activated:
		return false

	_is_activated = true
	checkpoint_reached.emit(get_checkpoint_position())
	actor_checkpoint_reached.emit(actor, get_checkpoint_position())
	queue_redraw()
	return true


func get_checkpoint_position() -> Vector2:
	return global_position


func _on_body_entered(actor: Node2D) -> void:
	activate(actor)


func reset_activation() -> void:
	_is_activated = false
	queue_redraw()


func _draw() -> void:
	var color := Color("#ffd54a") if _is_activated else Color("#8a7431")
	draw_rect(Rect2(-4.0, -64.0, 8.0, 64.0), color)
	draw_polygon(PackedVector2Array([Vector2(4.0, -64.0), Vector2(38.0, -52.0), Vector2(4.0, -40.0)]), PackedColorArray([color]))
