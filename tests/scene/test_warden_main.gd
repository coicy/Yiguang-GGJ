extends "res://tests/scene/test_greenhouse_encounters.gd"
## Isolate the new elite in the shipped F5 level, using the real player movement.
func _run() -> void:
	for form: StringName in [&"humanoid", &"mature"]:
		var main := MAIN.instantiate()
		root.add_child(main)
		await physics_frame
		level = main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
		player = level.get_node("Actors/Player") as Player
		player.form_controller.restore_form(form)
		player.combat.health.damaged.connect(_record_damage)
		var encounter := level.encounters[7]
		_expect(encounter.encounter_id == &"warden", "Uses the authored core encounter")
		await _fight(encounter, form)
		_expect(level.exit_goal.is_unlocked(), "%s elite victory unlocks the production exit" % form)
		_expect(encounter.enemies.is_empty() and encounter.projectiles.is_empty(), "%s completed core clears threats" % form)
		_release_inputs()
		paused = false
		level.feedback.clear()
		main.queue_free()
		await process_frame
	print("WARDEN MAIN: %d assertions, %d failures" % [checks, failures.size()])
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
