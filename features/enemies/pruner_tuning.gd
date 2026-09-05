class_name PrunerTuning
extends Resource
@export var shear: PrunerMove
@export var lunge: PrunerMove
@export var cleave: PrunerMove
@export_group("Awareness and footwork")
@export var notice_distance: float = 310.0
@export var lose_distance: float = 420.0
@export var lost_target_seconds: float = 0.8
@export var notice_duration: float = 0.32
@export var turn_duration: float = 0.3
@export var patrol_radius: float = 64.0
@export var patrol_speed: float = 19.0
@export var patrol_pause: float = 0.7
@export var acceleration: float = 260.0
@export var attack_height: float = 38.0
@export var lunge_min_range: float = 78.0
@export var lunge_cooldown: float = 3.2
@export var cleave_cooldown: float = 3.6
@export_group("Guard and reactions")
@export var guard_release_fraction: float = 0.38
@export var block_duration: float = 0.24
@export var block_speed: float = 32.0
@export var block_memory: float = 2.4
@export var guard_break_stun: float = 0.95
@export var wall_stun: float = 0.5
@export var hit_braking: float = 540.0
@export var transition_blend: float = 0.09

func move_for(kind: StringName) -> PrunerMove:
	if kind == &"lunge":
		return lunge
	if kind == &"slam":
		return cleave
	return shear
