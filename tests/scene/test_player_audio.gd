extends SceneTree
## Scene test for the standalone SoundEmitter contract.

const SOUND_EMITTER_SCENE: PackedScene = preload("res://features/audio/sound_emitter.tscn")
const SOUND_BANK: SoundBank = preload("res://features/audio/walk_test_bank.tres")

var _played_cues: Array[StringName] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var emitter := SOUND_EMITTER_SCENE.instantiate() as SoundEmitter
	emitter.sound_bank = SOUND_BANK
	root.add_child(emitter)
	emitter.cue_played.connect(_on_cue_played)
	await process_frame

	assert(emitter.play_cue(&"step_grass"), "A configured cue must play.")
	assert(_played_cues == [&"step_grass"], "Playing a cue must emit cue_played once.")
	assert(not emitter.play_cue(&"step_grass"), "A repeated cue must honor its cooldown.")
	for frame: int in range(4):
		await physics_frame
	assert(emitter.play_cue(&"step_grass"), "A cue must play again after its cooldown.")
	assert(emitter.get_child_count() == 6, "The voice pool must stay bounded.")
	assert(emitter.play_cue(&"step_hard"), "A second configured cue must play.")
	assert(not emitter.play_cue(&"unknown"), "Unknown cues must be rejected safely.")

	var assigned_streams: int = 0
	for voice: Node in emitter.get_children():
		var player := voice as AudioStreamPlayer
		if player.stream != null:
			assigned_streams += 1
		assert(player.bus == &"SFX", "SFX voices must route to the SFX bus.")
	assert(assigned_streams == 3, "Each successful cue must occupy a pooled voice.")

	emitter.free()
	print("PASS: standalone SoundEmitter uses resource cues, SFX routing, cooldowns and bounded voices")
	quit(0)


func _on_cue_played(cue: StringName) -> void:
	_played_cues.append(cue)
