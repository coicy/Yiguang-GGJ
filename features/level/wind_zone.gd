class_name WindZone
extends Area2D
## Alternates a readable warning phase with a force-applying blow phase.

@export var warning_duration: float = 1.0
@export var blow_duration: float = 1.5
@export var wind_force: float = 900.0
@export_range(-1.0, 1.0, 2.0) var direction: float = 1.0

var _blowing: bool = false
var _phase_remaining: float = 1.0


func _ready() -> void:
	_phase_remaining = warning_duration
	queue_redraw()


func _physics_process(delta: float) -> void:
	_phase_remaining -= delta
	if _phase_remaining <= 0.0:
		_blowing = not _blowing
		_phase_remaining += blow_duration if _blowing else warning_duration
		queue_redraw()
	if _blowing:
		for actor: Node2D in get_overlapping_bodies():
			apply_to_actor(actor, delta)


func apply_to_actor(actor: Node2D, delta: float) -> void:
	if _blowing and actor != null and actor.has_method(&"apply_wind"):
		actor.call(&"apply_wind", wind_force * direction, delta)


func set_blowing_for_test(active: bool) -> void:
	_blowing = active
	_phase_remaining = blow_duration if active else warning_duration
	queue_redraw()


func is_blowing() -> bool:
	return _blowing


func _draw() -> void:
	var color := Color(0.32, 0.72, 1.0, 0.32) if _blowing else Color(1.0, 0.82, 0.25, 0.22)
	draw_rect(Rect2(-180.0, -70.0, 360.0, 140.0), color)
	var arrow_direction := signf(direction)
	for y: float in [-36.0, 0.0, 36.0]:
		draw_line(Vector2(-140.0 * arrow_direction, y), Vector2(140.0 * arrow_direction, y), Color.WHITE, 3.0)
		draw_line(Vector2(140.0 * arrow_direction, y), Vector2(115.0 * arrow_direction, y - 12.0), Color.WHITE, 3.0)
		draw_line(Vector2(140.0 * arrow_direction, y), Vector2(115.0 * arrow_direction, y + 12.0), Color.WHITE, 3.0)
