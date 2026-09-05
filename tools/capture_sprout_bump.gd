extends SceneTree
## Review the real Player in the shipped main level; no alternate playable scene.
const MAIN: PackedScene = preload("res://scenes/app/main.tscn")
const STEP: float = 1.0 / 60.0
var _level: GreenhouseLevel
var _actor: Player
var _directory: String
var _records: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	_directory = ProjectSettings.globalize_path("res://build/qa/sprout-bump")
	DirAccess.make_dir_recursive_absolute(_directory)
	var main := MAIN.instantiate()
	root.add_child(main)
	current_scene = main
	_level = main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	_actor = _level._player
	await process_frame
	_level.set_process(false)
	var gif_mode := OS.get_cmdline_user_args().has("--gif")
	_actor.set_physics_process(gif_mode)
	for driver_name: String in ["PhantomCameraHost", "PhantomCamera2D", "EncounterCamera2D"]:
		var driver: Node = _level.find_child(driver_name, true, false)
		if driver != null:
			driver.process_mode = Node.PROCESS_MODE_DISABLED
	_level._camera.global_position = Vector2(940.0, 370.0)
	_level._camera.zoom = Vector2.ONE * 3.0
	_level._camera.reset_smoothing()
	_level._camera.force_update_scroll()
	if gif_mode:
		await _record_gif(main)
		return
	for face: float in [1.0, -1.0]:
		_actor.combat.reset()
		_actor.form_controller.restore_form(&"sprout")
		_actor.position = Vector2(940.0, 400.0)
		_actor.velocity = Vector2.ZERO
		for tick: int in range(30):
			await _step(0.0)
		_actor.visuals.animation_machine.set_facing(face)
		var side := "right" if face > 0.0 else "left"
		_level.combat_hud.set_progress("幼芽前顶", "缩身 → 前顶 → 回弹", 0, 0)
		await _capture(side + "_00_idle")
		_actor.combat.request_action(&"attack", _actor.position + Vector2(face * 300.0, 0.0))
		for tick: int in range(23):
			await _step(0.0)
			if tick in [5, 8, 13, 21]:
				await _capture(side + "_%02d" % tick)
		_actor.combat.request_action(&"attack", _actor.position + Vector2(face * 300.0, 0.0))
		for tick: int in range(23):
			await _step(-face)
			_records.append({"side": side, "tick": tick, "x": _actor.position.x, "y": _actor.position.y, "vx": _actor.velocity.x, "elapsed": _actor.combat.elapsed, "state": String(_actor.combat.state)})
	var file := FileAccess.open(_directory.path_join("motion.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_records, "	"))
	main.queue_free()
	await process_frame
	await process_frame
	print("PASS sprout bump capture: " + _directory)
	quit()

func _step(direction: float) -> void:
	await physics_frame
	_actor.combat.tick(STEP)
	_actor.movement.tick(STEP, direction, false)
	_actor.combat.after_movement()
	_actor.visuals.set_combat_state(_actor.combat)
	# Keep the base clip clock identical to the real attack clock for captured poses.
	_actor.visuals._spine_visual.spine_sprite.update_skeleton(0.0)
	await process_frame
	await RenderingServer.frame_post_draw

func _capture(label: String) -> void:
	root.get_texture().get_image().save_webp(_directory.path_join(label + ".webp"))

func _record_gif(main: Node) -> void:
	# Run with --fixed-fps 60: every captured frame is 1/60 s of real Player physics.
	_directory = _directory.path_join("gif-frames")
	DirAccess.make_dir_recursive_absolute(_directory)
	_level._camera.global_position = Vector2(952.0, 382.0)
	_level._camera.zoom = Vector2.ONE * 6.0
	_level._camera.reset_smoothing()
	_level._camera.force_update_scroll()
	for action: StringName in [&"move_left", &"move_right", &"jump"]:
		Input.action_release(action)
	var frame_index: int = 0
	for face: float in [1.0, -1.0]:
		_actor.combat.reset()
		_actor.form_controller.restore_form(&"sprout")
		_actor.position = Vector2(940.0, 400.0)
		_actor.velocity = Vector2.ZERO
		_actor.visuals.animation_machine.set_facing(face)
		for tick: int in range(30):
			await _gif_frame()
		for tick: int in range(66):
			if tick == 24:
				_actor.combat.request_action(&"attack", _actor.position + Vector2(face * 300.0, 0.0))
			await _gif_frame()
			root.get_texture().get_image().get_region(Rect2i(320, 200, 640, 320)).save_png(_directory.path_join("frame_%04d.png" % frame_index))
			_records.append({"frame": frame_index, "side": "right" if face > 0 else "left", "tick": tick, "x": _actor.position.x, "elapsed": _actor.combat.elapsed, "state": String(_actor.combat.state)})
			frame_index += 1
	var file := FileAccess.open(_directory.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps": 60, "kind": "production_player_physics", "frames": _records}, "  "))
	main.queue_free()
	await process_frame
	print("PASS whole-body GIF source: %d frames at 60 fps / %s" % [frame_index, _directory])
	quit()

func _gif_frame() -> void:
	await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw
