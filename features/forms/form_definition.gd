class_name FormDefinition
extends Resource
## Serializable form configuration. Data only: no node references, no per-frame logic.

@export var id: StringName = &"humanoid"
@export var display_name: String = "Humanoid"
@export var move_speed: float = 300.0
@export var jump_force: float = -400.0
@export var gravity_scale: float = 1.0
@export var max_fall_speed: float = 800.0
@export var glide_enabled: bool = false
@export var glide_fall_speed: float = 140.0
@export var sprite_frames: SpriteFrames


static func from_dict(data: Dictionary) -> FormDefinition:
	var definition := FormDefinition.new()
	definition.id = StringName(str(data.get("id", "form")))
	definition.display_name = str(data.get("display_name", ""))
	definition.move_speed = float(data.get("move_speed", 300.0))
	definition.jump_force = float(data.get("jump_force", -400.0))
	definition.gravity_scale = float(data.get("gravity_scale", 1.0))
	definition.max_fall_speed = float(data.get("max_fall_speed", 800.0))
	definition.glide_enabled = bool(data.get("glide_enabled", false))
	definition.glide_fall_speed = float(data.get("glide_fall_speed", 140.0))
	return definition
