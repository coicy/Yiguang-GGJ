extends SceneTree
## Production entry only. Movement uses physical D/A/Space/E events from the
## authored spawn; no position, form, resource or camera writes complete a route.
## Explicit lethal callbacks isolate retry; they are not a human playthrough.
const MAIN: PackedScene = preload("res://scenes/app/main.tscn")
var level: GreenhouseLevel
var player: Player
var camera: Camera2D
var host: PhantomCameraHost
var checks: int = 0
var failures: PackedStringArray = []
var keys: Dictionary[Key, bool] = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	await process_frame # Host registers after its first idle frame.
	await _frames(6)
	level = main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	player = level.get_node("Actors/Player") as Player
	camera = level.get_node("Camera2D") as Camera2D
	host = camera.get_node("PhantomCameraHost") as PhantomCameraHost
	_expect(player.current_form_id() == &"sprout", "Main spawns the actual sprout")
	_expect(player.global_position.distance_to(Vector2(35,530)) < 3.0, "Authored spawn settles on the nursery floor")
	_expect(level.room_regions.size() == 2, "Production nursery authors its two view regions")
	_expect(level.find_children("*", "Camera2D", true, false).size() == 1, "Nursery and combat share one physical Camera2D")
	_expect(_has_room(), "Spawn immediately resolves its room metadata")
	if _has_room():
		_assert_room_frame(Vector2(330,400), 1.5, "entry")
		_expect(level.combat_hud.objective_label.text == level.current_room.objective, "Room objective overrides the legacy X section")
	_expect(level.get_node_or_null("Geometry/Mechanisms/SproutSwitch") == null, "Nursery has no floor pedal")
	_expect(level.get_node_or_null("Geometry/Mechanisms/IntroGate") == null, "Nursery has no exit gate")
	_expect(_exit_is_clear(), "Nursery exit is physically open from the start")
	await _capture("01_entry")
	_expect(await _walk_to(210), "Sprout physically enters the narrow root tunnel")
	_expect(player.is_on_floor() and absf(player.global_position.y-530.0) < 3.0, "Tunnel movement stays on the real floor")
	_expect(player.current_form_id() == &"sprout", "Tunnel crossing preserves sprout form")
	await _capture("02_tunnel")
	_expect(await _walk_to(375), "Sprout leaves the tunnel on foot and reaches nutrition")
	await _frames(28)
	_assert_room_frame(Vector2(330,400), 1.5, "main cavity")
	await _capture("03_cavity_sprout")
	# Die after changing room, then verify that retry resolves the saved spawn.
	level._on_actor_killed(player)
	await _frames(55)
	_expect(paused and level.dead and level.combat_hud.is_overlay_visible(), "Nursery death reaches the paused retry overlay")
	level.retry_checkpoint()
	_expect(player.global_position.distance_to(Vector2(35,530)) < 3.0, "Retry restores the authored starting point")
	_expect(player.current_form_id() == &"sprout" and player.combat.health.current == 5, "Initial retry restores sprout and full health")
	_expect(player.velocity == Vector2.ZERO and not paused, "Retry clears velocity and resumes physics")
	_assert_room_frame(Vector2(330,400), 1.5, "retry entry")
	_expect(await _walk_to(375), "Retry route crosses the entire tunnel again through real movement")
	_key(KEY_E, true)
	for tick in range(240):
		await _frames(1)
		if player.current_form_id() == &"humanoid":
			break
	_key(KEY_E, false)
	await _frames(8)
	_expect(player.current_form_id() == &"humanoid", "Held E at the embedded wall nutrient source grows a human")
	_expect((level.get_node("Interface/HandbuiltHud") as HandbuiltHud)._form_id == &"humanoid", "Growth HUD follows the actual form change")
	await _capture("04_cavity_human")
	if player.current_form_id() == &"humanoid":
		var targets: Array[Vector2] = [Vector2(480,482), Vector2(585,438), Vector2(675,394)]
		var launches: Array[float] = [364.0, 486.0, 590.0]
		for index in range(targets.size()):
			var reached := await _jump_to(targets[index], launches[index], index == 0)
			_expect(reached, "Physical jump reaches nursery stair %d %s (ended %s)" % [index, targets[index], player.global_position])
			if not reached:
				break
			await _capture("05_stair_%d" % index)
		_expect(await _walk_to(725), "Human walks through the unobstructed exit to the real checkpoint")
		await _frames(30)
		var checkpoint := level.get_node("Checkpoints/Nursery") as Checkpoint
		_expect(checkpoint._is_activated, "Walking through the nursery exit activates its checkpoint")
		_expect(level.current_room == null and host.get_active_pcam() == level._phantom_camera, "Exit x >= 695 returns to framed exploration")
		_expect(camera.zoom.is_equal_approx(Vector2.ONE*2.5), "Ordinary follow restores its authored zoom")
		await _capture("06_checkpoint")
		var saved := level._checkpoint_state.duplicate(true)
		_expect(StringName(saved.get("form", &"")) == &"humanoid", "Checkpoint captures the form gained by absorption")
		_expect(await _walk_to(663), "Walking backwards re-enters the cavity without a position helper")
		await _frames(28)
		_assert_room_frame(Vector2(330,400), 1.5, "return cavity")
		level._on_actor_killed(player)
		level.retry_checkpoint()
		_expect(player.global_position.distance_to(saved.position) < 0.1, "Retry selects the exit checkpoint even when death occurred in the cavity")
		_expect(player.current_form_id() == saved.form and player.resources.snapshot() == saved.resources, "Exit retry restores the saved form and resources")
		_expect(level.current_room == null and host.get_active_pcam() == level._phantom_camera, "Exit retry immediately restores the correct follow camera")
		_expect(camera.zoom.is_equal_approx(level._phantom_camera.zoom), "No old cavity zoom survives checkpoint retry")
		_expect(player.velocity == Vector2.ZERO and player.combat.health.current == 5, "Exit retry clears movement and restores health")
		await _frames(30)
		_expect(host.get_active_pcam() == level._phantom_camera and camera.zoom.is_equal_approx(Vector2.ONE*2.5), "Previous view transition cannot overwrite retry after later frames")
	_release_keys()
	paused = false
	level.feedback.clear()
	main.queue_free()
	await process_frame
	print("NURSERY ROOM: %d assertions, %d failures" % [checks,failures.size()])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _has_room() -> bool:
	return level.current_room != null

func _assert_room_frame(center: Vector2, zoom: float, label: String) -> void:
	_expect(_has_room(), "%s resolves a room at the actual player position" % label)
	if not _has_room():
		return
	_expect(host.get_active_pcam() == level._room_cameras[level.current_room], "%s selects its authored Phantom through the Host" % label)
	_expect(camera.global_position.distance_to(center) < 0.2, "%s uses the authored center (actual %s)" % [label, camera.global_position])
	_expect(camera.zoom.is_equal_approx(Vector2.ONE*zoom), "%s uses the authored zoom" % label)
	_assert_nursery_visible(label)

func _assert_nursery_visible(label: String) -> void:
	# Assert what is on screen, not just the configured camera position. The
	# entrance, nutrient source, stairs and exit must all fit together.
	var frame := root.get_visible_rect().grow(-24.0)
	var world_to_screen := root.get_canvas_transform()
	var landmarks: Array[Vector2] = [Vector2(35, 510), Vector2(429, 511), Vector2(480, 482), Vector2(585, 438), Vector2(675, 394), Vector2(705, 390)]
	for point: Vector2 in landmarks:
		_expect(frame.has_point(world_to_screen * point), "%s includes nursery landmark %s in the visible frame" % [label, point])

func _exit_is_clear() -> bool:
	var query := PhysicsRayQueryParameters2D.create(Vector2(670, 365), Vector2(720, 365), 1)
	return player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _pause_in_air() -> void:
	_expect(not player.is_on_floor(), "Pause case occurs during a real upward jump")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _frames(1)
	var position := player.global_position
	var transform := camera.global_transform
	var zoom := camera.zoom
	var time := level.elapsed_seconds
	_expect(paused, "Physical Escape opens the pause menu")
	await _frames(8)
	_expect(player.global_position == position, "Pause freezes nursery physics in midair")
	_expect(camera.global_transform == transform and camera.zoom == zoom, "Pause freezes the real Phantom view")
	_expect(is_equal_approx(level.elapsed_seconds,time), "Paused time is excluded")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _frames(1)
	_expect(not paused, "Physical Escape resumes the jump")

func _walk_to(target: float, budget: int = 260) -> bool:
	for tick in range(budget):
		if absf(player.global_position.x-target) <= 4.0:
			_set_direction(0.0)
			await _frames(6)
			return absf(player.global_position.x-target) < 12.0
		_set_direction(signf(target-player.global_position.x))
		await _frames(1)
	_set_direction(0.0)
	print("NURSERY walk failed target=%s position=%s pressed_left=%s pressed_right=%s velocity=%s" % [target,player.global_position,Input.is_action_pressed(&"move_left"),Input.is_action_pressed(&"move_right"),player.velocity])
	return false

func _jump_to(target: Vector2, launch: float, pause_case: bool) -> bool:
	var jumped := false
	var airborne_ticks := 0
	for tick in range(200):
		if jumped and player.is_on_floor() and absf(player.global_position.y-target.y) < 3.0 and absf(player.global_position.x-target.x) < 12.0:
			_set_direction(0.0)
			_key(KEY_SPACE,false)
			await _frames(6)
			return true
		var dx := target.x-player.global_position.x
		_set_direction(signf(dx) if absf(dx) > 5.0 else 0.0)
		if not jumped and player.is_on_floor() and player.global_position.x >= launch-2.0:
			_key(KEY_SPACE,true)
			jumped = true
		if jumped:
			airborne_ticks += 1
			if pause_case and airborne_ticks == 8:
				await _pause_in_air()
		await _frames(1)
	_set_direction(0.0)
	_key(KEY_SPACE,false)
	return false

func _set_direction(direction: float) -> void:
	_key(KEY_A,direction < 0.0)
	_key(KEY_D,direction > 0.0)

func _key(code: Key, pressed: bool) -> void:
	var actions: Dictionary[Key, StringName] = {KEY_A: &"move_left", KEY_D: &"move_right", KEY_SPACE: &"jump", KEY_E: &"absorb_resource", KEY_ESCAPE: &"pause"}
	if keys.get(code,false) == pressed and (not pressed or Input.is_action_pressed(actions[code])):
		return
	keys[code] = pressed
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _release_keys() -> void:
	for code: Key in keys.keys():
		_key(code,false)

func _frames(count: int) -> void:
	for tick in range(count):
		await physics_frame

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("NURSERY FAILURE: "+message)

func _capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var folder := "res://build/qa/nursery-input"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("capture_dir="):
			folder = argument.trim_prefix("capture_dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var result := root.get_texture().get_image().save_png(folder + "/" + label + ".png")
	_expect(result == OK, "Real input frame saved: " + label)
