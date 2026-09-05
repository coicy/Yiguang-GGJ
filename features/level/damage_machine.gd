class_name DamageMachine
extends Area2D
## A reusable, instant-death horizontal hazard with explicit designer-tuned endpoints.

signal actor_killed(actor: Node2D)

@export var travel_distance: float = 32.0
@export var travel_speed: float = 64.0

var _origin_x: float = 0.0
var _direction: float = 1.0


func _ready() -> void:
	_origin_x = global_position.x
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	var next_x := global_position.x + _direction * travel_speed * delta
	var left_x := _origin_x - travel_distance
	var right_x := _origin_x + travel_distance
	if next_x >= right_x:
		next_x = right_x
		_direction = -1.0
	elif next_x <= left_x:
		next_x = left_x
		_direction = 1.0
	global_position.x = next_x


func _on_body_entered(actor: Node2D) -> void:
	actor_killed.emit(actor)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 8.0, Color("#d84b55"))
	draw_line(Vector2(-10.0, 0.0), Vector2(10.0, 0.0), Color("#ffeddc"), 2.0)
	draw_line(Vector2(0.0, -10.0), Vector2(0.0, 10.0), Color("#ffeddc"), 2.0)
