class_name WardenBehavior
extends Node
## Position-driven intent; locked attacks and finite pressure strings leave real openings.
signal transition_requested(state: StringName)
signal attack_requested(kind: StringName)
signal feedback_requested(kind: StringName, point: Vector2, strength: float)
signal waves_requested(point: Vector2)
@export var tuning: WardenTuning
var actor: CombatEnemy
var motion := Vector2.ZERO
var direction: float = -1.0
var recovery_duration: float = 0.65
var recovery_pose: WardenPose
var stun_duration: float = 1.05
var parry_pose: WardenPose
var reaction: StringName = &"light"
var reaction_left: float = 0.0
var reaction_duration: float = 0.22
var hit_direction: float = -1.0
var poise: float = 0.0
var combo_planned: bool = false
var phase_pending: bool = false
var charge_cooldown_left: float = 0.0
var slam_cooldown_left: float = 0.0
var uppercut_cooldown_left: float = 0.0
var _introduced: bool = false
var _turn_to: float = -1.0
var _turned: bool = false
var _close_time: float = 0.0
var _poise_memory_left: float = 0.0
var _last_move: StringName = &""
var _impact_emitted: bool = false
var _phase_attack: bool = false
var _step_delta: float = 1.0 / 60.0

func configure(enemy: CombatEnemy) -> void:
	actor = enemy
	direction = actor.facing

func current_move() -> WardenMove:
	return tuning.move_for(actor.attack_kind)

func tick(delta: float) -> void:
	_step_delta = delta
	motion = actor.velocity
	direction = actor.facing
	reaction_left = maxf(0.0, reaction_left - delta)
	charge_cooldown_left = maxf(0.0, charge_cooldown_left - delta)
	slam_cooldown_left = maxf(0.0, slam_cooldown_left - delta)
	uppercut_cooldown_left = maxf(0.0, uppercut_cooldown_left - delta)
	_poise_memory_left = maxf(0.0, _poise_memory_left - delta)
	if _poise_memory_left <= 0.0:
		poise = maxf(0.0, poise - tuning.poise_decay * delta)
	if not actor.is_on_floor():
		motion.y = minf(motion.y + actor.definition.gravity * delta, actor.definition.max_fall_speed)
	elif motion.y > 0.0:
		motion.y = 0.0
	if actor.state == &"stun":
		motion.x = move_toward(motion.x, 0.0, actor.definition.stun_braking * delta)
		if actor.elapsed >= stun_duration and actor.is_on_floor():
			_recover(0.28)
	elif not can_engage():
		motion.x = move_toward(motion.x, 0.0, tuning.acceleration * delta)
		combo_planned = false
		if actor.state not in [&"idle", &"recover"]:
			_recover(0.4)
	elif actor.state == &"windup":
		motion.x = move_toward(motion.x, 0.0, actor.definition.recovery_braking * delta)
		if not actor.is_on_floor():
			_recover(current_move().recovery)
		elif actor.elapsed >= current_move().windup:
			_impact_emitted = false
			transition_requested.emit(&"strike")
			feedback_requested.emit(&"swing", actor.global_position + Vector2(0, -48), 1.0)
	elif actor.state == &"strike":
		_tick_strike()
	elif actor.state == &"recover":
		motion.x = move_toward(motion.x, 0.0, actor.definition.recovery_braking * delta)
		if actor.elapsed >= recovery_duration:
			_finish_opening()
	elif actor.state in [&"notice", &"overload"]:
		motion.x = move_toward(motion.x, 0.0, tuning.acceleration * delta)
		var duration := tuning.phase_notice_duration if actor.state == &"overload" else tuning.notice_duration
		if actor.elapsed >= duration:
			transition_requested.emit(&"idle")
	elif actor.state == &"turn":
		motion.x = move_toward(motion.x, 0.0, tuning.acceleration * 2.0 * delta)
		if actor.elapsed >= tuning.turn_duration * 0.5 and not _turned:
			direction = _turn_to
			_turned = true
		if actor.elapsed >= tuning.turn_duration:
			transition_requested.emit(&"idle")
	else:
		_tick_intent(delta)
	# Every driven action samples the next support point. Knockback still uses physics.
	if actor.state != &"stun" and absf(motion.x) > 0.01 and not safe_ground(signf(motion.x), absf(motion.x) * delta):
		motion.x = 0.0
		if actor.state == &"strike":
			var support_x := actor.global_position.x + direction * (actor.definition.body_size.x * 0.5 + 5.0 + absf(actor.velocity.x) * delta)
			if actor.attack_kind == &"charge" and (support_x < actor.bounds.position.x + 8.0 or support_x > actor.bounds.end.x - 8.0):
				_stagger(&"wall", tuning.wall_stun, Vector2(-direction * 95, 0))
				feedback_requested.emit(&"heavy_hit", actor.global_position + Vector2(direction * 28, -35), 0.9)
			else:
				_recover(current_move().recovery)

func _tick_intent(delta: float) -> void:
	if not _introduced:
		_introduced = true
		transition_requested.emit(&"notice")
		return
	if phase_pending:
		_finish_opening()
		return
	var offset := actor.target.global_position - actor.global_position
	if not has_sight():
		motion.x = move_toward(motion.x, 0.0, tuning.acceleration * delta)
		_close_time = 0.0
		return
	var wanted := signf(offset.x) if absf(offset.x) > 4.0 else direction
	if wanted != direction:
		_turn_to = wanted
		_turned = false
		transition_requested.emit(&"turn")
		return
	var distance := absf(offset.x)
	_close_time = _close_time + delta if distance < tuning.slash.reach else 0.0
	if actor.is_on_floor():
		if offset.y < -tuning.air_min_height and offset.y > -tuning.air_max_height and distance < tuning.uppercut.reach and uppercut_cooldown_left <= 0.0:
			uppercut_cooldown_left = tuning.uppercut_cooldown
			_begin_attack(&"uppercut")
			return
		if absf(offset.y) < tuning.attack_height:
			if distance >= tuning.charge_min_distance and distance <= tuning.charge.reach and charge_cooldown_left <= 0.0 and lane_supported():
				charge_cooldown_left = tuning.charge_cooldown
				_begin_attack(&"charge")
				return
			if distance <= tuning.slam.reach and slam_cooldown_left <= 0.0 and (_last_move in [&"slash", &"backswing"] or _close_time >= tuning.close_pressure_seconds):
				slam_cooldown_left = tuning.slam_cooldown
				_begin_attack(&"slam")
				return
			if distance <= tuning.slash.reach:
				_begin_attack(&"slash")
				return
	var speed := actor.definition.move_speed * (tuning.phase_speed_multiplier if actor.second_phase else 1.0)
	# Do not camp directly under a target that cannot currently be reached.
	var desired := direction * speed if distance > 60.0 else 0.0
	motion.x = move_toward(motion.x, desired, tuning.acceleration * delta)

func _begin_attack(kind: StringName, followup: bool = false) -> void:
	motion.x = 0.0
	_last_move = kind
	_phase_attack = actor.second_phase and not phase_pending
	combo_planned = kind == &"slash" and _phase_attack and not followup
	attack_requested.emit(kind)
	transition_requested.emit(&"windup")
	feedback_requested.emit(&"danger" if kind == &"slam" else &"warning", actor.global_position, 1.0)

func _tick_strike() -> void:
	if not actor.is_on_floor():
		_recover(current_move().recovery)
		return
	var move := current_move()
	var t := actor.elapsed
	if actor.attack_kind == &"charge":
		var launch := smoothstep(0.0, 0.11, t)
		var brake := 1.0 - smoothstep(move.active_end - 0.06, move.step_end, t)
		motion.x = direction * move.step_speed * launch * brake
	else:
		motion.x = direction * move.step_speed * sin(clampf(t / move.step_end, 0.0, 1.0) * PI) if t < move.step_end else 0.0
	if t >= move.duration:
		var offset := actor.target.global_position - actor.global_position
		# Followup is announced at the first startup, has its own startup, and cannot turn.
		if combo_planned and offset.x * direction > 8.0 and absf(offset.x) < tuning.backswing.reach and absf(offset.y) < tuning.attack_height and has_sight():
			_begin_attack(&"backswing", true)
		else:
			_recover(move.recovery)

func after_movement() -> void:
	if actor.state != &"strike":
		return
	if actor.attack_kind == &"charge" and actor.is_on_wall():
		_stagger(&"wall", tuning.wall_stun, Vector2(-direction * 95.0, 0.0))
		feedback_requested.emit(&"heavy_hit", actor.global_position + Vector2(direction * 28, -35), 0.9)
		return
	if actor.attack_kind == &"slam" and actor.is_on_floor() and actor.elapsed >= current_move().active_start and not _impact_emitted:
		_impact_emitted = true
		var impact := impact_point()
		if CombatQuery.clear_path(actor, actor.global_position + Vector2(0, -18), impact):
			feedback_requested.emit(&"heavy_hit", impact, 1.25)
			if _phase_attack:
				waves_requested.emit(impact)

func attack_active() -> bool:
	return actor.state == &"strike" and actor.is_on_floor() and can_engage() and actor.elapsed >= current_move().active_start and actor.elapsed - _step_delta < current_move().active_end

func attack_samples() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var move := current_move()
	if actor.attack_kind == &"slam":
		points.append(impact_point())
		return points
	if actor.attack_kind == &"charge":
		points.append(actor.global_position + Vector2(direction * 24, -34))
		return points
	# Sweep the actual blade through physics time, including the last active boundary.
	var from_time := maxf(move.active_start, actor.elapsed - _step_delta)
	var to_time := minf(actor.elapsed, move.active_end)
	for sample_index: int in range(4):
		var time := lerpf(from_time, to_time, sample_index / 3.0)
		var pose := WardenPose.sample(actor, 0.0, time)
		var start := pose.hand
		var end := pose.blade_tip(tuning.blade_length)
		for point_index: int in range(9):
			points.append(actor.global_position + start.lerp(end, point_index / 8.0) * Vector2(direction, 1.0))
	return points

func hit_size() -> Vector2:
	if actor.attack_kind == &"slam": return Vector2(98, 22)
	if actor.attack_kind == &"charge": return Vector2(42, 62)
	return Vector2.ONE * tuning.blade_radius * 2.0

func impact_point() -> Vector2:
	var pose := WardenPose.strike_pose(&"slam", tuning.slam.active_end, tuning.slam)
	return actor.global_position + Vector2(pose.blade_tip(tuning.blade_length).x * direction, -10)

func react_to_hit(request: DamageRequest, dead: bool) -> void:
	hit_direction = signf(request.knockback.x)
	if is_zero_approx(hit_direction):
		hit_direction = -1.0 if request.origin.x >= actor.global_position.x else 1.0
	var heavy := request.breaks_guard or request.amount >= 2
	if actor.state != &"stun":
		reaction = &"heavy" if heavy else &"light"
	reaction_duration = tuning.heavy_reaction if heavy else tuning.light_reaction
	reaction_left = reaction_duration
	if dead:
		return
	if actor.state == &"stun":
		return # Further hits deal damage without extending the earned opening.
	poise += 3.0 if heavy else 1.0
	_poise_memory_left = tuning.poise_memory
	if poise >= tuning.poise_limit:
		_stagger(&"break", tuning.stagger_duration, Vector2(hit_direction * 115, -65))
		feedback_requested.emit(&"heavy_hit", actor.global_position + Vector2(0, -48), 0.85)
	elif actor.state not in [&"windup", &"strike"]:
		motion = Vector2(request.knockback.x * tuning.reaction_knockback_ratio, actor.velocity.y)
	else:
		motion = actor.velocity

func react_to_parry() -> void:
	parry_pose = WardenPose.sample(actor, 0.0)
	if actor.state == &"stun": return
	_stagger(&"parry", tuning.parry_duration, Vector2(-direction * 100, -55))

func _stagger(kind: StringName, duration: float, impulse: Vector2) -> void:
	reaction = kind
	hit_direction = signf(impulse.x)
	stun_duration = duration
	reaction_duration = duration
	reaction_left = duration
	poise = 0.0
	combo_planned = false
	motion = impulse
	transition_requested.emit(&"stun")

func _recover(duration: float) -> void:
	recovery_pose = WardenPose.sample(actor, 0.0)
	if actor.state == &"stun":
		reaction_left = 0.0
	combo_planned = false
	recovery_duration = duration
	transition_requested.emit(&"recover")

func _finish_opening() -> void:
	if phase_pending:
		phase_pending = false
		transition_requested.emit(&"overload")
		feedback_requested.emit(&"danger", actor.global_position, 1.2)
	else:
		transition_requested.emit(&"idle")

func can_engage() -> bool:
	return actor.awake and is_instance_valid(actor.target) and actor.target.combat.health.current > 0

func has_sight() -> bool:
	return CombatQuery.clear_path(actor, actor.global_position + Vector2(0, -43), actor.target.global_position + Vector2(0, -22))

func safe_ground(face: float, extra: float) -> bool:
	var x := actor.global_position.x + face * (actor.definition.body_size.x * 0.5 + 5.0 + extra)
	if x < actor.bounds.position.x + 8.0 or x > actor.bounds.end.x - 8.0: return false
	var start := Vector2(x, actor.global_position.y - 10)
	var ray := PhysicsRayQueryParameters2D.create(start, start + Vector2(0, 35), 1)
	return not actor.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func lane_supported() -> bool:
	# Check the entire rush, not just the first footstep, before committing.
	var distance := tuning.charge.step_speed * tuning.charge.step_end
	for index: int in range(1, ceili(distance / 14.0) + 1):
		var support_x := actor.global_position.x + direction * (actor.definition.body_size.x * 0.5 + 5 + index * 14)
		# Arena gates stop a rush physically; they are valid bait, unlike missing floor.
		if support_x < actor.bounds.position.x + 8.0 or support_x > actor.bounds.end.x - 8.0: return true
		if not safe_ground(direction, index * 14.0): return false
	return true
