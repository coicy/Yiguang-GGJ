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
	var dark := Color("#263c2a")
	var bronze := Color("#a08455")
	var highlight := Color("#d5bf83")
	var living := Color("#a9d977") if _available else Color("#596b4c")
	# The open center is the attach point; the vine wrapping supplies its world identity.
	draw_arc(Vector2.ZERO, 10.0, 0, TAU, 32, dark, 7.0, true)
	draw_arc(Vector2.ZERO, 10.0, 0, TAU, 32, bronze, 4.0, true)
	draw_arc(Vector2.ZERO, 10.2, -2.55, -0.75, 12, highlight, 1.2, true)
	draw_arc(Vector2.ZERO, 7.0, 0.1, 1.35, 10, Color("#58784e"), 1.2, true)
	var stem := PackedVector2Array([Vector2(-5, -22), Vector2(-2, -17), Vector2(-4, -12), Vector2(0, -9), Vector2(3, -12)])
	draw_polyline(stem, dark, 4.0, true)
	draw_polyline(stem, Color("#6e914d"), 2.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -16), Vector2(-10, -16), Vector2(-14, -22), Vector2(-7, -22), Vector2(-3, -18)]), Color("#648748"))
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -15), Vector2(1, -21), Vector2(8, -24), Vector2(7, -18), Vector2(1, -15)]), living)
	draw_line(Vector2(-2, -16), Vector2(5, -21), Color("#bed68a"), 0.8, true)
	draw_line(Vector2(8, 6), Vector2(13, 11), dark, 2.6, true)
	draw_colored_polygon(PackedVector2Array([Vector2(10, 8), Vector2(18, 7), Vector2(16, 13), Vector2(12, 12)]), living)
	for angle: float in [-0.45, 2.65]:
		var point := Vector2.from_angle(angle) * 10.0
		draw_circle(point, 1.5, dark)
		draw_circle(point, 0.8, highlight)
