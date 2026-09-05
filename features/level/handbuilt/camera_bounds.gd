@tool
class_name CameraBounds
extends Node2D
## Top-left anchored camera limits for a hand-built level.

@export var bounds_size: Vector2 = Vector2(1344.0, 640.0):
	set(value):
		bounds_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		queue_redraw()


func get_world_rect() -> Rect2:
	return Rect2(global_position, bounds_size)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(Vector2.ZERO, bounds_size), Color(0.25, 0.64, 0.95, 0.08))
	draw_dashed_line(Vector2.ZERO, Vector2(bounds_size.x, 0.0), Color("78c8ff"), 1.5, 8.0)
	draw_dashed_line(Vector2(bounds_size.x, 0.0), bounds_size, Color("78c8ff"), 1.5, 8.0)
	draw_dashed_line(bounds_size, Vector2(0.0, bounds_size.y), Color("78c8ff"), 1.5, 8.0)
	draw_dashed_line(Vector2(0.0, bounds_size.y), Vector2.ZERO, Color("78c8ff"), 1.5, 8.0)
