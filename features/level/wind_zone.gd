class_name WindZone
extends Area2D
## Applies continuous leftward wind inside the JSON-defined rectangle, clipped by world blockers.

const VISUAL_INK := Color(0.94, 0.96, 0.93, 1.0)
const VISUAL_SHADE := Color(0.05, 0.06, 0.055, 0.24)
const WIND_STREAK_COUNT: int = 9
const WIND_DIRECTION: float = -1.0
const WORLD_COLLISION_MASK: int = 1

@export var wind_force: float = 1800.0
@export var zone_size: Vector2 = Vector2(360.0, 140.0):
	set(value):
		zone_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_update_collision_shape()

var _visual_elapsed: float = 0.0
var _visual_left_bounds: Array[float] = []

@onready var _collision_shape: CollisionShape2D = %CollisionShape2D


func _ready() -> void:
	_visual_left_bounds.resize(WIND_STREAK_COUNT)
	for streak_index: int in range(WIND_STREAK_COUNT):
		_visual_left_bounds[streak_index] = _zone_rect().position.x
	_make_collision_shape_unique()
	_update_collision_shape()
	queue_redraw()


func _process(delta: float) -> void:
	_visual_elapsed = fmod(_visual_elapsed + delta, 120.0)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_update_visual_bounds()
	for actor: Node2D in get_overlapping_bodies():
		apply_to_actor(actor, delta)


func apply_to_actor(actor: Node2D, delta: float) -> void:
	if actor == null or not actor.has_method(&"apply_wind") or _is_wind_path_blocked(actor):
		return
	actor.call(&"apply_wind", wind_force * WIND_DIRECTION, delta)


func _is_wind_path_blocked(actor: Node2D) -> bool:
	var zone_rect := _zone_rect()
	var actor_local := to_local(actor.global_position)
	if not zone_rect.has_point(actor_local):
		return true
	var wind_origin := to_global(Vector2(zone_rect.end.x + 2.0, actor_local.y))
	var actor_position := actor.global_position
	if actor_position.x >= wind_origin.x:
		return false
	# A ray beginning inside a wall may not report that wall. Check the source edge
	# separately so a wall overlapping the wind boundary never leaks wind through.
	if _is_world_point_blocked(wind_origin):
		return true
	var query := PhysicsRayQueryParameters2D.create(wind_origin, actor_position, WORLD_COLLISION_MASK)
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	return not result.is_empty()


func _update_visual_bounds() -> void:
	var zone_rect := _zone_rect()
	for streak_index: int in range(WIND_STREAK_COUNT):
		var lane_y := zone_rect.position.y + (float(streak_index) + 1.0) * zone_rect.size.y / float(WIND_STREAK_COUNT + 1)
		_visual_left_bounds[streak_index] = _find_wall_limit(lane_y)


func _find_wall_limit(lane_y: float) -> float:
	var zone_rect := _zone_rect()
	var wind_origin := to_global(Vector2(zone_rect.end.x + 2.0, lane_y))
	var wind_end := to_global(Vector2(zone_rect.position.x, lane_y))
	if _is_world_point_blocked(wind_origin):
		return zone_rect.end.x
	var query := PhysicsRayQueryParameters2D.create(wind_origin, wind_end, WORLD_COLLISION_MASK)
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return zone_rect.position.x
	return clampf(to_local(result["position"]).x, zone_rect.position.x, zone_rect.end.x)


func _draw() -> void:
	var zone_rect := _zone_rect()
	draw_rect(zone_rect, VISUAL_SHADE)
	_draw_blowing_wind(zone_rect)
	_draw_phase_label(zone_rect)


func _draw_phase_label(zone_rect: Rect2) -> void:
	var label_rect := Rect2(zone_rect.position + Vector2(0.0, -28.0), Vector2(zone_rect.size.x, 24.0))
	draw_rect(label_rect, Color(0.05, 0.06, 0.055, 0.82))
	draw_string(ThemeDB.fallback_font, label_rect.position + Vector2(0.0, 18.0), "<<< 强风 · 扎根抗风 <<<", HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x, 17, VISUAL_INK)


func _draw_blowing_wind(zone_rect: Rect2) -> void:
	var border_pulse := (sin(_visual_elapsed * TAU * 4.0) + 1.0) * 0.5
	draw_rect(zone_rect, Color(VISUAL_INK, 0.58 + border_pulse * 0.22), false, 3.0)
	for streak_index: int in range(WIND_STREAK_COUNT):
		var travel := fmod(_visual_elapsed * (250.0 + float(streak_index % 3) * 35.0) + float(streak_index) * 67.0, zone_rect.size.x + 150.0)
		var head_x := zone_rect.end.x + 55.0 - travel
		var lane_y := zone_rect.position.y + (float(streak_index) + 1.0) * zone_rect.size.y / float(WIND_STREAK_COUNT + 1) + sin(_visual_elapsed * 7.0 + float(streak_index)) * 3.0
		var streak_length := 54.0 + float(streak_index % 4) * 13.0
		_draw_wind_streak(Vector2(head_x, lane_y), streak_length, _visual_left_bounds[streak_index], streak_index, zone_rect)


func _draw_wind_streak(head: Vector2, length: float, left_bound: float, index: int, zone_rect: Rect2) -> void:
	var right_bound := zone_rect.end.x - 7.0
	var tail_x := head.x + length
	var clipped_head_x := clampf(head.x, left_bound, right_bound)
	var clipped_tail_x := clampf(tail_x, left_bound, right_bound)
	if absf(clipped_head_x - clipped_tail_x) < 4.0:
		return
	var strength := 0.48 + float(index % 3) * 0.16
	var streak_color := Color(VISUAL_INK, strength)
	var stroke_width := 2.0 + float(index % 2)
	draw_line(Vector2(clipped_tail_x, head.y), Vector2(clipped_head_x, head.y), streak_color, stroke_width)
	if head.x < left_bound or head.x > right_bound:
		return
	var arrow_back := head.x + 12.0
	draw_line(head, Vector2(arrow_back, head.y - 5.0), streak_color, stroke_width)
	draw_line(head, Vector2(arrow_back, head.y + 5.0), streak_color, stroke_width)


func _zone_rect() -> Rect2:
	return Rect2(Vector2.ZERO, zone_size)


func _is_world_point_blocked(world_point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_point
	query.collision_mask = WORLD_COLLISION_MASK
	return not get_world_2d().direct_space_state.intersect_point(query).is_empty()


func _update_collision_shape() -> void:
	if not is_instance_valid(_collision_shape):
		return
	var shape := _collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		_collision_shape.shape = shape
	shape.size = zone_size
	_collision_shape.position = zone_size * 0.5


func _make_collision_shape_unique() -> void:
	if is_instance_valid(_collision_shape) and _collision_shape.shape != null:
		_collision_shape.shape = _collision_shape.shape.duplicate(true)
