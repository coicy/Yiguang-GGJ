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
	var outline := Color("#233b2a")
	var bronze := Color("#9f8153")
	var edge := Color("#c5ad78")
	var light := Color("#caff9b") if _is_activated else Color("#71845b")
	var lantern := Vector2(9, -32)
	if _is_activated:
		draw_circle(lantern, 12.0, Color(0.60, 0.86, 0.36, 0.09))
		draw_circle(lantern, 8.0, Color(0.65, 0.95, 0.42, 0.14))
	# The checkpoint origin is 20 units above its landing surface in the main level.
	var stem := PackedVector2Array([Vector2(0, 20), Vector2(-2, 1), Vector2(-3, -24), Vector2(-1, -40), Vector2(4, -46), Vector2(10, -45), Vector2(12, -41)])
	draw_polyline(stem, outline, 4.2, true)
	draw_polyline(stem, Color("#66844d"), 2.1, true)
	draw_line(Vector2(10, -43), Vector2(9, -41), bronze, 1.4, true)
	var housing := PackedVector2Array([lantern + Vector2(-6, -8), lantern + Vector2(6, -8), lantern + Vector2(7, 6), lantern + Vector2(0, 11), lantern + Vector2(-7, 6)])
	draw_colored_polygon(housing, Color("#354a31"))
	draw_polyline(housing + PackedVector2Array([housing[0]]), outline, 3.4, true)
	draw_polyline(housing + PackedVector2Array([housing[0]]), bronze, 1.5, true)
	draw_colored_polygon(PackedVector2Array([lantern + Vector2(-4, -5), lantern + Vector2(4, -5), lantern + Vector2(4, 5), lantern + Vector2(0, 8), lantern + Vector2(-4, 5)]), light)
	draw_line(lantern + Vector2(0, -6), lantern + Vector2(0, 8), Color("#789960"), 1.0, true)
	draw_line(lantern + Vector2(-7, -8), lantern + Vector2(7, -8), edge, 2.0, true)
	draw_line(lantern + Vector2(-6, 6), lantern + Vector2(6, 6), bronze, 1.4, true)
	for side: float in [-1.0, 1.0]:
		var leaf := PackedVector2Array([Vector2(-2, -8), Vector2(-2 + side * 7, -15), Vector2(-2 + side * 13, -16), Vector2(-2 + side * 9, -9), Vector2(-2 + side * 3, -7)])
		draw_colored_polygon(leaf, Color("#5d7d46"))
		draw_line(Vector2(-2, -8), Vector2(-2 + side * 10, -14), Color("#a3b875"), 0.8, true)
		draw_line(Vector2(0, 18), Vector2(side * 8, 20), outline, 3.0, true)
		draw_line(Vector2(0, 18), Vector2(side * 8, 20), bronze, 1.4, true)
	if _is_activated:
		draw_circle(lantern + Vector2(-1.4, -1.5), 1.5, Color("#efffcb"))
