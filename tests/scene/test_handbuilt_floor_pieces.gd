extends SceneTree

const TERRAIN_SCENE: PackedScene = preload("res://features/level/handbuilt/terrain_piece.tscn")
const HARD_FLOOR_SCENE: PackedScene = preload("res://features/level/handbuilt/hard_floor_piece.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_root_texture_drives_both_artwork_modes()
	await _verify_root_scale_expands_tiled_visual_and_collision()
	await _verify_whole_texture_scales_with_collision()
	await _verify_rect_polygon_layout_tracks_piece_size()
	await _verify_polygon_repeat_offset_is_instance_local()
	await _verify_polygon_collision_syncs_on_scene_load()
	await _verify_independent_polygon_collision_is_preserved()
	await _verify_untextured_polygon_keeps_valid_collision()
	await _verify_one_way_collision_is_polygon_only()
	await _verify_hard_floor_defaults()
	quit()


func _verify_root_texture_drives_both_artwork_modes() -> void:
	var terrain := TERRAIN_SCENE.instantiate() as TerrainPiece
	var root_texture := GradientTexture2D.new()
	root_texture.width = 16
	root_texture.height = 16
	terrain.sprite_variants = null
	terrain.art_texture = root_texture
	terrain.display_mode = TerrainPiece.DisplayMode.SPRITE
	root.add_child(terrain)
	await process_frame
	var nine_patch := terrain.get_node("TerrainVisual") as NinePatchRect
	var polygon_artwork := terrain.get_node("PolygonArtwork") as Polygon2D
	assert(terrain.art_texture == root_texture)
	assert(nine_patch.texture == root_texture)
	assert(nine_patch.visible)
	assert(nine_patch.size == terrain.piece_size)
	assert(nine_patch.patch_margin_left == 64)
	assert(nine_patch.patch_margin_right == 64)
	terrain.piece_size = Vector2(384.0, 96.0)
	await process_frame
	assert(nine_patch.size == terrain.piece_size)

	terrain.display_mode = TerrainPiece.DisplayMode.POLYGON
	await process_frame
	assert(polygon_artwork.texture == root_texture)
	assert(polygon_artwork.visible)
	assert(not nine_patch.visible)
	var variant_texture := GradientTexture2D.new()
	variant_texture.width = 8
	variant_texture.height = 8
	var variant := LevelSpriteVariant.new()
	variant.texture = variant_texture
	var variants := SpriteVariantSet.new()
	variants.variants = [variant]
	terrain.sprite_variants = variants
	await process_frame
	assert(polygon_artwork.texture == variant_texture)
	terrain.queue_free()


func _verify_root_scale_expands_tiled_visual_and_collision() -> void:
	var terrain := TERRAIN_SCENE.instantiate() as TerrainPiece
	terrain.sprite_variants = null
	terrain.art_texture = _test_texture(16)
	terrain.scale = Vector2(2.0, 0.5)
	root.add_child(terrain)
	await process_frame
	var visual := terrain.get_node("TerrainVisual") as NinePatchRect
	var collision := terrain.get_node("CollisionPolygon2D") as CollisionPolygon2D
	assert(terrain.scale == Vector2.ONE)
	assert(terrain.piece_size == Vector2(384.0, 24.0))
	assert(visual.size == terrain.piece_size)
	assert(collision.polygon == _rectangle_polygon(terrain.piece_size))
	terrain.queue_free()


func _verify_whole_texture_scales_with_collision() -> void:
	var terrain := TERRAIN_SCENE.instantiate() as TerrainPiece
	terrain.sprite_variants = null
	terrain.art_texture = _test_texture(16)
	terrain.piece_size = Vector2(16.0, 16.0)
	terrain.display_mode = TerrainPiece.DisplayMode.WHOLE_TEXTURE
	terrain.scale = Vector2(0.5, 0.5)
	root.add_child(terrain)
	await process_frame

	var whole_artwork := terrain.get_node("WholeArtwork") as Sprite2D
	var collision := terrain.get_node("CollisionPolygon2D") as CollisionPolygon2D
	assert(terrain.scale.is_equal_approx(Vector2(0.5, 0.5)))
	assert(whole_artwork.visible and whole_artwork.texture == terrain.art_texture)
	assert(whole_artwork.global_transform.get_scale().is_equal_approx(Vector2(0.5, 0.5)))
	assert(collision.global_transform.get_scale().is_equal_approx(Vector2(0.5, 0.5)))
	terrain.queue_free()


func _verify_rect_polygon_layout_tracks_piece_size() -> void:
	var terrain := TERRAIN_SCENE.instantiate() as TerrainPiece
	terrain.sprite_variants = null
	terrain.art_texture = _test_texture(16)
	terrain.display_mode = TerrainPiece.DisplayMode.POLYGON
	terrain.collision_mode = TerrainPiece.CollisionMode.POLYGON
	terrain.polygon_layout = TerrainPiece.PolygonLayout.RECT_FROM_PIECE_SIZE
	terrain.piece_size = Vector2(384.0, 96.0)
	terrain.art_scale_multiplier = 0.5
	root.add_child(terrain)
	await process_frame
	var visual := terrain.get_node("PolygonArtwork") as Polygon2D
	var collision := terrain.get_node("CollisionPolygon2D") as CollisionPolygon2D
	assert(terrain.display_mode == TerrainPiece.DisplayMode.POLYGON)
	assert(visual.polygon == _rectangle_polygon(Vector2(384.0, 96.0)))
	assert(collision.polygon == visual.polygon)
	assert(visual.texture_scale == Vector2(2.0, 2.0))

	terrain.piece_size = Vector2(576.0, 64.0)
	await process_frame
	assert(visual.polygon == _rectangle_polygon(Vector2(576.0, 64.0)))
	assert(collision.polygon == visual.polygon)
	terrain.queue_free()


func _verify_polygon_repeat_offset_is_instance_local() -> void:
	var terrain := TERRAIN_SCENE.instantiate() as TerrainPiece
	var variant := LevelSpriteVariant.new()
	variant.texture = _test_texture(16)
	var left_cap_texture := _test_texture(12)
	var right_cap_texture := _test_texture(20)
	variant.left_cap_texture = left_cap_texture
	variant.right_cap_texture = right_cap_texture
	variant.polygon_texture_offset = Vector2(12.0, 8.0)
	variant.polygon_texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var variants := SpriteVariantSet.new()
	variants.variants = [variant]
	terrain.sprite_variants = variants
	terrain.display_mode = TerrainPiece.DisplayMode.POLYGON
	terrain.polygon_repeat_offset = Vector2(-192.0, 4.0)
	terrain.art_offset = Vector2(3.0, -2.0)
	terrain.art_scale_multiplier = 0.5
	root.add_child(terrain)
	await process_frame
	var visual := terrain.get_node("PolygonArtwork") as Polygon2D
	var left_cap := terrain.get_node("LeftCap") as Sprite2D
	var right_cap := terrain.get_node("RightCap") as Sprite2D
	assert(visual.texture == variant.texture)
	assert(visual.texture_offset == Vector2(-177.0, 10.0))
	assert(visual.texture_scale == Vector2(2.0, 2.0))
	assert(visual.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED)
	assert(left_cap.texture == left_cap_texture)
	assert(right_cap.texture == right_cap_texture)
	assert(left_cap.visible)
	assert(right_cap.visible)

	terrain.polygon_repeat_offset = Vector2(-384.0, -8.0)
	await process_frame
	assert(visual.texture_offset == Vector2(-369.0, -2.0))
	assert(variant.polygon_texture_offset == Vector2(12.0, 8.0))
	terrain.queue_free()


func _verify_polygon_collision_syncs_on_scene_load() -> void:
	var terrain := TERRAIN_SCENE.instantiate() as TerrainPiece
	terrain.display_mode = TerrainPiece.DisplayMode.POLYGON
	terrain.collision_mode = TerrainPiece.CollisionMode.POLYGON
	terrain.polygon_layout = TerrainPiece.PolygonLayout.CUSTOM_POLYGON
	var visual := terrain.get_node("PolygonArtwork") as Polygon2D
	visual.polygon = _slope_polygon()
	root.add_child(terrain)
	await process_frame
	var collision := terrain.get_node("CollisionPolygon2D") as CollisionPolygon2D
	assert(terrain.collision_follows_visual)
	assert(collision.polygon == visual.polygon)
	assert(not collision.disabled)
	terrain.queue_free()


func _verify_independent_polygon_collision_is_preserved() -> void:
	var terrain := TERRAIN_SCENE.instantiate() as TerrainPiece
	terrain.display_mode = TerrainPiece.DisplayMode.POLYGON
	terrain.collision_mode = TerrainPiece.CollisionMode.POLYGON
	terrain.collision_follows_visual = false
	terrain.polygon_layout = TerrainPiece.PolygonLayout.CUSTOM_POLYGON
	var visual := terrain.get_node("PolygonArtwork") as Polygon2D
	var collision := terrain.get_node("CollisionPolygon2D") as CollisionPolygon2D
	visual.polygon = _slope_polygon()
	var independent_collision := PackedVector2Array([Vector2(0, 24), Vector2(192, 24), Vector2(192, 48), Vector2(0, 48)])
	collision.polygon = independent_collision
	root.add_child(terrain)
	await process_frame
	assert(not terrain.collision_follows_visual)
	assert(collision.polygon == independent_collision)
	assert(collision.polygon != visual.polygon)
	assert(not collision.disabled)
	terrain.queue_free()


func _verify_untextured_polygon_keeps_valid_collision() -> void:
	var terrain := TERRAIN_SCENE.instantiate() as TerrainPiece
	terrain.sprite_variants = null
	terrain.art_texture = null
	terrain.display_mode = TerrainPiece.DisplayMode.POLYGON
	terrain.collision_mode = TerrainPiece.CollisionMode.POLYGON
	terrain.polygon_layout = TerrainPiece.PolygonLayout.CUSTOM_POLYGON
	var visual := terrain.get_node("PolygonArtwork") as Polygon2D
	visual.polygon = _slope_polygon()
	root.add_child(terrain)
	await process_frame
	var collision := terrain.get_node("CollisionPolygon2D") as CollisionPolygon2D
	assert(visual.texture == null)
	assert(not visual.visible)
	assert(not Geometry2D.triangulate_polygon(collision.polygon).is_empty())
	assert(collision.polygon == visual.polygon)
	assert(not collision.disabled)
	terrain.queue_free()


func _verify_one_way_collision_is_polygon_only() -> void:
	var terrain := TERRAIN_SCENE.instantiate() as TerrainPiece
	terrain.display_mode = TerrainPiece.DisplayMode.POLYGON
	terrain.collision_mode = TerrainPiece.CollisionMode.POLYGON
	terrain.one_way_collision = true
	root.add_child(terrain)
	await process_frame
	var collision := terrain.get_node("CollisionPolygon2D") as CollisionPolygon2D
	assert(collision.one_way_collision)

	terrain.collision_mode = TerrainPiece.CollisionMode.RECTANGLE
	await process_frame
	var warnings: PackedStringArray = terrain._get_configuration_warnings()
	assert(not collision.one_way_collision)
	assert(not warnings.is_empty())
	assert(warnings[0].contains("only applies when Collision Mode is Polygon"))
	terrain.queue_free()


func _verify_hard_floor_defaults() -> void:
	var hard_floor := HARD_FLOOR_SCENE.instantiate() as TerrainPiece
	root.add_child(hard_floor)
	await process_frame
	assert(not hard_floor.can_root())
	assert(hard_floor.display_mode == TerrainPiece.DisplayMode.SPRITE)
	assert(hard_floor.collision_mode == TerrainPiece.CollisionMode.RECTANGLE)
	hard_floor.queue_free()


func _slope_polygon() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 48), Vector2(96, 8), Vector2(192, 0), Vector2(192, 48)])


func _rectangle_polygon(size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
	])


func _test_texture(size: int) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.width = size
	texture.height = size
	return texture
