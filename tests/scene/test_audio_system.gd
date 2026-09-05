extends SceneTree
## Validates production wiring, voice budgets, lifecycle and full material bank.
const MAIN := preload("res://scenes/app/main.tscn")
var checks: int = 0
var failures: Array[String] = []
var heard: Array[StringName] = []
func _init() -> void:
	call_deferred("_run")
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func _run() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	var level := main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	level.sounds.cue_played.connect(func(key: StringName) -> void: heard.append(key))
	level._player.audio.sounds.cue_played.connect(func(key: StringName) -> void: heard.append(key))
	expect(level.soundscape != null and level.soundscape.mode == &"explore", "F5 starts with exploration music")
	for bus: StringName in [&"SFX", &"Music", &"Ambience", &"UI"]:
		expect(AudioServer.get_bus_index(bus) >= 0, "Named audio bus: " + String(bus))
	for key: StringName in AudioPalette.CUES:
		var data: Dictionary = AudioPalette.CUES[key]
		for stream: AudioStream in data["files"]:
			expect(stream != null and stream.get_length() > 0.05 and stream.get_length() <= 3.0, "Valid short cue: " + String(key))
	level.sounds.stop_all()
	expect(level.sounds.play_cue(&"parry"), "First important cue accepted")
	expect(not level.sounds.play_cue(&"parry"), "Same-frame duplicate suppressed")
	expect(not level.sounds.play_cue(&"missing"), "Unknown cue safely rejected")
	var previous: int = -1
	for index: int in range(8):
		level.sounds.stop_all()
		level.sounds.play_cue(&"hit")
		var selected: int = level.sounds._variants[&"hit"]
		expect(selected != previous, "Variants do not immediately repeat")
		previous = selected
	expect(level.sounds.get_child_count() == 22, "Shared world and UI pools stay bounded")
	var samples: Array[AudioStream] = []
	for family: String in ["beetle", "spore", "pruner", "warden"]:
		var warning: AudioStream = AudioPalette.CUES[StringName(family + "_warning")]["files"][0]
		expect(not samples.has(warning), "Independent warning timbre: " + family)
		samples.append(warning)
	var ordinary: EncounterController = level.encounters[0]
	ordinary.begin()
	expect(level.soundscape.mode == &"battle", "Actual encounter switches music")
	for enemy: CombatEnemy in ordinary.enemies:
		expect(enemy.audio.sounds == level.sounds, "Enemy uses surviving shared spatial pool")
		enemy._set_state(&"notice")
		expect(heard.has(StringName(String(enemy.audio.family) + "_notice")), "Enemy real state routes notice")
		var request := DamageRequest.new()
		request.amount = enemy.health.maximum
		enemy.health.take_damage(request)
		expect(heard.has(StringName(String(enemy.audio.family) + "_death")), "Death routes creature-specific tail")
	ordinary.reset_encounter()
	level.current_encounter = null
	level.soundscape.set_mode(&"explore")
	var boss: EncounterController = level.encounters.back()
	expect(not level.sounds.play_at(&"warden_phase", level._camera.get_screen_center_position() + Vector2(5000, 0)), "Offscreen effects are culled")
	level._player.global_position = boss.checkpoint_position()
	level._reset_exploration_camera()
	boss.begin()
	expect(level.soundscape.mode == &"boss", "Warden encounter gets its own score")
	for enemy: CombatEnemy in boss.enemies:
		enemy._set_state(&"overload")
		expect(heard.has(&"warden_phase"), "Boss overload has independent audio")
	level._pause()
	expect(paused, "Pause remains functional")
	level._resume()
	expect(not paused, "Resume remains functional")
	level._on_player_died()
	expect(heard.has(&"death"), "Player death has its own cue")
	level.retry_checkpoint()
	expect(not level.dead and not paused and level.soundscape.mode == &"explore", "Retry restores audio lifecycle")
	for loop: AudioStreamPlayer2D in level.soundscape._platforms.values():
		expect(not loop.playing, "Retry stops mechanism loops")
	level.feedback.clear()
	main.queue_free()
	await process_frame
	print("AUDIO SYSTEM: %d assertions, %d failures" % [checks, failures.size()])
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
