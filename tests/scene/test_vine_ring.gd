extends SceneTree

const RING_SCENE: PackedScene = preload("res://features/abilities/vine_ring.tscn")
const PLAYER_SCENE: PackedScene = preload("res://features/player/player.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ring := RING_SCENE.instantiate() as Node2D
	root.add_child(ring)
	ring.global_position = Vector2.ZERO
	await physics_frame

	assert(ring.is_in_group("vine_anchor"), "The ring tip must remain a vine anchor target.")
	var hook_shape := ring.get_node("HookArea/HookCollision").shape as CircleShape2D
	assert(is_equal_approx(hook_shape.radius, 10.0), "The default hook target must be a small area.")
	assert(not bool(ring.call(&"is_hook_prompt_visible")), "The mature prompt starts hidden.")

	var player := PLAYER_SCENE.instantiate() as Player
	root.add_child(player)
	player.global_position = Vector2(0.0, 80.0)
	await physics_frame
	assert(player.form_controller.restore_form(&"mature"))
	await physics_frame
	assert(bool(ring.call(&"is_hook_prompt_visible")), "A nearby mature player must see the hook prompt.")

	assert(player.form_controller.restore_form(&"sprout"))
	await physics_frame
	assert(not bool(ring.call(&"is_hook_prompt_visible")), "Early forms must not see the mature hook prompt.")

	player.queue_free()
	ring.queue_free()
	print("Vine ring scene checks passed.")
	quit()
