extends SceneTree

const TERRAIN_SCENE: PackedScene = preload("res://features/level/handbuilt/terrain_piece.tscn")
const HARD_FLOOR_SCENE: PackedScene = preload("res://features/level/handbuilt/hard_floor_piece.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var terrain := TERRAIN_SCENE.instantiate() as TerrainPiece
	root.add_child(terrain)
	await process_frame
	assert(terrain.can_root())
	assert(not (terrain.get_node("CollisionShape2D") as CollisionShape2D).disabled)
	assert((terrain.get_node("CollisionPolygon2D") as CollisionPolygon2D).disabled)
	terrain.display_mode = TerrainPiece.DisplayMode.POLYGON
	terrain.collision_mode = TerrainPiece.CollisionMode.POLYGON
	var visual := terrain.get_node("PolygonArtwork") as Polygon2D
	visual.polygon = PackedVector2Array([Vector2(0, 48), Vector2(192, 0), Vector2(192, 48)])
	assert(terrain.sync_polygons())
	await process_frame
	var collision := terrain.get_node("CollisionPolygon2D") as CollisionPolygon2D
	assert(not collision.disabled)
	assert(collision.polygon == visual.polygon)
	assert((terrain.get_node("CollisionShape2D") as CollisionShape2D).disabled)
	terrain.one_way_collision = true
	await process_frame
	assert(collision.one_way_collision)

	var hard_floor := HARD_FLOOR_SCENE.instantiate() as TerrainPiece
	root.add_child(hard_floor)
	await process_frame
	assert(not hard_floor.can_root())
	assert(hard_floor.display_mode == TerrainPiece.DisplayMode.SPRITE)
	assert(hard_floor.collision_mode == TerrainPiece.CollisionMode.RECTANGLE)
	terrain.queue_free()
	hard_floor.queue_free()
	quit()
