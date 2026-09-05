@tool
class_name SpawnPoint
extends Marker2D
## The runtime spawn location used by HandbuiltLevel.

@export var preview_radius := 18.0:
	set(value):
		preview_radius = maxf(value, 1.0)
		queue_redraw()


func _ready() -> void:
	add_to_group(&"handbuilt_spawn_points")
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_circle(Vector2.ZERO, preview_radius, Color(0.24, 0.78, 0.52, 0.3))
	draw_arc(Vector2.ZERO, preview_radius, 0.0, TAU, 20, Color("88f0a8"), 2.0, true)
	draw_line(Vector2(0.0, preview_radius), Vector2(0.0, -preview_radius), Color("e6ffec"), 2.0)
	draw_line(Vector2(-6.0, -preview_radius + 7.0), Vector2(0.0, -preview_radius), Color("e6ffec"), 2.0)
	draw_line(Vector2(6.0, -preview_radius + 7.0), Vector2(0.0, -preview_radius), Color("e6ffec"), 2.0)
