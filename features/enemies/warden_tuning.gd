class_name WardenTuning
extends Resource
@export var slash: WardenMove
@export var charge: WardenMove
@export var slam: WardenMove
@export var uppercut: WardenMove
@export var backswing: WardenMove
@export_group("Intent and commitment")
@export var notice_duration: float = 0.65
@export var turn_duration: float = 0.28
@export var acceleration: float = 540.0
@export var charge_min_distance: float = 130.0
@export var charge_cooldown: float = 2.8
@export var slam_cooldown: float = 2.9
@export var uppercut_cooldown: float = 2.2
@export var attack_height: float = 42.0
@export var air_min_height: float = 32.0
@export var air_max_height: float = 146.0
@export var close_pressure_seconds: float = 0.85
@export var phase_notice_duration: float = 0.9
@export var phase_speed_multiplier: float = 1.2
@export_group("Poise and feedback")
@export var poise_limit: float = 6.0
@export var poise_memory: float = 2.0
@export var poise_decay: float = 1.4
@export var stagger_duration: float = 1.05
@export var parry_duration: float = 2.0
@export var wall_stun: float = 1.15
@export var light_reaction: float = 0.22
@export var heavy_reaction: float = 0.34
@export var reaction_knockback_ratio: float = 0.2
@export_group("Rig and contact")
@export var blade_length: float = 67.0
@export var blade_radius: float = 9.0
@export var transition_blend: float = 0.08

func move_for(kind: StringName) -> WardenMove:
	match kind:
		&"charge": return charge
		&"slam": return slam
		&"uppercut": return uppercut
		&"backswing": return backswing
	return slash
