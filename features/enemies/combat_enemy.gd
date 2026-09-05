class_name CombatEnemy
extends CharacterBody2D
signal defeated(enemy: CombatEnemy)
signal audio_state_changed(state: StringName)
signal feedback_requested(kind: StringName, point: Vector2, strength: float)
signal projectile_requested(enemy: CombatEnemy, position: Vector2, direction: Vector2, wave: bool)
@export var definition: EnemyDefinition
@export var beetle_behavior: BeetleBehavior
@export var pruner_behavior: PrunerBehavior
@export var spore_behavior: SporeBehavior
@export var warden_behavior: WardenBehavior
@onready var health: HealthComponent = %EnemyHealth
@onready var visuals: EnemyVisual = %EnemyVisual
var poise := PoiseComponent.new()
var target: Player
var state: StringName = &"idle"
var elapsed: float = 0.0
var facing: float = -1.0
var bounds := Rect2(-100000.0, -2000.0, 200000.0, 4000.0)
var awake: bool = false
var attack_kind: StringName = &"slash"
var second_phase: bool = false
var _attack_count: int = 0
var _hit_delivered: bool = false
var _repeat_started: bool = false
var _waves_emitted: bool = false
var _guard_open: float = 0.0
var _death_reported: bool = false
var _stun_duration: float = 0.3
var _knockback: float = 0.0
var hurtbox: Hurtbox
var audio: EnemyAudio
func _ready() -> void:
	poise.configure(definition.maximum_poise, definition.poise_recovery_delay, definition.poise_recovery_rate, definition.poise_recovery_protection)
	health.maximum = definition.maximum_health
	health.protection_seconds = 0.0
	health.reset_health()
	health.died.connect(_die)
	var shape := RectangleShape2D.new()
	shape.size = definition.body_size
	%BodyShape.shape = shape
	%BodyShape.position.y = -definition.body_size.y * 0.5
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.configure(self, CombatQuery.ENEMY_HURT, definition.body_size)
	add_child(hurtbox)
	if beetle_behavior != null and definition.kind == EnemyDefinition.Kind.BEETLE:
		beetle_behavior.configure(self)
		beetle_behavior.transition_requested.connect(_set_state)
		beetle_behavior.attack_requested.connect(_select_beetle_attack)
		beetle_behavior.feedback_requested.connect(_forward_beetle_feedback)
	else:
		beetle_behavior = null
	if spore_behavior != null and definition.kind == EnemyDefinition.Kind.SPORE:
		spore_behavior.configure(self)
		spore_behavior.transition_requested.connect(_set_state)
		spore_behavior.attack_requested.connect(_select_beetle_attack)
		spore_behavior.shot_requested.connect(_release_spore)
		spore_behavior.feedback_requested.connect(_forward_beetle_feedback)
	else:
		spore_behavior = null
	if pruner_behavior != null and definition.kind == EnemyDefinition.Kind.PRUNER:
		pruner_behavior.configure(self)
		pruner_behavior.transition_requested.connect(_set_state)
		pruner_behavior.attack_requested.connect(_select_beetle_attack)
		pruner_behavior.feedback_requested.connect(_forward_beetle_feedback)
	else:
		pruner_behavior = null
	if warden_behavior != null and definition.kind == EnemyDefinition.Kind.WARDEN:
		warden_behavior.configure(self)
		warden_behavior.transition_requested.connect(_set_state)
		warden_behavior.attack_requested.connect(_select_beetle_attack)
		warden_behavior.feedback_requested.connect(_forward_beetle_feedback)
		warden_behavior.waves_requested.connect(_release_warden_waves)
	else:
		warden_behavior = null
	visuals.configure(self)
	audio = EnemyAudio.new()
	audio.name = "EnemyAudio"
	add_child(audio)
	audio.setup(self)
func _physics_process(delta: float) -> void:
	health.tick(delta)
	if state != &"dead":
		poise.tick(delta)
	elapsed += delta
	_guard_open = maxf(0.0, _guard_open - delta)
	if state == &"dead":
		if spore_behavior != null or warden_behavior != null:
			var braking := spore_behavior.tuning.hit_braking if spore_behavior != null else definition.stun_braking
			velocity.x = move_toward(velocity.x, 0.0, braking * delta)
			if not is_on_floor():
				velocity.y = minf(velocity.y + definition.gravity * delta, definition.max_fall_speed)
			move_and_slide()
		if elapsed >= definition.death_duration:
			queue_free()
		return
	if global_position.y > bounds.end.y + definition.fall_out_margin:
		_die()
		return
	if warden_behavior != null:
		warden_behavior.tick(delta)
		velocity = warden_behavior.motion
		facing = warden_behavior.direction
		move_and_slide()
		warden_behavior.after_movement()
		if state == &"stun":
			velocity = warden_behavior.motion
		if warden_behavior.attack_active():
			_deliver_warden_strike()
		return
	if spore_behavior != null:
		spore_behavior.tick(delta)
		velocity = spore_behavior.motion
		facing = spore_behavior.direction
		move_and_slide()
		if spore_behavior.attack_active():
			_deliver_strike()
		return
	if pruner_behavior != null:
		pruner_behavior.tick(delta)
		velocity = pruner_behavior.motion
		facing = pruner_behavior.direction
		move_and_slide()
		pruner_behavior.after_movement()
		if state == &"stun":
			velocity = pruner_behavior.motion
		if pruner_behavior.attack_active():
			_deliver_strike()
		return
	if beetle_behavior != null:
		beetle_behavior.tick(delta)
		velocity = beetle_behavior.motion
		facing = beetle_behavior.direction
		move_and_slide()
		beetle_behavior.after_movement()
		if state == &"stun":
			velocity = beetle_behavior.motion
		if beetle_behavior.attack_active():
			_deliver_strike()
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + definition.gravity * delta, definition.max_fall_speed)
	if not awake or not is_instance_valid(target):
		velocity.x = 0.0
		move_and_slide()
		return
	if state == &"stun":
		velocity.x = move_toward(velocity.x, 0.0, delta * definition.stun_braking)
		if elapsed >= _stun_duration:
			_set_state(&"recover")
	elif state == &"windup":
		velocity.x = 0.0
		var windup := definition.windup
		if attack_kind == &"slam":
			windup = definition.slam_windup
		elif attack_kind == &"charge":
			windup = definition.charge_windup
		if elapsed >= windup:
			_set_state(&"strike")
			_hit_delivered = false
			_repeat_started = false
			_waves_emitted = false
			if definition.kind == EnemyDefinition.Kind.SPORE:
				var spawn_offset := definition.projectile_spawn_offset
				var direction := (target.global_position + definition.projectile_target_offset - (global_position + Vector2(0.0, spawn_offset.y))).normalized()
				projectile_requested.emit(self, global_position + Vector2(facing * spawn_offset.x, spawn_offset.y), direction, false)
	elif state == &"strike":
		_tick_strike(delta)
	elif state == &"recover":
		velocity.x = move_toward(velocity.x, 0.0, delta * definition.recovery_braking)
		if elapsed >= definition.recovery:
			_set_state(&"idle")
	else:
		_tick_pursuit()
	if state != &"stun" and state != &"strike" and not _floor_ahead():
		velocity.x = 0.0
	if global_position.x < bounds.position.x + definition.arena_margin and velocity.x < 0.0:
		velocity.x = 0.0
	if global_position.x > bounds.end.x - definition.arena_margin and velocity.x > 0.0:
		velocity.x = 0.0
	move_and_slide()
	if state == &"strike" and definition.kind != EnemyDefinition.Kind.SPORE:
		_deliver_strike()
func _tick_pursuit() -> void:
	var distance := target.global_position.x - global_position.x
	facing = -1.0 if distance < 0.0 else 1.0
	var in_range := absf(distance) <= definition.attack_range and absf(target.global_position.y - global_position.y) < definition.vertical_attack_tolerance
	if definition.kind == EnemyDefinition.Kind.SPORE:
		velocity.x = 0.0
		in_range = absf(distance) < definition.attack_range
	else:
		velocity.x = facing * definition.move_speed if absf(distance) > definition.pursuit_stop_distance else 0.0
	if in_range and CombatQuery.clear_path(self, global_position + Vector2(0.0, -20.0), target.global_position + Vector2(0.0, -20.0)):
		attack_kind = &"charge" if definition.kind == EnemyDefinition.Kind.BEETLE else &"slash"
		if definition.kind == EnemyDefinition.Kind.WARDEN:
			attack_kind = [&"slash", &"charge", &"slam"][_attack_count % 3]
			_attack_count += 1
		_set_state(&"windup")
		feedback_requested.emit(&"danger" if attack_kind == &"slam" else &"warning", global_position, 1.0)
func _tick_strike(_delta: float) -> void:
	var duration := definition.strike_duration
	if attack_kind == &"charge":
		velocity.x = facing * definition.charge_speed
		duration = definition.charge_duration
		if is_on_wall():
			duration = 0.0
	elif attack_kind == &"slam":
		velocity.x = 0.0
		duration = definition.slam_duration
		if not _waves_emitted and second_phase:
			_waves_emitted = true
			projectile_requested.emit(self, global_position + Vector2(-definition.wave_spawn_offset.x, definition.wave_spawn_offset.y), Vector2.LEFT, true)
			projectile_requested.emit(self, global_position + definition.wave_spawn_offset, Vector2.RIGHT, true)
	else:
		velocity.x = 0.0
		if definition.kind == EnemyDefinition.Kind.WARDEN and second_phase:
			duration = definition.double_strike_duration
			if elapsed >= definition.second_strike_start and not _repeat_started:
				_hit_delivered = false
				_repeat_started = true
	if elapsed >= duration:
		_set_state(&"recover")
func _deliver_strike() -> void:
	if state != &"strike" or _hit_delivered:
		return
	if pruner_behavior != null and not pruner_behavior.attack_active():
		return
	if beetle_behavior != null and not beetle_behavior.attack_active():
		return
	if spore_behavior != null and not spore_behavior.attack_active():
		return
	if definition.kind == EnemyDefinition.Kind.WARDEN and attack_kind == &"slash" and elapsed > definition.first_strike_end and elapsed < definition.second_strike_start:
		return
	var size := definition.slam_size if attack_kind == &"slam" else definition.strike_size
	if beetle_behavior != null:
		size = beetle_behavior.hit_size()
	if spore_behavior != null:
		size = spore_behavior.tuning.lash_size
	if pruner_behavior != null:
		size = pruner_behavior.current_move().hit_size
	var width := size.x
	var height := size.y
	var origin := global_position + Vector2(0.0, -height * 0.5)
	var center := origin + Vector2(facing * width * definition.strike_forward_ratio, 0.0)
	if pruner_behavior != null:
		var offset := pruner_behavior.current_move().hit_offset
		center = global_position + Vector2(offset.x * facing, offset.y)
		origin = global_position + Vector2(0, -28)
	for hurt: Hurtbox in CombatQuery.targets(self, center, Vector2(width, height), CombatQuery.PLAYER_HURT):
		if not CombatQuery.clear_path(self, origin, hurt.world_center()):
			continue
		var request := DamageRequest.new()
		request.source = self
		request.origin = origin
		request.amount = definition.slam_damage if attack_kind == &"slam" else definition.strike_damage
		request.parryable = attack_kind != &"slam"
		request.knockback = Vector2(facing * definition.strike_knockback.x, definition.strike_knockback.y)
		if pruner_behavior != null:
			var move := pruner_behavior.current_move()
			request.amount = move.damage
			request.parryable = move.parryable
			request.knockback = Vector2(facing * move.knockback.x, move.knockback.y)
		var result := hurt.deliver(request)
		if result != DamageRequest.Result.IGNORED:
			_hit_delivered = true
			break
func _deliver_warden_strike() -> void:
	if state != &"strike" or _hit_delivered:
		return
	var move := warden_behavior.current_move()
	var origin := global_position + Vector2(0, -34)
	for point: Vector2 in warden_behavior.attack_samples():
		if not CombatQuery.clear_path(self, origin, point):
			continue
		for hurt: Hurtbox in CombatQuery.targets(self, point, warden_behavior.hit_size(), CombatQuery.PLAYER_HURT):
			if not CombatQuery.clear_path(self, origin, hurt.world_center()):
				continue
			var request := DamageRequest.new()
			request.source = self
			request.origin = origin
			request.amount = move.damage
			request.parryable = move.parryable
			request.knockback = Vector2(facing * move.knockback.x, move.knockback.y)
			if hurt.deliver(request) != DamageRequest.Result.IGNORED:
				_hit_delivered = true
				return

func _release_warden_waves(point: Vector2) -> void:
	for face: float in [-1.0, 1.0]:
		var spawn := point + Vector2(face * 8, 0)
		if CombatQuery.clear_path(self, point, spawn):
			projectile_requested.emit(self, spawn, Vector2(face, 0), true)

func receive_damage(request: DamageRequest) -> int:
	if state == &"dead":
		return DamageRequest.Result.IGNORED
	var guarded := definition.kind == EnemyDefinition.Kind.PRUNER and _guard_open <= 0.0 and state not in [&"stun", &"recover", &"strike"]
	if pruner_behavior != null:
		guarded = _guard_open <= 0.0 and pruner_behavior.guarding()
	var guard_broken := false
	if guarded and (request.origin.x - global_position.x) * facing >= 0.0:
		if not request.breaks_guard:
			if pruner_behavior != null:
				pruner_behavior.react_to_block(request)
				velocity = pruner_behavior.motion
			return DamageRequest.Result.BLOCKED
		_guard_open = definition.guard_open_seconds
		guard_broken = true
	if not health.take_damage(request):
		return DamageRequest.Result.IGNORED
	visuals.flash_left = definition.hit_flash_duration
	if warden_behavior != null:
		if state != &"dead" and not second_phase and health.current <= definition.maximum_health * definition.second_phase_health_fraction:
			second_phase = true
			warden_behavior.phase_pending = true
		warden_behavior.react_to_hit(request, state == &"dead")
		velocity = warden_behavior.motion
		return DamageRequest.Result.HIT
	var stagger := false
	if state not in [&"dead", &"stun"]:
		stagger = guard_broken or poise.maximum <= 0.0 or poise.take_damage(request.poise_damage)
	if pruner_behavior != null:
		pruner_behavior.react_to_hit(request, state == &"dead", guard_broken, stagger)
		velocity = pruner_behavior.motion
		return DamageRequest.Result.HIT
	if spore_behavior != null:
		spore_behavior.react_to_hit(request, state == &"dead", stagger)
		velocity = spore_behavior.motion
		return DamageRequest.Result.HIT
	if beetle_behavior != null:
		beetle_behavior.react_to_hit(request, state == &"dead", stagger)
		velocity = beetle_behavior.motion
		return DamageRequest.Result.HIT
	if stagger and state != &"dead" and definition.kind != EnemyDefinition.Kind.WARDEN:
		velocity = request.knockback
		_stun_duration = maxf(definition.poise_break_stun, definition.heavy_stun if request.breaks_guard else definition.light_stun)
		_set_state(&"stun")
	if state != &"dead" and definition.kind == EnemyDefinition.Kind.WARDEN and not second_phase and health.current <= definition.maximum_health * definition.second_phase_health_fraction:
		second_phase = true
		feedback_requested.emit(&"heavy_hit", global_position + Vector2(0.0, -40.0), 1.4)
	return DamageRequest.Result.HIT
func receive_parry(_actor: Node2D) -> void:
	if state in [&"dead", &"stun"]:
		return
	# Close all pending contacts before entering the recoil, including repeat strikes.
	_hit_delivered = true
	_repeat_started = true
	_waves_emitted = true
	if warden_behavior != null:
		warden_behavior.react_to_parry()
		velocity = warden_behavior.motion
		return
	if pruner_behavior != null:
		_guard_open = definition.guard_open_seconds
		pruner_behavior.react_to_parry()
		velocity = pruner_behavior.motion
		return
	if spore_behavior != null:
		spore_behavior.react_to_parry()
		velocity = spore_behavior.motion
		return
	if beetle_behavior != null:
		beetle_behavior.react_to_parry()
		velocity = beetle_behavior.motion
		return
	_guard_open = definition.guard_open_seconds
	_stun_duration = definition.parry_stun
	velocity.x = -facing * definition.parry_knockback
	_set_state(&"stun")
func _floor_ahead() -> bool:
	var from := global_position + Vector2(facing * 25.0, -10.0)
	var ray := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 45.0), 1)
	return not get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
func _set_state(value: StringName) -> void:
	if value == &"stun":
		if state == &"stun":
			return
		poise.break_poise()
	elif state == &"stun" and value != &"dead":
		poise.finish_stagger()
	state = value
	audio_state_changed.emit(value)
	elapsed = 0.0
	if value == &"strike":
		_hit_delivered = false

func _select_beetle_attack(kind: StringName) -> void:
	attack_kind = kind

func _forward_beetle_feedback(kind: StringName, point: Vector2, strength: float) -> void:
	feedback_requested.emit(kind, point, strength)

func _release_spore(direction: Vector2) -> void:
	# Both rendering and emission use this physics-time full-body pose. No stale Sprite transform.
	var pose: SporePose = SporePose.sample(self, 0.0)
	var muzzle: Vector2 = global_position + pose.muzzle_local() * Vector2(facing, 1.0)
	if CombatQuery.clear_path(self, global_position + Vector2(0, -26), muzzle):
		projectile_requested.emit(self, muzzle, direction, false)

func _die() -> void:
	if _death_reported:
		return
	_death_reported = true
	_set_state(&"dead")
	collision_layer = 0
	collision_mask = 1 if spore_behavior != null or warden_behavior != null else 0
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", false)
	feedback_requested.emit(&"enemy_death", global_position + Vector2(0.0, -20.0), 0.7)
	defeated.emit(self)
