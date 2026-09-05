class_name SporeTuning
extends Resource
## Read-only species parameters. Runtime timers belong to SporeBehavior.
@export_group("Perception")
@export var notice_distance: float = 420.0
@export var lose_distance: float = 510.0
@export var notice_duration: float = 0.34
@export var lost_target_seconds: float = 0.9
@export var turn_duration: float = 0.32
@export var aim_height: float = 130.0
@export var aim_limit: float = 0.65
@export var aim_lock_before_release: float = 0.22
@export_group("Spit")
@export var spit_min_range: float = 76.0
@export var spit_windup: float = 0.84
@export var spit_duration: float = 0.30
@export var spit_release: float = 0.10
@export var spit_recovery: float = 1.12
@export var spit_cooldown: float = 2.25
@export_group("Body Lash")
@export var lash_range: float = 73.0
@export var lash_height: float = 46.0
@export var lash_windup: float = 0.48
@export var lash_duration: float = 0.28
@export var lash_active_start: float = 0.075
@export var lash_active_end: float = 0.19
@export var lash_size: Vector2 = Vector2(66.0, 43.0)
@export var lash_recovery: float = 0.86
@export var lash_cooldown: float = 1.85
@export_group("Reactions")
@export var hit_braking: float = 1050.0
@export var settle_duration: float = 0.34
@export var parry_lift: float = 70.0
