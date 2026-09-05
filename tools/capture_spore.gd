extends SceneTree
## Captures the production entity or production main encounter; no new playable level.
const SPORE: PackedScene = preload("res://features/enemies/spore.tscn")
var directory: String

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://build/qa/spore")
	DirAccess.make_dir_recursive_absolute(directory)
	if OS.get_cmdline_user_args().has("--main") or OS.get_cmdline_user_args().has("--flight"):
		await _main_capture()
		return
	RenderingServer.set_default_clear_color(Color("#20332e"))
	root.size = Vector2i(800, 640)
	root.content_scale_size = root.size
	if OS.get_cmdline_user_args().has("--reel"):
		await _reel()
		return
	var cases: Array[Array] = [
		[&"spit", &"idle", 0.0, "REST / rooted breathing"],
		[&"spit", &"windup", 0.81, "LOAD / inflate and brace"],
		[&"spit", &"strike", 0.10, "RELEASE / contract and whip"],
		[&"lash", &"strike", 0.105, "LASH / drive the whole sac"],
	]
	for i: int in range(4):
		var enemy: CombatEnemy = SPORE.instantiate() as CombatEnemy
		root.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.visuals.set_process(false)
		enemy.position = Vector2(160 + i % 2 * 400, 240 + i / 2 * 320)
		enemy.facing = 1.0
		enemy.spore_behavior.aim_point = enemy.global_position + Vector2(180, -26)
		enemy.visuals.scale = Vector2.ONE * 2.8
		enemy.attack_kind = cases[i][0]
		enemy.state = cases[i][1]
		enemy.elapsed = cases[i][2]
		enemy.visuals._process(1.0)
		var label := Label.new()
		label.position = Vector2(22 + i % 2 * 400, 277 + i / 2 * 320)
		label.text = cases[i][3]
		label.add_theme_font_size_override("font_size", 17)
		root.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp(directory.path_join("poses.webp"))
	print("SPORE CAPTURE ", directory)
	quit()

func _reel() -> void:
	root.size = Vector2i(720, 400)
	root.content_scale_size = root.size
	var actors: Array[CombatEnemy] = []
	for face: float in [1.0, -1.0]:
		var enemy: CombatEnemy = SPORE.instantiate() as CombatEnemy
		root.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.visuals.set_process(false)
		enemy.position = Vector2(170 if face > 0 else 550, 315)
		enemy.facing = face
		enemy.spore_behavior.aim_point = enemy.global_position + Vector2(face * 180, -26)
		enemy.visuals.scale = Vector2.ONE * 3.0
		actors.append(enemy)
	var label := Label.new()
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size", 21)
	root.add_child(label)
	var moves: Array[Array] = [
		[&"idle", &"spit", 0.5, "REST / roots and breathing", &"light"],
		[&"windup", &"spit", 0.84, "SPIT / inflate and load the roots", &"light"],
		[&"strike", &"spit", 0.3, "SPIT / contract, extend, recoil", &"light"],
		[&"recover", &"spit", 1.12, "SPIT / settle the pressure sac", &"light"],
		[&"windup", &"lash", 0.48, "LASH / coil away from the target", &"light"],
		[&"strike", &"lash", 0.28, "LASH / root-driven body whip", &"light"],
		[&"recover", &"lash", 0.86, "LASH / catch and settle", &"light"],
		[&"stun", &"lash", 0.28, "LIGHT HIT / fold and brace", &"light"],
		[&"stun", &"lash", 0.7, "HEAVY HIT / lose balance", &"heavy"],
		[&"stun", &"lash", 0.7, "PARRY / nozzle kicked upward", &"parry"],
		[&"dead", &"lash", 1.15, "DEATH / wilt with connected limbs", &"heavy"],
	]
	var frame_index: int = 0
	for move: Array in moves:
		label.text = move[3]
		for enemy: CombatEnemy in actors:
			enemy._set_state(move[0])
			enemy.attack_kind = move[1]
			enemy.spore_behavior.reaction = move[4]
			enemy.spore_behavior.hit_direction = -enemy.facing
			enemy.spore_behavior.stun_duration = move[2]
		for frame: int in range(ceili(float(move[2]) * 30)):
			for enemy: CombatEnemy in actors:
				enemy.elapsed = frame / 30.0
				enemy.visuals._process(1.0 / 30.0)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("reel_%04d.png" % frame_index))
			frame_index += 1
	print("SPORE REEL ", frame_index, " frames")
	quit()

func _main_capture() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var main_scene: PackedScene = load("res://scenes/app/main.tscn")
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await physics_frame
	var level: GreenhouseLevel = main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	var encounter: EncounterController = level.encounters[2]
	level._player.form_controller.restore_form(&"humanoid")
	# Isolate the actual encounter on its open side so the planter does not occlude the tell.
	level._player.global_position = encounter.global_position + Vector2(400, -2)
	level._player.velocity = Vector2.ZERO
	for tick: int in range(24):
		await physics_frame
	if not encounter.active:
		encounter.begin()
	var flight: bool = OS.get_cmdline_user_args().has("--flight")
	for tick: int in range(180 if flight else 120):
		await physics_frame
		await RenderingServer.frame_post_draw
		if tick in [15, 40, 60, 85, 115]:
			root.get_texture().get_image().save_webp(directory.path_join("main_%03d.webp" % tick))
		if flight and tick % 2 == 0:
			root.get_texture().get_image().save_webp(directory.path_join("flight_%03d.webp" % tick))
	level.feedback.clear()
	main.queue_free()
	await process_frame
	print("SPORE MAIN CAPTURE ", directory)
	quit()
