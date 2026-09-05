extends SceneTree

const BRANCH_WALL_SCENE: PackedScene = preload("res://features/level/branch_wall.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var wall := BRANCH_WALL_SCENE.instantiate() as BranchWall
	root.add_child(wall)
	await process_frame

	assert(wall.collision_layer == 1)
	assert(wall.collision_mask == 2)
	var visual := wall.get_node("WallSprite") as Sprite2D
	assert(visual.texture.resource_path == "res://assets/runtime/scenery/branch_wall.png")
	assert(is_equal_approx(visual.rotation, PI * 0.5))
	var polygon_collider := wall.get_node("CollisionPolygon2D") as CollisionPolygon2D
	assert(polygon_collider.polygon.size() >= 3)
	assert(not Geometry2D.triangulate_polygon(polygon_collider.polygon).is_empty())
	var authored_outline := polygon_collider.polygon

	wall.wall_height = 360.0
	wall.wall_width = 60.0
	assert(visual.scale.is_equal_approx(Vector2(360.0 / 571.0, 60.0 / 105.0)))
	assert(polygon_collider.polygon == authored_outline, "Resizing art must not overwrite a hand-authored collision outline.")
	wall.queue_free()
	print("Branch wall scene checks passed.")
	quit()
