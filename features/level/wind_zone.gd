class_name WindZone
extends Area2D
## Alternates a readable warning phase with a force-applying blow phase.

const ZONE_RECT := Rect2(-180.0, -70.0, 360.0, 140.0)
const LABEL_RECT := Rect2(-180.0, -108.0, 360.0, 28.0)
const VISUAL_INK := Color(0.94, 0.96, 0.93, 1.0)
const VISUAL_SHADE := Color(0.05, 0.06, 0.055, 0.24)
const WIND_STREAK_COUNT: int = 9

@export var warning_duration: float = 1.0
@export var blow_duration: float = 1.5
@export var wind_force: float = 1800.0
@export_range(-1.0, 1.0, 2.0) var direction: float = 1.0

var _blowing: bool = false
var _phase_remaining: float = 1.0
var _visual_elapsed: float = 0.0


func _ready() -> void:
	_phase_remaining = warning_duration
	queue_redraw()


func _process(delta: float) -> void:
	_visual_elapsed = fmod(_visual_elapsed + delta, 120.0)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_phase_remaining -= delta
	if _phase_remaining <= 0.0:
		_blowing = not _blowing
		_phase_remaining += blow_duration if _blowing else warning_duration
		_visual_elapsed = 0.0
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
	_visual_elapsed = 0.0
	queue_redraw()


func is_blowing() -> bool:
	return _blowing


func _draw() -> void:
	draw_rect(ZONE_RECT, VISUAL_SHADE)
	if _blowing:
		_draw_blowing_wind()
	else:
		_draw_wind_warning()
	_draw_phase_label()


func _draw_phase_label() -> void:
	draw_rect(LABEL_RECT, Color(0.05, 0.06, 0.055, 0.82))
	var phase_label := (
		">>> 强风 · 按住 Q 扎根 >>>"
		if _blowing
		else "蓄风中 · %.1f 秒后起风" % maxf(_phase_remaining, 0.0)
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-180.0, -87.0),
		phase_label,
		HORIZONTAL_ALIGNMENT_CENTER,
		360.0,
		17,
		VISUAL_INK
	)


func _draw_wind_warning() -> void:
	var pulse := (sin(_visual_elapsed * TAU * 0.75) + 1.0) * 0.5
	draw_rect(ZONE_RECT, Color(VISUAL_INK, 0.24 + pulse * 0.18), false, 2.0 + pulse)

	# Slow inward-moving frames read as wind charging, without implying active force.
	for frame_index: int in range(3):
		var progress := fmod(_visual_elapsed * 0.55 + float(frame_index) / 3.0, 1.0)
		var inset := 4.0 + progress * 30.0
		var frame_rect := ZONE_RECT.grow(-inset)
		draw_rect(frame_rect, Color(VISUAL_INK, (1.0 - progress) * 0.25), false, 1.5)

	var bracket_alpha := 0.42 + pulse * 0.38
	var bracket_color := Color(VISUAL_INK, bracket_alpha)
	for y: float in [-34.0, 0.0, 34.0]:
		draw_line(Vector2(-150.0, y - 8.0), Vector2(-132.0, y), bracket_color, 2.0)
		draw_line(Vector2(-150.0, y + 8.0), Vector2(-132.0, y), bracket_color, 2.0)
		draw_line(Vector2(150.0, y - 8.0), Vector2(132.0, y), bracket_color, 2.0)
		draw_line(Vector2(150.0, y + 8.0), Vector2(132.0, y), bracket_color, 2.0)


func _draw_blowing_wind() -> void:
	var wind_direction := -1.0 if direction < 0.0 else 1.0
	var border_pulse := (sin(_visual_elapsed * TAU * 4.0) + 1.0) * 0.5
	draw_rect(ZONE_RECT, Color(VISUAL_INK, 0.58 + border_pulse * 0.22), false, 3.0)

	# Dense, fast streaks make active force readable even in grayscale.
	for streak_index: int in range(WIND_STREAK_COUNT):
		var travel := fmod(
			_visual_elapsed * (250.0 + float(streak_index % 3) * 35.0)
			+ float(streak_index) * 67.0,
			ZONE_RECT.size.x + 150.0
		)
		var head_x := (
			ZONE_RECT.position.x - 55.0 + travel
			if wind_direction > 0.0
			else ZONE_RECT.end.x + 55.0 - travel
		)
		var lane_y := (
			ZONE_RECT.position.y + 14.0
			+ float(streak_index) * 14.0
			+ sin(_visual_elapsed * 7.0 + float(streak_index)) * 3.0
		)
		var streak_length := 54.0 + float(streak_index % 4) * 13.0
		_draw_wind_streak(Vector2(head_x, lane_y), streak_length, wind_direction, streak_index)


func _draw_wind_streak(head: Vector2, length: float, wind_direction: float, index: int) -> void:
	var left_bound := ZONE_RECT.position.x + 7.0
	var right_bound := ZONE_RECT.end.x - 7.0
	var tail_x := head.x - wind_direction * length
	var clipped_head_x := clampf(head.x, left_bound, right_bound)
	var clipped_tail_x := clampf(tail_x, left_bound, right_bound)
	if absf(clipped_head_x - clipped_tail_x) < 4.0:
		return

	var strength := 0.48 + float(index % 3) * 0.16
	var streak_color := Color(VISUAL_INK, strength)
	var stroke_width := 2.0 + float(index % 2)
	draw_line(
		Vector2(clipped_tail_x, head.y),
		Vector2(clipped_head_x, head.y),
		streak_color,
		stroke_width
	)
	if head.x < left_bound or head.x > right_bound:
		return

	var arrow_back := head.x - wind_direction * 12.0
	draw_line(head, Vector2(arrow_back, head.y - 5.0), streak_color, stroke_width)
	draw_line(head, Vector2(arrow_back, head.y + 5.0), streak_color, stroke_width)
