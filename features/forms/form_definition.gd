class_name FormDefinition
extends Resource
## Serializable form configuration. Data only: no node references, no per-frame logic.

@export var id: StringName = &"humanoid"
@export var display_name: String = "Humanoid"
@export var move_speed: float = 300.0
@export var jump_force: float = -400.0
@export var gravity_scale: float = 1.0
@export var max_fall_speed: float = 800.0
@export var collision_size: Vector2 = Vector2(28.0, 40.0)
@export var body_color: Color = Color("5abf77")
@export_range(0.0, 1000.0, 1.0) var growth_threshold: float = 0.0
@export var can_root: bool = false
@export var can_extend_legs: bool = false
@export var can_use_vine: bool = false
@export var can_glide: bool = false
# Kept while the movement controller is migrated to the capability flag.
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
	definition.collision_size = data.get("collision_size", Vector2(28.0, 40.0)) as Vector2
	definition.body_color = data.get("body_color", Color("5abf77")) as Color
	definition.growth_threshold = float(data.get("growth_threshold", 0.0))
	definition.can_root = bool(data.get("can_root", false))
	definition.can_extend_legs = bool(data.get("can_extend_legs", false))
	definition.can_use_vine = bool(data.get("can_use_vine", false))
	definition.can_glide = bool(data.get("can_glide", false))
	definition.glide_enabled = bool(data.get("glide_enabled", false))
	definition.glide_fall_speed = float(data.get("glide_fall_speed", 140.0))
	return definition
