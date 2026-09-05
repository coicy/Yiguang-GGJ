extends SceneTree
## Scripted damage-query review in the authoritative production level.
## Enemy AI is held for a repeatable contact; real combat ticks, terrain and Hurtboxes remain active.
const MAIN: PackedScene = preload("res://scenes/app/main.tscn")
const STEP: float = 1.0 / 60.0
var _main: Node
var _level: GreenhouseLevel
var _actor: Player
var _records: Array[Dictionary] = []
var _directory: String
var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	_directory = ProjectSettings.globalize_path("res://build/qa/vine-attack/contacts")
	DirAccess.make_dir_recursive_absolute(_directory)
	_main = MAIN.instantiate()
	root.add_child(_main)
	current_scene = _main
	_level = _main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	_actor = _level._player
	await process_frame
	_level.set_process(false)
	_freeze_camera_drivers()
	_actor.set_physics_process(false)
	for form: StringName in [&"humanoid", &"mature"]:
		for index: int in [0, 4, 7]:
			if index == 4:
				await _contact(form, index, &"attack")
			await _contact(form, index, &"attack" if index == 0 else &"heavy")
	var record: Dictionary = {"kind": "scripted_production_contact", "fps": 60, "rate": 1.0, "resolution": [1280, 720], "checks": _records, "failures": _failures}
	var output := FileAccess.open(_directory.path_join("contact_manifest.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(record, "  "))
	_level.feedback.clear()
	_main.queue_free()
	await process_frame
	for message: String in _failures:
		push_error(message)
	print("VINE_CONTACT_CAPTURE ", _records.size(), " cases / ", _failures.size(), " failures / ", _directory)
	quit(0 if _failures.is_empty() else 1)

func _contact(form: StringName, index: int, action: StringName) -> void:
	_level.feedback.clear()
	_actor.combat.reset()
	_actor.revive_animation()
	_actor.form_controller.restore_form(form)
	var encounter: EncounterController = _level.encounters[index]
	encounter.reset_encounter()
	await process_frame
	encounter.completed = false
	encounter.begin()
	encounter.set_physics_process(false)
	var enemy: CombatEnemy = encounter.enemies[0]
	enemy.set_physics_process(false)
	enemy.state = &"idle"
	enemy.facing = -1.0
	var definition: AttackDefinition = _actor.combat.tuning.find_attack(&"light_1" if action == &"attack" else &"heavy")
	_actor.global_position = enemy.global_position + Vector2(-definition.reach * _actor.combat.reach_scale() * 0.84, -1.0)
	_actor.velocity = Vector2.ZERO
	_actor.visuals.set_state(&"idle")
	_level._camera.global_position = encounter.camera_center()
	_level._camera.zoom = Vector2.ONE * encounter.camera_zoom
	_level._camera.reset_smoothing()
	_level._camera.force_update_scroll()
	for frame: int in range(8):
		await physics_frame
		_actor.movement.tick(STEP, 0.0, false)
	_actor.combat.request_action(action, enemy.global_position)
	var initial_health: int = enemy.health.current
	var guard: bool = index == 4 and action == &"attack"
	var feedback: Array[StringName] = []
	var collect: Callable = func(kind: StringName, _point: Vector2, _strength: float) -> void: feedback.append(kind)
	_actor.combat.feedback_requested.connect(collect)
	var key: String = "%s_%s_%s" % [form, encounter.encounter_id, action]
	_level.combat_hud.set_progress(encounter.display_name, "命中检查 / " + String(form) + " / " + String(action), 0, 0)
	var contact_time: float = -1.0
	var saved: bool = false
	for frame: int in range(90):
		await physics_frame
		var delta: float = STEP * Engine.time_scale
		_actor.combat.tick(delta)
		_actor.movement.tick(delta, 0.0, false)
		_actor.combat.after_movement()
		_actor.visuals.set_combat_state(_actor.combat)
		await process_frame
		await RenderingServer.frame_post_draw
		if not saved and (enemy.health.current < initial_health or &"guard" in feedback):
			contact_time = _actor.combat.elapsed
			root.get_texture().get_image().save_webp(_directory.path_join(key + ".webp"))
			saved = true
	_actor.combat.feedback_requested.disconnect(collect)
	var passed: bool = (&"guard" in feedback and enemy.health.current == initial_health) if guard else enemy.health.current == initial_health - definition.damage
	if not passed:
		_failures.append(key + " expected production contact did not occur")
	_records.append({"key": key, "passed": passed, "expected_guard": guard, "initial_health": initial_health, "final_health": enemy.health.current, "contact_elapsed": contact_time, "windup": definition.windup * _actor.combat.time_scale_for_form(), "active": definition.active * _actor.combat.time_scale_for_form(), "zoom": encounter.camera_zoom})
	encounter.reset_encounter()
	await process_frame

func _freeze_camera_drivers() -> void:
	# Only this review instance freezes tracking; the shipped camera setup stays intact.
	for driver_name: String in ["PhantomCameraHost", "PhantomCamera2D", "EncounterCamera2D"]:
		var driver: Node = _level.find_child(driver_name, true, false)
		if driver != null:
			driver.process_mode = Node.PROCESS_MODE_DISABLED
