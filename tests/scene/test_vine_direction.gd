extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := preload("res://features/player/player.tscn").instantiate() as Player
	root.add_child(player)
	await physics_frame
	player.global_position = Vector2(200.0, 200.0)
	player.velocity = Vector2.ZERO
	assert(player.form_controller.restore_form(&"mature"))

	var off_direction_anchor := preload("res://features/abilities/vine_anchor.tscn").instantiate() as VineAnchor
	root.add_child(off_direction_anchor)
	off_direction_anchor.global_position = player.global_position + Vector2(40.0, -40.0)
	var aimed_anchor := preload("res://features/abilities/vine_anchor.tscn").instantiate() as VineAnchor
	root.add_child(aimed_anchor)
	aimed_anchor.global_position = player.global_position + Vector2(180.0, 0.0)

	var aim := InputEventMouseMotion.new()
	aim.position = aimed_anchor.global_position
	player._unhandled_input(aim)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Q
	event.pressed = true
	player._unhandled_input(event)
	assert(player.abilities.get_vine_anchor() == aimed_anchor, "Vine must attach to the anchor in the mouse direction.")

	quit()
