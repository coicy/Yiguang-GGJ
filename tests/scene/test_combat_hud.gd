extends SceneTree
## Small presentation contract test; no additional playable level.
var _failures: PackedStringArray = []
var _hud: CombatHud
var _player: Player
var _boss: CombatEnemy
var _host: Node2D
var _capture_dir: String = ""
var _capture_main: bool = false
var _resumes: int = 0
var _retries: int = 0
var _restarts: int = 0

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "capture_main":
			_capture_main = true
		if argument.begins_with("capture="):
			_capture_dir = argument.trim_prefix("capture=")
	call_deferred("_run")

func _run() -> void:
	if _capture_main:
		await _capture_production()
		return
	_host = Node2D.new()
	root.add_child(_host)
	_player = load("res://features/player/player.tscn").instantiate() as Player
	_host.add_child(_player)
	_player.set_physics_process(false)
	_player.hide()
	_hud = load("res://features/ui/combat_hud.tscn").instantiate() as CombatHud
	_host.add_child(_hud)
	var growth_layer := CanvasLayer.new()
	_host.add_child(growth_layer)
	var growth_hud := load("res://features/ui/handbuilt_hud.tscn").instantiate() as HandbuiltHud
	growth_layer.add_child(growth_hud)
	growth_hud.bind_player(_player)
	_hud.bind_player(_player)
	_hud.set_progress("04  /  修枝车间", "观察机兵的挥刃，重击破防或从背后攻击", 125.7, 2)
	_hud.resume_requested.connect(func() -> void: _resumes += 1)
	_hud.retry_requested.connect(func() -> void: _retries += 1)
	_hud.restart_requested.connect(func() -> void: _restarts += 1)
	await _frames(3)
	_expect(_all_ignore_mouse(_hud.get_node("%Gameplay")), "Game HUD must pass every mouse event through")
	_expect(_hud.health_label.text == "生命  5 / 5", "Initial real health must bind")
	_expect(_hud.run_label.text.contains("02:05") and _hud.run_label.text.contains("2"), "Run time uses mm:ss and supplied death count")
	_expect(_hud.dash_label.text.contains("未解锁"), "Sprout must not advertise available combat actions")
	_expect(not _hud._details_expanded and not _hud.dash_label.visible and not _hud.parry_label.visible, "Sprout hides the large unavailable combat controls")
	_expect(_hud.health_pips.visible and _hud.health_pips.get_child_count() == 5, "Compact sprout keeps all five real HP pips")
	_expect((_hud.get_node("%CombatPanel") as Control).size.y <= 90.0, "Stable combat card occupies at most 90 pixels vertically")
	_player.form_controller.restore_form(&"humanoid")
	await _frames(2)
	_expect(_hud._details_expanded and _hud.dash_label.visible, "Growing reveals unlocked combat detail temporarily")
	_hud._process(3.1)
	await _frames(2)
	_expect(not _hud._details_expanded and _hud._compact_actions.text.contains("弹反"), "Stable human collapses while retaining brief availability")
	var request := DamageRequest.new()
	request.amount = 3
	_player.combat.health.take_damage(request)
	await _frames(2)
	_expect(_hud.health_label.text == "生命  2 / 5 · 危险", "Damage signal updates health with a text danger warning")
	_expect((_hud.health_pips.get_child(1) as ProgressBar).value == 1.0 and (_hud.health_pips.get_child(2) as ProgressBar).value == 0.0, "HP leaves must show actual lost health")
	_player.combat.dash_cooldown_left = 0.3
	await _frames(2)
	_expect(_hud._compact_actions.text.contains("0.3s"), "Compact cooldown stays readable without expanding the card")
	_expect(not _hud._details_expanded, "Cooldown ticks do not repeatedly expand the card")
	_expect(_hud.dash_label.text.contains("0.3s") and _hud.dash_bar.value < 0.4, "Dash UI reads the configured cooldown")
	_player.combat.air_dash_used = true
	await _frames(2)
	_expect(_hud.dash_label.text.contains("落地恢复"), "Air dash availability must explain landing recovery")
	_player.combat.state = &"parry"
	_player.combat.elapsed = 0.1
	await _frames(2)
	_expect(_hud.parry_label.text.contains("防御窗口"), "Parry UI identifies the active window")
	_player.combat.state = &"parry_success"
	await _frames(2)
	_expect(_hud.parry_label.text.contains("反击"), "Successful parry invites a counterattack")
	_player.combat.reset()
	_hud.bind_player(_player)
	_hud.bind_player(_player)
	_player.combat.health.reset_health()
	_expect(_hud.health_label.text == "生命  5 / 5", "Rebinding does not leave stale health subscriptions")
	_boss = load("res://features/enemies/warden.tscn").instantiate() as CombatEnemy
	_host.add_child(_boss)
	_boss.set_physics_process(false)
	_boss.hide()
	_hud.set_boss(_boss)
	await _frames(2)
	_expect(_hud.boss_panel.visible and _hud.boss_bar.max_value == 40, "Boss UI binds actual health")
	_boss.health.current = 19
	_boss.second_phase = true
	await _frames(2)
	_expect(_hud.boss_bar.value == 19 and _hud.boss_phase.text.contains("第二阶段"), "Boss damage and phase update together")
	await _capture("01-combat-hud")
	_assert_fits()
	_hud.show_pause()
	paused = true
	await _frames(20)
	_expect(_hud.is_overlay_visible() and _hud.controls_guide.visible, "Pause opens controls and overlay")
	_expect(_hud.primary_button.has_focus(), "Pause puts keyboard focus on the primary action")
	await _click(_hud.primary_button)
	_expect(_resumes == 1 and paused, "Pause button emits intent while level retains pause ownership")
	await _capture("02-pause")
	_hud.hide_overlay()
	paused = false
	_expect(not _hud.is_overlay_visible(), "Resume command clears overlay")
	_hud.show_death()
	await _frames(20)
	await _click(_hud.primary_button)
	_expect(_retries == 1 and not _hud.controls_guide.visible, "Death primary action requests local retry")
	await _click(_hud.restart_button)
	_expect(_restarts == 1, "Secondary action requests whole-level restart")
	await _capture("03-death")
	_hud.show_complete(623.8, 3)
	await _frames(20)
	_expect(_hud.overlay_stats.text.contains("10:23") and _hud.overlay_stats.text.contains("3"), "Completion shows final supplied statistics")
	_expect(not _hud.restart_button.visible, "Completion has a single replay action")
	await _click(_hud.primary_button)
	_expect(_restarts == 2, "Completion replay requests whole-level restart")
	await _capture("04-complete")
	_assert_fits()
	_hud.hide_overlay()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1344, 640)]:
		root.size = size
		await _frames(4)
		_assert_fits()
		await _capture("05-size-%dx%d" % [size.x, size.y])
	_hud.set_boss(null)
	_expect(not _hud.boss_panel.visible, "Completed encounter clears boss UI")
	_hud.set_boss(_boss)
	_boss.queue_free()
	await _frames(2)
	_expect(not _hud.boss_panel.visible, "Freed boss never leaves stale UI or invalid reads")
	_hud.bind_player(null)
	_expect(not _hud.get_node("%CombatPanel").visible, "Unbinding clears the health panel")
	_host.queue_free()
	await _frames(2)
	for failure: String in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: Combat HUD health, cooldown, phases, read-only binding, pause input, death/replay signals, responsive layout")
	quit(0 if _failures.is_empty() else 1)

func _assert_fits() -> void:
	var screen_rect := Rect2(Vector2.ZERO, _hud.screen.size)
	for name: String in ["%CombatPanel", "%SectionLabel", "%ObjectiveLabel", "%BossPanel"]:
		var control := _hud.get_node(name) as Control
		_expect(screen_rect.encloses(control.get_global_rect()), "%s must fit viewport %s" % [name, _hud.screen.size])
	_expect(not (_hud.get_node("%CombatPanel") as Control).get_global_rect().intersects((_hud.get_node("%ObjectiveLabel") as Control).get_global_rect()), "Health and objective must not overlap")
	if _hud.is_overlay_visible():
		_expect(screen_rect.encloses((_hud.get_node("%Panel") as Control).get_global_rect()), "Overlay contents must fit viewport")

func _click(button: Button) -> void:
	var location := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = location
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = location
	event.pressed = true
	root.push_input(event, true)
	await _frames(1)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await _frames(2)

func _frames(count: int) -> void:
	for frame: int in range(count):
		await process_frame

func _capture(label: String) -> void:
	if _capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_webp(_capture_dir.path_join(label + ".webp"), false, 0.9)
	print("CAPTURE ", label, " screen=", img.get_size(), " hud=", _hud.screen.size)

func _all_ignore_mouse(node: Node) -> bool:
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child: Node in node.get_children():
		if not _all_ignore_mouse(child):
			return false
	return true

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _capture_production() -> void:
	change_scene_to_file("res://scenes/app/main.tscn")
	await _frames(8)
	var level := current_scene.get_node("LevelHost/LevelMain/Level01") as GreenhouseLevel
	_hud = level.combat_hud
	_player = level.get_node("Actors/Player") as Player
	await create_timer(0.3).timeout
	_assert_fits()
	await _capture("06-main-cultivation")
	_player.form_controller.restore_form(&"mature")
	_player.global_position = Vector2(7650.0, 398.0)
	_player.velocity = Vector2.ZERO
	var encounter := level.get_node("Encounters/Warden") as EncounterController
	encounter.begin()
	await _frames(4)
	paused = true
	var camera := level.get_node("Camera2D") as Camera2D
	camera.position = encounter.camera_center()
	camera.zoom = Vector2.ONE * 1.65
	camera.reset_smoothing()
	_hud.set_progress("07 / 温室核心", "红叉重砸不可弹反 · 抓住收招", 540.0, 2)
	await _frames(3)
	_assert_fits()
	await _capture("07-main-boss")
	_hud.show_pause()
	await create_timer(0.2, true).timeout
	await _capture("08-main-pause")
	_hud.show_complete(623.8, 3)
	await create_timer(0.2, true).timeout
	await _capture("09-main-complete")
	paused = false
	current_scene.queue_free()
	await _frames(2)
	for failure: String in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: production main HUD layout and screenshots")
	quit(0 if _failures.is_empty() else 1)
