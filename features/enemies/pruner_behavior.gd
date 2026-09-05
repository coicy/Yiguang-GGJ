class_name PrunerBehavior
extends Node
## Dedicated intent and motion component. The actor owns state, health and movement.
signal transition_requested(state: StringName)
signal attack_requested(kind: StringName)
signal feedback_requested(kind: StringName, point: Vector2, strength: float)
@export var tuning: PrunerTuning
var actor: CombatEnemy
var motion := Vector2.ZERO
var direction: float = -1.0
var parry_pose: PrunerPose
var parry_recovery_pose: PrunerPose
var reaction: StringName = &"light"
var hit_direction: float = -1.0
var stun_duration: float = 0.28
var recovery_duration: float = 0.72
var lunge_cooldown_left: float = 0.0
var cleave_cooldown_left: float = 0.0
var _alert: bool = false
var _lost_time: float = 0.0
var _home_x: float = 0.0
var _turn_to: float = -1.0
var _turned: bool = false
var _block_count: int = 0
var _block_memory_left: float = 0.0
var _last_move: StringName = &""
var _impact_emitted: bool = false

func configure(enemy: CombatEnemy) -> void:
	actor = enemy
	direction = actor.facing
	_home_x = actor.global_position.x

func current_move() -> PrunerMove:
	return tuning.move_for(actor.attack_kind)

func tick(delta: float) -> void:
	motion = actor.velocity
	direction = actor.facing
	lunge_cooldown_left = maxf(0.0, lunge_cooldown_left - delta)
	cleave_cooldown_left = maxf(0.0, cleave_cooldown_left - delta)
	_block_memory_left = maxf(0.0, _block_memory_left - delta)
	if _block_memory_left <= 0.0:
		_block_count = 0
	if not actor.is_on_floor():
		motion.y = minf(motion.y + actor.definition.gravity * delta, actor.definition.max_fall_speed)
	elif motion.y > 0.0:
		motion.y = 0.0
	match actor.state:
		&"stun":
			motion.x = move_toward(motion.x, 0.0, tuning.hit_braking * delta)
			if actor.elapsed >= stun_duration and actor.is_on_floor():
				_recover(0.32)
		&"guard_bump":
			motion.x = move_toward(motion.x, 0.0, tuning.hit_braking * delta)
			if actor.elapsed >= tuning.block_duration:
				transition_requested.emit(&"idle")
		&"windup":
			motion.x = move_toward(motion.x, 0.0, actor.definition.recovery_braking * delta)
			if not _can_engage() or not actor.is_on_floor():
				_recover(0.35)
			elif actor.elapsed >= current_move().windup:
				_impact_emitted = false
				transition_requested.emit(&"strike")
				feedback_requested.emit(&"swing", actor.global_position + Vector2(0, -30), 0.7)
		&"strike":
			_tick_strike()
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
	if actor.state != &"stun" and absf(motion.x) > 0.01:
		if not _safe_ground(signf(motion.x), absf(motion.x) * delta):
			motion.x = 0.0
			if actor.state == &"strike":
				_recover(current_move().recovery)

func _tick_intent(delta: float) -> void:
	if not _can_engage():
		_alert = false
		motion.x = move_toward(motion.x, 0.0, tuning.acceleration * delta)
		return
	var offset := actor.target.global_position - actor.global_position
	var sees := absf(offset.x) < (tuning.lose_distance if _alert else tuning.notice_distance) and absf(offset.y) < 100.0 and _has_sight()
	if sees:
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
	if not sees:
		motion.x = move_toward(motion.x, 0.0, tuning.acceleration * delta)
		return
	var wanted := signf(offset.x) if absf(offset.x) > 3.0 else direction
	if wanted != direction:
		_turn(wanted)
		return
	var distance := absf(offset.x)
	if actor.is_on_floor() and absf(offset.y) <= tuning.attack_height:
		if distance <= tuning.cleave.reach and cleave_cooldown_left <= 0.0 and (_block_count >= 2 or _last_move == &"shear"):
			cleave_cooldown_left = tuning.cleave_cooldown
			_block_count = 0
			_begin_attack(&"slam")
			return
		if distance <= tuning.shear.reach:
			_begin_attack(&"shear")
			return
		if distance >= tuning.lunge_min_range and distance <= tuning.lunge.reach and lunge_cooldown_left <= 0.0 and _lane_clear():
			lunge_cooldown_left = tuning.lunge_cooldown
			_begin_attack(&"lunge")
			return
	# Close behind the shield; do not repeatedly swing into a target on a ledge.
	var speed := direction * actor.definition.move_speed if distance > tuning.shear.reach * 0.82 else 0.0
	motion.x = move_toward(motion.x, speed, tuning.acceleration * delta)

func _patrol(delta: float) -> void:
	if actor.state != &"patrol":
		transition_requested.emit(&"patrol")
	if actor.elapsed < tuning.patrol_pause:
		motion.x = move_toward(motion.x, 0.0, tuning.acceleration * delta)
		return
	if (actor.global_position.x - _home_x) * direction > tuning.patrol_radius or not _safe_ground(direction, 7.0) or actor.is_on_wall():
		_turn(-direction)
		return
	motion.x = move_toward(motion.x, direction * tuning.patrol_speed, tuning.acceleration * delta)

func _turn(wanted: float) -> void:
	_turn_to = wanted
	_turned = false
	transition_requested.emit(&"turn")

func _begin_attack(kind: StringName) -> void:
	motion.x = 0.0
	_last_move = kind
	attack_requested.emit(kind)
	transition_requested.emit(&"windup")
	feedback_requested.emit(&"danger" if kind == &"slam" else &"warning", actor.global_position, 0.8)

func _tick_strike() -> void:
	if not _can_engage() or not actor.is_on_floor():
		_recover(0.35)
		return
	var move := current_move()
	var progress := clampf(actor.elapsed / move.step_end, 0.0, 1.0)
	motion.x = direction * move.step_speed * sin(progress * PI) if actor.elapsed < move.step_end else 0.0
	if actor.elapsed >= move.active_start and not _impact_emitted:
		_impact_emitted = true
		if actor.attack_kind == &"slam":
			feedback_requested.emit(&"heavy_hit", actor.global_position + Vector2(direction * 38.0, -2.0), 0.45)
	if actor.elapsed >= move.duration:
		_recover(move.recovery)

func after_movement() -> void:
	if actor.state == &"strike" and actor.attack_kind == &"lunge" and actor.is_on_wall():
		reaction = &"wall"
		hit_direction = -direction
		stun_duration = tuning.wall_stun
		motion = Vector2(-direction * 45.0, 0.0)
		transition_requested.emit(&"stun")
		feedback_requested.emit(&"block", actor.global_position + Vector2(direction * 22, -24), 0.6)

func attack_active() -> bool:
	return actor.state == &"strike" and actor.is_on_floor() and _can_engage() and actor.elapsed >= current_move().active_start and actor.elapsed <= current_move().active_end

func guarding() -> bool:
	if actor.state == &"windup":
		return actor.elapsed < current_move().windup * tuning.guard_release_fraction
	return actor.state in [&"idle", &"patrol", &"notice", &"turn", &"guard_bump"]

func react_to_block(_request: DamageRequest) -> void:
	_alert = true
	_block_count += 1
	_block_memory_left = tuning.block_memory
	hit_direction = -direction
	reaction = &"block"
	motion = Vector2(-direction * tuning.block_speed, actor.velocity.y)
	transition_requested.emit(&"guard_bump")
	feedback_requested.emit(&"block", actor.global_position + Vector2(direction * 19, -31), 0.45)

func react_to_hit(request: DamageRequest, dead: bool, guard_broken: bool, stagger: bool = true) -> void:
	_alert = true
	if not dead and not stagger:
		motion = actor.velocity
		return
	hit_direction = signf(request.knockback.x)
	if is_zero_approx(hit_direction):
		hit_direction = -1.0 if request.origin.x >= actor.global_position.x else 1.0
	reaction = &"break" if guard_broken else &"heavy" if request.breaks_guard or request.amount >= 2 else &"light"
	_alert = true
	motion = request.knockback
	if not dead:
		stun_duration = tuning.guard_break_stun if guard_broken else maxf(actor.definition.poise_break_stun, actor.definition.heavy_stun if reaction == &"heavy" else actor.definition.light_stun)
		transition_requested.emit(&"stun")

func react_to_parry() -> void:
	parry_pose = PrunerPose.sample(actor, 0.0)
	reaction = &"parry"
	hit_direction = -direction
	stun_duration = actor.definition.parry_stun
	motion = Vector2(-direction * actor.definition.parry_knockback, -65.0)
	transition_requested.emit(&"stun")

func _recover(duration: float) -> void:
	parry_recovery_pose = PrunerPose.sample(actor, 0.0) if actor.state == &"stun" and reaction == &"parry" else null
	recovery_duration = duration
	transition_requested.emit(&"recover")

func _can_engage() -> bool:
	return actor.awake and is_instance_valid(actor.target) and actor.target.combat.health.current > 0

func _has_sight() -> bool:
	return CombatQuery.clear_path(actor, actor.global_position + Vector2(0, -28), actor.target.global_position + Vector2(0, -22))

func _safe_ground(face: float, extra: float) -> bool:
	var x := actor.global_position.x + face * (actor.definition.body_size.x * 0.5 + 5.0 + extra)
	if x < actor.bounds.position.x + 8.0 or x > actor.bounds.end.x - 8.0:
		return false
	var start := Vector2(x, actor.global_position.y - 10.0)
	var ray := PhysicsRayQueryParameters2D.create(start, start + Vector2(0, 34), 1)
	return not actor.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _lane_clear() -> bool:
	var distance := tuning.lunge.step_speed * tuning.lunge.step_end * 2.0 / PI
	for step: int in range(1, ceili(distance / 12.0) + 1):
		if not _safe_ground(direction, step * 12.0):
			return false
	return true
