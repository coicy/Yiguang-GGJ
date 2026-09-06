class_name StartScreenVisuals
extends Control
## Quiet, replaceable vector atmosphere behind the title menu.

const LINE := Color(0.309804, 0.803922, 0.419608, 0.13)
const BLUE := Color(0.2, 0.721569, 0.921569, 0.08)
const PURPLE := Color(0.560784, 0.34902, 0.921569, 0.07)
const TOXIN := Color(0.854902, 0.294118, 0.54902, 0.12)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	# A barely-there growth path keeps the white placeholder from feeling empty,
	# while leaving the center clear for a future illustration or screenshot.
	var left_base := Vector2(size.x * 0.12, size.y * 0.92)
	var left_points := PackedVector2Array([
		left_base,
		left_base + Vector2(size.x * 0.025, -size.y * 0.18),
		left_base + Vector2(-size.x * 0.01, -size.y * 0.34),
		left_base + Vector2(size.x * 0.045, -size.y * 0.51),
		left_base + Vector2(size.x * 0.015, -size.y * 0.68),
	])
	draw_polyline(left_points, LINE, 2.0, true)
	draw_line(left_points[2], left_points[2] + Vector2(-size.x * 0.09, -size.y * 0.04), LINE, 2.0, true)
	draw_line(left_points[3], left_points[3] + Vector2(size.x * 0.1, -size.y * 0.05), LINE, 2.0, true)
	draw_circle(left_points[1], 4.0, LINE)
	draw_circle(left_points[3], 5.0, BLUE)

	var right_center := Vector2(size.x * 0.88, size.y * 0.22)
	draw_arc(right_center, minf(size.x, size.y) * 0.16, PI * 0.18, PI * 1.22, 48, Color(LINE, 0.7), 2.0, true)
	draw_arc(right_center, minf(size.x, size.y) * 0.21, PI * 0.2, PI * 1.18, 48, PURPLE, 1.0, true)
	draw_circle(right_center + Vector2(-size.x * 0.05, size.y * 0.12), 4.0, TOXIN)
