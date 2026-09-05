class_name SoundEmitter
extends Node
## Local, bounded sound voices. Shared audio streams are never mutated.
signal cue_played(cue: StringName)
@export_range(-40.0, 0.0, 1.0) var gain_db: float = -10.0
@export_range(1, 8, 1) var voice_count: int = 6
const CUES := {
	&"step_grass": {"files": [preload("res://assets/runtime/audio/footstep_grass_000.ogg"), preload("res://assets/runtime/audio/footstep_grass_001.ogg"), preload("res://assets/runtime/audio/footstep_grass_002.ogg")], "db": -7.0},
	&"step_hard": {"files": [preload("res://assets/runtime/audio/footstep_concrete_000.ogg"), preload("res://assets/runtime/audio/footstep_concrete_001.ogg")], "db": -7.0},
	&"jump": {"files": [preload("res://assets/runtime/audio/cloth1.ogg")], "db": -6.0},
	&"land": {"files": [preload("res://assets/runtime/audio/impactSoft_medium_000.ogg")], "db": -4.0},
	&"grow": {"files": [preload("res://assets/runtime/audio/jingles_PIZZI02.ogg")], "db": -4.0},
	&"wither": {"files": [preload("res://assets/runtime/audio/jingles_PIZZI06.ogg")], "db": -4.0},
	&"absorb": {"files": [preload("res://assets/runtime/audio/handleCoins2.ogg")], "db": -14.0},
	&"root": {"files": [preload("res://assets/runtime/audio/beltHandle1.ogg")], "db": -5.0},
	&"extend": {"files": [preload("res://assets/runtime/audio/clothBelt.ogg")], "db": -9.0},
	&"vine": {"files": [preload("res://assets/runtime/audio/metalLatch.ogg")], "db": -6.0},
	&"glide": {"files": [preload("res://assets/runtime/audio/cloth2.ogg")], "db": -8.0},
	&"button": {"files": [preload("res://assets/runtime/audio/click3.ogg")], "db": -3.0},
	&"mechanism_start": {"files": [preload("res://assets/runtime/audio/creak1.ogg")], "db": -7.0},
	&"mechanism_stop": {"files": [preload("res://assets/runtime/audio/impactWood_medium_000.ogg")], "db": -5.0},
	&"checkpoint": {"files": [preload("res://assets/runtime/audio/jingles_PIZZI00.ogg")], "db": -4.0},
	&"death": {"files": [preload("res://assets/runtime/audio/impactSoft_heavy_000.ogg")], "db": -2.0},
}
var _voices: Array[AudioStreamPlayer] = []
var _variants: Dictionary = {}
var _last_frame: Dictionary = {}
var _next_voice: int = 0
func _ready() -> void:
	for index: int in range(voice_count):
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % index
		add_child(voice)
		_voices.append(voice)
func play_cue(cue: StringName, extra_gain_db: float = 0.0) -> bool:
	if not CUES.has(cue) or _voices.is_empty():
		return false
	var frame := Engine.get_physics_frames()
	if _last_frame.get(cue, -1) == frame:
		return false
	_last_frame[cue] = frame
	var entry: Dictionary = CUES[cue]
	var streams: Array = entry["files"]
	var variant := int(_variants.get(cue, 0)) % streams.size()
	_variants[cue] = variant + 1
	var voice := _voices[_next_voice]
	for candidate: AudioStreamPlayer in _voices:
		if not candidate.playing:
			voice = candidate
			break
	_next_voice = (_voices.find(voice) + 1) % _voices.size()
	voice.stream = streams[variant] as AudioStream
	voice.volume_db = gain_db + float(entry["db"]) + extra_gain_db
	# Headless uses a silent driver that does not drain Ogg playback on shutdown.
	# Still route cues and assign streams; rendered acceptance tests exercise the mixer.
	if DisplayServer.get_name() != "headless":
		voice.play()
	cue_played.emit(cue)
	return true
func stop_all() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()


func _exit_tree() -> void:
	stop_all()
	for voice: AudioStreamPlayer in _voices:
		voice.stream = null
