class_name ToxinZone
extends Area2D

@export var zone_size: Vector2 = Vector2(128.0, 64.0)
@export var show_whitebox_visual: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

signal actor_entered(actor: Node2D)
signal actor_exited(actor: Node2D)


var _actors_inside: Array[Node2D] = []


func _ready() -> void:
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle = rectangle.duplicate() as RectangleShape2D
		collision_shape.shape = rectangle
		rectangle.size = zone_size
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


func is_actor_inside(actor: Node2D) -> bool:
	return _actors_inside.has(actor)


func _on_body_entered(actor: Node2D) -> void:
	if _actors_inside.has(actor):
		return

	_actors_inside.append(actor)
	actor_entered.emit(actor)


func _on_body_exited(actor: Node2D) -> void:
	if not _actors_inside.has(actor):
		return

	_actors_inside.erase(actor)
	actor_exited.emit(actor)


func _draw() -> void:
	if not show_whitebox_visual:
		return
	draw_rect(Rect2(-zone_size * 0.5, zone_size), Color(1.0, 0.2, 0.9, 0.62))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-zone_size.x * 0.5 + 3.0, 5.0),
		"TOXIN",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		12,
		Color.WHITE
	)
