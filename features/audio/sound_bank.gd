class_name SoundBank
extends Resource
## Read-only collection of designer-authored sound definitions.

@export var sounds: Array[SoundDefinition] = []

var _lookup: Dictionary = {}
var _lookup_built: bool = false


func get_sound(sound_id: StringName) -> SoundDefinition:
	_build_lookup()
	return _lookup.get(sound_id) as SoundDefinition


func _build_lookup() -> void:
	if _lookup_built:
		return
	for sound: SoundDefinition in sounds:
		if sound != null:
			var sound_id := StringName(sound.get(&"sound_id"))
			if not sound_id.is_empty():
				_lookup[sound_id] = sound
	_lookup_built = true
