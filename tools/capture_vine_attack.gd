extends SceneTree
## Samples production attack timing on the authoritative main level for visual review.
## Repositions production actors for controlled comparison; not an input-driven playthrough.
const MAIN: PackedScene = preload("res://scenes/app/main.tscn")
const ACTIONS: Array[StringName] = [&"light_1", &"light_2", &"light_3", &"heavy", &"air"]
const FPS: float = 60.0
var _main: Node
var _level: GreenhouseLevel
var _actor: Player
var _tag: String = "after"
var _rate: float = 1.0
var _region: String = "moss"
var _body_only: bool = false
var _light_enabled: bool = true
var _light_state: Dictionary = {}
var _directory: String
var _frame: int = 0
var _entries: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_tag = args[0]
	if args.size() > 1:
		_rate = maxf(float(args[1]), 0.1)
	if args.size() > 2:
		_region = args[2]
	if args.size() > 3:
		_body_only = args[3] == "body-only"
	if args.size() > 4:
		_light_enabled = args[4] != "unlit"
	_directory = ProjectSettings.globalize_path("res://build/qa/vine-attack/" + _tag)
	DirAccess.make_dir_recursive_absolute(_directory)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	_main = MAIN.instantiate()
	root.add_child(_main)
	current_scene = _main
	_level = _main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	_actor = _level._player
	var flower_light := _actor.find_child("FlowerLight", true, false) as PointLight2D
	if flower_light != null:
		_light_state = {"present": true, "enabled_in_scene": flower_light.enabled, "energy": flower_light.energy, "color": str(flower_light.color)}
		flower_light.enabled = flower_light.enabled and _light_enabled
		_light_state["enabled_in_capture"] = flower_light.enabled
	else:
		_light_state = {"present": false}
	await process_frame
	_level.set_process(false)
	_freeze_camera_drivers()
	_actor.set_physics_process(false)
	var actor_x: float = 1030.0 if _region == "moss" else 4200.0 if _region == "workshop" else 7750.0
	_level._camera.global_position = Vector2(actor_x + 40.0, 325.0)
	_level._camera.zoom = Vector2.ONE * (1.65 if _region == "core" else 2.1)
	_level._camera.reset_smoothing()
	_level._camera.force_update_scroll()
	for form: StringName in [&"humanoid", &"mature"]:
		_actor.form_controller.restore_form(form)
		_actor.global_position = Vector2(actor_x, 400.0)
		if _body_only:
			_disable_trails(_actor.visuals)
		_actor.velocity = Vector2.ZERO
		for action: StringName in ACTIONS:
			for facing: float in [1.0, -1.0]:
				await _attack(form, action, facing)
	var manifest: Dictionary = {"kind": "production_scene_timeline_sampling", "resolution": [1280, 720], "camera_zoom": _level._camera.zoom.x, "region": _region, "body_only": _body_only, "flower_light": _light_state, "fps": FPS, "playback_rate": _rate, "tag": _tag, "entries": _entries}
	var file := FileAccess.open(_directory.path_join("capture_manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  "))
	_main.queue_free()
	await process_frame
	print("VINE_CAPTURE_COMPLETE ", _directory, " frames=", _frame)
	quit()

func _attack(form: StringName, action: StringName, facing: float) -> void:
	_actor.combat.cancel()
	_actor.combat.attack = _actor.combat.tuning.find_attack(action)
	_actor.combat.state = &"attack"
	_actor.combat.facing = facing
	_actor.combat.elapsed = 0.0
	var attack: AttackDefinition = _actor.combat.attack
	var timing: float = _actor.combat.time_scale_for_form()
	var duration: float = attack.duration() * timing
	var count: int = int(ceil(duration / _rate * FPS)) + 1
	var side: String = "right" if facing > 0.0 else "left"
	var key: String = "%s_%s_%s" % [form, action, side]
	_level.combat_hud.set_progress("藤蔓动作 / " + String(form), "%s / %s / %.2fx" % [action, side, _rate], 0, 0)
	_entries.append({"key": key, "start_frame": _frame, "frames": count, "attack_duration": duration, "windup": attack.windup * timing, "active": attack.active * timing, "recovery": attack.recovery * timing})
	var captures: Dictionary = {}
	for phase: String in ["prepare", "strike", "recoil"]:
		var time: float = attack.windup * timing * 0.65
		if phase == "strike":
			time = (attack.windup + attack.active * 0.5) * timing
		elif phase == "recoil":
			time = (attack.windup + attack.active + attack.recovery * 0.35) * timing
		captures[mini(int(round(time / _rate * FPS)), count - 1)] = phase
	for frame: int in range(count):
		_actor.combat.elapsed = minf(duration, frame / FPS * _rate)
		_actor.visuals.set_combat_state(_actor.combat)
		await process_frame
		await RenderingServer.frame_post_draw
		if captures.has(frame):
			root.get_texture().get_image().save_webp(_directory.path_join(key + "_" + String(captures[frame]) + ".webp"))
		_frame += 1
	_actor.combat.cancel()
	_actor.visuals.set_combat_state(_actor.combat)
	for frame: int in range(8):
		await process_frame
		_frame += 1

func _disable_trails(node: Node) -> void:
	if node.has_method("sample_combat"):
		node.set("trail_enabled", false)
	for child: Node in node.get_children():
		_disable_trails(child)

func _freeze_camera_drivers() -> void:
	# Only this review instance freezes tracking; the shipped camera setup stays intact.
	for driver_name: String in ["PhantomCameraHost", "PhantomCamera2D", "EncounterCamera2D"]:
		var driver: Node = _level.find_child(driver_name, true, false)
		if driver != null:
			driver.process_mode = Node.PROCESS_MODE_DISABLED
