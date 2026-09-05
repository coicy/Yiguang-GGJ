class_name WhiteboxDoor
extends MoveableCube
## A solid door that latches open after a button command.

signal opened

enum OpeningMode { SLIDE, ROTATE }

@export var opening_mode: OpeningMode = OpeningMode.SLIDE
@export var open_offset: Vector2 = Vector2(0.0, -48.0)
@export var hinge_offset: Vector2 = Vector2.ZERO
@export_range(-180.0, 180.0, 1.0) var opening_degrees: float = 90.0

var _activated: bool = false
var _opened: bool = false


func _ready() -> void:
	super._ready()
	motion_completed.connect(_on_motion_completed)


func open() -> bool:
	if _activated:
		return false
	var started: bool = false
	match opening_mode:
		OpeningMode.SLIDE:
			started = move_top_left_to(to_global(open_offset))
		OpeningMode.ROTATE:
			started = rotate_clockwise_about(to_global(hinge_offset), opening_degrees)
	_activated = started
	return started


func is_open() -> bool:
	return _opened


func _on_motion_completed(_cube: MoveableCube) -> void:
	if not _activated or _opened:
		return
	_opened = true
	queue_redraw()
	opened.emit()


func _draw() -> void:
	draw_set_transform(_visual_offset)
	var fill: Color = Color("#65a575") if _opened else Color("#a77b53")
	draw_rect(Rect2(Vector2.ZERO, cube_size), fill)
	draw_rect(Rect2(Vector2.ZERO, cube_size), Color("#f0d9ad"), false, 2.0)
	draw_circle(cube_size * Vector2(0.75, 0.5), minf(cube_size.x, cube_size.y) * 0.08, Color("#f0d9ad"))
	draw_set_transform(Vector2.ZERO)
