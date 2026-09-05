class_name DamageRequest
extends RefCounted
enum Result { IGNORED, HIT, BLOCKED, PARRIED }
var source: Node2D
var attack_id: int = 0
var amount: int = 1
var poise_damage: float = 10.0
var origin := Vector2.ZERO
var knockback := Vector2.ZERO
var parryable: bool = true
var breaks_guard: bool = false
