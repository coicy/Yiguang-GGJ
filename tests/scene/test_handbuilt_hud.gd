extends SceneTree
const STEP := 1.0 / 60.0
var _failures: PackedStringArray = []
var _hud: HandbuiltHud
var _player: Player
var _capture_dir := ""

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("capture="):
			_capture_dir = argument.trim_prefix("capture=")
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/app/main.tscn")
	await process_frame
	await process_frame
	var level := current_scene.get_node("LevelHost/LevelMain/Level01")
	_player = level.get_node("Actors/Player") as Player
	_hud = level.get_node("Interface/HandbuiltHud") as HandbuiltHud
	_player.set_physics_process(false)
	var nutrition := level.get_node("Areas/FirstGrowth") as NutritionTank
	var toxin := level.get_node("Areas/BranchWither") as ToxinResource
	nutrition.set_physics_process(false)
	toxin.set_physics_process(false)
	_expect(not nutrition.show_world_prompt and not toxin.show_world_prompt, "Main resources must use the screen-space prompt")
	_expect(_all_ignore_mouse(_hud), "HUD controls must not intercept gameplay clicks")
	_player.global_position = nutrition.global_position + Vector2(0.0, 15.0)
	await _frames(8)
	_expect(_hud.form_name.text == "幼芽期", "HUD binds the real main player")
	_expect(_hud.interaction.visible and _hud.interaction_title.text == "吸收营养液", "Only nearby nutrition should offer absorption")
	_expect(not _hud.get_node("%JumpHint").visible, "Sprout must not advertise jumping")
	_expect(not _hud._details_expanded, "Stable initial HUD defaults to compact")
	_expect((_hud.get_node("%Status") as Control).size.y <= 90.0, "Compact resource card occupies at most 90 pixels vertically")
	_expect(_hud._compact_resources.text.contains("成长 0%") and _hud._compact_resources.text.contains("稳定 100%"), "Compact card retains both resource readings")
	await _capture("01-sprout")
	var original_status: Rect2 = _hud.get_node("%Status").get_global_rect()
	var camera := level.get_node("Camera2D") as Camera2D
	var initial_zoom := camera.zoom
	camera.zoom = Vector2.ONE * 2.0
	await _frames(2)
	_expect(_hud.get_node("%Status").get_global_rect() == original_status, "Camera zoom must not resize HUD")
	camera.zoom = initial_zoom
	Input.action_press(&"absorb_resource")
	for frame: int in range(75):
		nutrition._physics_process(STEP)
	await _frames(2)
	_expect(_hud.growth_bar.value > 45.0 and _hud.growth_bar.value < 55.0, "HUD shows real nutrition progress")
	_expect(_hud.interaction_title.text == "正在吸收营养液", "Held E shows absorption state")
	_expect(_hud._details_expanded and _hud.growth_bar.is_visible_in_tree(), "Actual absorption reveals the detailed resource bars")
	await _capture("02-absorbing")
	for frame: int in range(90):
		nutrition._physics_process(STEP)
	await _frames(3)
	_expect(_player.current_form_id() == &"humanoid" and _hud.form_name.text == "人形期", "Form transitions update HUD")
	_expect(_hud.interaction_detail.text.contains("松开 E"), "One-stage absorption must explain the release lock")
	_expect(_hud._details_expanded, "Form change reveals detail for its 3-second reading window")
	await _capture("03-release")
	# Holding a blocked absorption key and passive values_changed emissions must
	# not refresh the detail timer forever. Explicit timer advancement isolates UI.
	_hud._process(3.1)
	for tick in range(30):
		_player.resources.tick(STEP)
	await _frames(3)
	_expect(not _hud._details_expanded, "Three seconds after the last absorption the card collapses despite passive resource updates")
	Input.action_release(&"absorb_resource")
	_player.velocity = Vector2.ZERO
	for frame: int in range(4):
		await physics_frame
		_player._physics_process(STEP)
	var click := InputEventKey.new()
	click.physical_keycode = KEY_Q
	click.keycode = KEY_Q
	click.pressed = true
	Input.parse_input_event(click)
	await _frames(4)
	_expect(_player.abilities.is_rooted(), "Q must toggle root while the HUD remains visible")
	_expect(_hud.get_node("%AbilityText").text == "拔根", "Rooted controls must explain unrooting")
	await _capture("04-rooted")
	_player.cancel_actions()
	_player.global_position = toxin.global_position + Vector2(0.0, 18.0)
	await _frames(6)
	Input.action_press(&"absorb_resource")
	for frame: int in range(90):
		toxin._physics_process(STEP)
	await _frames(2)
	_expect(_hud.interaction_title.text == "正在吸收毒液", "Toxin must have a distinct absorption prompt")
	_expect(absf(_hud.interaction_bar.value - 60.0) < 0.1, "Toxin bar uses the actual withering threshold and progress")
	await _capture("05-toxin")
	Input.action_release(&"absorb_resource")
	_player.form_controller.restore_form(&"sprout")
	await _frames(3)
	_expect(_hud.interaction_title.text == "幼芽无需退化", "Unavailable toxin action must explain why")
	_player.form_controller.restore_form(&"mature")
	_player.resources.stability = 25.0
	_player.resources.restore(_player.resources.snapshot())
	await _frames(3)
	_expect(_hud.stability_label.text.contains("危险"), "Low stability has text warning, not color alone")
	_hud._process(3.1)
	await _frames(2)
	_expect(_hud._compact_resources.text.contains("危险") and _hud._compact_resources.text.contains("25%"), "Compact stability retains numeric and text danger feedback")
	_expect(_hud.growth_value.text == "已成熟", "Mature form must not show an impossible next growth stage")
	await _capture("06-mature")
	_player.global_position = Vector2(600.0, 450.0)
	await _frames(6)
	_expect(not _hud.interaction.visible, "Leaving all resources must hide the interaction prompt")
	_hud.bind_player(_player, [nutrition, toxin])
	_hud.bind_player(_player, [nutrition, toxin])
	_player.resources.reset()
	await _frames(2)
	_expect(_hud.stability_value.text == "100%", "Rebinding must retain a single working set of subscriptions")
	if not _capture_dir.is_empty():
		root.size = Vector2i(960, 540)
		await _frames(4)
		await _capture("07-small-window")
		var screen := Rect2(Vector2.ZERO, _hud.size)
		_expect(screen.encloses(_hud.get_node("%ControlsPanel").get_global_rect()), "Controls must fit the smaller window")
	current_scene.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	for failure: String in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: main HUD binding, nutrition/toxin, form lock, controls, click-through and camera independence")
	quit(0 if _failures.is_empty() else 1)

func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame

func _capture(label: String) -> void:
	if _capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_webp(_capture_dir.path_join(label + ".webp"), false, 0.9)
	print("CAPTURE ", label, " screen=", img.get_size(), " hud=", _hud.size)

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
