class_name SoundEmitter
extends Node
## Reusable local SFX player with a bounded voice pool.
## Components send a logical cue ID; this node owns playback policy only.

signal cue_played(cue: StringName)
signal cue_rejected(cue: StringName, reason: StringName)

@export var sound_bank: SoundBank
@export_range(1, 16, 1) var voice_count: int = 6
@export_range(-40.0, 6.0, 0.5) var gain_db: float = 0.0
@export var bus: StringName = &"SFX"

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _next_variant: Dictionary = {}
var _last_played_frame: Dictionary = {}


func _ready() -> void:
	voice_count = maxi(1, voice_count)
	for index: int in range(voice_count):
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % index
		voice.bus = _resolve_bus()
		add_child(voice)
		_voices.append(voice)


func play_sound(cue: StringName, extra_gain_db: float = 0.0) -> bool:
	return play_cue(cue, extra_gain_db)


func play_cue(cue: StringName, extra_gain_db: float = 0.0) -> bool:
	if sound_bank == null:
		cue_rejected.emit(cue, &"missing_bank")
		return false
	var definition := sound_bank.get_sound(cue)
	if definition == null:
		cue_rejected.emit(cue, &"missing_definition")
		return false
	var streams: Array[AudioStream] = definition.streams
	if streams.is_empty():
		cue_rejected.emit(cue, &"missing_stream")
		return false
	if _is_on_cooldown(cue, definition.cooldown_seconds):
		cue_rejected.emit(cue, &"cooldown")
		return false

	var variant_index := int(_next_variant.get(cue, 0)) % streams.size()
	_next_variant[cue] = variant_index + 1
	var voice := _take_voice()
	voice.stream = streams[variant_index]
	voice.volume_db = gain_db + definition.volume_db + extra_gain_db
	voice.pitch_scale = _pick_pitch(definition.pitch_randomness)
	# Headless validation checks routing and stream assignment without leaving playback handles alive.
	if DisplayServer.get_name() != "headless":
		voice.play()
	_last_played_frame[cue] = Engine.get_physics_frames()
	cue_played.emit(cue)
	return true


func stop_all() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()


func active_voice_count() -> int:
	var active: int = 0
	for voice: AudioStreamPlayer in _voices:
		if voice.playing:
			active += 1
	return active


func _take_voice() -> AudioStreamPlayer:
	for offset: int in range(_voices.size()):
		var index := (_next_voice + offset) % _voices.size()
		if not _voices[index].playing:
			_next_voice = (index + 1) % _voices.size()
			return _voices[index]
	var stolen := _voices[_next_voice]
	stolen.stop()
	_next_voice = (_next_voice + 1) % _voices.size()
	return stolen


func _is_on_cooldown(cue: StringName, cooldown_seconds: float) -> bool:
	if cooldown_seconds <= 0.0:
		return false
	var last_frame := int(_last_played_frame.get(cue, -1000000000))
	var cooldown_frames := maxi(1, ceili(cooldown_seconds * Engine.physics_ticks_per_second))
	return Engine.get_physics_frames() - last_frame < cooldown_frames


func _pick_pitch(randomness: float) -> float:
	if randomness <= 0.0:
		return 1.0
	return randf_range(1.0 - randomness, 1.0 + randomness)


func _resolve_bus() -> StringName:
	return bus if AudioServer.get_bus_index(bus) >= 0 else &"Master"


func _exit_tree() -> void:
	stop_all()
	for voice: AudioStreamPlayer in _voices:
		voice.stream = null
