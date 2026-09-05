class_name CombatTuning
extends Resource
@export var attacks: Array[AttackDefinition] = []
@export var buffer_seconds: float = 0.12
@export var combo_grace: float = 0.2
@export_group("Attack Movement")
@export var ground_attack_stop_seconds: float = 0.06
@export var ground_attack_braking: float = 3600.0
@export_range(0.0, 1.0) var air_attack_steering: float = 0.35
@export var attack_landing_recovery: float = 0.08
@export_group("Defense")
@export var dash_duration: float = 0.16
@export var dash_speed: float = 600.0
@export var dash_cooldown: float = 0.45
@export var dash_safe_start: float = 0.02
@export var dash_safe_end: float = 0.14
@export var parry_start: float = 0.03
@export var parry_window: float = 0.14
@export var parry_recovery: float = 0.25
@export var parry_success_duration: float = 0.28
@export var parry_pose_transfer: float = 0.045
@export_group("Form Modifiers")
@export var mature_time_scale: float = 1.2
@export var mature_range_scale: float = 1.4
func find_attack(id: StringName) -> AttackDefinition:
	for attack: AttackDefinition in attacks:
		if attack.id == id:
			return attack
	return null
