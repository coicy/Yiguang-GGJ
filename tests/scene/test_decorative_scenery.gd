extends SceneTree

const DECORATIVE_SCENE: PackedScene = preload("res://features/level/handbuilt/decorative_scenery.tscn")
const GRASS_TURF_VARIANTS: SpriteVariantSet = preload("res://assets/runtime/scenery/variants/grass_turf_variants.tres")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scenery := DECORATIVE_SCENE.instantiate() as DecorativeScenery
	root.add_child(scenery)
	await process_frame

	assert(scenery.sprite_variants == null, "The reusable component must not bind a specific sprite set.")
	assert(scenery.get_artwork() != null, "The component must provide one persistent Artwork node.")
	assert(scenery.get_tiled_artwork() != null, "The component must provide one persistent tiled renderer.")
	assert(scenery.get_artwork().texture == null, "An unconfigured decoration must remain visually empty.")

	scenery.position = Vector2(120.0, 80.0)
	scenery.scale = Vector2(0.5, 0.5)
	scenery.set_variant_set(GRASS_TURF_VARIANTS, 1)
	await process_frame
	await process_frame

	assert(scenery.get_artwork().texture == GRASS_TURF_VARIANTS.variants[1].texture)
	assert(scenery.position == Vector2(120.0, 80.0), "Changing art must not move the component instance.")
	assert(scenery.scale == Vector2(0.5, 0.5), "Changing art must not resize the component instance.")

	scenery.variant_index = 2
	scenery.flip_h = true
	await process_frame
	await process_frame
	assert(scenery.get_artwork().texture == GRASS_TURF_VARIANTS.variants[2].texture)
	assert(scenery.get_artwork().flip_h, "Flip settings must be applied to Artwork.")

	scenery.flip_h = false
	scenery.layout_mode = DecorativeScenery.LayoutMode.GRID
	scenery.tile_count = Vector2i(3, 2)
	scenery.tile_spacing = Vector2(-8.0, -4.0)
	await process_frame
	await process_frame
	assert(not scenery.get_artwork().visible, "Grid mode must hide the single-sprite renderer.")
	if Engine.is_editor_hint():
		assert(scenery.get_preview_tile_count() == 6, "The editor must create six visible preview sprites for a 3 by 2 grid.")
		assert(not scenery.get_tiled_artwork().visible, "The runtime MultiMesh must stay hidden in the editor.")
	else:
		assert(scenery.get_tiled_artwork().visible, "Grid mode must show the tiled renderer at runtime.")
		assert(scenery.get_tiled_artwork().texture == GRASS_TURF_VARIANTS.variants[2].texture)
		assert(scenery.get_tiled_artwork().multimesh != null)
		assert(scenery.get_tiled_artwork().multimesh.instance_count == 6, "A 3 by 2 grid must create six batched instances.")
	var expected_step_x := GRASS_TURF_VARIANTS.variants[2].texture.get_width() - 8.0
	assert(is_equal_approx(scenery.get_tile_step().x, expected_step_x), "Tile spacing must follow scaled texture width automatically.")

	scenery.queue_free()
	await process_frame
	quit()
