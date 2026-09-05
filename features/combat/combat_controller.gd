class_name CombatController
extends Node
signal action_started(action: StringName)
signal feedback_requested(kind: StringName, point: Vector2, strength: float)
signal defeated
@export var tuning: CombatTuning
@onready var health: HealthComponent = %CombatHealth
var player: Player
var state: StringName = &"idle"
var attack: AttackDefinition
var facing: float = 1.0
var elapsed: float = 0.0
var dash_cooldown_left: float = 0.0
var air_dash_used: bool = false
var air_attack_used: bool = false
var _buffer: StringName = &""
var _buffer_left: float = 0.0
var _aim := Vector2.ZERO
var _combo: int = 0
var _grace: float = 0.0
var _hit_targets: Dictionary = {}
var _attack_serial: int = 0
var _hurt_velocity: float = 0.0
var _swing_emitted: bool = false
var _ground_attack_brake: float = 0.0
var parry_from_progress: float = 0.0
var landing_from_progress: float = 0.0
var landing_from_elapsed: float = 0.0
func setup(actor: Player) -> void:
	player = actor
	health.reset_health()
	health.died.connect(_on_died)
func request_action(action: StringName, aim: Vector2) -> void:
	if player == null or health.current <= 0:
		return
	_buffer = action
	_buffer_left = tuning.buffer_seconds
	_aim = aim
func is_busy() -> bool:
	return state != &"idle"
func can_use_ability() -> bool:
	return state == &"idle" and health.current > 0
func time_scale_for_form() -> float:
	return tuning.mature_time_scale if player.current_form_id() == &"mature" else 1.0
func reach_scale() -> float:
	return tuning.mature_range_scale if player.current_form_id() == &"mature" else 1.0
func is_ground_attack() -> bool:
	return state == &"attack" and attack != null and attack.id != &"air" and player.is_on_floor()
func landing_progress() -> float:
	return clampf(elapsed / maxf(tuning.attack_landing_recovery, 0.001), 0.0, 1.0)
func progress() -> float:
	if state == &"attack_landing":
		return landing_progress()
	var duration := attack.duration() * time_scale_for_form() if attack != null else 0.42
	if state == &"dash":
		duration = tuning.dash_duration
	elif state == &"parry":
		duration = tuning.parry_start + tuning.parry_window + tuning.parry_recovery
	elif state == &"parry_success":
		duration = tuning.parry_success_duration
	return clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
func tick(delta: float) -> void:
	health.tick(delta)
	dash_cooldown_left = maxf(0.0, dash_cooldown_left - delta)
	_grace = maxf(0.0, _grace - delta)
	player.movement.clear_motion_override()
	if health.current <= 0:
		return
	if player.is_on_floor():
		air_dash_used = false
		air_attack_used = false
	elapsed += delta
	if state == &"attack" and attack != null:
		if elapsed >= attack.windup * time_scale_for_form() and not _swing_emitted:
			_swing_emitted = true
			feedback_requested.emit(&"swing", player.global_position, 1.0)
		if elapsed >= attack.duration() * time_scale_for_form():
			_finish()
	elif state == &"attack_landing":
		if elapsed >= tuning.attack_landing_recovery:
			_finish()
	elif state == &"dash":
		if elapsed >= tuning.dash_duration:
			dash_cooldown_left = tuning.dash_cooldown
			_finish()
	elif state == &"parry":
		if elapsed >= tuning.parry_start + tuning.parry_window + tuning.parry_recovery:
			_finish()
	elif state == &"parry_success":
		if elapsed >= tuning.parry_success_duration:
			_finish()
	elif state == &"hurt":
		if elapsed >= 0.22:
			_finish()
	if not _buffer.is_empty() and _buffer_left > 0.0:
		var can_cancel := state == &"idle" or state == &"parry_success"
		if state == &"attack" and attack != null:
			can_cancel = elapsed >= (attack.windup + attack.active) * time_scale_for_form()
			if _buffer in [&"attack", &"heavy"]:
				can_cancel = false # Buffer the next strike until recovery actually ends.
		if can_cancel and _try_start(_buffer):
			_buffer = &""
			_buffer_left = 0.0
	_buffer_left = maxf(0.0, _buffer_left - delta)
	if _buffer_left <= 0.0:
		_buffer = &""
	if state == &"dash":
		player.movement.set_motion_override(facing * tuning.dash_speed, 0.0)
	elif state == &"hurt":
		player.movement.set_motion_override(_hurt_velocity * (1.0 - elapsed / 0.22))
	player.movement.ground_brake_acceleration = 0.0
	player.movement.air_steering_scale = 1.0
	player.movement.preserve_air_momentum = false
	player.movement.control_scale = 0.0 if state in [&"parry", &"hurt"] else 1.0
	if (state in [&"parry", &"parry_success"] and player.is_on_floor()) or is_ground_attack() or state == &"attack_landing":
		player.movement.ground_brake_acceleration = _ground_attack_brake
		player.movement.control_scale = 0.0
	elif state == &"attack" and attack != null and attack.id == &"air":
		player.movement.air_steering_scale = tuning.air_attack_steering
		player.movement.preserve_air_momentum = true
	if is_ground_attack() and attack.lunge_speed > 0.0:
		var active_start := attack.windup * time_scale_for_form()
		var active_end := (attack.windup + attack.active) * time_scale_for_form()
		# Integrate only the part of this tick inside the impulse window.
		var active_step := maxf(0.0, minf(elapsed, active_end) - maxf(elapsed - delta, active_start))
		if elapsed >= active_start:
			player.movement.set_motion_override(facing * attack.lunge_speed * active_step / maxf(delta, 0.001))
	player.movement.allow_jump = state in [&"idle", &"parry_success"]
	player.movement.allow_glide = state == &"idle"
func after_movement() -> void:
	if player.is_on_floor():
		air_dash_used = false
		air_attack_used = false
		if state == &"attack" and attack != null and attack.id == &"air":
			# Landing closes the hit window immediately; visuals retract from this pose.
			landing_from_progress = progress()
			landing_from_elapsed = elapsed
			elapsed = 0.0
			state = &"attack_landing"
			_ground_attack_brake = _brake_for_stop(player.velocity.x, tuning.attack_landing_recovery)
	elif state == &"attack_landing" or (state == &"attack" and attack != null and attack.id != &"air"):
		# Grounded strikes and landing poses require continued floor support.
		cancel()
	if state != &"attack" or attack == null or health.current <= 0:
		return
	var t := elapsed / time_scale_for_form()
	if t < attack.windup or t >= attack.windup + attack.active:
		return
	var origin := player.global_position + Vector2(0.0, -attack.origin_height)
	var reach := attack.reach * reach_scale()
	var center := origin + Vector2(facing * reach * 0.5, 8.0 if attack.id == &"air" else 0.0)
	for hurt: Hurtbox in CombatQuery.targets(player, center, Vector2(reach, attack.height), CombatQuery.ENEMY_HURT):
		var target := hurt.receiver
		var id := target.get_instance_id()
		if _hit_targets.has(id) or not CombatQuery.clear_path(player, origin, hurt.world_center()):
			continue
		_hit_targets[id] = true
		var request := DamageRequest.new()
		request.source = player
		request.origin = origin
		request.amount = attack.damage
		request.poise_damage = attack.poise_damage
		request.breaks_guard = attack.breaks_guard
		request.attack_id = _attack_serial
		request.knockback = Vector2(facing * attack.knockback, -65.0)
		var result := hurt.deliver(request)
		if result == DamageRequest.Result.HIT:
			feedback_requested.emit(&"heavy_hit" if attack.damage >= 2 else &"hit", target.global_position + Vector2(0.0, -20.0), 1.0)
		elif result == DamageRequest.Result.BLOCKED:
			feedback_requested.emit(&"guard", target.global_position + Vector2(0.0, -24.0), 1.0)
func _try_start(action: StringName) -> bool:
	var is_sprout := player.current_form_id() == &"sprout"
	var on_ground := player.is_on_floor()
	if is_sprout and (action != &"attack" or not on_ground):
		return false
	# Let a buffered jump take off before choosing the attack variant.
	if on_ground and action in [&"attack", &"heavy"] and player.movement.has_buffered_jump():
		return false
	var chosen: AttackDefinition
	if action == &"dash":
		if dash_cooldown_left > 0.0 or (not on_ground and air_dash_used):
			return false
	elif action == &"heavy":
		if not on_ground:
			return false
		chosen = tuning.find_attack(&"heavy")
	elif action == &"attack":
		if is_sprout:
			chosen = tuning.find_attack(&"sprout_bump")
		elif not on_ground:
			if air_attack_used:
				return false
			chosen = tuning.find_attack(&"air")
		else:
			if _grace <= 0.0 and state != &"attack":
				_combo = 0
			_combo = _combo % 3 + 1
			chosen = tuning.find_attack(StringName("light_%d" % _combo))
	elif action != &"parry":
		return false
	if action in [&"attack", &"heavy"] and chosen == null:
		return false
	if state == &"dash":
		dash_cooldown_left = tuning.dash_cooldown
	var previous_velocity := player.velocity
	player.abilities.cancel_all()
	player.visuals.cancel_vine_effect()
	player.velocity = previous_velocity
	facing = -1.0 if _aim.x < player.global_position.x else 1.0
	attack = chosen
	landing_from_progress = 0.0
	landing_from_elapsed = 0.0
	_ground_attack_brake = 0.0
	parry_from_progress = 0.0
	if action == &"parry":
		_ground_attack_brake = _brake_for_stop(previous_velocity.x, tuning.parry_start)
	if chosen != null and chosen.id != &"air":
		_ground_attack_brake = _brake_for_stop(previous_velocity.x, chosen.windup * time_scale_for_form())
	_hit_targets.clear()
	_attack_serial += 1
	elapsed = 0.0
	_swing_emitted = false
	if action == &"dash":
		state = &"dash"
		if not on_ground:
			air_dash_used = true
		feedback_requested.emit(&"dash", player.global_position, 1.0)
	elif action == &"parry":
		state = &"parry"
	else:
		state = &"attack"
		if chosen.id == &"air":
			air_attack_used = true
	_grace = 0.0
	action_started.emit(chosen.id if chosen != null else state)
	return true
func _brake_for_stop(speed: float, available_time: float) -> float:
	var stop_time := maxf(0.001, minf(tuning.ground_attack_stop_seconds, available_time))
	return maxf(tuning.ground_attack_braking, absf(speed) / stop_time)
func receive_damage(request: DamageRequest) -> int:
	if health.current <= 0:
		return DamageRequest.Result.IGNORED
	if state == &"dash" and elapsed >= tuning.dash_safe_start and elapsed <= tuning.dash_safe_end:
		return DamageRequest.Result.IGNORED
	var in_front := (request.origin.x - player.global_position.x) * facing >= -3.0
	if state == &"parry" and request.parryable and in_front and elapsed >= tuning.parry_start and elapsed <= tuning.parry_start + tuning.parry_window:
		parry_from_progress = progress()
		state = &"parry_success"
		elapsed = 0.0
		if is_instance_valid(request.source) and request.source.has_method(&"receive_parry"):
			request.source.call(&"receive_parry", player)
		player.visuals.set_combat_state(self)
		feedback_requested.emit(&"parry", player.visuals.parry_contact_world_position(), 1.0)
		return DamageRequest.Result.PARRIED
	if not health.take_damage(request):
		return DamageRequest.Result.IGNORED
	if health.current > 0:
		cancel()
		player.abilities.cancel_all()
		player.visuals.cancel_vine_effect()
		state = &"hurt"
		_hurt_velocity = request.knockback.x
		player.velocity.y = minf(player.velocity.y, request.knockback.y)
		action_started.emit(&"hurt")
	feedback_requested.emit(&"hurt", player.global_position + Vector2(0.0, -20.0), 1.0)
	return DamageRequest.Result.HIT
func cancel() -> void:
	if state == &"dash":
		dash_cooldown_left = tuning.dash_cooldown
	state = &"idle"
	attack = null
	elapsed = 0.0
	_buffer = &""
	_buffer_left = 0.0
	_combo = 0
	_grace = 0.0
	_hit_targets.clear()
	if player != null:
		player.movement.clear_motion_override()
		player.movement.control_scale = 1.0
		player.movement.ground_brake_acceleration = 0.0
		player.movement.air_steering_scale = 1.0
		player.movement.preserve_air_momentum = false
		player.movement.allow_jump = true
		player.movement.allow_glide = true
func reset() -> void:
	cancel()
	dash_cooldown_left = 0.0
	air_dash_used = false
	air_attack_used = false
	health.reset_health()
func _finish() -> void:
	if state == &"attack" and attack != null and String(attack.id).begins_with("light"):
		_grace = tuning.combo_grace
	else:
		_combo = 0
	state = &"idle"
	attack = null
	elapsed = 0.0
func _on_died() -> void:
	cancel()
	state = &"dead"
	player.abilities.cancel_all()
	player.visuals.cancel_vine_effect()
	player.visuals.play_death()
	defeated.emit()
