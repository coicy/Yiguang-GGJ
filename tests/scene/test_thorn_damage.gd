extends SceneTree

const THORN_DAMAGE_SCENE: PackedScene = preload("res://features/level/handbuilt/thorn_damage.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var thorn := THORN_DAMAGE_SCENE.instantiate() as Area2D
	assert(thorn != null, "ThornDamage scene must instantiate its script.")
	root.add_child(thorn)
	await process_frame

	assert(thorn.is_in_group(&"handbuilt_hazards"))
	var variant_set := thorn.get(&"sprite_variants") as SpriteVariantSet
	assert(variant_set != null)
	assert(variant_set.variants.size() == 3)
	assert(thorn.get_node("Artwork").visible)
	assert(not thorn.get_node("CollisionPolygon2D").disabled)

	var hurt_events := [0]
	var killed_events := [0]
	var damage_received := [0.0]
	thorn.connect(&"actor_hurt", func(_actor: Node2D, amount: float) -> void:
		hurt_events[0] += 1
		damage_received[0] = amount
	)
	thorn.connect(&"actor_killed", func(_actor: Node2D) -> void: killed_events[0] += 1)
	var actor := Node2D.new()
	root.add_child(actor)
	thorn.call(&"_on_body_entered", actor)
	assert(hurt_events[0] == 1)
	assert(killed_events[0] == 1)
	assert(is_equal_approx(damage_received[0], float(thorn.get(&"damage_amount"))))

	thorn.scale = Vector2(0.5, 0.75)
	await process_frame
	var artwork := thorn.get_node("Artwork") as Sprite2D
	var collision := thorn.get_node("CollisionPolygon2D") as CollisionPolygon2D
	assert(is_equal_approx(artwork.global_scale.x, collision.global_scale.x))
	assert(is_equal_approx(artwork.global_scale.y, collision.global_scale.y))

	actor.free()
	thorn.free()
	quit()
