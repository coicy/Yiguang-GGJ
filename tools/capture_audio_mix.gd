extends SceneTree
## Record the real Godot master bus while exercising the shipped scene.
const MAIN := preload("res://scenes/app/main.tscn")
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	# Ignore desktop key events; the harness drives actions explicitly.
	root.set_disable_input(true)
	var main := MAIN.instantiate()
	root.add_child(main)
	await process_frame
	var level := main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	var player := level._player
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, recorder)
	recorder.set_recording_active(true)
	await create_timer(1.5).timeout
	player.form_controller.restore_form(&"humanoid")
	Input.action_press(&"move_right")
	await create_timer(.6).timeout
	Input.action_release(&"move_right")
	Input.action_press(&"jump")
	await create_timer(.12).timeout
	Input.action_release(&"jump")
	await create_timer(.9).timeout
	for action: StringName in [&"attack", &"heavy", &"dash", &"parry"]:
		player.combat.request_action(action, player.global_position + Vector2(100, 0))
		await create_timer(.85).timeout
	level.soundscape.set_mode(&"battle")
	# Recorded samples from the real spatial pool, left and right of the camera.
	var center := level._camera.get_screen_center_position()
	for family: String in ["beetle", "spore", "pruner", "warden"]:
		level.sounds.play_at(StringName(family + "_warning"), center + Vector2(-160, 0))
		await create_timer(.7).timeout
		level.sounds.play_at(StringName(family + "_attack"), center + Vector2(160, 0))
		await create_timer(.55).timeout
		level.sounds.play_at(StringName(family + "_death"), center)
		await create_timer(1.35).timeout
	level.soundscape.set_mode(&"boss")
	level.sounds.play_at(&"warden_phase", center)
	await create_timer(2).timeout
	# Exercise simultaneous priorities through the compressor and final limiter.
	for key: StringName in [&"warden_slam", &"heavy_hit", &"guard", &"parry", &"hurt", &"spore_burst"]:
		level.sounds.play_at(key, center)
	await create_timer(1.3).timeout
	level._pause()
	await create_timer(.8).timeout
	level._resume()
	level.soundscape.set_mode(&"explore")
	await create_timer(1.5).timeout
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	var result := recording.save_to_wav("res://build/audio/in_game_mix.wav")
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	assert(result == OK and recording.get_length() > 20.0)
	print("PASS: captured %.2fs of real master-bus mix, spatial SFX, score crossfade and pause" % recording.get_length())
	level.feedback.clear()
	main.queue_free()
	await process_frame
	await create_timer(.2).timeout
	quit(0)
