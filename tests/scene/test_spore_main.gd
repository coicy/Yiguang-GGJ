extends "res://tests/scene/test_greenhouse_encounters.gd"
## Input-driven verification of the two existing spore encounters in the production level.
func _run() -> void:
	for form: StringName in [&"humanoid", &"mature"]:
		var main: Node = MAIN.instantiate()
		root.add_child(main)
		await physics_frame
		level = main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
		player = level._player
		player.form_controller.restore_form(form)
		for index: int in [2, 3]:
			await _fight(level.encounters[index], form)
		_release_inputs()
		paused = false
		level.feedback.clear()
		main.queue_free()
		await process_frame
	print("SPORE MAIN: %d assertions, %d failures" % [checks, failures.size()])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)
