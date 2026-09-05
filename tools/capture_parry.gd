extends SceneTree
## Reproducible real Hurtbox contacts in the shipped hand-built level.
## Holds AI intent for staging; the actors still use their normal physics and damage queries.
const MAIN: PackedScene = preload("res://scenes/app/main.tscn")
const STEP: float = 1.0 / 60.0
var directory: String
var main: Node
var level: GreenhouseLevel
var player: Player
var failures: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://build/qa/parry")
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	main = MAIN.instantiate()
	root.add_child(main)
	current_scene = main
	level = main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	player = level._player
	await process_frame
	level.set_process(false)
	player.set_physics_process(false)
	for driver_name: String in ["PhantomCameraHost", "PhantomCamera2D", "EncounterCamera2D"]:
		var driver := level.find_child(driver_name, true, false)
		if driver != null:
			driver.process_mode = Node.PROCESS_MODE_DISABLED
	for form: StringName in [&"humanoid", &"mature"]:
		for encounter_index: int in [0, 4, 7]:
			await _capture_contact(form, encounter_index)
	level.feedback.clear()
	main.queue_free()
	await process_frame
	for failure: String in failures:
		push_error(failure)
	print("PARRY MAIN CAPTURE: 6 production contacts / %d failures / %s" % [failures.size(), directory])
	quit(0 if failures.is_empty() else 1)

func _capture_contact(form: StringName, index: int) -> void:
	level.feedback.clear()
	player.combat.reset()
	player.revive_animation()
	player.form_controller.restore_form(form)
	var encounter: EncounterController = level.encounters[index]
	encounter.reset_encounter()
	await process_frame
	encounter.completed = false
	encounter.begin()
	encounter.set_physics_process(false)
	for member: CombatEnemy in encounter.enemies:
		member.set_physics_process(false)
	var enemy := encounter.enemies[0]
	player.global_position = enemy.global_position + Vector2(-48, -1)
	player.velocity = Vector2.ZERO
	player.visuals.set_state(&"idle")
	level._camera.global_position = encounter.camera_center()
	level._camera.zoom = Vector2.ONE * encounter.camera_zoom
	level._camera.reset_smoothing()
	level._camera.force_update_scroll()
	for frame: int in range(8):
		await physics_frame
		player.movement.tick(STEP, 0.0, false)
		enemy.velocity = Vector2(0, 20)
		enemy.move_and_slide()
	enemy.facing = -1
	if enemy.beetle_behavior != null:
		enemy.beetle_behavior.direction = -1
	elif enemy.pruner_behavior != null:
		enemy.pruner_behavior.direction = -1
	else:
		enemy.warden_behavior.direction = -1
	enemy.attack_kind = &"charge" if index == 0 else &"slash"
	enemy._set_state(&"strike")
	enemy.elapsed = 0.12
	enemy.visuals._process(1.0)
	player.combat.request_action(&"parry", enemy.global_position)
	for frame: int in range(4):
		player.combat.tick(STEP)
	player.visuals.set_combat_state(player.combat)
	var initial_health: int = player.combat.health.current
	var caught: bool = false
	var caught_at: float = -1.0
	var captures: int = 0
	var key := "%s_%s" % [form, encounter.encounter_id]
	level.combat_hud.set_progress(encounter.display_name, "弹反动作检查 / " + String(form), 0, 0)
	for frame: int in range(70):
		await physics_frame
		var step: float = STEP * Engine.time_scale
		player.combat.tick(step)
		player.movement.tick(step, 0.0, false)
		player.combat.after_movement()
		var before_contact: float = player.combat.elapsed
		enemy._physics_process(step)
		player.visuals.set_combat_state(player.combat)
		if player.combat.state == &"parry_success" and not caught:
			caught_at = before_contact
			caught = true
		if caught:
			if captures == 0 or (captures == 1 and enemy.elapsed >= 0.065) or (captures == 2 and enemy.elapsed >= 0.2) or (captures == 3 and enemy.elapsed >= 0.45):
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_webp(directory.path_join("%s_%d.webp" % [key, captures]))
				captures += 1
			if captures >= 4:
				break
	if not caught or player.combat.health.current != initial_health or enemy.state != &"stun":
		failures.append(key + " must parry a real strike, keep health, and leave the attacker stunned")
	print(key, " caught=", caught, " hp=", player.combat.health.current, " enemy=", enemy.state, " contact=", caught_at)
	level.feedback.clear()
	encounter.reset_encounter()
	await process_frame
