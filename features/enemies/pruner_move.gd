class_name PrunerMove
extends Resource
## One read-only move. Timing is shared by decisions, collision and pose sampling.
@export var kind: StringName = &"shear"
@export var windup: float = 0.52
@export var duration: float = 0.3
@export var active_start: float = 0.09
@export var active_end: float = 0.19
@export var recovery: float = 0.72
@export var reach: float = 58.0
@export var hit_size := Vector2(44.0, 34.0)
@export var hit_offset := Vector2(32.0, -28.0)
@export var step_speed: float = 48.0
@export var step_end: float = 0.18
@export var damage: int = 1
@export var parryable: bool = true
@export var knockback := Vector2(190.0, -90.0)
