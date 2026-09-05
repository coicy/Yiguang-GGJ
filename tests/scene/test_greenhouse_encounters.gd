extends SceneTree
## Combat-only integration: every real production encounter, attacked through the
## player controller. Entry positioning isolates combat, not route traversal.
## This deterministic bot reads enemy state and is not a human timing sample.
const MAIN: PackedScene = preload("res://scenes/app/main.tscn")
var level: GreenhouseLevel
var player: Player
var failures: PackedStringArray = []
var checks: int = 0
var _jump_hold: int = 0
var _damage_trace: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for form: StringName in [&"humanoid", &"mature"]:
		var main := MAIN.instantiate()
		root.add_child(main)
		await physics_frame
		level = main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
		player = level.get_node("Actors/Player") as Player
		player.form_controller.restore_form(form)
		player.combat.health.damaged.connect(_record_damage)
		for encounter: EncounterController in level.encounters:
			await _fight(encounter, form)
		_expect(level.encounters.all(func(room: EncounterController) -> bool: return room.completed), "%s clears all eight production encounters" % form)
		_expect(level.exit_goal.is_unlocked(), "%s combat victory unlocks the exit" % form)
		_release_inputs()
		paused = false
		level.feedback.clear()
		main.queue_free()
		await process_frame
	print("GREENHOUSE COMBAT: %d assertions, %d failures" % [checks, failures.size()])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _fight(encounter: EncounterController, form: StringName) -> void:
	_release_inputs()
	player.cancel_actions()
	player.global_position = encounter.global_position + Vector2(72.0, -2.0)
	player.velocity = Vector2.ZERO
	_damage_trace.clear()
	var attempts := 0
	var total_frames := 0
	var start_time := level.elapsed_seconds
	var waves_seen: Dictionary = {}
	var starting_deaths := level.death_count
	while total_frames < 14400 and not encounter.completed:
		await physics_frame
		total_frames += 1
		if level.dead:
			_release_inputs()
			attempts += 1
			if attempts >= 3:
				break
			level.retry_checkpoint()
			# Warden's real checkpoint is outside the trigger, so enter from there.
			if encounter.encounter_id == &"warden":
				player.global_position = encounter.global_position + Vector2(72.0, -2.0)
			continue
		if not encounter.active:
			continue
		waves_seen[encounter.wave_index] = true
		_drive(encounter)
	_release_inputs()
	var alive := 0
	for enemy: CombatEnemy in encounter.enemies:
		if is_instance_valid(enemy):
			alive += enemy.health.current
	print("MEASURE room=%s form=%s completed=%s combat_time=%.2f deaths=%d HP=%d remaining_enemy_HP=%d waves=%d/%d" % [encounter.encounter_id, form, encounter.completed, level.elapsed_seconds - start_time, level.death_count - starting_deaths, player.combat.health.current, alive, waves_seen.size(), encounter.waves.size()])
	_expect(encounter.completed, "%s clears %s through ordinary combat without parry" % [form, encounter.encounter_id])
	_expect(waves_seen.size() == encounter.waves.size(), "%s sees every wave in %s" % [form, encounter.encounter_id])
	if not encounter.completed:
		for entry: String in _damage_trace:
			print(entry)
		# Reset this failed room so later diagnostics do not inherit its enemies.
		level.retry_checkpoint()
		encounter.reset_encounter()

func _drive(encounter: EncounterController) -> void:
	var target: CombatEnemy
	var best := INF
	for enemy: CombatEnemy in encounter.enemies:
		if not is_instance_valid(enemy) or enemy.state == &"dead":
			continue
		var score := player.global_position.distance_to(enemy.global_position)
		if enemy.definition.kind == EnemyDefinition.Kind.SPORE:
			score *= 0.8
		if score < best:
			best = score
			target = enemy
	if target == null:
		_set_direction(0.0)
		_set_jump(false)
		return
	var delta_x := target.global_position.x - player.global_position.x
	var toward := signf(delta_x)
	var distance := absf(delta_x)
	var direction := 0.0
	var action: StringName = &""
	var aim := target.global_position
	var jump := false
	var is_elite := target.definition.kind == EnemyDefinition.Kind.WARDEN
	var target_danger := target.state in [&"windup", &"strike"]
	if is_elite and target_danger:
		var safe_x := clampf(target.global_position.x - target.facing * 60.0, encounter.global_position.x + 28.0, encounter.global_position.x + encounter.arena_size.x - 28.0)
		if absf(safe_x - player.global_position.x) > 10.0:
			direction = signf(safe_x - player.global_position.x)
		var in_front := (player.global_position.x - target.global_position.x) * target.facing >= 0.0
		if in_front and distance < 95.0 and player.combat.dash_cooldown_left <= 0.0:
			action = &"dash"
			aim = player.global_position + Vector2(direction * 300.0, 0.0)
		if target.attack_kind == &"slam" and target.state == &"windup" and target.elapsed > 0.64:
			jump = true
	else:
		var reach := 46.0 if player.current_form_id() == &"humanoid" else 67.0
		if distance > reach:
			direction = toward
		elif player.combat.state == &"idle":
			action = &"heavy" if player.is_on_floor() else &"attack"
		# When a one-way platform is above the target, leave its edge to regain
		# the target's elevation; do not keep swinging through solid height.
		if player.is_on_floor() and target.global_position.y - player.global_position.y > 25.0:
			direction = toward if distance > 10.0 else -target.facing
			action = &""
	# The production spore rooms have visible 32-high solid planter cover.
	# Sense the same world collision as a moving player and jump over it;
	# do not teleport across cover or change enemy/attack values.
	if not is_zero_approx(direction) and player.is_on_floor() and player.test_move(player.global_transform, Vector2(direction * 28.0, 0.0)):
		jump = true
	for shot: SporeProjectile in encounter.projectiles:
		var offset := shot.global_position - player.global_position
		var incoming := offset.x * shot.direction.x < 0.0
		if incoming and absf(offset.x) < 95.0 and absf(offset.y) < 70.0:
			jump = true
	# Side platforms alter approach timing in the courtyard. React to nearby
	# visible melee windups, including an attacker other than the current target.
	# Use the production dash/cancel rules instead of trading every hit.
	for threat: CombatEnemy in encounter.enemies:
		if not is_instance_valid(threat) or threat.definition.kind not in [EnemyDefinition.Kind.BEETLE, EnemyDefinition.Kind.PRUNER]:
			continue
		var threat_dx := player.global_position.x - threat.global_position.x
		if threat.state in [&"windup", &"strike"] and threat_dx * threat.facing >= 0.0 and absf(threat_dx) < 95.0 and absf(player.global_position.y - threat.global_position.y) < 35.0:
			if player.combat.dash_cooldown_left <= 0.0:
				direction = -threat.facing
				aim = player.global_position + Vector2(direction * 300.0, 0.0)
				action = &"dash"
				jump = false
				break
	if jump and player.is_on_floor() and player.movement.allow_jump:
		_jump_hold = 20
		action = &"" # Jump must win over a ground heavy that would suppress it.
	_set_jump(_jump_hold > 0)
	_jump_hold = maxi(0, _jump_hold - 1)
	if not action.is_empty():
		player.combat.request_action(action, aim)
	_set_direction(direction)

func _set_direction(direction: float) -> void:
	if direction < 0.0:
		Input.action_press(&"move_left")
		Input.action_release(&"move_right")
	elif direction > 0.0:
		Input.action_press(&"move_right")
		Input.action_release(&"move_left")
	else:
		Input.action_release(&"move_left")
		Input.action_release(&"move_right")

func _set_jump(held: bool) -> void:
	if held:
		Input.action_press(&"jump")
	else:
		Input.action_release(&"jump")

func _release_inputs() -> void:
	_set_direction(0.0)
	_set_jump(false)
	_jump_hold = 0

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func _record_damage(request: DamageRequest) -> void:
	var source := "unknown"
	if request.source is CombatEnemy:
		source = String((request.source as CombatEnemy).definition.display_name)
	elif request.source is SporeProjectile:
		source = "shockwave" if (request.source as SporeProjectile).shockwave else "spore"
	_damage_trace.append("DAMAGE source=%s amount=%d player=(%.1f,%.1f) action=%s HP=%d wave=%d" % [source, request.amount, player.global_position.x, player.global_position.y, player.combat.state, player.combat.health.current, level.current_encounter.wave_index])
