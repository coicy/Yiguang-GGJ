extends SceneTree
## Production Player input/physics transition reel in the authoritative main level.
## Fixed review camera and actor start positions; no alternate playable level.
const MAIN: PackedScene = preload("res://scenes/app/main.tscn")
var _main: Node
var _level: GreenhouseLevel
var _actor: Player
var _directory: String
var _scenario: String = ""
var _frames: Array[Dictionary] = []
var _shots: Dictionary = {}
var _frame_number: int = 0
var _scenario_tick: int = 0
var _seen_attack: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var capture_tag: String = arguments[0] if not arguments.is_empty() else "attack-transitions"
	_directory = ProjectSettings.globalize_path("res://build/qa/" + capture_tag)
	DirAccess.make_dir_recursive_absolute(_directory)
	_main = MAIN.instantiate()
	root.add_child(_main)
	current_scene = _main
	_level = _main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	_actor = _level._player
	await process_frame
	_level.set_process(false)
	for driver_name: String in ["PhantomCameraHost", "PhantomCamera2D", "EncounterCamera2D"]:
		var driver: Node = _level.find_child(driver_name, true, false)
		if driver != null:
			driver.process_mode = Node.PROCESS_MODE_DISABLED
	_level._camera.global_position = Vector2(1070.0, 325.0)
	_level._camera.zoom = Vector2.ONE * 2.1
	_level._camera.reset_smoothing()
	_level._camera.force_update_scroll()
	for form: StringName in [&"humanoid", &"mature"]:
		await _prepare(form, "run_light_run", "走动 → 轻击站稳 → 按住方向继续跑")
		Input.action_press(&"move_right")
		await _advance(24)
		_actor.combat.request_action(&"attack", _actor.global_position + Vector2.RIGHT * 300.0)
		await _advance(52)
		await _prepare(form, "run_heavy_reverse", "走动 → 重击站稳 → 反向跑动")
		Input.action_press(&"move_right")
		await _advance(24)
		_actor.combat.request_action(&"heavy", _actor.global_position + Vector2.RIGHT * 300.0)
		await _advance(6)
		Input.action_release(&"move_right")
		Input.action_press(&"move_left")
		await _advance(64)
		await _prepare(form, "jump_attack", "走动 → 同帧跳跃与攻击 → 着地接跑动")
		Input.action_press(&"move_right")
		await _advance(16)
		Input.action_press(&"jump")
		_actor.combat.request_action(&"attack", _actor.global_position + Vector2.RIGHT * 300.0)
		await _advance(36)
		Input.action_release(&"jump")
		await _advance(35)
		await _prepare(form, "fall_attack_landing", "跳跃下落 → 空击 → 落地收回 → 继续走动")
		Input.action_press(&"move_right")
		Input.action_press(&"jump")
		await _advance(12)
		Input.action_release(&"jump")
		for tick: int in range(60):
			await _advance(1)
			if not _actor.is_on_floor() and _actor.velocity.y > 0.0 and _actor.global_position.y > 350.0:
				break
		_actor.combat.request_action(&"attack", _actor.global_position + Vector2.RIGHT * 300.0)
		await _advance(35)
	_release_inputs()
	_level.feedback.clear()
	var output := FileAccess.open(_directory.path_join("transition_manifest.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"kind": "production_player_input_physics", "fps": 60, "rate": 1.0, "resolution": [1280, 720], "camera_zoom": 2.1, "frames": _frames}, "  "))
	_main.queue_free()
	await process_frame
	print("ATTACK_TRANSITION_CAPTURE ", _frame_number, " frames / ", _directory)
	quit()

func _prepare(form: StringName, label: String, title: String) -> void:
	_release_inputs()
	_level.feedback.clear()
	_actor.combat.reset()
	_actor.revive_animation()
	_actor.form_controller.restore_form(form)
	_actor.global_position = Vector2(940.0, 400.0)
	_actor.velocity = Vector2.ZERO
	_scenario = String(form) + "_" + label
	_scenario_tick = 0
	_seen_attack = false
	_level.combat_hud.set_progress("攻击衔接 / " + String(form), title, 0, 0)
	await _advance(14)

func _advance(count: int) -> void:
	for tick: int in range(count):
		await physics_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var attack: AttackDefinition = _actor.combat.attack
		_seen_attack = _seen_attack or attack != null
		_frames.append({"frame": _frame_number, "scenario": _scenario, "tick": _scenario_tick, "x": _actor.position.x, "y": _actor.position.y, "vx": _actor.velocity.x, "vy": _actor.velocity.y, "grounded": _actor.is_on_floor(), "combat": String(_actor.combat.state), "attack": String(attack.id) if attack != null else "", "elapsed": _actor.combat.elapsed, "locomotion": String(_actor.current_state())})
		var phase: String = ""
		if _actor.combat.state == &"attack_landing":
			phase = "landing"
		elif attack != null:
			var local_elapsed: float = _actor.combat.elapsed / _actor.combat.time_scale_for_form()
			phase = "windup" if local_elapsed < attack.windup * 0.5 else "charge" if local_elapsed < attack.windup else "strike"
		elif _seen_attack and absf(_actor.velocity.x) > 100.0 and _actor.is_on_floor():
			phase = "resume"
		var key: String = _scenario + "_" + phase
		if not phase.is_empty() and not _shots.has(key):
			root.get_texture().get_image().save_webp(_directory.path_join(key + ".webp"))
			_shots[key] = true
		_frame_number += 1
		_scenario_tick += 1

func _release_inputs() -> void:
	for action: StringName in [&"move_left", &"move_right", &"jump"]:
		Input.action_release(action)
