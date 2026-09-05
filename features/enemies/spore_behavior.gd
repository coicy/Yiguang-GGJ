class_name SporeBehavior
extends Node
## Rooted ranged ambusher. CombatEnemy owns movement, health and damage delivery.
signal transition_requested(state: StringName)
signal attack_requested(kind: StringName)
signal shot_requested(direction: Vector2)
signal feedback_requested(kind: StringName, point: Vector2, strength: float)
@export var tuning: SporeTuning
var actor: CombatEnemy
var motion: Vector2 = Vector2.ZERO
var direction: float = -1.0
var aim_angle: float = 0.0
var aim_point: Vector2 = Vector2.ZERO
var parry_pose: SporePose
var parry_recovery_pose: SporePose
var reaction: StringName = &"light"
var hit_direction: float = -1.0
var stun_duration: float = 0.28
var recovery_duration: float = 1.12
var spit_cooldown_left: float = 0.0
var lash_cooldown_left: float = 0.0
var alerted: bool = false
var aim_locked: bool = false
var _lost_time: float = 0.0
var _turn_to: float = -1.0
var _turned: bool = false
var _shot_emitted: bool = false

func configure(enemy: CombatEnemy) -> void:
	actor = enemy
	direction = actor.facing
	aim_point = actor.global_position + Vector2(direction * 200.0, -32.0)

func tick(delta: float) -> void:
	motion = actor.velocity
	direction = actor.facing
	spit_cooldown_left = maxf(0.0, spit_cooldown_left - delta)
	lash_cooldown_left = maxf(0.0, lash_cooldown_left - delta)
	motion.x = move_toward(motion.x, 0.0, tuning.hit_braking * delta)
	if not actor.is_on_floor():
		motion.y = minf(motion.y + actor.definition.gravity * delta, actor.definition.max_fall_speed)
	elif motion.y > 0.0:
		motion.y = 0.0
	match actor.state:
		&"stun":
			if actor.elapsed >= stun_duration and actor.is_on_floor():
				_recover(tuning.settle_duration)
		&"recover":
			if actor.elapsed >= recovery_duration:
				transition_requested.emit(&"idle")
		&"turn":
			if actor.elapsed >= tuning.turn_duration * 0.5 and not _turned:
				direction = _turn_to
				_turned = true
			if actor.elapsed >= tuning.turn_duration:
				transition_requested.emit(&"idle")
		&"notice":
			if actor.elapsed >= tuning.notice_duration:
				transition_requested.emit(&"idle")
		&"windup":
			if not _can_engage() or not actor.is_on_floor():
				_recover(tuning.settle_duration)
				return
			if actor.attack_kind == &"spit" and not aim_locked:
				_track_aim()
				if actor.elapsed >= tuning.spit_windup - tuning.aim_lock_before_release:
					aim_locked = true
			if actor.elapsed >= windup_duration():
				transition_requested.emit(&"strike")
		&"strike":
			if not _can_engage() or not actor.is_on_floor():
				_recover(tuning.settle_duration)
				return
			if actor.attack_kind == &"spit":
				if actor.elapsed >= tuning.spit_release and not _shot_emitted:
					_shot_emitted = true
					var pose: SporePose = SporePose.sample(actor, 0.0)
					shot_requested.emit(pose.muzzle_direction_local() * Vector2(direction, 1.0))
					feedback_requested.emit(&"swing", actor.global_position, 0.55)
				if actor.elapsed >= tuning.spit_duration:
					_recover(tuning.spit_recovery)
			elif actor.elapsed >= tuning.lash_duration:
				_recover(tuning.lash_recovery)
		_:
			_tick_intent(delta)

func _tick_intent(delta: float) -> void:
	if not _can_engage():
		alerted = false
		return
	var offset: Vector2 = actor.target.global_position - actor.global_position
	var seen: bool = absf(offset.x) <= (tuning.lose_distance if alerted else tuning.notice_distance) and absf(offset.y) <= tuning.aim_height and _has_sight()
	if not seen:
		_lost_time += delta
		if _lost_time >= tuning.lost_target_seconds:
			alerted = false
		return
	_lost_time = 0.0
	if not alerted:
		alerted = true
		transition_requested.emit(&"notice")
		return
	var wanted: float = signf(offset.x) if absf(offset.x) > 4.0 else direction
	if wanted != direction:
		_turn_to = wanted
		_turned = false
		transition_requested.emit(&"turn")
		return
	if not actor.is_on_floor():
		return
	var distance: float = absf(offset.x)
	if distance <= tuning.lash_range and absf(offset.y) <= tuning.lash_height:
		if lash_cooldown_left <= 0.0:
			_begin_attack(&"lash")
	elif distance >= tuning.spit_min_range and distance <= actor.definition.attack_range and spit_cooldown_left <= 0.0 and _target_in_aim_cone():
		_begin_attack(&"spit")

func _begin_attack(kind: StringName) -> void:
	motion.x = 0.0
	attack_requested.emit(kind)
	_shot_emitted = false
	aim_locked = false
	if kind == &"spit":
		spit_cooldown_left = tuning.spit_cooldown
		_track_aim()
	else:
		lash_cooldown_left = tuning.lash_cooldown
		aim_angle = 0.0
	transition_requested.emit(&"windup")
	feedback_requested.emit(&"warning", actor.global_position, 0.6)

func _track_aim() -> void:
	# Keep a world-space target point. The moving nozzle solves its own pitch to this point.
	# Crossing behind or above the aim cone preserves the last readable direction.
	if not _target_in_aim_cone():
		return
	aim_point = actor.target.hurtbox.world_center()
	var offset: Vector2 = aim_point - (actor.global_position + Vector2(0.0, -32.0))
	aim_angle = atan2(offset.y, offset.x * direction)

func _target_in_aim_cone() -> bool:
	var offset: Vector2 = actor.target.hurtbox.world_center() - (actor.global_position + Vector2(0.0, -32.0))
	return offset.x * direction > 0.0 and absf(atan2(offset.y, offset.x * direction)) <= tuning.aim_limit

func _can_engage() -> bool:
	return actor.awake and is_instance_valid(actor.target) and actor.target.combat.health.current > 0

func _has_sight() -> bool:
	return CombatQuery.clear_path(actor, actor.global_position + Vector2(0.0, -26.0), actor.target.global_position + actor.definition.projectile_target_offset)

func _recover(duration: float) -> void:
	parry_recovery_pose = SporePose.sample(actor, 0.0) if actor.state == &"stun" and reaction == &"parry" else null
	recovery_duration = duration
	transition_requested.emit(&"recover")

func windup_duration() -> float:
	return tuning.spit_windup if actor.attack_kind == &"spit" else tuning.lash_windup

func attack_active() -> bool:
	return actor.state == &"strike" and actor.attack_kind == &"lash" and actor.is_on_floor() and actor.elapsed >= tuning.lash_active_start and actor.elapsed <= tuning.lash_active_end

func react_to_hit(request: DamageRequest, dead: bool, stagger: bool = true) -> void:
	alerted = true
	if not dead and not stagger:
		motion = actor.velocity
		return
	hit_direction = signf(request.knockback.x)
	if is_zero_approx(hit_direction):
		hit_direction = -1.0 if request.origin.x >= actor.global_position.x else 1.0
	reaction = &"heavy" if request.breaks_guard or request.amount >= 2 else &"light"
	motion = request.knockback
	alerted = true
	if not dead:
		stun_duration = maxf(actor.definition.poise_break_stun, actor.definition.heavy_stun if reaction == &"heavy" else actor.definition.light_stun)
		transition_requested.emit(&"stun")

func react_to_parry() -> void:
	parry_pose = SporePose.sample(actor, 0.0)
	reaction = &"parry"
	hit_direction = -direction
	stun_duration = actor.definition.parry_stun
	motion = Vector2(-direction * actor.definition.parry_knockback, -tuning.parry_lift)
	transition_requested.emit(&"stun")
