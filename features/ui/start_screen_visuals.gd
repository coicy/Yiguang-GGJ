class_name StartScreenVisuals
extends Control
## Procedural identity layer for the whitebox start screen.

const GRID_COLOR := Color(0.48, 0.72, 0.68, 0.08)
const SPROUT_COLOR := Color("4fcd6b")
const HUMANOID_COLOR := Color("33b8eb")
const MATURE_COLOR := Color("8f59eb")
const TOXIN_COLOR := Color("da4b8c")

var _elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, 120.0)
	queue_redraw()


func _draw() -> void:
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	for x: float in range(0.0, viewport_size.x + 32.0, 32.0):
		draw_line(Vector2(x, 0.0), Vector2(x, viewport_size.y), GRID_COLOR, 1.0)
	for y: float in range(0.0, viewport_size.y + 32.0, 32.0):
		draw_line(Vector2(0.0, y), Vector2(viewport_size.x, y), GRID_COLOR, 1.0)

	var base := Vector2(viewport_size.x * 0.22, viewport_size.y * 0.84)
	var stem := PackedVector2Array([
		base,
		base + Vector2(20.0, -68.0),
		base + Vector2(8.0, -150.0),
		base + Vector2(48.0, -232.0),
		base + Vector2(42.0, -322.0),
	])
	draw_polyline(stem, Color(0.48, 0.86, 0.68, 0.36), 2.0, true)
	draw_line(base + Vector2(8.0, -150.0), base + Vector2(-72.0, -202.0), Color(SPROUT_COLOR, 0.42), 2.0, true)
	draw_line(base + Vector2(48.0, -232.0), base + Vector2(142.0, -276.0), Color(HUMANOID_COLOR, 0.42), 2.0, true)
	draw_line(base + Vector2(42.0, -322.0), base + Vector2(-46.0, -366.0), Color(MATURE_COLOR, 0.42), 2.0, true)

	_draw_form_node(base + Vector2(-72.0, -202.0), SPROUT_COLOR, 15.0, 0.0)
	_draw_form_node(base + Vector2(142.0, -276.0), HUMANOID_COLOR, 20.0, 1.8)
	_draw_form_node(base + Vector2(-46.0, -366.0), MATURE_COLOR, 26.0, 3.4)

	var pulse := (sin(_elapsed * TAU * 0.7) + 1.0) * 0.5
	draw_circle(base + Vector2(42.0, -322.0), 5.0 + pulse * 3.0, Color(TOXIN_COLOR, 0.18 + pulse * 0.12))
	draw_circle(base + Vector2(42.0, -322.0), 2.0, Color(TOXIN_COLOR, 0.8))


func _draw_form_node(center: Vector2, color: Color, radius: float, phase: float) -> void:
	var pulse := (sin(_elapsed * TAU * 0.45 + phase) + 1.0) * 0.5
	for layer: int in range(3, 0, -1):
		draw_circle(center, radius + float(layer) * 10.0 + pulse * 4.0, Color(color, 0.018 * float(4 - layer)))
	draw_arc(center, radius + 7.0 + pulse * 3.0, -PI * 0.7, PI * 0.95, 24, Color(color, 0.38), 1.0, true)
	draw_circle(center, radius, Color(color, 0.14))
	draw_circle(center, radius, Color(color, 0.85), false, 2.0, true)
	draw_circle(center, 3.0, Color(0.94, 1.0, 0.9, 0.92))
