class_name VineAnchor
extends Node2D
## Visible whitebox grapple point discovered through the vine_anchor group.


var _available: bool = true


func _ready() -> void:
	set_available(_available)
	queue_redraw()


func set_available(available: bool) -> void:
	_available = available
	visible = available
	if not is_inside_tree():
		return
	if available:
		add_to_group("vine_anchor")
	else:
		remove_from_group("vine_anchor")


func is_available() -> bool:
	return _available


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color("#f3cf55"))
	draw_circle(Vector2.ZERO, 6.0, Color("#574519"))
	draw_line(Vector2(-18.0, 0.0), Vector2(18.0, 0.0), Color.WHITE, 2.0)
	draw_line(Vector2(0.0, -18.0), Vector2(0.0, 18.0), Color.WHITE, 2.0)
