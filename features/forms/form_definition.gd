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
