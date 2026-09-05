extends SceneTree
## Production terrain routes. Each fresh run sets position/form only at its start.
## All subsequent falling, walking, absorption, jumping and Q/E climbing use input
## and normal player physics. No teleports or resource/health writes skip the route.
## These deterministic checks are not human playtests or first-clear time samples.
const MAIN: PackedScene = preload("res://scenes/app/main.tscn")
var level: GreenhouseLevel
var player: Player
var checks: int = 0
var failures: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var forms: Array[StringName] = [&"humanoid", &"mature"]
	if "--vines-only" in OS.get_cmdline_user_args():
		forms.clear()
	for form: StringName in forms:
		var main := await _start(Vector2(5730.0, 258.0), form)
		await _lower_recovery(form)
		await _dispose(main)
	var main := await _start(Vector2(5370.0, 348.0), &"mature")
	await _three_rings()
	await _dispose(main)
	print("TERRAIN ROUTES: %d assertions, %d failures" % [checks, failures.size()])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _start(position: Vector2, form: StringName) -> Node:
	_release_inputs()
	var main := MAIN.instantiate()
	root.add_child(main)
	await _frames(3)
	level = main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	player = level.get_node("Actors/Player") as Player
	# The only position/form initialization in a route. Never used between targets.
	player.form_controller.restore_form(form)
	player.global_position = position
	player.velocity = Vector2.ZERO
	await _frames(8)
	_expect(player.is_on_floor(), "%s route starts on its real upper platform" % form)
	return main

func _dispose(main: Node) -> void:
	_release_inputs()
	paused = false
	level.feedback.clear()
	main.queue_free()
	await process_frame

func _lower_recovery(form: StringName) -> void:
	# Leave Crown through the real 5600..5660 gap and let gravity reach Catch.
	if not await _walk_to(5630.0, 180):
		_expect(false, "%s reaches the real drop gap (ended %s)" % [form, player.global_position])
		return
	var landed := false
	for tick in range(180):
		if player.is_on_floor() and absf(player.global_position.y - 555.0) < 3.0:
			landed = true
			break
		await _frames(1)
	_expect(landed, "%s physically falls from Crown to Catch y555 (ended %s)" % [form, player.global_position])
	if not landed:
		return
	_expect(not level.dead and player.combat.health.current == 5, "%s catch prevents lethal fall" % form)
	_expect(await _walk_to(5600.0), "%s walks to lower wither point" % form)
	while player.current_form_id() != &"sprout":
		if not await _absorb_one_stage():
			_expect(false, "%s withers one stage through held E" % form)
			return
	_expect(player.current_form_id() == &"sprout", "%s reaches sprout using the actual toxin point" % form)
	# Enter the 33-high alcove from the right, then return the same way.
	# Its left end meets the existing main foundation; it is not a through tunnel.
	_expect(await _walk_to(5435.0, 240), "%s sprout walks 100 units into the lower alcove" % form)
	_expect(player.current_form_id() == &"sprout" and absf(player.global_position.y - 555.0) < 3.0, "%s tunnel crossing stays on the lower floor as sprout" % form)
	_expect(await _walk_to(5680.0, 240), "%s sprout returns on foot to the real nutrition point" % form)
	while player.current_form_id() != form:
		if not await _absorb_one_stage():
			_expect(false, "%s regrows one stage through held E" % form)
			return
	_expect(player.current_form_id() == form, "%s recovers the requested combat form without restoring state" % form)

	# The last jump may touch the existing TreeLanding at y350 before walking
	# off its right edge; verify the main floor beyond x6220, not an air point.
	var targets: Array[Vector2] = [Vector2(5890,510),Vector2(5990,465),Vector2(6090,420),Vector2(6280,400)]
	var launches: Array[float] = [5815.0,5890.0,5990.0,6100.0]
	for index in range(targets.size()):
		var reached := await _jump_to(targets[index], launches[index])
		_expect(reached, "%s returns via real stair %d at %s (ended %s)" % [form,index,targets[index],player.global_position])
		if not reached:
			return
	_expect(player.is_on_floor() and absf(player.global_position.y - 400.0) < 3.0, "%s lower recovery reaches the actual main floor y400" % form)
	_expect(not level.dead and level.death_count == 0, "%s finishes lower recovery without death or retry" % form)
	_expect(not player.abilities.is_vine_attached() and not player.abilities.is_rooted(), "%s lower recovery needs no vine/root bypass" % form)
	print("ROUTE lower form=%s endpoint=%s deaths=%d" % [form,player.global_position,level.death_count])

func _three_rings() -> void:
	var landings: Array[Vector2] = [Vector2(5540,300),Vector2(5730,260),Vector2(5950,300)]
	for index in range(3):
		var anchor := level.get_node("Geometry/Mechanisms/Ring%d" % index) as VineAnchor
		var start := player.global_position
		_expect(start.distance_to(anchor.global_position) <= 260.0, "Ring %d is within the designed 260-unit launch range" % index)
		var aim := InputEventMouseMotion.new()
		aim.position = player.get_viewport().get_screen_transform() * player.get_viewport().get_canvas_transform() * anchor.global_position
		Input.parse_input_event(aim)
		Input.flush_buffered_events()
		_key(KEY_Q, true)
		await _frames(2)
		_key(KEY_Q, false)
		var attached := player.abilities.get_vine_anchor() == anchor
		_expect(attached, "Q with real mouse aim attaches production ring %d" % index)
		if not attached:
			print("VINE DIAGNOSTIC player=%s mouse=%s stored_aim=%s has_aim=%s clear_path=%s Q=%s" % [player.global_position,aim.position,player.abilities._vine_aim_global_position,player.abilities._has_vine_aim_position,player.abilities._has_clear_path(anchor),Input.is_action_pressed(&"ability_primary")])
			return
		_key(KEY_E, true)
		var climb_seen := false
		var highest := player.global_position.y
		var max_step := 0.0
		var previous := player.global_position
		var landed := false
		for tick in range(240):
			await _frames(1)
			climb_seen = climb_seen or player.movement.is_vine_climbing()
			highest = minf(highest, player.global_position.y)
			max_step = maxf(max_step, previous.distance_to(player.global_position))
			previous = player.global_position
			if climb_seen and not player.abilities.is_vine_attached() and player.is_on_floor() and player.global_position.distance_to(landings[index]) < 5.0:
				landed = true
				break
		_key(KEY_E, false)
		await _frames(3)
		_expect(climb_seen, "E starts multi-frame climb on ring %d" % index)
		_expect(max_step < 18.0, "Ring %d travel is continuous physics, max frame step %.2f" % [index,max_step])
		_expect(highest <= anchor.global_position.y - 12.0, "Ring %d feet reach above the ring before release" % index)
		_expect(landed, "Ring %d automatically releases and lands on its real platform (ended %s)" % [index,player.global_position])
		if not landed:
			return
	_expect(not level.dead and level.death_count == 0, "All three Q/E rings complete continuously without death or retry")
	print("ROUTE vines endpoint=%s deaths=%d" % [player.global_position,level.death_count])

func _absorb_one_stage() -> bool:
	_set_direction(0.0)
	Input.action_release(&"absorb_resource")
	await _frames(3)
	var before := player.current_form_id()
	Input.action_press(&"absorb_resource")
	for tick in range(480):
		await _frames(1)
		if player.current_form_id() != before:
			Input.action_release(&"absorb_resource")
			await _frames(3)
			return true
	Input.action_release(&"absorb_resource")
	return false

func _walk_to(target_x: float, budget: int = 180) -> bool:
	for tick in range(budget):
		var dx := target_x - player.global_position.x
		if absf(dx) <= 5.0:
			_set_direction(0.0)
			await _frames(6)
			return absf(target_x - player.global_position.x) < 12.0
		_set_direction(signf(dx))
		await _frames(1)
	_set_direction(0.0)
	return false

func _jump_to(target: Vector2, launch_x: float) -> bool:
	var jumped := false
	for tick in range(200):
		if jumped and player.is_on_floor() and absf(player.global_position.y - target.y) < 3.0 and absf(player.global_position.x - target.x) < 12.0:
			_set_direction(0.0)
			Input.action_release(&"jump")
			await _frames(6)
			return true
		var dx := target.x - player.global_position.x
		_set_direction(signf(dx) if absf(dx) > 6.0 else 0.0)
		if not jumped and player.is_on_floor() and player.global_position.x >= launch_x - 3.0:
			Input.action_press(&"jump")
			jumped = true
		await _frames(1)
	_set_direction(0.0)
	Input.action_release(&"jump")
	return false

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _set_direction(direction: float) -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	if direction > 0.0:
		Input.action_press(&"move_right")
	elif direction < 0.0:
		Input.action_press(&"move_left")

func _release_inputs() -> void:
	for action: StringName in [&"move_left", &"move_right", &"jump", &"ability_primary", &"absorb_resource"]:
		Input.action_release(action)
	_key(KEY_Q, false)
	_key(KEY_E, false)

func _frames(count: int) -> void:
	for tick in range(count):
		await physics_frame

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("ROUTE FAILURE: " + message)
