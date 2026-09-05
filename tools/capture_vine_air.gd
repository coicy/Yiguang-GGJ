extends SceneTree
## Real Player physics and locomotion during airborne attacks in the production level.
const MAIN: PackedScene = preload("res://scenes/app/main.tscn")
var _results: Array[Dictionary] = []
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var directory: String = ProjectSettings.globalize_path("res://build/qa/vine-attack/airborne")
	DirAccess.make_dir_recursive_absolute(directory)
	var main: Node = MAIN.instantiate()
	root.add_child(main)
	current_scene = main
	var level: GreenhouseLevel = main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	var actor: Player = level._player
	await process_frame
	level.set_process(false)
	for driver_name: String in ["PhantomCameraHost", "PhantomCamera2D", "EncounterCamera2D"]:
		var driver: Node = level.find_child(driver_name, true, false)
		if driver != null:
			driver.process_mode = Node.PROCESS_MODE_DISABLED
	level._camera.global_position = Vector2(1070.0, 325.0)
	level._camera.zoom = Vector2.ONE * 2.1
	level._camera.reset_smoothing()
	level._camera.force_update_scroll()
	for form: StringName in [&"humanoid", &"mature"]:
		for facing: float in [1.0, -1.0]:
			level.feedback.clear()
			actor.combat.reset()
			actor.form_controller.restore_form(form)
			actor.global_position = Vector2(1030.0, 398.0)
			actor.velocity = Vector2(0.0, -450.0)
			for tick: int in range(2):
				await physics_frame
			actor.combat.request_action(&"attack", actor.global_position + Vector2(facing * 300.0, 0.0))
			var key: String = "%s_air_%s" % [form, "right" if facing > 0.0 else "left"]
			level.combat_hud.set_progress("真实跳跃攻击 / " + String(form), "正式 Player 物理 / " + key, 0, 0)
			var captured: bool = false
			var record: Dictionary = {"key": key, "captured": false}
			for tick: int in range(70):
				await physics_frame
				await process_frame
				await RenderingServer.frame_post_draw
				if not captured and actor.combat.attack != null and actor.combat.attack.id == &"air" and actor.combat.elapsed >= (actor.combat.attack.windup + actor.combat.attack.active * 0.5) * actor.combat.time_scale_for_form():
					root.get_texture().get_image().save_webp(directory.path_join(key + ".webp"))
					record = {"key": key, "captured": true, "on_floor": actor.is_on_floor(), "elapsed": actor.combat.elapsed, "position": str(actor.global_position), "state": str(actor.state_machine.current_state)}
					captured = true
			_results.append(record)
	var output := FileAccess.open(directory.path_join("airborne_manifest.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"kind": "production_player_physics_airborne", "fps": 60, "rate": 1.0, "checks": _results}, "  "))
	main.queue_free()
	await process_frame
	var failures: int = 0
	for result: Dictionary in _results:
		if not bool(result.get("captured", false)) or bool(result.get("on_floor", true)):
			failures += 1
			push_error("Expected an airborne active strike: " + String(result.get("key", "unknown")))
	print("VINE_AIR_CAPTURE ", _results)
	quit(0 if failures == 0 else 1)
