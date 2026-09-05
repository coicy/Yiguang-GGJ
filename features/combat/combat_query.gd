class_name CombatQuery
extends RefCounted
const PLAYER_HURT: int = 256
const ENEMY_HURT: int = 512
static func targets(actor: Node2D, center: Vector2, size: Vector2, mask: int) -> Array[Hurtbox]:
	var shape := RectangleShape2D.new()
	shape.size = size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var found: Array[Hurtbox] = []
	for hit: Dictionary in actor.get_world_2d().direct_space_state.intersect_shape(query, 32):
		var hurt := hit.get("collider") as Hurtbox
		if hurt != null and is_instance_valid(hurt.receiver):
			found.append(hurt)
	return found
static func clear_path(actor: Node2D, start: Vector2, end: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(start, end, 1)
	if actor is CollisionObject2D:
		ray.exclude = [(actor as CollisionObject2D).get_rid()]
	return actor.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
