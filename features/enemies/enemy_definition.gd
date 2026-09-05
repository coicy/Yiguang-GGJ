class_name EnemyDefinition
extends Resource
enum Kind { BEETLE, SPORE, PRUNER, WARDEN }

@export var kind: Kind = Kind.BEETLE
@export var display_name: String = "污染甲虫"
@export var maximum_health: int = 4
@export var body_size := Vector2(36.0, 28.0)

@export_group("Poise")
## Zero leaves stagger handling to a species-specific behavior (the Warden).
@export_range(0.0, 200.0, 1.0) var maximum_poise: float = 30.0
@export_range(0.0, 10.0, 0.1) var poise_recovery_delay: float = 2.0
@export_range(0.0, 100.0, 1.0) var poise_recovery_rate: float = 15.0
@export_range(0.0, 3.0, 0.05) var poise_break_stun: float = 0.65
@export_range(0.0, 3.0, 0.05) var poise_recovery_protection: float = 0.75

@export_group("Movement")
@export var move_speed: float = 65.0
@export var gravity: float = 1200.0
@export var max_fall_speed: float = 700.0
@export var pursuit_stop_distance: float = 38.0
@export var vertical_attack_tolerance: float = 90.0
@export var recovery_braking: float = 800.0
@export var stun_braking: float = 700.0
@export var arena_margin: float = 24.0
@export var fall_out_margin: float = 120.0

@export_group("Strike")
@export var windup: float = 0.6
@export var recovery: float = 0.9
@export var attack_range: float = 80.0
@export var strike_duration: float = 0.22
@export var strike_size := Vector2(48.0, 38.0)
@export var strike_forward_ratio: float = 0.4
@export var strike_damage: int = 1
@export var strike_knockback := Vector2(230.0, -130.0)

@export_group("Charge")
@export var charge_windup: float = 0.6
@export var charge_speed: float = 260.0
@export var charge_duration: float = 0.48

@export_group("Slam")
@export var slam_windup: float = 0.9
@export var slam_duration: float = 0.28
@export var slam_size := Vector2(145.0, 28.0)
@export var slam_damage: int = 2
@export var wave_spawn_offset := Vector2(30.0, -10.0)

@export_group("Second Phase")
@export var second_phase_health_fraction: float = 0.5
@export var double_strike_duration: float = 0.67
@export var first_strike_end: float = 0.2
@export var second_strike_start: float = 0.42

@export_group("Responses")
@export var light_stun: float = 0.28
@export var heavy_stun: float = 0.7
@export var parry_stun: float = 0.7
@export var guard_open_seconds: float = 1.3
@export var parry_knockback: float = 80.0
@export var death_duration: float = 0.65
@export var hit_flash_duration: float = 0.12

@export_group("Projectile")
@export var projectile_spawn_offset := Vector2(22.0, -26.0)
@export var projectile_target_offset := Vector2(0.0, -20.0)

@export_group("Presentation")
@export var atlas: Texture2D
@export var tint := Color("#b6ad63")
