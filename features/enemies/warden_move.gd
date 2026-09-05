class_name WardenMove
extends Resource
## Shared timing contract for intent, full-body pose and the damage window.
@export var kind: StringName = &"slash"
@export var windup: float = 0.48
@export var duration: float = 0.32
@export var active_start: float = 0.1
@export var active_end: float = 0.22
@export var recovery: float = 0.65
@export var reach: float = 98.0
@export var step_speed: float = 130.0
@export var step_end: float = 0.24
@export var damage: int = 1
@export var parryable: bool = true
@export var knockback := Vector2(230.0, -110.0)
