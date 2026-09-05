class_name WhiteboxButton
extends Area2D
## A one-shot whitebox button. It latches after a player contact until level reset.

signal pressed(button: WhiteboxButton, actor: Node2D)

@export var button_size: Vector2 = Vector2(16.0, 16.0):
	set(value):
		button_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_update_shape()

@export_range(0.0, 16.0, 1.0) var activation_top_margin: float = 6.0

var _is_pressed: bool = false

@onready var _collision_shape: CollisionShape2D = %CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_make_collision_shape_unique()
	_update_shape()
	queue_redraw()


func press(actor: Node2D = null) -> bool:
	if _is_pressed:
		return false
	_is_pressed = true
	pressed.emit(self, actor)
	queue_redraw()
	return true


func reset_button() -> void:
	if not _is_pressed:
		return
	_is_pressed = false
	queue_redraw()


func is_pressed() -> bool:
	return _is_pressed


func _on_body_entered(actor: Node2D) -> void:
	if actor != null and actor.is_in_group(&"player"):
		press(actor)


func _update_shape() -> void:
	if not is_instance_valid(_collision_shape):
		return
	var shape := _collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		_collision_shape.shape = shape
	shape.size = Vector2(button_size.x, button_size.y + activation_top_margin)
	_collision_shape.position = Vector2(button_size.x * 0.5, button_size.y * 0.5 - activation_top_margin * 0.5)


func _make_collision_shape_unique() -> void:
	if is_instance_valid(_collision_shape) and _collision_shape.shape != null:
		_collision_shape.shape = _collision_shape.shape.duplicate(true)


func _draw() -> void:
	var fill := Color("#86d96d") if _is_pressed else Color("#e0bc43")
	draw_rect(Rect2(Vector2.ZERO, button_size), fill)
	draw_rect(Rect2(Vector2.ZERO, button_size), Color("#1c251d"), false, 2.0)
