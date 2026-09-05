extends SceneTree
## Offscreen captures of production entities. Invoke with -- heavy, -- parry, or -- enemies.
## No gameplay scene or test level is created; output is written to the OS temporary folder.
const PLAYER: PackedScene = preload("res://features/player/player.tscn")
const ENEMY: PackedScene = preload("res://features/enemies/beetle.tscn")
var players: Array[Player] = []
var enemies: Array[CombatEnemy] = []
var face: float = 1.0
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(960, 640)
	root.content_scale_size = Vector2i(960, 640)
	RenderingServer.set_default_clear_color(Color("#172a2b"))
	var args := OS.get_cmdline_user_args()
	var action := StringName(args[0]) if not args.is_empty() else &"heavy"
	var suffix := args[1] if args.size() > 1 else "early"
	face = -1.0 if args.has("left") else 1.0
	if action == &"enemies":
		_add_enemies(StringName(suffix))
	else:
		_add_players(action, suffix == "late")
	await create_timer(0.08).timeout
	for player: Player in players:
		player.visuals.set_combat_state(player.combat)
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("TEMP").path_join("combat_visual_%s_%s.webp" % [action, suffix + ("_left" if face < 0 else "")])
	var capture := root.get_texture().get_image()
	capture.resize(768, 512, Image.INTERPOLATE_LANCZOS)
	capture.save_webp(output)
	print("VISUAL_CAPTURE ", output)
	for player: Player in players:
		player.queue_free()
	for enemy: CombatEnemy in enemies:
		enemy.queue_free()
	players.clear()
	enemies.clear()
	await process_frame
	await process_frame
	quit()
func _add_players(action: StringName, late: bool) -> void:
	for index in range(4):
		var player := PLAYER.instantiate() as Player
		root.add_child(player)
		player.set_physics_process(false)
		player.position = Vector2((330 if face < 0 else 150) + (index % 2) * 480, 255 + (index / 2) * 315)
		player.scale = Vector2.ONE * 2.5
		player.form_controller.switch_to(&"humanoid" if index < 2 else &"mature")
		var progress := (0.65 if index % 2 == 0 else 0.9) if late else (0.22 if index % 2 == 0 else 0.44)
		player.combat.state = action
		player.combat.attack = player.combat.tuning.find_attack(action)
		var duration := 0.42
		if player.combat.attack != null:
			player.combat.state = &"attack"
			duration = player.combat.attack.duration() * player.combat.time_scale_for_form()
		elif action == &"dash":
			duration = player.combat.tuning.dash_duration
		elif action == &"parry_success":
			duration = 0.08
		elif action == &"hurt":
			duration = 0.22
		player.combat.elapsed = duration * progress
		player.combat.facing = face
		player.visuals.set_combat_state(player.combat)
		players.append(player)
		_label(Vector2(48 + (index % 2) * 480, 36 + (index / 2) * 315), "%s / %s / %.2f" % [player.current_form_id(), action, progress])
func _add_enemies(state: StringName) -> void:
	for index in range(4):
		var enemy := ENEMY.instantiate() as CombatEnemy
		enemy.definition = load("res://features/enemies/data/%s.tres" % ["beetle", "spore", "pruner", "warden"][index])
		root.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.position = Vector2(175 + (index % 2) * 480, 255 + (index / 2) * 315)
		enemy.scale = Vector2.ONE * 2.5
		enemy.facing = face
		enemy.attack_kind = &"charge" if index == 0 else &"slash"
		enemy.state = state
		enemy.elapsed = enemy.definition.windup * 0.85 if state == &"windup" else 0.09 if state == &"strike" else 0.0
		enemies.append(enemy)
		_label(Vector2(48 + (index % 2) * 480, 36 + (index / 2) * 315), "%s / %s" % [enemy.definition.display_name, state])
func _label(at: Vector2, value: String) -> void:
	var label := Label.new()
	label.position = at
	label.text = value
	label.add_theme_font_size_override("font_size", 20)
	root.add_child(label)
