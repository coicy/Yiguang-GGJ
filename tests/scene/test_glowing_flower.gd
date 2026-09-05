extends SceneTree

const FLOWER_SCENE: PackedScene = preload("res://features/level/handbuilt/glowing_flower.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var flower := FLOWER_SCENE.instantiate() as Node2D
	root.add_child(flower)
	await process_frame

	var decoration := flower.get_node("Decoration") as DecorativeScenery
	var glow_edge := flower.get_node("GlowEdge") as Sprite2D
	var light := flower.get_node("FlowerLight") as PointLight2D
	assert(decoration != null)
	assert(glow_edge != null)
	assert(glow_edge.texture != null)
	assert(glow_edge.scale.x > decoration.scale.x, "The flower edge glow must extend beyond the artwork.")
	assert(glow_edge.modulate.a > 0.0)
	assert(decoration.variant_index == 1, "Glowing flowers must use the red flower decoration variant.")
	assert(decoration.get_artwork().texture != null)
	assert(light != null)
	assert(light.shadow_enabled, "Flower lights must respect solid-wall occlusion.")
	assert(light.texture != null)

	flower.queue_free()
	await process_frame
	quit()
