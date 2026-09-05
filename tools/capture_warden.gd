extends SceneTree
## Captures the shipped component or the authoritative main encounter; no demo level.
const WARDEN: PackedScene = preload("res://features/enemies/warden.tscn")
const MAIN: PackedScene = preload("res://scenes/app/main.tscn")
var directory: String

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://build/qa/warden")
	DirAccess.make_dir_recursive_absolute(directory)
	if OS.get_cmdline_user_args().has("--main"):
		await _capture_main()
		return
	if OS.get_cmdline_user_args().has("--reel"):
		await _capture_reel()
		return
	RenderingServer.set_default_clear_color(Color("#20332e"))
	root.size = Vector2i(1000, 700)
	root.content_scale_size = Vector2i(1000, 700)
	var cases: Array[Array] = [
		[&"slash", &"idle", 0.0, "GUARD / weight and planted feet"],
		[&"slash", &"windup", 0.43, "LOAD / hips back, blade above"],
		[&"slash", &"strike", 0.15, "CUT / drive, turn, follow through"],
		[&"charge", &"stun", 0.18, "PARRY / blade thrown, stance broken"],
	]
	if OS.get_cmdline_user_args().has("--skills"):
		cases = [
			[&"charge", &"windup", 0.58, "RUSH / crouch behind the shield"],
			[&"uppercut", &"strike", 0.18, "RISE / legs drive the upward cut"],
			[&"slam", &"windup", 0.74, "SLAM / brace and lift the blade"],
			[&"slam", &"strike", 0.2, "IMPACT / weight into the floor"],
		]
	var enemies: Array[CombatEnemy] = []
	for index: int in range(4):
		var enemy := WARDEN.instantiate() as CombatEnemy
		root.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.position = Vector2(220 + index % 2 * 500, 290 + index / 2 * 340)
		enemy.facing = 1.0
		enemy.visuals.scale = Vector2.ONE * 1.58
		enemy.visuals.set_process(false)
		enemy.attack_kind = cases[index][0]
		enemy.state = cases[index][1]
		enemy.elapsed = cases[index][2]
		enemy.warden_behavior.reaction = &"parry"
		enemy.warden_behavior.stun_duration = 1.1
		enemy.visuals._process(1.0)
		enemies.append(enemy)
		var label := Label.new()
		label.position = Vector2(28 + index % 2 * 500, 302 + index / 2 * 340)
		label.text = cases[index][3]
		label.add_theme_font_size_override("font_size", 16)
		root.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp(directory.path_join("skills.webp" if OS.get_cmdline_user_args().has("--skills") else "poses.webp"))
	for enemy: CombatEnemy in enemies: enemy.queue_free()
	await process_frame
	print("CAPTURE ", directory)
	quit()

func _capture_reel() -> void:
	RenderingServer.set_default_clear_color(Color("#20332e"))
	root.size = Vector2i(800, 512)
	root.content_scale_size = Vector2i(800, 512)
	var enemy := WARDEN.instantiate() as CombatEnemy
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.visuals.set_process(false)
	enemy.visuals.scale = Vector2.ONE * 2.25
	enemy.position = Vector2(335, 426)
	enemy.facing = 1
	var label := Label.new()
	label.position = Vector2(28, 28)
	label.add_theme_font_size_override("font_size", 21)
	root.add_child(label)
	var frame_index := 0
	for kind: StringName in [&"slash", &"charge", &"uppercut", &"slam", &"backswing"]:
		var move := enemy.warden_behavior.tuning.move_for(kind)
		var phases: Array[Array] = [[&"windup", move.windup], [&"strike", move.duration], [&"recover", move.recovery]]
		for phase: Array in phases:
			enemy.attack_kind = kind
			enemy._set_state(phase[0])
			enemy.warden_behavior.recovery_duration = move.recovery
			label.text = "WARDEN / %s / %s" % [kind.to_upper(), String(phase[0]).to_upper()]
			for frame: int in range(ceili(float(phase[1]) * 30)):
				enemy.elapsed = frame / 30.0
				enemy.visuals._process(1.0 / 30.0)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(directory.path_join("reel_%04d.png" % frame_index))
				frame_index += 1
	enemy.queue_free()
	await process_frame
	print("REEL ", frame_index, " frames ", directory)
	quit()

func _capture_main() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	current_scene = main
	await physics_frame
	var level := main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	var player := level._player
	var encounter := level.encounters[7]
	player.form_controller.restore_form(&"humanoid")
	player.global_position = encounter.global_position + Vector2(95, -2)
	player.velocity = Vector2.ZERO
	for frame: int in range(220):
		await physics_frame
		await RenderingServer.frame_post_draw
		if frame in [25, 55, 90, 135, 180, 215]:
			root.get_texture().get_image().save_webp(directory.path_join("main_%03d.webp" % frame))
	level.feedback.clear()
	main.queue_free()
	await process_frame
	print("MAIN CAPTURE ", directory)
	quit()
