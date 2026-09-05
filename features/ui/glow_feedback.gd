class_name GlowFeedback
extends Node2D
## Reusable layered 2D glow with no external textures or addon dependencies.

enum Style {
	ORB,
	RING,
	FIELD,
}

@export var style: Style = Style.ORB
@export var glow_color: Color = Color(0.35, 0.95, 0.55, 1.0)
@export var radius: float = 28.0
@export var field_size: Vector2 = Vector2(128.0, 64.0)
@export_range(0.0, 1.0, 0.01) var idle_strength: float = 0.42
@export var active: bool = true

var _elapsed: float = 0.0
var _pulse_strength: float = 0.0
var _pulse_time: float = 0.0


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, 120.0)
	if _pulse_time > 0.0:
		_pulse_time = maxf(0.0, _pulse_time - delta)
		_pulse_strength = minf(1.0, _pulse_time / 0.42) * _pulse_strength
	else:
		_pulse_strength = move_toward(_pulse_strength, 0.0, delta * 2.4)
	queue_redraw()


func pulse(strength: float = 1.0) -> void:
	_pulse_strength = maxf(_pulse_strength, clampf(strength, 0.0, 1.0))
	_pulse_time = 0.42
	queue_redraw()


func set_active(value: bool) -> void:
	active = value
	queue_redraw()


func set_glow_color(value: Color) -> void:
	glow_color = value
	queue_redraw()


func _draw() -> void:
	if not active and _pulse_strength <= 0.01:
		return
	var breathe := (sin(_elapsed * TAU * 0.7) + 1.0) * 0.5
	var strength := (idle_strength if active else 0.0) + _pulse_strength + breathe * 0.08
	match style:
		Style.ORB:
			_draw_orb(strength)
		Style.RING:
			_draw_ring(strength)
		Style.FIELD:
			_draw_field(strength)


func _draw_orb(strength: float) -> void:
	for layer: int in range(6, 0, -1):
		var layer_radius := radius * (0.72 + float(layer) * 0.22) + _pulse_strength * 12.0
		var alpha := (0.012 + (7.0 - float(layer)) * 0.012) * strength
		draw_circle(Vector2.ZERO, layer_radius, Color(glow_color, alpha))
	draw_circle(Vector2.ZERO, radius * 0.72, Color(glow_color, 0.11 * strength), false, 2.0)


func _draw_ring(strength: float) -> void:
	var rotation := _elapsed * 0.65
	for layer: int in range(4, 0, -1):
		var ring_radius := radius + float(layer) * 7.0 + _pulse_strength * 8.0
		draw_arc(Vector2.ZERO, ring_radius, rotation, rotation + TAU * 0.82, 48, Color(glow_color, 0.028 * strength), 4.0)
	draw_arc(Vector2.ZERO, radius, rotation, rotation + TAU * 0.7, 48, Color(glow_color, 0.64 * strength), 2.0)
	for spark_index: int in range(3):
		var angle := rotation + float(spark_index) * TAU / 3.0
		var spark_position := Vector2.from_angle(angle) * (radius + 2.0)
		draw_circle(spark_position, 8.0, Color(glow_color, 0.035 * strength))
		draw_circle(spark_position, 3.0, Color(glow_color, 0.72 * strength))


func _draw_field(strength: float) -> void:
	var rect := Rect2(-field_size * 0.5, field_size)
	for layer: int in range(4, 0, -1):
		var inset := float(layer) * 6.0 + _pulse_strength * 10.0
		draw_rect(rect.grow(inset), Color(glow_color, 0.018 * strength), false, 4.0)
	draw_rect(rect, Color(glow_color, 0.55 * strength), false, 2.0)
