class_name BeetleBehavior
extends Node
## Beetle-specific decisions and motion requests; CombatEnemy owns the body/health.
signal transition_requested(state: StringName)
signal attack_requested(kind: StringName)
signal feedback_requested(kind: StringName, point: Vector2, strength: float)
@export var tuning: BeetleTuning
var actor: CombatEnemy
var motion := Vector2.ZERO
var direction: float = -1.0
var parry_pose: BeetlePose
var parry_recovery_pose: BeetlePose
var reaction: StringName = &"light"
var hit_direction: float = -1.0
var stun_duration: float = 0.28
var recovery_duration: float = 0.56
var charge_cooldown_left: float = 0.0
var _home_x: float = 0.0
var _lost_time: float = 0.0
var _alert: bool = false
var _turn_to: float = -1.0
var _turned: bool = false

func configure(enemy: CombatEnemy) -> void:
	actor = enemy
	direction = actor.facing
	_home_x = actor.global_position.x

func tick(delta: float) -> void:
	motion = actor.velocity
	direction = actor.facing
	charge_cooldown_left = maxf(0.0, charge_cooldown_left - delta)
	if not actor.is_on_floor():
		motion.y = minf(motion.y + actor.definition.gravity * delta, actor.definition.max_fall_speed)
	elif motion.y > 0.0:
		motion.y = 0.0
	# Reactions finish even after the target disappears or the encounter sleeps.
	match actor.state:
		&"stun":
			motion.x = move_toward(motion.x, 0.0, tuning.hit_braking * delta)
			if actor.elapsed >= stun_duration and actor.is_on_floor():
				_recover(0.24)
		&"windup":
			motion.x = move_toward(motion.x, 0.0, actor.definition.recovery_braking * delta)
			if not _can_engage() or not actor.is_on_floor():
				_recover(0.3)
			elif actor.elapsed >= windup_duration():
				transition_requested.emit(&"strike")
				feedback_requested.emit(&"swing", actor.global_position, 0.6)
		&"strike":
			_tick_attack()
		&"recover":
			motion.x = move_toward(motion.x, 0.0, actor.definition.recovery_braking * delta)
			if actor.elapsed >= recovery_duration:
				transition_requested.emit(&"idle")
		&"turn":
			motion.x = move_toward(motion.x, 0.0, tuning.acceleration * 2.0 * delta)
			if actor.elapsed >= tuning.turn_duration * 0.5 and not _turned:
				direction = _turn_to
				_turned = true
			if actor.elapsed >= tuning.turn_duration:
				transition_requested.emit(&"idle")
		&"notice":
			motion.x = move_toward(motion.x, 0.0, tuning.acceleration * delta)
			if actor.elapsed >= tuning.notice_duration:
				transition_requested.emit(&"idle")
		_:
			_tick_intent(delta)
	# Never run unsupported attacks. Knockback still uses the normal physics body.
	if actor.state != &"stun" and absf(motion.x) > 0.01:
		var travel_direction := signf(motion.x)
		if not _safe_ground(travel_direction, absf(motion.x) * delta):
			motion.x = 0.0
			if actor.state == &"strike":
				_recover(tuning.charge_recovery)

func _tick_intent(delta: float) -> void:
	if not _can_engage():
		_alert = false
		motion.x = move_toward(motion.x, 0.0, tuning.acceleration * delta)
		return
	var offset := actor.target.global_position - actor.global_position
	var sees_target := absf(offset.x) <= (tuning.lose_distance if _alert else tuning.notice_distance) and absf(offset.y) < 100.0 and _has_sight()
	if sees_target:
		_lost_time = 0.0
		if not _alert:
			_alert = true
			transition_requested.emit(&"notice")
			return
	else:
		_lost_time += delta
		if _lost_time >= tuning.lost_target_seconds:
			_alert = false
	if not _alert:
		_patrol(delta)
		return
	if not sees_target:
		motion.x = move_toward(motion.x, 0.0, tuning.acceleration * delta)
		return
	var wanted := signf(offset.x) if absf(offset.x) > 4.0 else direction
	if wanted != direction:
		_turn(wanted)
		return
	var distance := absf(offset.x)
	if actor.is_on_floor() and absf(offset.y) <= tuning.attack_height:
		if distance <= tuning.bite_range:
			_begin_attack(&"horn")
			return
		if distance >= tuning.charge_min_range and distance <= tuning.charge_max_range and charge_cooldown_left <= 0.0 and _charge_lane_clear(distance):
			charge_cooldown_left = tuning.charge_cooldown
			_begin_attack(&"charge")
			return
	motion.x = move_toward(motion.x, direction * actor.definition.move_speed if distance > tuning.bite_range * 0.85 else 0.0, tuning.acceleration * delta)

func _patrol(delta: float) -> void:
	if actor.state != &"patrol":
		transition_requested.emit(&"patrol")
	if actor.elapsed < tuning.patrol_pause:
		motion.x = move_toward(motion.x, 0.0, tuning.acceleration * delta)
		return
	if not _safe_ground(direction, 6.0) or (actor.global_position.x - _home_x) * direction > tuning.patrol_radius or actor.is_on_wall():
		_turn(-direction)
		return
	motion.x = move_toward(motion.x, direction * tuning.patrol_speed, tuning.acceleration * delta)

func _turn(wanted: float) -> void:
	_turn_to = wanted
	_turned = false
	transition_requested.emit(&"turn")

func _begin_attack(kind: StringName) -> void:
	motion.x = 0.0
	attack_requested.emit(kind)
	transition_requested.emit(&"windup")
	feedback_requested.emit(&"warning", actor.global_position, 0.7)

func _tick_attack() -> void:
	if not _can_engage() or not actor.is_on_floor():
		_recover(0.3)
		return
	if actor.attack_kind == &"charge":
		var launch := smoothstep(0.0, tuning.charge_launch_seconds, actor.elapsed)
		motion.x = direction * actor.definition.charge_speed * launch
		if actor.elapsed >= actor.definition.charge_duration:
			_recover(tuning.charge_recovery)
	else:
		motion.x = direction * tuning.bite_lunge_speed * sin(clampf(actor.elapsed / tuning.bite_duration, 0.0, 1.0) * PI)
		if actor.elapsed >= tuning.bite_duration:
			_recover(tuning.bite_recovery)

func after_movement() -> void:
	if actor.state == &"strike" and actor.attack_kind == &"charge" and actor.is_on_wall():
		reaction = &"wall"
		hit_direction = -direction
		stun_duration = tuning.wall_stun
		motion = Vector2(-direction * tuning.wall_rebound, 0.0)
		transition_requested.emit(&"stun")
		feedback_requested.emit(&"heavy_hit", actor.global_position + Vector2(direction * 18.0, -16.0), 0.65)

func react_to_hit(request: DamageRequest, dead: bool, stagger: bool = true) -> void:
	_alert = true
	if not dead and not stagger:
		motion = actor.velocity
		return
	hit_direction = signf(request.knockback.x)
	if is_zero_approx(hit_direction):
		hit_direction = -1.0 if request.origin.x >= actor.global_position.x else 1.0
	reaction = &"heavy" if request.breaks_guard or request.amount >= 2 else &"light"
	_alert = true
	motion = request.knockback
	if not dead:
		stun_duration = maxf(actor.definition.poise_break_stun, actor.definition.heavy_stun if reaction == &"heavy" else actor.definition.light_stun)
		transition_requested.emit(&"stun")

func react_to_parry() -> void:
	parry_pose = BeetlePose.sample(actor, 0.0)
	reaction = &"parry"
	hit_direction = -direction
	stun_duration = actor.definition.parry_stun
	motion = Vector2(-direction * actor.definition.parry_knockback, -55.0)
	transition_requested.emit(&"stun")

func _recover(duration: float) -> void:
	parry_recovery_pose = BeetlePose.sample(actor, 0.0) if actor.state == &"stun" and reaction == &"parry" else null
	recovery_duration = duration
	transition_requested.emit(&"recover")

func windup_duration() -> float:
	return actor.definition.charge_windup if actor.attack_kind == &"charge" else tuning.bite_windup

func attack_active() -> bool:
	if actor.state != &"strike" or not actor.is_on_floor():
		return false
	if actor.attack_kind == &"charge":
		return actor.elapsed >= tuning.charge_launch_seconds * 0.5 and actor.elapsed <= tuning.charge_active_end
	return actor.elapsed >= tuning.bite_active_start and actor.elapsed <= tuning.bite_active_end

func hit_size() -> Vector2:
	return tuning.charge_size if actor.attack_kind == &"charge" else tuning.bite_size

func _can_engage() -> bool:
	return actor.awake and is_instance_valid(actor.target) and actor.target.combat.health.current > 0

func _has_sight() -> bool:
	return CombatQuery.clear_path(actor, actor.global_position + Vector2(0.0, -18.0), actor.target.global_position + Vector2(0.0, -18.0))

func _safe_ground(face: float, extra: float) -> bool:
	var x := actor.global_position.x + face * (actor.definition.body_size.x * 0.5 + 5.0 + extra)
	if x < actor.bounds.position.x + 8.0 or x > actor.bounds.end.x - 8.0:
		return false
	var start := Vector2(x, actor.global_position.y - 10.0)
	var ray := PhysicsRayQueryParameters2D.create(start, start + Vector2(0.0, 34.0), 1)
	return not actor.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _charge_lane_clear(distance: float) -> bool:
	# Sample the reachable lane, not just the toe: do not charge across platform gaps.
	for step: int in range(1, ceili(minf(distance, actor.definition.charge_speed * actor.definition.charge_duration) / 20.0) + 1):
		if not _safe_ground(direction, step * 20.0):
			return false
	return true
