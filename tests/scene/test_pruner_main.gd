extends "res://tests/scene/test_greenhouse_encounters.gd"
## Exercise the third enemy in the existing hand-built workshop and courtyard.
func _run() -> void:
	for form: StringName in [&"humanoid", &"mature"]:
		var main := MAIN.instantiate()
		root.add_child(main)
		await physics_frame
		level = main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
		player = level._player
		player.form_controller.restore_form(form)
		player.combat.health.damaged.connect(_record_damage)
		for index: int in [4, 5, 6]:
			await _fight(level.encounters[index], form)
		_release_inputs()
		paused = false
		level.feedback.clear()
		main.queue_free()
		await process_frame
	print("PRUNER MAIN: %d checks, %d failures" % [checks, failures.size()])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)
