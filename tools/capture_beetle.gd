extends SceneTree
## Capture production entities and the first encounter; never creates a playable level.
const MAIN: PackedScene = preload("res://scenes/app/main.tscn")
const BEETLE: PackedScene = preload("res://features/enemies/beetle.tscn")
var directory: String

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(960, 640)
	root.content_scale_size = Vector2i(960, 640)
	directory = ProjectSettings.globalize_path("res://build/qa/beetle")
	DirAccess.make_dir_recursive_absolute(directory)
	if OS.get_cmdline_user_args().has("--main"):
		await _capture_main()
		return
	if OS.get_cmdline_user_args().has("--reel"):
		await _capture_reel()
		return
	RenderingServer.set_default_clear_color(Color("#20332e"))
	var cases: Array[Array] = [
		[&"horn", &"idle", 0.0, "REST / six planted feet"],
		[&"horn", &"windup", 0.35, "LOAD / weight back"],
		[&"horn", &"strike", 0.1, "RELEASE / rear-leg drive"],
		[&"charge", &"stun", 0.12, "IMPACT / brace and recoil"],
	]
	var enemies: Array[CombatEnemy] = []
	for i: int in range(4):
		var enemy := BEETLE.instantiate() as CombatEnemy
		root.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.position = Vector2(225 + i % 2 * 480, 210 + i / 2 * 320)
		enemy.facing = 1.0
		enemy.visuals.scale = Vector2.ONE * 4.5
		enemy.visuals.set_process(false)
		enemy.attack_kind = cases[i][0]
		enemy.state = cases[i][1]
		enemy.elapsed = cases[i][2]
		enemy.beetle_behavior.reaction = &"heavy"
		enemy.beetle_behavior.stun_duration = 0.7
		enemy.visuals._process(1.0)
		enemies.append(enemy)
		var label := Label.new()
		label.position = Vector2(26 + i % 2 * 480, 260 + i / 2 * 320)
		label.text = cases[i][3]
		label.add_theme_font_size_override("font_size", 18)
		root.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp(directory.path_join("poses.webp"))
	for enemy: CombatEnemy in enemies:
		enemy.queue_free()
	await process_frame
	print("CAPTURE ", directory)
	quit()

func _capture_reel() -> void:
	RenderingServer.set_default_clear_color(Color("#20332e"))
	root.size = Vector2i(640, 400)
	root.content_scale_size = Vector2i(640, 400)
	var enemy := BEETLE.instantiate() as CombatEnemy
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.visuals.set_process(false)
	enemy.visuals.scale = Vector2.ONE * 4.0
	enemy.position = Vector2(310, 310)
	enemy.facing = 1.0
	var title := Label.new()
	title.position = Vector2(24, 22)
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)
	var moves: Array[Array] = [
		[&"idle", &"horn", 0.45, "IDLE / breathe and feel"],
		[&"windup", &"horn", 0.38, "HORN / load the hind legs"],
		[&"strike", &"horn", 0.24, "HORN / drive and lift"],
		[&"recover", &"horn", 0.56, "HORN / plant and settle"],
		[&"windup", &"charge", 0.6, "CHARGE / scrape and crouch"],
		[&"strike", &"charge", 0.48, "CHARGE / accelerate"],
		[&"recover", &"charge", 0.78, "CHARGE / brake and brace"],
		[&"stun", &"charge", 0.7, "HEAVY HIT / recoil and catch"],
		[&"recover", &"charge", 0.3, "RECOVER / regain footing"],
		[&"dead", &"charge", 1.1, "DEATH / fold and collapse"],
	]
	var frame_index := 0
	for move: Array in moves:
		enemy._set_state(move[0])
		enemy.attack_kind = move[1]
		title.text = move[3]
		enemy.beetle_behavior.recovery_duration = move[2]
		enemy.beetle_behavior.reaction = &"heavy"
		enemy.beetle_behavior.stun_duration = 0.7
		for frame: int in range(ceili(float(move[2]) * 30.0)):
			enemy.elapsed = frame / 30.0
			# Pose reel is in place. Simulate body displacement only for gait sampling.
			if enemy.state == &"strike" and enemy.attack_kind == &"charge":
				enemy.velocity.x = 260.0
				(enemy.visuals as BeetleVisual)._last_position.x = enemy.position.x - 260.0 / 30.0
			else:
				enemy.velocity.x = 0.0
			enemy.visuals._process(1.0 / 30.0)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("reel_%04d.png" % frame_index))
			frame_index += 1
	enemy.queue_free()
	await process_frame
	print("POSE REEL ", frame_index, " frames / ", directory)
	quit()

func _capture_main() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	current_scene = main
	await physics_frame
	var level := main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	var player := level._player
	var encounter := level.encounters[0]
	player.form_controller.restore_form(&"humanoid")
	player.global_position = encounter.global_position + Vector2(90, -2)
	player.velocity = Vector2.ZERO
	for tick: int in range(24):
		await physics_frame
	if not encounter.active:
		encounter.begin()
	for tick: int in range(100):
		await physics_frame
		await RenderingServer.frame_post_draw
		if tick in [0, 20, 45, 65, 90]:
			root.get_texture().get_image().save_webp(directory.path_join("main_%03d.webp" % tick))
	level.feedback.clear()
	main.queue_free()
	await process_frame
	print("MAIN CAPTURE ", directory)
	quit()
