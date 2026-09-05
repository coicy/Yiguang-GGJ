class_name AttackDefinition
extends Resource
@export var id: StringName = &"light_1"
@export var damage: int = 1
@export_range(0.0, 100.0, 1.0) var poise_damage: float = 10.0
@export var windup: float = 0.08
@export var active: float = 0.07
@export var recovery: float = 0.13
@export var reach: float = 60.0
@export var height: float = 38.0
@export var knockback: float = 100.0
@export var breaks_guard: bool = false
## Height of the attack origin above the feet; short forms strike at body height.
@export var origin_height: float = 22.0
## Horizontal impulse during the active window, applied through MovementController.
@export var lunge_speed: float = 0.0
func duration() -> float:
	return windup + active + recovery
