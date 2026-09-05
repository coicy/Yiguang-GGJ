class_name SoundEmitter
extends Node
## Fixed pools, per-event cooldown, nonrepeating variants and priority voice stealing.
signal cue_played(cue: StringName)
@export_range(-40.0, 0.0, 1.0) var gain_db: float = -10.0
@export_range(1, 16, 1) var voice_count: int = 6
@export_range(0, 24, 1) var spatial_voice_count: int = 0
const CUES := AudioPalette.CUES
var _voices: Array[AudioStreamPlayer] = []
var _world_voices: Array[AudioStreamPlayer2D] = []
var _variants: Dictionary = {}
var _last_frame: Dictionary = {}
var _last_time: Dictionary = {}
var _rng := RandomNumberGenerator.new()
func _ready() -> void:
	_rng.randomize()
	for index: int in range(voice_count):
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % index
		voice.bus = &"SFX"
		add_child(voice)
		_voices.append(voice)
	configure_world_pool(spatial_voice_count)
func configure_world_pool(count: int) -> void:
	spatial_voice_count = clampi(count, 0, 24)
	for index: int in range(_world_voices.size(), spatial_voice_count):
		var voice := AudioStreamPlayer2D.new()
		voice.name = "WorldVoice%d" % index
		voice.bus = &"SFX"
		voice.max_distance = 1000.0
		voice.attenuation = 1.35
		voice.panning_strength = 0.75
		voice.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(voice)
		_world_voices.append(voice)
func play_cue(cue: StringName, extra_gain_db: float = 0.0) -> bool:
	return _play(cue, extra_gain_db, Vector2.ZERO, false)
func play_at(cue: StringName, point: Vector2, extra_gain_db: float = 0.0) -> bool:
	return _play(cue, extra_gain_db, point, not _world_voices.is_empty())
func _play(cue: StringName, extra_gain_db: float, point: Vector2, spatial: bool) -> bool:
	if not CUES.has(cue) or _voices.is_empty():
		return false
	var entry: Dictionary = CUES[cue]
	spatial = spatial and entry["bus"] != &"UI"
	if spatial:
		var camera := get_viewport().get_camera_2d()
		if camera != null and point.distance_to(camera.get_screen_center_position()) > 1200.0:
			return false
	var frame := Engine.get_physics_frames()
	var now := Time.get_ticks_msec()
	if _last_frame.get(cue, -1) == frame or now - int(_last_time.get(cue, -100000)) < float(entry["cooldown"]) * 1000.0:
		return false
	var pool: Array = _world_voices if spatial else _voices
	var voice: Node = _choose_voice(pool, int(entry["priority"]))
	if voice == null:
		return false
	var streams: Array = entry["files"]
	var variant := _rng.randi_range(0, streams.size() - 1)
	if streams.size() > 1 and variant == int(_variants.get(cue, -1)):
		variant = (variant + _rng.randi_range(1, streams.size() - 1)) % streams.size()
	_variants[cue] = variant
	_last_frame[cue] = frame
	_last_time[cue] = now
	voice.set("stream", streams[variant])
	voice.set("bus", entry["bus"])
	voice.set("volume_db", gain_db + float(entry["db"]) + extra_gain_db)
	voice.set("pitch_scale", _rng.randf_range(0.975, 1.025) if streams.size() > 1 else 1.0)
	voice.set_meta(&"priority", int(entry["priority"]))
	voice.set_meta(&"started", now)
	if spatial:
		(voice as AudioStreamPlayer2D).global_position = point
	# Silent driver shutdown does not drain Ogg. Rendered tests exercise the mixer.
	if DisplayServer.get_name() != "headless":
		voice.call(&"play")
	cue_played.emit(cue)
	return true
func _choose_voice(pool: Array, priority: int) -> Node:
	var choice: Node
	for voice: Node in pool:
		if not bool(voice.get("playing")):
			return voice
		var previous := int(voice.get_meta(&"priority", 0))
		if previous > priority or previous >= 3:
			continue
		if choice == null or previous < int(choice.get_meta(&"priority", 0)) or (previous == int(choice.get_meta(&"priority", 0)) and int(voice.get_meta(&"started", 0)) < int(choice.get_meta(&"started", 0))):
			choice = voice
	return choice
func stop_all() -> void:
	for voice: Node in _voices + _world_voices:
		voice.call(&"stop")
	_last_frame.clear()
	_last_time.clear()
func _exit_tree() -> void:
	stop_all()
	for voice: Node in _voices + _world_voices:
		voice.set("stream", null)
