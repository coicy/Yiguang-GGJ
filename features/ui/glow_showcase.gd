class_name GlowShowcase
extends Node2D
## Standalone visual test for lightweight layered 2D glow effects.

const VIEW_SIZE := Vector2(1280.0, 720.0)
const BACKGROUND := Color(0.018, 0.027, 0.038, 1.0)
const PANEL := Color(0.035, 0.055, 0.072, 0.92)
const TEXT := Color(0.82, 0.9, 0.92, 1.0)
const MUTED_TEXT := Color(0.42, 0.55, 0.6, 1.0)
const CYAN := Color(0.22, 0.9, 0.98, 1.0)
const AMBER := Color(1.0, 0.66, 0.25, 1.0)
const GREEN := Color(0.42, 1.0, 0.62, 1.0)

var _elapsed: float = 0.0


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, 120.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), BACKGROUND)
	draw_rect(Rect2(44.0, 42.0, 1192.0, 636.0), PANEL)
	draw_line(Vector2(44.0, 112.0), Vector2(1236.0, 112.0), Color(0.15, 0.28, 0.32, 0.8), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(76.0, 82.0), "GLOW EFFECTS TEST", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, TEXT)
	draw_string(ThemeDB.fallback_font, Vector2(76.0, 101.0), "Layered 2D light studies for the whitebox presentation", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, MUTED_TEXT)

	_draw_panel(Rect2(76.0, 150.0, 330.0, 450.0), "01  PULSE CORE", "Soft concentric layers", CYAN)
	_draw_panel(Rect2(474.0, 150.0, 330.0, 450.0), "02  ENERGY RING", "Orbiting sparks and halo", AMBER)
	_draw_panel(Rect2(872.0, 150.0, 330.0, 450.0), "03  SIGNAL BEAM", "Moving streaks and nodes", GREEN)

	_draw_pulse_core(Vector2(241.0, 365.0), CYAN)
	_draw_energy_ring(Vector2(639.0, 365.0), AMBER)
	_draw_signal_beam(Rect2(912.0, 300.0, 250.0, 130.0), GREEN)

	draw_string(ThemeDB.fallback_font, Vector2(76.0, 644.0), "All effects are procedural, animated, and safe to reuse in gameplay scenes.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, MUTED_TEXT)
	draw_string(ThemeDB.fallback_font, Vector2(1202.0, 644.0), "F6", HORIZONTAL_ALIGNMENT_RIGHT, 60.0, 15, TEXT)


func _draw_panel(rect: Rect2, title: String, subtitle: String, accent: Color) -> void:
	draw_rect(rect, Color(0.02, 0.035, 0.047, 0.9), true)
	draw_rect(rect, Color(accent, 0.32), false, 2.0)
	draw_rect(Rect2(rect.position + Vector2(0.0, 0.0), Vector2(5.0, rect.size.y)), accent)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(25.0, 38.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, TEXT)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(25.0, 62.0), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, MUTED_TEXT)


func _draw_pulse_core(center: Vector2, color: Color) -> void:
	var pulse := (sin(_elapsed * TAU * 0.7) + 1.0) * 0.5
	for layer: int in range(7, 0, -1):
		var radius := 30.0 + float(layer) * 14.0 + pulse * 8.0
		var alpha := 0.018 + (8.0 - float(layer)) * 0.012
		draw_circle(center, radius, Color(color, alpha))
	draw_circle(center, 46.0 + pulse * 5.0, Color(color, 0.15), false, 2.0)
	draw_circle(center, 29.0 + pulse * 2.0, Color(color, 0.32), false, 2.0)
	draw_circle(center, 18.0, Color(color, 0.55))
	draw_circle(center, 8.0, Color(0.94, 1.0, 1.0, 0.98))
	var ray_length := 58.0 + pulse * 12.0
	for ray_index: int in range(8):
		var angle := _elapsed * 0.4 + float(ray_index) * TAU / 8.0
		var ray_start := center + Vector2.from_angle(angle) * 66.0
		var ray_end := center + Vector2.from_angle(angle) * (66.0 + ray_length * 0.32)
		draw_line(ray_start, ray_end, Color(color, 0.28), 2.0)


func _draw_energy_ring(center: Vector2, color: Color) -> void:
	var rotation := _elapsed * 0.8
	var breathe := (sin(_elapsed * TAU * 0.55) + 1.0) * 0.5
	for layer: int in range(5, 0, -1):
		var radius := 44.0 + float(layer) * 13.0 + breathe * 4.0
		draw_arc(center, radius, rotation, rotation + PI * 1.55, 64, Color(color, 0.025 + (6.0 - float(layer)) * 0.018), 5.0)
	draw_arc(center, 62.0 + breathe * 4.0, rotation, rotation + TAU * 0.82, 64, Color(color, 0.75), 2.5)
	draw_arc(center, 48.0, -rotation * 0.7, -rotation * 0.7 + TAU * 0.6, 64, Color(1.0, 0.86, 0.56, 0.62), 2.0)
	for spark_index: int in range(6):
		var angle := rotation * (1.0 if spark_index % 2 == 0 else -0.8) + float(spark_index) * TAU / 6.0
		var radius := 64.0 + sin(_elapsed * 2.0 + float(spark_index)) * 5.0
		var spark := center + Vector2.from_angle(angle) * radius
		_draw_spark(spark, color, 5.0 + float(spark_index % 2) * 2.0)
	draw_circle(center, 22.0, Color(color, 0.08))
	draw_circle(center, 10.0, Color(color, 0.45))
	draw_circle(center, 4.0, Color(1.0, 0.98, 0.8, 1.0))


func _draw_spark(position: Vector2, color: Color, radius: float) -> void:
	draw_circle(position, radius * 2.8, Color(color, 0.025))
	draw_circle(position, radius * 1.7, Color(color, 0.08))
	draw_circle(position, radius, Color(color, 0.72))


func _draw_signal_beam(rect: Rect2, color: Color) -> void:
	var center_y := rect.position.y + rect.size.y * 0.5
	var travel := fmod(_elapsed * 150.0, rect.size.x + 90.0)
	for layer: int in range(6, 0, -1):
		var height := 4.0 + float(layer) * 5.0
		draw_line(Vector2(rect.position.x, center_y), Vector2(rect.end.x, center_y), Color(color, 0.012 + (7.0 - float(layer)) * 0.012), height)
	draw_line(Vector2(rect.position.x, center_y), Vector2(rect.end.x, center_y), Color(color, 0.72), 2.0)
	for node_index: int in range(5):
		var x := rect.position.x + 18.0 + float(node_index) * 58.0
		var node_y := center_y + sin(_elapsed * 2.2 + float(node_index)) * 25.0
		draw_line(Vector2(x, center_y), Vector2(x, node_y), Color(color, 0.3), 1.0)
		_draw_spark(Vector2(x, node_y), color, 4.0)
	var head := Vector2(rect.position.x + travel - 45.0, center_y)
	draw_circle(head, 30.0, Color(color, 0.04))
	draw_circle(head, 14.0, Color(color, 0.18))
	draw_circle(head, 5.0, Color(0.9, 1.0, 0.9, 0.95))
