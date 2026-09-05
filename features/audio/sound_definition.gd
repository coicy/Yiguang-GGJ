class_name SoundDefinition
extends Resource
## Designer-owned definition for one logical sound cue.

@export var sound_id: StringName
@export var streams: Array[AudioStream] = []
@export_range(-30.0, 6.0, 0.5) var volume_db: float = -6.0
@export_range(0.0, 2.0, 0.01) var cooldown_seconds: float = 0.0
@export_range(0.0, 0.2, 0.01) var pitch_randomness: float = 0.0


func has_streams() -> bool:
	return not streams.is_empty()

