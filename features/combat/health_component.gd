class_name HealthComponent
extends Node
signal health_changed(current: int, maximum: int)
signal damaged(request: DamageRequest)
signal died
@export var maximum: int = 5
@export var protection_seconds: float = 0.8
var current: int = 5
var protection_left: float = 0.0
func reset_health() -> void:
	current = maximum
	protection_left = 0.0
	health_changed.emit(current, maximum)
func tick(delta: float) -> void:
	protection_left = maxf(0.0, protection_left - delta)
func take_damage(request: DamageRequest) -> bool:
	if current <= 0 or protection_left > 0.0 or request.amount <= 0:
		return false
	current = maxi(0, current - request.amount)
	protection_left = protection_seconds
	health_changed.emit(current, maximum)
	damaged.emit(request)
	if current == 0:
		died.emit()
	return true
