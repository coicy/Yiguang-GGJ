extends SceneTree
## Integration checks run on the production level; position helpers isolate lifecycle
## cases and do not represent a human playthrough or timing acceptance.
const MAIN := preload("res://scenes/app/main.tscn")
var level: GreenhouseLevel
var player: Player
var checks: int = 0
var failures: Array[String] = []
func _init() -> void:
	call_deferred("_run")
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)
func frames(count: int) -> void:
	for index in range(count):
		await physics_frame
func _run() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	await frames(3)
	level = root.find_child("Level01",true,false) as GreenhouseLevel
	expect(level != null,"F5 entry resolves to the production greenhouse")
	if level == null:
		quit(1)
		return
	player = level.get_node("Actors/Player") as Player
	expect(get_nodes_in_group("player").size() == 1,"Only one player in main entry")
	expect(level.encounters.size() == 8,"Seven sections contain eight encounters")
	expect(player.current_form_id() == &"sprout","Begin as sprout")
	expect(not level.exit_goal.is_unlocked(),"Exit starts locked")
	expect((level.get_node("Interface/HandbuiltHud") as HandbuiltHud)._player == player,"Growth HUD is bound to production player")
	await _nursery_route()
	await _lifecycle()
	await _canopy_route(&"humanoid")
	await _canopy_route(&"mature")
	await _finish()
	paused = false
	level.feedback.clear()
	main.queue_free()
	await process_frame
	print("GREENHOUSE: %d assertions, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
func _nursery_route() -> void:
	# Move through the actual root vault from the authored spawn; no helper
	# teleports to the nutrition tank or across the three solid nursery stairs.
	Input.action_press("move_right")
	for tick in range(260):
		if player.global_position.x >= 351.0:
			break
		await frames(1)
	Input.action_release("move_right")
	await frames(8)
	expect(player.global_position.x > 310.0,"Sprout exits low passage")
	expect(level.get_node_or_null("Geometry/Mechanisms/IntroGate") == null,"Nursery exit has no gate")
	Input.action_press("absorb_resource")
	await frames(180)
	Input.action_release("absorb_resource")
	await frames(2)
	expect(player.current_form_id() == &"humanoid","First real nutrition point grows sprout to human")
	expect((level.get_node("Interface/HandbuiltHud") as HandbuiltHud)._form_id == &"humanoid","Growth HUD tracks form change")
	var targets: Array[Vector2] = [Vector2(480,486),Vector2(585,445),Vector2(675,400)]
	var launches: Array[float] = [401.0,504.0,613.0]
	for index in range(targets.size()):
		var jumped := false
		var reached := false
		for tick in range(180):
			var target := targets[index]
			var dx := target.x-player.global_position.x
			if jumped and player.is_on_floor() and absf(dx) < 12.0 and absf(player.global_position.y-target.y) < 3.0:
				reached = true
				break
			Input.action_release("move_left")
			Input.action_release("move_right")
			if dx > 5.0: Input.action_press("move_right")
			elif dx < -5.0: Input.action_press("move_left")
			if not jumped and player.is_on_floor() and player.global_position.x >= launches[index]-2.0:
				Input.action_press("jump")
				jumped = true
			await frames(1)
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("jump")
		await frames(6)
		expect(reached,"Nursery solid stair %d reached by actual jumping" % index)
func place_at_encounter(index: int) -> EncounterController:
	var encounter := level.encounters[index]
	player.global_position = encounter.global_position + Vector2(72,-2)
	player.velocity = Vector2.ZERO
	await frames(3)
	return encounter
func defeat_wave(encounter: EncounterController) -> void:
	for enemy: CombatEnemy in encounter.enemies.duplicate():
		var request := DamageRequest.new()
		request.amount = 100
		request.breaks_guard = true
		request.origin = enemy.global_position - Vector2(enemy.facing*20,0)
		enemy.receive_damage(request)
	await frames(70)
func _lifecycle() -> void:
	# Sprout must never be sealed into a combat room.
	player.form_controller.restore_form(&"sprout")
	var first := await place_at_encounter(0)
	expect(not first.active,"Sprout cannot trigger a sealed encounter")
	player.form_controller.restore_form(&"humanoid")
	await frames(3)
	expect(first.active and first.enemies.size() == 1,"Combat form starts first beetle")
	expect(player.combat.health.current == 5,"Encounter checkpoint heals player")
	await defeat_wave(first)
	expect(first.completed,"Defeating wave completes encounter")
	expect((first._gates[1].get_child(0) as CollisionShape2D).disabled,"Cleared right gate opens")
	var second := await place_at_encounter(1)
	var snapshot := player.capture_state()
	expect(second.enemies.size() == 2,"Second encounter starts its pair")
	second._spawn_projectile(second.enemies[0],player.global_position+Vector2(180,-30),Vector2.LEFT,false)
	expect(second.projectiles.size() == 1,"Projectile belongs to active encounter")
	player.form_controller.restore_form(&"mature")
	level._on_actor_killed(player)
	expect(level.dead and level.death_count == 1,"Lethal danger enters death flow and counts once")
	expect(player.combat.health.current == 0,"Hazard bypasses combat protection")
	await frames(55)
	expect(paused and level.combat_hud.is_overlay_visible(),"Death opens paused retry overlay")
	level.retry_checkpoint()
	expect(not paused and not level.dead,"Retry unpauses and revives")
	expect(player.current_form_id() == snapshot.form,"Retry restores pre-encounter form")
	expect(player.resources.snapshot() == snapshot.resources,"Retry restores resource snapshot")
	expect(player.velocity == Vector2.ZERO,"Retry clears velocity")
	expect(player.combat.health.current == 5,"Retry fills health")
	expect(second.enemies.is_empty() and second.projectiles.is_empty(),"Retry removes encounter enemies and projectiles")
	expect(first.completed,"Retry preserves completed encounter")
	await frames(3)
	expect(second.active and second.enemies.size() == 2,"Retry recreates only the unfinished wave")
	await defeat_wave(second)
	var before_pause := level.elapsed_seconds
	level.feedback.cue(&"hit",player.global_position,1.0)
	level._pause()
	expect(is_equal_approx(Engine.time_scale,1.0),"Pause clears hit stop")
	await frames(6)
	expect(is_equal_approx(before_pause,level.elapsed_seconds),"Paused time excluded")
	level._resume()
	await frames(3)
	expect(level.elapsed_seconds > before_pause,"Timer resumes")
	for index in range(2,6):
		var encounter := await place_at_encounter(index)
		expect(encounter.active,"Encounter %d triggers" % index)
		await defeat_wave(encounter)
		expect(encounter.completed,"Encounter %d clears" % index)
	var court := await place_at_encounter(6)
	expect(court.enemies.size() == 3,"Courtyard first wave contains at most three")
	await defeat_wave(court)
	expect(court.active and court.wave_index == 1 and court.enemies.size() == 3,"Courtyard second wave follows first")
	# Fallen enemies must not permanently lock the room.
	for enemy: CombatEnemy in court.enemies.duplicate():
		enemy.global_position.y = court.global_position.y + 150.0
	await frames(75)
	expect(court.completed,"Enemies outside arena count as defeated")
func _canopy_route(form: StringName) -> void:
	# Actual movement/physics across shared jump platforms, no teleport between them.
	player.form_controller.restore_form(form)
	player.global_position = Vector2(5225,398)
	player.velocity = Vector2.ZERO
	await frames(8)
	var destinations := [Vector2(5350,350),Vector2(5540,300),Vector2(5730,260),Vector2(5950,300),Vector2(6150,350),Vector2(6320,400)]
	var launches := [5225.0,5410.0,5580.0,5790.0,5990.0,6180.0]
	var destination_index := 0
	for target: Vector2 in destinations:
		var ticks := 0
		var jumped := false
		while ticks < 160:
			var dx := target.x-player.global_position.x
			if absf(dx)<14.0 and player.is_on_floor() and absf(player.global_position.y-target.y)<12.0:
				break
			var direction := signf(dx) if absf(dx)>9.0 else 0.0
			Input.action_release("move_left")
			Input.action_release("move_right")
			if direction > 0.0: Input.action_press("move_right")
			elif direction < 0.0: Input.action_press("move_left")
			if player.is_on_floor() and not jumped and player.global_position.x >= launches[destination_index]:
				player.movement.request_jump()
				jumped = true
			await frames(1)
			ticks += 1
		destination_index += 1
		expect(ticks < 160,"%s canopy platform %s reachable via actual movement (ended %s)" % [form,target,player.global_position])
		Input.action_release("move_left")
		Input.action_release("move_right")
		await frames(8)
	expect(player.global_position.x > 6280.0,"%s crosses shared canopy route" % form)
func _finish() -> void:
	var warden := await place_at_encounter(7)
	expect(warden.active and warden.enemies.size() == 1,"Elite starts alone")
	level._on_actor_killed(player)
	level.retry_checkpoint()
	expect(player.global_position.x < warden.global_position.x,"Elite retry returns to preparation area")
	expect(not warden.active,"Elite retry allows preparation before re-entry")
	warden = await place_at_encounter(7)
	expect(not level.exit_goal.try_complete(player),"Locked exit cannot complete")
	await defeat_wave(warden)
	expect(warden.completed and level.exit_goal.is_unlocked(),"Elite defeat unlocks exit")
	expect(not level.finished,"Elite defeat alone does not finish level")
	expect(level.exit_goal.try_complete(player),"Entering unlocked exit completes run")
	expect(level.finished and paused,"Completion shows result and stops simulation")
