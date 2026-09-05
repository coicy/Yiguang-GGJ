class_name PoiseComponent
extends RefCounted
## Per-enemy toughness. Health damage remains independent of stagger resistance.
var maximum: float = 0.0
var current: float = 0.0
var broken: bool = false
var protection_left: float = 0.0
var _recovery_left: float = 0.0
var _recovery_delay: float = 2.0
var _recovery_rate: float = 15.0
var _protection_duration: float = 0.75


func configure(capacity: float, delay: float, rate: float, protection: float) -> void:
	maximum = maxf(0.0, capacity)
	_recovery_delay = maxf(0.0, delay)
	_recovery_rate = maxf(0.0, rate)
	_protection_duration = maxf(0.0, protection)
	current = maximum
	broken = false
	protection_left = 0.0
	_recovery_left = 0.0


func tick(delta: float) -> void:
	if broken or maximum <= 0.0:
		return
	protection_left = maxf(0.0, protection_left - delta)
	var recovery_step := maxf(0.0, delta - _recovery_left)
	_recovery_left = maxf(0.0, _recovery_left - delta)
	current = minf(maximum, current + _recovery_rate * recovery_step)


func take_damage(amount: float) -> bool:
	if maximum <= 0.0 or amount <= 0.0 or broken or protection_left > 0.0:
		return false
	_recovery_left = _recovery_delay
	current = maxf(0.0, current - amount)
	if current <= 0.0:
		return break_poise()
	return false


func break_poise() -> bool:
	if maximum <= 0.0 or broken:
		return false
	current = 0.0
	broken = true
	return true


func finish_stagger() -> void:
	if not broken:
		return
	broken = false
	current = maximum
	_recovery_left = _recovery_delay
	protection_left = _protection_duration
