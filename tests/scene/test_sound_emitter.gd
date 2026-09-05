extends SceneTree
## Isolated scheduling/routing contracts; headless does not exercise the mixer.

var _checks: int = 0
var _failures: PackedStringArray = []
var _cues: Array[StringName] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for bus: StringName in [&"SFX", &"UI", &"Music", &"Ambience"]:
		_expect(AudioServer.get_bus_index(bus) >= 0, "Named audio bus exists: %s" % bus)
	for cue: StringName in AudioPalette.CUES:
		var entry: Dictionary = AudioPalette.CUES[cue]
		_expect(AudioServer.get_bus_index(entry["bus"]) >= 0, "Cue routes to an existing bus: %s" % cue)
		var streams: Array = entry["files"]
		_expect(not streams.is_empty(), "Cue has streams: %s" % cue)
		for stream: AudioStream in streams:
			_expect(stream != null and stream.get_length() > 0.0, "Cue stream is playable: %s" % cue)

	var emitter := SoundEmitter.new()
	emitter.voice_count = 2
	emitter.spatial_voice_count = 2
	root.add_child(emitter)
	emitter.cue_played.connect(func(cue: StringName) -> void: _cues.append(cue))
	var voices := emitter.find_children("*", "AudioStreamPlayer", false, false)
	var world_voices := emitter.find_children("*", "AudioStreamPlayer2D", false, false)
	_expect(voices.size() == 2 and world_voices.size() == 2, "Configured fixed voice pools are created")
	emitter.configure_world_pool(2)
	_expect(emitter.get_child_count() == 4, "Repeated configuration does not allocate more voices")
	_expect(not emitter.play_cue(&"missing_cue_for_test"), "Unknown cue is rejected")
	_expect(_cues.is_empty(), "Rejected cue emits no playback event")

	_expect(emitter.play_at(&"jump", Vector2(32, 48)), "World cue is accepted")
	var world_voice := world_voices[0] as AudioStreamPlayer2D
	_expect(world_voice.stream != null and world_voice.bus == &"SFX", "World cue routes through spatial SFX")
	_expect(world_voice.global_position == Vector2(32, 48), "World cue retains its requested position")
	_expect(not emitter.play_cue(&"jump"), "Same-frame duplicate is rejected across both pools")
	_expect(_cues.count(&"jump") == 1, "Duplicate produces only one playback event")
	_expect(emitter.play_at(&"ui_confirm", Vector2(400, 500)), "UI cue accepts a world-position request")
	var ui_voice := voices[0] as AudioStreamPlayer
	_expect(ui_voice.stream == AudioPalette.CUES[&"ui_confirm"]["files"][0] and ui_voice.bus == &"UI", "UI remains nonspatial when requested at a position")
	_expect(is_equal_approx(ui_voice.pitch_scale, 1.0), "Single-variant cue retains normal pitch")

	emitter.stop_all()
	_expect(emitter.play_cue(&"absorb"), "Absorption cue starts before its cooldown test")
	var first_frame := Engine.get_physics_frames()
	var started := Time.get_ticks_msec()
	await physics_frame
	await physics_frame
	_expect(Engine.get_physics_frames() > first_frame, "Cooldown check spans physics frames")
	_expect(Time.get_ticks_msec() - started < 600, "Cooldown check runs inside the 600 ms absorption window")
	_expect(not emitter.play_cue(&"absorb"), "Cooldown suppresses a repeated cue on a later frame")
	# The emitter uses wall time; headless SceneTree timers can advance faster.
	while Time.get_ticks_msec() - started < 650:
		await create_timer(0.05).timeout
	_expect(emitter.play_cue(&"absorb"), "Cue is playable again after cooldown expires")
	_expect(_cues.count(&"absorb") == 2, "Cooldown rejection emits no extra event")

	# Reset scheduling between attempts to isolate variant selection from timing.
	var previous: AudioStream
	for attempt: int in range(18):
		emitter.stop_all()
		_expect(emitter.play_cue(&"step_grass"), "Stopped pool accepts another cue")
		var voice := voices[0] as AudioStreamPlayer
		_expect(voice.stream != previous, "Adjacent multi-variant cues do not repeat")
		_expect(AudioPalette.CUES[&"step_grass"]["files"].has(voice.stream), "Chosen stream belongs to the requested cue")
		previous = voice.stream
	_expect(emitter.get_child_count() == 4, "Repeated playback does not grow the pools")
	emitter.stop_all()
	for voice: Node in emitter.get_children():
		_expect(not bool(voice.get("playing")), "stop_all stops every pooled voice")
	_expect(emitter.play_cue(&"step_grass"), "stop_all clears same-frame and cooldown suppression")
	emitter.stop_all()
	emitter.queue_free()
	await process_frame
	print("SOUND EMITTER: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
