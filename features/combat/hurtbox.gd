class_name Hurtbox
extends Area2D
var receiver: Node2D
func configure(actor: Node2D, layer: int, body_size: Vector2) -> void:
	receiver = actor
	collision_layer = layer
	collision_mask = 0
	monitoring = false
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = body_size
	shape_node.shape = shape
	shape_node.position.y = -body_size.y * 0.5
	add_child(shape_node)
func resize(body_size: Vector2, offset: Vector2) -> void:
	var shape_node := get_child(0) as CollisionShape2D
	(shape_node.shape as RectangleShape2D).size = body_size
	shape_node.position = Vector2(0.0, -body_size.y * 0.5) + offset
func deliver(request: DamageRequest) -> int:
	if not is_instance_valid(receiver) or not receiver.has_method(&"receive_damage"):
		return DamageRequest.Result.IGNORED
	return int(receiver.call(&"receive_damage", request))

func world_center() -> Vector2:
	return (get_child(0) as CollisionShape2D).global_position
