extends SceneTree
## Capture the production pruner and workshop; never creates a playable level.
const MAIN: PackedScene = preload("res://scenes/app/main.tscn")
const PRUNER: PackedScene = preload("res://features/enemies/pruner.tscn")
var directory: String

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(960, 800)
	root.content_scale_size = Vector2i(960, 800)
	directory = ProjectSettings.globalize_path("res://build/qa/pruner")
	DirAccess.make_dir_recursive_absolute(directory)
	if OS.get_cmdline_user_args().has("--main"):
		await _capture_main()
		return
	if OS.get_cmdline_user_args().has("--reel"):
		await _capture_reel()
		return
	RenderingServer.set_default_clear_color(Color("#20332e"))
	var cases: Array[Array] = [
		[&"shear", &"idle", 0.0, "REST / shield and shears"],
		[&"shear", &"windup", 0.5, "SHEAR / hips load, blades open"],
		[&"shear", &"strike", 0.1, "CUT / drive, close, brace"],
		[&"slam", &"windup", 0.9, "CLEAVE / planted overhead lift"],
	]
	if OS.get_cmdline_user_args().has("--reactions"):
		cases = [[&"shear", &"guard_bump", 0.1, "BLOCK / shield catches, knees bend"], [&"shear", &"stun", 0.1, "BREAK / shield drops, torso opens"], [&"shear", &"stun", 0.1, "PARRY / cutting arm deflected"], [&"slam", &"dead", 0.6, "DEATH / knees fold, weight falls"]]
	var enemies: Array[CombatEnemy] = []
	for i: int in range(4):
		var enemy := PRUNER.instantiate() as CombatEnemy
		root.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.position = Vector2(180 + i % 2 * 480, 290 + i / 2 * 400)
		enemy.facing = 1.0
		enemy.visuals.scale = Vector2.ONE * 3.4
		enemy.visuals.set_process(false)
		enemy.attack_kind = cases[i][0]
		enemy.state = cases[i][1]
		enemy.elapsed = cases[i][2]
		enemy.pruner_behavior.reaction = (&"parry" if i == 2 else &"break") if OS.get_cmdline_user_args().has("--reactions") else &"heavy"
		enemy.pruner_behavior.stun_duration = 0.7
		enemy.visuals._process(1.0)
		enemies.append(enemy)
		var label := Label.new()
		label.position = Vector2(26 + i % 2 * 480, 342 + i / 2 * 400)
		label.text = cases[i][3]
		label.add_theme_font_size_override("font_size", 18)
		root.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp(directory.path_join("reactions.webp" if OS.get_cmdline_user_args().has("--reactions") else "poses.webp"))
	for enemy: CombatEnemy in enemies:
		enemy.queue_free()
	await process_frame
	print("CAPTURE ", directory)
	quit()

func _capture_reel() -> void:
	RenderingServer.set_default_clear_color(Color("#20332e"))
	root.size = Vector2i(640,480)
	root.content_scale_size = Vector2i(640,480)
	var enemy := PRUNER.instantiate() as CombatEnemy
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.visuals.set_process(false)
	enemy.visuals.scale = Vector2.ONE * 4.0
	enemy.position = Vector2(270,380)
	enemy.facing = 1.0
	var title := Label.new()
	title.position = Vector2(24,22)
	title.add_theme_font_size_override("font_size",22)
	root.add_child(title)
	var moves: Array[Array] = [[&"idle",&"shear",0.5,"REST / settle and scan"]]
	for kind: StringName in [&"shear",&"lunge",&"slam"]:
		var move := enemy.pruner_behavior.tuning.move_for(kind)
		moves.append([&"windup",kind,move.windup,String(kind).to_upper()+" / plant and load"])
		moves.append([&"strike",kind,move.duration,String(kind).to_upper()+" / drive and release"])
		moves.append([&"recover",kind,move.recovery,String(kind).to_upper()+" / brake and reset"])
	moves.append([&"guard_bump",&"shear",0.24,"BLOCK / shield, hip, knees"])
	moves.append([&"stun",&"shear",0.95,"BREAK / shield drops"])
	moves.append([&"recover",&"shear",0.32,"RECOVER / regain footing"])
	moves.append([&"stun",&"lunge",0.85,"PARRY / arm deflects"])
	moves.append([&"dead",&"shear",1.15,"DEATH / fold and collapse"])
	var frame_index := 0
	for move: Array in moves:
		enemy._set_state(move[0])
		enemy.attack_kind = move[1]
		title.text = move[3]
		enemy.pruner_behavior.recovery_duration = move[2]
		enemy.pruner_behavior.stun_duration = move[2]
		enemy.pruner_behavior.reaction = &"parry" if move[1] == &"lunge" else &"break"
		for frame: int in range(ceili(float(move[2])*30.0)):
			enemy.elapsed = frame/30.0
			enemy.visuals._process(1.0/30.0)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("reel_%04d.png" % frame_index))
			frame_index += 1
	enemy.queue_free()
	await process_frame
	print("PRUNER POSE REEL ",frame_index," frames / ",directory)
	quit()

func _capture_main() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	current_scene = main
	await physics_frame
	var level := main.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	var player := level._player
	var encounter := level.encounters[4]
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
