class_name VineVisual
extends Node2D
## Presentation only: animates casts while AbilityController owns attachment and physics.

signal latched

const IDLE: StringName = &"idle"
const FLYING: StringName = &"flying"
const ATTACHED: StringName = &"attached"
const RETURNING: StringName = &"returning"
const OUTLINE := Color("#263d25")
const STEM := Color("#88af50")
const HIGHLIGHT := Color("#d1e88b")

@export var launch_speed: float = 1400.0
@export var return_speed: float = 1900.0
@export var minimum_flight_time: float = 0.12
@export var maximum_flight_time: float = 0.25
@export var impact_duration: float = 0.20

var _phase: StringName = IDLE
var _hand_world := Vector2.ZERO
var _tip_world := Vector2.ZERO
var _start_world := Vector2.ZERO
var _target_world := Vector2.ZERO
var _anchor: Node2D
var _will_attach: bool = false
var _elapsed: float = 0.0
var _duration: float = 0.2
var _impact_left: float = 0.0
var _launch_left: float = 0.0

func set_hand_position(world_position: Vector2) -> void:
	_hand_world = world_position

func set_anchor(anchor: Node2D) -> void:
	if _anchor == anchor:
		return
	_anchor = anchor
	if anchor == null and _phase in [FLYING, ATTACHED] and _will_attach:
		_begin_return()

func fire(target_world: Vector2, will_attach: bool) -> void:
	_start_world = _hand_world
	_tip_world = _hand_world
	_target_world = target_world
	_will_attach = will_attach
	_elapsed = 0.0
	_duration = clampf(_start_world.distance_to(target_world) / maxf(launch_speed, 1.0), minimum_flight_time, maximum_flight_time)
	_impact_left = 0.0
	_launch_left = 0.10
	_phase = FLYING
	queue_redraw()

func clear() -> void:
	_phase = IDLE
	_anchor = null
	_will_attach = false
	_impact_left = 0.0
	_launch_left = 0.0
	queue_redraw()

func phase() -> StringName:
	return _phase

func tip_global_position() -> Vector2:
	return _tip_world

func _process(delta: float) -> void:
	if _phase == IDLE:
		return
	_elapsed += delta
	_launch_left = maxf(0.0, _launch_left - delta)
	_impact_left = maxf(0.0, _impact_left - delta)
	match _phase:
		FLYING:
			if _will_attach:
				if not is_instance_valid(_anchor):
					_begin_return()
					queue_redraw()
					return
				_target_world = _anchor.global_position
			var progress := clampf(_elapsed / _duration, 0.0, 1.0)
			_tip_world = _start_world.lerp(_target_world, 1.0 - pow(1.0 - progress, 1.5))
			if progress >= 1.0:
				if _will_attach:
					_phase = ATTACHED
					_elapsed = 0.0
					_impact_left = impact_duration
					latched.emit()
				else:
					_begin_return()
		ATTACHED:
			if is_instance_valid(_anchor):
				_tip_world = _anchor.global_position
			else:
				_begin_return()
		RETURNING:
			var progress := clampf(_elapsed / _duration, 0.0, 1.0)
			_tip_world = _start_world.lerp(_hand_world, progress * progress)
			if progress >= 1.0:
				clear()
	queue_redraw()

func _begin_return() -> void:
	_start_world = _tip_world
	_duration = clampf(_tip_world.distance_to(_hand_world) / maxf(return_speed, 1.0), 0.08, 0.20)
	_elapsed = 0.0
	_will_attach = false
	_impact_left = 0.0
	_phase = RETURNING

func _draw() -> void:
	if _phase == IDLE:
		return
	var hand := to_local(_hand_world)
	var tip := to_local(_tip_world)
	var direction := (tip - hand).normalized()
	if direction.is_zero_approx():
		direction = (to_local(_target_world) - hand).normalized()
	var normal := direction.orthogonal()
	var distance := hand.distance_to(tip)
	var amplitude := minf(7.0, distance * 0.05)
	if _phase == ATTACHED:
		amplitude *= clampf(_impact_left / maxf(impact_duration, 0.01), 0.0, 1.0)
	elif _phase == RETURNING:
		amplitude *= 0.65
	var points := PackedVector2Array()
	for index: int in range(25):
		var fraction := float(index) / 24.0
		var wave := sin(fraction * TAU * 1.5 - _elapsed * 32.0) * sin(fraction * PI) * amplitude
		points.append(hand.lerp(tip, fraction) + normal * wave)
	if distance > 0.1:
		draw_polyline(points, OUTLINE, 4.5, true)
		draw_polyline(points, STEM, 2.5, true)
		draw_polyline(points, Color(HIGHLIGHT, 0.5), 0.8, true)
	if _phase == FLYING:
		# A leading bud and short speed streaks make the moving front unmistakable.
		_draw_bud(tip, direction, 7.0)
		for side: float in [-1.0, 1.0]:
			draw_line(tip - direction * 7.0 + normal * side * 5.0, tip - direction * 20.0 + normal * side * 7.0, Color(HIGHLIGHT, 0.7), 1.2, true)
	elif _phase == ATTACHED:
		draw_arc(tip, 14.0, -0.7, TAU - 0.3, 28, STEM, 2.5, true)
		_draw_bud(tip + Vector2(10.0, -12.0), Vector2(0.7, -0.7), 5.0)
		if _impact_left > 0.0:
			_draw_impact(tip)
	else:
		_draw_bud(tip, -direction, 4.0)
	if _launch_left > 0.0:
		var alpha := _launch_left / 0.10
		for index: int in range(3):
			var ray := direction.rotated((index - 1) * 0.5)
			draw_line(hand + ray * 3.0, hand + ray * 11.0, Color(HIGHLIGHT, alpha), 1.5, true)

func _draw_bud(tip: Vector2, direction: Vector2, length: float) -> void:
	var normal := direction.orthogonal()
	var shape := PackedVector2Array([tip + direction * length, tip + normal * length * 0.5, tip - direction * length * 0.6, tip - normal * length * 0.5, tip + direction * length])
	draw_colored_polygon(shape, STEM)
	draw_polyline(shape, OUTLINE, 1.2, true)
	draw_line(tip - direction * length * 0.4, tip + direction * length * 0.8, HIGHLIGHT, 1.0, true)

func _draw_impact(tip: Vector2) -> void:
	var progress := 1.0 - _impact_left / maxf(impact_duration, 0.01)
	var alpha := 1.0 - progress
	draw_arc(tip, 16.0 + progress * 10.0, 0.0, TAU, 28, Color(HIGHLIGHT, alpha), 1.5, true)
	for index: int in range(6):
		var direction := Vector2.RIGHT.rotated(float(index) * TAU / 6.0)
		var start := tip + direction * (17.0 + progress * 10.0)
		draw_line(start, start + direction * 4.0, Color(HIGHLIGHT, alpha), 1.7, true)
