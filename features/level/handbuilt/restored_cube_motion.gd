@tool
extends MoveableCube
## Scene-local destination motion, including rotation after a nonuniform layout mapping.

## The destination is authored in the UpperEntities coordinate space.
@export var target_rect: Rect2
@export var target_reference_path: NodePath = ^"../.."
@export_range(0.0, 90.0, 90.0) var target_rotation_degrees: float = 0.0


func activate() -> bool:
	if Engine.is_editor_hint() or not is_node_ready() or _activation_latched or is_moving():
		return false
	var reference: Node2D = get_node(target_reference_path) as Node2D
	var target_size: Vector2 = target_rect.size
	var target_origin: Vector2 = target_rect.position
	if is_equal_approx(target_rotation_degrees, 90.0):
		# A nonuniform mapping changes the local dimensions after rotation.
		target_size = Vector2(target_rect.size.y, target_rect.size.x)
		target_origin += Vector2(target_rect.size.x, 0.0)
	var local_target := Transform2D(deg_to_rad(target_rotation_degrees), target_origin)
	var world_target: Transform2D = reference.global_transform * local_target
	_activation_latched = true
	if not _begin_motion(world_target, target_size):
		_activation_latched = false
		return false
	return true


func get_target_world_rect() -> Rect2:
	var reference: Node2D = get_node(target_reference_path) as Node2D
	return reference.global_transform * target_rect


func _sync_artwork() -> void:
	super._sync_artwork()
	if not is_instance_valid(_artwork) or _artwork.texture == null:
		return
	# Fit only the visual; the reusable cube owns collision and physics motion.
	_artwork.scale = cube_size / _artwork.texture.get_size()
