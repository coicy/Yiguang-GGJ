extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://features/level/toxin_zone.tscn") as PackedScene
	var zone := scene.instantiate() as Area2D
	var collision := zone.get_node("CollisionShape2D") as CollisionShape2D
	collision.shape = collision.shape.duplicate(true)
	(collision.shape as RectangleShape2D).size = Vector2(640, 280)
	collision.position = Vector2(320, 140)
	zone.position = Vector2(320, 240)
	root.add_child(zone)
	var fog := zone.get_node("PoisonFog/Fog") as ColorRect
	assert(fog.size == Vector2(640, 280), "Fog must fit configured zone dimensions")
	assert(fog.position == Vector2.ZERO, "Fog must match the collision offset")
	var other := scene.instantiate() as Area2D
	root.add_child(other)
	var other_fog := other.get_node("PoisonFog/Fog") as ColorRect
	assert(fog.material != other_fog.material, "Instances must have independent tuning")
	other.queue_free()
	await create_timer(1.0).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://.godot/poison_fog_preview.png") == OK)
	print("PASS: poison fog bounds and material isolation")
	quit()
