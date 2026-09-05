extends SceneTree
## Verify the reusable production player's cast presentation and audio timing.
const PLAYER: PackedScene = preload("res://features/player/player.tscn")
var cues: Array[StringName] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := PLAYER.instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2(400.0, 300.0)
	assert(player.form_controller.restore_form(&"mature"))
	var effect := player.visuals.vine_visual
	effect.set_process(false)
	player.visuals.set_process(false)
	player.audio.sounds.cue_played.connect(func(cue: StringName) -> void: cues.append(cue))
	await physics_frame

	# A miss still travels out from the hand, then returns without a latch cue.
	player.abilities.set_vine_aim_global_position(player.global_position + Vector2(220.0, -100.0))
	assert(not player.abilities.try_attach_vine())
	assert(not player.movement.is_vine_attached())
	assert(effect.phase() == VineVisual.FLYING)
	var launch := effect.tip_global_position()
	assert(launch.distance_to(player.global_position) < 80.0)
	effect._process(0.04)
	assert(effect.tip_global_position().distance_to(launch) > 15.0)
	assert(effect.tip_global_position().distance_to(launch) < 220.0, "The tip must travel, not appear at full length.")
	assert(cues.count(&"vine_launch") == 1 and not cues.has(&"vine"))
	effect._process(0.3)
	assert(effect.phase() == VineVisual.RETURNING)
	effect._process(0.3)
	assert(effect.phase() == VineVisual.IDLE and not cues.has(&"vine"))

	# Existing immediate gameplay attachment is preserved; latch feedback waits for arrival.
	var anchor := VineAnchor.new()
	anchor.position = player.global_position + Vector2(180.0, -100.0)
	root.add_child(anchor)
	player.abilities.set_vine_aim_global_position(anchor.global_position)
	await physics_frame
	assert(player.abilities.try_attach_vine())
	assert(player.movement.is_vine_attached() and effect.phase() == VineVisual.FLYING)
	assert(cues.count(&"vine_launch") == 2 and not cues.has(&"vine"))
	effect._process(0.04)
	assert(effect.tip_global_position().distance_to(anchor.global_position) > 20.0)
	effect._process(0.3)
	assert(effect.phase() == VineVisual.ATTACHED)
	assert(effect.tip_global_position().is_equal_approx(anchor.global_position))
	assert(cues.count(&"vine") == 1)
	anchor.position += Vector2(20.0, 10.0)
	effect._process(0.1)
	assert(effect.tip_global_position().is_equal_approx(anchor.global_position))
	assert(cues.count(&"vine") == 1, "Holding a vine must not repeat impact audio.")
	player.abilities.stop_primary()
	assert(effect.phase() == VineVisual.RETURNING)
	effect._process(0.3)
	assert(effect.phase() == VineVisual.IDLE)

	# Cancel in flight, and fire again during its return: no ghost impact from the old cast.
	await physics_frame
	assert(player.abilities.try_attach_vine())
	effect._process(0.04)
	player.abilities.stop_primary()
	assert(effect.phase() == VineVisual.RETURNING)
	anchor.set_available(false)
	await physics_frame
	assert(not player.abilities.try_attach_vine())
	assert(effect.phase() == VineVisual.FLYING)
	effect._process(0.3)
	effect._process(0.3)
	assert(effect.phase() == VineVisual.IDLE and cues.count(&"vine") == 1)

	# The visual miss endpoint stops at world geometry.
	var wall := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20.0, 200.0)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector2(500.0, 230.0)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	player.abilities.set_vine_aim_global_position(Vector2(700.0, 277.0))
	assert(not player.abilities.try_attach_vine())
	effect._process(0.3)
	assert(absf(effect.tip_global_position().x - 490.0) < 0.1, "A missed vine must stop at a wall.")
	player.cancel_actions()
	assert(effect.phase() == VineVisual.IDLE)
	wall.queue_free()
	await physics_frame

	# Form changes and death clear effects; invalid anchors retract without a late impact.
	assert(not player.abilities.try_attach_vine())
	assert(player.form_controller.restore_form(&"sprout"))
	assert(effect.phase() == VineVisual.IDLE)
	var launch_count := cues.count(&"vine_launch")
	assert(not player.abilities.try_attach_vine())
	assert(cues.count(&"vine_launch") == launch_count)
	assert(player.form_controller.restore_form(&"mature"))
	anchor.set_available(true)
	player.abilities.set_vine_aim_global_position(anchor.global_position)
	await physics_frame
	assert(player.abilities.try_attach_vine())
	anchor.queue_free()
	await process_frame
	effect._process(0.3)
	assert(effect.phase() == VineVisual.RETURNING)
	effect._process(0.3)
	assert(effect.phase() == VineVisual.IDLE and cues.count(&"vine") == 1)
	player.cancel_actions()
	await physics_frame
	assert(not player.abilities.try_attach_vine())
	player.play_death_animation()
	assert(effect.phase() == VineVisual.IDLE)
	effect._process(1.0)
	assert(cues.count(&"vine") == 1)
	player.queue_free()
	await process_frame
	print("PASS: travelling casts, miss/wall return, timed latch audio, moving anchors, recast, cancel, form/death cleanup")
	quit(0)
