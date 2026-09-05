extends SceneTree
## Production entities in a physics fixture; no extra playable level.
const PRUNER: PackedScene = preload("res://features/enemies/pruner.tscn")
const PLAYER: PackedScene = preload("res://features/player/player.tscn")
const STEP: float = 1.0 / 60.0
var world: Node2D
var player: Player
var enemy: CombatEnemy
var failures: PackedStringArray = []
var checks: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	_solid(Vector2(0,110),Vector2(1000,20))
	player = PLAYER.instantiate() as Player
	world.add_child(player)
	player.set_physics_process(false)
	player.form_controller.restore_form(&"humanoid")
	for distance: float in [44.0,108.0]:
		await _spawn(0,distance)
		await _until(&"windup",120)
		_expect(enemy.attack_kind == (&"shear" if distance < 60 else &"lunge"), "Distance selects a distinct move")
		var start_x := enemy.position.x
		while enemy.state == &"windup":
			_expect(player.combat.health.current == 5,"Windup has no damage")
			await _step()
		_expect(absf(enemy.position.x-start_x)<0.5,"Windup plants feet")
		while enemy.state == &"strike":
			if enemy.elapsed < enemy.pruner_behavior.current_move().active_start:
				_expect(player.combat.health.current == 5,"Blade travel before contact has no damage")
			player.combat.health.protection_left = 0.0
			await _step()
		_expect(player.combat.health.current == 4,"Move hits once even without player invulnerability at %.0f (HP=%d, enemy_x=%.1f)" % [distance,player.combat.health.current,enemy.position.x])
		enemy._deliver_strike()
		_expect(player.combat.health.current == 4,"Recovery has no stale hitbox")
	await _spawn(0,44)
	await _until(&"windup",120)
	await _until(&"recover",120)
	await _until(&"windup",120)
	_expect(enemy.attack_kind == &"slam","Staying close after a shear provokes heavy cleave")
	player.combat.health.reset_health()
	await _until(&"strike",100)
	await _until(&"recover",100)
	_expect(player.combat.health.current == 3,"Cleave deals one two-damage impact")
	_expect(enemy.pruner_behavior.recovery_duration > 1.0,"Cleave leaves an extended punish window")
	await _spawn(0,108)
	await _until(&"windup",120)
	player.position.x = -45
	await _until(&"recover",120)
	_expect(enemy.facing == 1.0 and enemy.position.x > 25,"Lunge commits to locked direction")
	_expect(player.combat.health.current == 5,"Dodging behind avoids the lunge")
	await _until(&"turn",120)
	await _until(&"idle",90)
	_expect(enemy.facing == -1,"Body plants and turns only after recovery")
	_expect(enemy.pruner_behavior.lunge_cooldown_left > 0,"Lunge has independent cooldown")
	for face: float in [-1.0,1.0]:
		await _spawn(0,44)
		enemy.facing = face
		var hit := DamageRequest.new()
		hit.origin = enemy.position + Vector2(face * 40,-25)
		hit.knockback = Vector2(-face * 100,-60)
		_expect(enemy.receive_damage(hit)==DamageRequest.Result.BLOCKED,"Facing shield blocks a light hit")
		_expect(enemy.health.current==enemy.health.maximum and enemy.state==&"guard_bump","Block has a full-body response without health loss")
		hit.breaks_guard = true
		_expect(enemy.receive_damage(hit)==DamageRequest.Result.HIT,"Heavy breaks the shield")
		_expect(enemy.pruner_behavior.reaction==&"break" and enemy.pruner_behavior.stun_duration>=0.9,"Guard break drops the arm and exposes the torso")
		enemy.target = null
		enemy.awake = false
		await _until(&"idle",180)
		_expect(enemy.is_on_floor(),"Reaction resolves and lands after target disappears")
		await _spawn(0,44)
		enemy.facing = face
		hit.breaks_guard = false
		hit.origin = enemy.position - Vector2(face * 40,0)
		hit.knockback.x = face * 100
		hit.poise_damage = enemy.poise.maximum
		_expect(enemy.receive_damage(hit)==DamageRequest.Result.HIT,"Rear hits bypass shield")
		_expect(enemy.pruner_behavior.hit_direction==face,"Recoil follows hit direction in both facings")
	# Test the actual player parry receiver for every move.
	for kind: StringName in [&"shear",&"lunge",&"slam"]:
		await _spawn(0,38)
		enemy.attack_kind = kind
		enemy._set_state(&"strike")
		enemy.elapsed = enemy.pruner_behavior.current_move().active_start
		player.combat.request_action(&"parry",enemy.global_position)
		player.combat.tick(STEP)
		player.combat.elapsed = player.combat.tuning.parry_start + 0.02
		enemy._deliver_strike()
		if kind == &"slam":
			_expect(player.combat.health.current==3,"Red-cross cleave cannot be parried")
		else:
			_expect(player.combat.health.current==5 and enemy.state==&"stun","Shear and lunge can be parried through combat receiver")
			_expect(enemy.pruner_behavior.reaction==&"parry","Parry throws the cutting arm upward")
	await _spawn(0,108)
	await _until(&"windup",120)
	var wall := _solid(Vector2(42,65),Vector2(4,70))
	await _until(&"stun",120)
	_expect(enemy.pruner_behavior.reaction==&"wall","Committed lunge hits a wall and stumbles")
	_expect(player.combat.health.current==5,"Wall occludes melee damage")
	wall.queue_free()
	await process_frame
	await _spawn(450,565)
	for tick: int in range(150):
		await _step()
	_expect(enemy.position.x<=480 and enemy.is_on_floor(),"Lunge and pursuit do not walk off a ledge (x=%.1f y=%.1f floor=%s)" % [enemy.position.x,enemy.position.y,enemy.is_on_floor()])
	await _spawn(0,44)
	player.position.y -= 100
	for tick: int in range(120):
		await _step()
	_expect(enemy.state not in [&"strike",&"windup"],"Cannot attack a target outside vertical reach")
	await _spawn(0,44)
	await _until(&"windup",120)
	enemy.target = null
	await _step()
	_expect(enemy.state==&"recover","Target loss cancels windup")
	await _verify_poses()
	enemy._set_state(&"recover")
	var kill := DamageRequest.new()
	kill.amount = 99
	kill.breaks_guard = true
	var deaths: Array[int] = [0]
	enemy.defeated.connect(func(_e: CombatEnemy) -> void: deaths[0]+=1)
	enemy.receive_damage(kill)
	enemy.receive_damage(kill)
	_expect(deaths[0]==1 and not enemy.pruner_behavior.attack_active(),"Death reports once and removes attack immediately")
	_expect(enemy.definition.maximum_health==12 and enemy.pruner_behavior.tuning.shear.damage==1,"Runtime leaves shared resources unchanged")
	world.queue_free()
	await process_frame
	print("PRUNER: %d checks, %d failures" % [checks,failures.size()])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _verify_poses() -> void:
	var visual := enemy.visuals as PrunerVisual
	visual.set_process(false)
	for kind: StringName in [&"shear",&"lunge",&"slam"]:
		enemy.attack_kind = kind
		enemy._set_state(&"idle")
		visual._process(1.0)
		var idle := visual.pose_snapshot()
		enemy._set_state(&"windup")
		enemy.elapsed = enemy.pruner_behavior.current_move().windup
		visual._process(1.0)
		var load := visual.pose_snapshot()
		_expect((idle.body as Transform2D).origin.distance_to((load.body as Transform2D).origin)>2,"Windup moves the hips")
		_expect((idle.tool as Transform2D).origin.distance_to((load.tool as Transform2D).origin)>5,"Windup draws the weapon arm")
		_expect((idle.shield as Transform2D).origin.distance_to((load.shield as Transform2D).origin)>3,"Offhand counters weapon motion")
		_expect((idle.feet[0] as Vector2).distance_to(load.feet[0])>2,"Feet widen to take the load")
		enemy._set_state(&"strike")
		enemy.elapsed = enemy.pruner_behavior.current_move().active_start
		visual._process(1.0)
		var strike := visual.pose_snapshot()
		_expect((strike.tool as Transform2D).origin.x>(load.tool as Transform2D).origin.x+10,"Release drives the cutting arm forward")
		_expect(strike.blade>0.2,"Shear blades close at the active contact frame")
	for face: float in [-1.0,1.0]:
		enemy.facing=face
		for state: StringName in [&"turn",&"guard_bump",&"stun",&"recover",&"dead"]:
			enemy._set_state(state)
			for time: float in [0.0,0.08,0.2,0.6,1.0]:
				enemy.elapsed=time
				visual._process(STEP)
				var pose := visual.pose_snapshot()
				_expect((pose.body as Transform2D).is_finite() and (pose.tool as Transform2D).is_finite(),"Mirrored reaction transforms remain finite")
				_expect((pose.feet[0] as Vector2).is_finite() and (pose.knees[1] as Vector2).is_finite(),"Leg IK stays finite during collapse")
	_expect(enemy.get_node("BodyShape").scale==Vector2.ONE,"Animation never scales collision")
	enemy._set_state(&"idle")
	enemy.facing=1
	enemy.velocity.x=34
	visual._stride=0
	visual._last_position=enemy.global_position
	visual._process(0.2)
	var planted: Vector2 = enemy.position+visual.pose_snapshot().feet[0]
	enemy.position.x+=1 # Fixture-only displacement to verify support stroke.
	visual._process(STEP)
	var next: Vector2 = enemy.position+visual.pose_snapshot().feet[0]
	_expect(planted.distance_to(next)<0.01,"Support foot stays planted as the body advances")

func _spawn(x: float, target_x: float) -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()
		await process_frame
	player.combat.reset()
	player.position = Vector2(target_x, 100)
	enemy = PRUNER.instantiate() as CombatEnemy
	enemy.position = Vector2(x, 100)
	enemy.facing = 1.0
	world.add_child(enemy)
	enemy.set_physics_process(false)
	# Land before allowing intent evaluation.
	enemy.velocity = Vector2(0, 1)
	await _step()
	enemy.target = player
	enemy.awake = true

func _until(state: StringName, limit: int) -> void:
	for tick: int in range(limit):
		if enemy.state == state:
			return
		await _step()
	_expect(false, "Timed out waiting for %s (was %s)" % [state, enemy.state])

func _step() -> void:
	await physics_frame
	enemy._physics_process(STEP)
	player.combat.health.tick(STEP)

func _solid(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
