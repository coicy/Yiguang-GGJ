extends SceneTree
## Static visual QA of the authoritative main scene, with production entities and HUD.
## This positions the player for inspection; it is not evidence of an input-driven playthrough.
const MAIN: PackedScene = preload("res://scenes/app/main.tscn")
var scene: Node
var level: GreenhouseLevel
var actor: Player
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	scene = MAIN.instantiate()
	root.add_child(scene)
	current_scene = scene
	level = scene.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	actor = level._player
	await process_frame
	level.set_process(false)
	# Static art framing intentionally suspends the production camera owner.
	level._camera_host.process_mode = Node.PROCESS_MODE_DISABLED
	level._phantom_camera.process_mode = Node.PROCESS_MODE_DISABLED
	level._encounter_camera.process_mode = Node.PROCESS_MODE_DISABLED
	actor.set_physics_process(false)
	var args := OS.get_cmdline_user_args()
	var shot := args[0] if not args.is_empty() else "nursery"
	match shot:
		"nursery":
			_place(&"sprout", Vector2(65, 400), Vector2(245, 320), 2.5, 0)
		"beetle", "humanoid_attack", "mature_attack":
			_place(&"mature" if shot == "mature_attack" else &"humanoid", Vector2(948, 400), Vector2(1040, 320), 2.1, 1)
			var encounter := level.get_node("Encounters/BeetleIntro") as EncounterController
			encounter.begin()
			for enemy: CombatEnemy in encounter.enemies:
				enemy.set_physics_process(false)
				enemy.state = &"windup"
				enemy.elapsed = enemy.definition.windup * 0.72
				enemy.attack_kind = &"charge"
			if shot != "beetle":
				_pose(&"heavy" if shot == "mature_attack" else &"light_1")
		"spore", "workshop", "courtyard":
			var room_index := 2 if shot == "spore" else 4 if shot == "workshop" else 6
			var encounter := level.encounters[room_index]
			_place(&"humanoid",encounter.global_position+Vector2(100 if shot == "spore" else 150,0),encounter.camera_center(),2.1,2 if shot == "spore" else 3 if shot == "workshop" else 5)
			encounter.begin()
			for enemy: CombatEnemy in encounter.enemies:
				enemy.set_physics_process(false)
				enemy.state = &"windup"
				enemy.elapsed = enemy.definition.windup*0.6
		"canopy_lower":
			_place(&"sprout", Vector2(5490, 555), Vector2(5660, 450), 2.0, 4)
		"canopy":
			_place(&"mature", Vector2(5710, 260), Vector2(5740, 200), 2.1, 4)
		"warden":
			_place(&"mature", Vector2(7660, 400), Vector2(7800, 320), 1.65, 6)
			var encounter := level.get_node("Encounters/Warden") as EncounterController
			encounter.begin()
			for enemy: CombatEnemy in encounter.enemies:
				enemy.set_physics_process(false)
				enemy.state = &"windup"
				enemy.elapsed = 0.66
				enemy.attack_kind = &"slam"
			_pose(&"idle")
	await process_frame
	actor.visuals.set_combat_state(actor.combat)
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://build/qa/combat-visuals")
	DirAccess.make_dir_recursive_absolute(directory)
	var output := directory.path_join("main_%s.webp" % shot)
	root.get_texture().get_image().save_webp(output)
	print("MAIN_VISUAL_CAPTURE ", output)
	scene.queue_free()
	await process_frame
	await process_frame
	quit()
func _place(form: StringName, position: Vector2, camera: Vector2, zoom: float, section: int) -> void:
	actor.form_controller.switch_to(form)
	actor.global_position = position
	actor.velocity = Vector2.ZERO
	level._camera.global_position = camera
	level._camera.zoom = Vector2.ONE * zoom
	level._camera.reset_smoothing()
	level._camera.force_update_scroll()
	level.combat_hud.set_progress(level.SECTION_NAMES[section], level.SECTION_GOALS[section], 0, 0)
func _pose(action: StringName) -> void:
	actor.combat.attack = actor.combat.tuning.find_attack(action)
	actor.combat.state = &"attack" if actor.combat.attack != null else action
	actor.combat.facing = 1.0
	actor.combat.elapsed = actor.combat.attack.duration() * actor.combat.time_scale_for_form() * 0.44 if actor.combat.attack != null else 0.1
	actor.visuals.set_combat_state(actor.combat)
