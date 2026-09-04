class_name WhiteboxMovingCube
extends AnimatableBody2D
## Designer-tunable whitebox moving geometry controlled by a latching switch.

@export var size: Vector2 = Vector2(64.0, 64.0)
@export var active_offset: Vector2 = Vector2.ZERO
@export var move_speed: float = 240.0

@onready var collision_shape: CollisionShape2D = %CollisionShape2D

var _rest_position: Vector2
var _target_position: Vector2
var _active: bool = false


func _ready() -> void:
	_rest_position = position
	_target_position = position
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision_shape.shape = rectangle
	else:
		rectangle = rectangle.duplicate() as RectangleShape2D
		collision_shape.shape = rectangle
	rectangle.size = size
	queue_redraw()


func _physics_process(delta: float) -> void:
	position = position.move_toward(_target_position, move_speed * delta)


func bind_switch(source_switch: Node) -> void:
	if source_switch != null and source_switch.has_signal(&"activated"):
		source_switch.connect(&"activated", activate)
	if source_switch != null and source_switch.has_method(&"is_active"):
		set_active(bool(source_switch.call(&"is_active")), true)


func activate() -> void:
	set_active(true)


func set_active(active: bool, snap: bool = false) -> void:
	_active = active
	_target_position = _rest_position + active_offset if active else _rest_position
	if snap:
		position = _target_position
	queue_redraw()


func is_active() -> bool:
	return _active


func _draw() -> void:
	var color := Color("#f0b27a") if not _active else Color("#ffd29f")
	draw_rect(Rect2(-size * 0.5, size), color)
	draw_rect(Rect2(-size * 0.5, size), Color("#6e432b"), false, 3.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-size.x * 0.5 + 6.0, 5.0),
		"MOVE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		12,
		Color("#4a2b1e")
	)
