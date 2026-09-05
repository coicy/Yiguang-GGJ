class_name BeetleTuning
extends Resource
## All combat times are seconds; distances are world units.
@export_group("Senses and footwork")
@export var notice_distance: float = 300.0
@export var lose_distance: float = 410.0
@export var notice_duration: float = 0.3
@export var lost_target_seconds: float = 1.0
@export var patrol_speed: float = 24.0
@export var patrol_radius: float = 70.0
@export var patrol_pause: float = 0.7
@export var acceleration: float = 360.0
@export var turn_duration: float = 0.24
@export var attack_height: float = 42.0
@export var bite_range: float = 49.0
@export var charge_min_range: float = 78.0
@export var charge_max_range: float = 210.0
@export var charge_cooldown: float = 2.6
@export_group("Horn lift")
@export var bite_windup: float = 0.38
@export var bite_duration: float = 0.24
@export var bite_active_start: float = 0.045
@export var bite_active_end: float = 0.16
@export var bite_recovery: float = 0.56
@export var bite_lunge_speed: float = 110.0
@export var bite_size := Vector2(44.0, 34.0)
@export_group("Charge")
@export var charge_launch_seconds: float = 0.09
@export var charge_active_end: float = 0.42
@export var charge_recovery: float = 0.78
@export var charge_size := Vector2(44.0, 28.0)
@export var wall_stun: float = 0.85
@export var wall_rebound: float = 65.0
@export var hit_braking: float = 920.0
