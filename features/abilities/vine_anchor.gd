class_name VineAnchor
extends Node2D
## Visible whitebox grapple point discovered through the vine_anchor group.


func _ready() -> void:
	add_to_group("vine_anchor")
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color("#f3cf55"))
	draw_circle(Vector2.ZERO, 6.0, Color("#574519"))
	draw_line(Vector2(-18.0, 0.0), Vector2(18.0, 0.0), Color.WHITE, 2.0)
	draw_line(Vector2(0.0, -18.0), Vector2(0.0, 18.0), Color.WHITE, 2.0)
